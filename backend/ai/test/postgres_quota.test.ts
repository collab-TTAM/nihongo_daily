// TEST ONLY protocol faults/downstream ports; no memory quota implementation.
import { test } from "node:test";
import assert from "node:assert/strict";
import { getEventListeners } from "node:events";
import { setImmediate } from "node:timers/promises";
import {
  PostgresQuotaLimiter,
  createPostgresQuotaLimiter,
} from "../src/postgres_quota.ts";
import type { QuotaConnection, QuotaResult } from "../src/postgres_quota.ts";
import { BoundaryError } from "../src/contracts.ts";
import type { Operation } from "../src/contracts.ts";
import { AiService } from "../src/service.ts";
import { setup, contracts, fixtures, userA, userB } from "./support.ts";

const freshSignal = () => new AbortController().signal;
function reply(text: string, allowed = true): QuotaResult {
  return {
    command: text.startsWith("SELECT") ? "SELECT" : text.split(" ")[0]!,
    rowCount: text.startsWith("SELECT") ? 1 : null,
    rows: text.startsWith("SELECT") ? [{ allowed }] : [],
  };
}
function fixture() {
  const calls: { text: string; values?: string[] }[] = [];
  let closed = 0;
  let connections = 0;
  let onQuery = async (text: string): Promise<QuotaResult> => reply(text);
  let onConnect = async () => {};
  const factory = (): QuotaConnection => {
    connections++;
    return {
      connect: () => onConnect(),
      query: async (text, values) => {
        calls.push({ text, values });
        return onQuery(text);
      },
      close: () => {
        closed++;
      },
    };
  };
  return {
    factory,
    calls,
    setQuery: (fn: typeof onQuery) => {
      onQuery = fn;
    },
    setConnect: (fn: typeof onConnect) => {
      onConnect = fn;
    },
    closed: () => closed,
    connections: () => connections,
  };
}
async function failure(result: Promise<unknown>, code = "NETWORK_UNAVAILABLE") {
  await assert.rejects(result, (error: unknown) => {
    assert.ok(error instanceof BoundaryError);
    assert.equal(error.code, code);
    assert.equal(error.message, code);
    assert.ok(!JSON.stringify(error).includes("PRIVATE"));
    return true;
  });
}

test("quota uses fixed role/isolation/deadlines and parameterized verified owner before confirmed commit", async () => {
  const f = fixture();
  const controller = new AbortController();
  const limiter = new PostgresQuotaLimiter(f.factory);
  assert.equal(
    await limiter.consume(
      userA.toUpperCase(),
      "conversation_turn",
      controller.signal,
    ),
    true,
  );
  assert.deepEqual(
    f.calls.map((c) => c.text),
    [
      "BEGIN ISOLATION LEVEL READ COMMITTED",
      "SET LOCAL ROLE service_role",
      "SET LOCAL lock_timeout = '1000ms'",
      "SET LOCAL statement_timeout = '2000ms'",
      "SET LOCAL idle_in_transaction_session_timeout = '3000ms'",
      "SELECT private.consume_ai_quota($1::uuid,$2::text) AS allowed",
      "COMMIT",
    ],
  );
  assert.deepEqual(f.calls[5]?.values, [userA, "conversation_turn"]);
  assert.equal(f.closed(), 1);
  assert.equal(controller.signal.aborted, false);
  assert.equal(getEventListeners(controller.signal, "abort").length, 0);
});
test("quota waits for COMMIT delivery before returning allowed", async () => {
  const f = fixture();
  let release!: (r: QuotaResult) => void;
  let arrived!: () => void;
  const commit = new Promise<void>((r) => {
    arrived = r;
  });
  f.setQuery(async (text) =>
    text === "COMMIT"
      ? new Promise((r) => {
          release = r;
          arrived();
        })
      : reply(text),
  );
  let settled = false;
  const result = new PostgresQuotaLimiter(f.factory)
    .consume(userA, "start_conversation", freshSignal())
    .then((v) => {
      settled = true;
      return v;
    });
  await commit;
  await setImmediate();
  assert.equal(settled, false);
  assert.equal(f.closed(), 0);
  release(reply("COMMIT"));
  assert.equal(await result, true);
  assert.equal(f.closed(), 1);
});
test("quota denial is confirmed with commit then returns false", async () => {
  const f = fixture();
  f.setQuery(async (text) => reply(text, false));
  assert.equal(
    await new PostgresQuotaLimiter(f.factory).consume(
      userA,
      "tutor_explain",
      freshSignal(),
    ),
    false,
  );
  assert.equal(f.calls.at(-1)?.text, "COMMIT");
  assert.equal(f.closed(), 1);
});
for (let phase = -1; phase < 7; phase++)
  test(`quota protocol failure at phase${phase} closes once and never retries`, async () => {
    const f = fixture();
    let queries = 0;
    if (phase < 0)
      f.setConnect(async () => {
        throw new Error("PRIVATE credentials");
      });
    f.setQuery(async (text) => {
      if (queries++ === phase) throw new Error("PRIVATE SQL");
      return reply(text);
    });
    await failure(
      new PostgresQuotaLimiter(f.factory).consume(
        userA,
        "start_conversation",
        freshSignal(),
      ),
    );
    assert.equal(f.connections(), 1);
    assert.equal(f.closed(), 1);
    assert.equal(f.calls.length, phase < 0 ? 0 : phase + 1);
  });
test("quota rejects malformed result shapes and COMMIT returning rollback", async () => {
  const invalid: QuotaResult[] = [
    { command: "SELECT", rowCount: 0, rows: [] },
    { command: "SELECT", rowCount: 1, rows: [{ allowed: "true" }] },
    {
      command: "SELECT",
      rowCount: 2,
      rows: [{ allowed: true }, { allowed: true }],
    },
    { command: "SELECT", rowCount: 1, rows: [{ allowed: true, owner: userB }] },
    { command: "UPDATE", rowCount: 1, rows: [{ allowed: true }] },
  ];
  for (const value of invalid) {
    const f = fixture();
    f.setQuery(async (text) =>
      text.startsWith("SELECT") ? value : reply(text),
    );
    await failure(
      new PostgresQuotaLimiter(f.factory).consume(
        userA,
        "finish_conversation",
        freshSignal(),
      ),
    );
    assert.ok(!f.calls.some((c) => c.text === "COMMIT"));
    assert.equal(f.closed(), 1);
  }
  const f = fixture();
  f.setQuery(async (text) =>
    text === "COMMIT" ? reply("ROLLBACK") : reply(text),
  );
  await failure(
    new PostgresQuotaLimiter(f.factory).consume(
      userA,
      "finish_conversation",
      freshSignal(),
    ),
  );
  assert.equal(f.closed(), 1);
});
test("quota deadline bounds ignored connect; late resolution cannot send SQL", async () => {
  const f = fixture();
  let release!: () => void;
  f.setConnect(
    async () =>
      new Promise<void>((r) => {
        release = r;
      }),
  );
  await failure(
    new PostgresQuotaLimiter(f.factory, 5).consume(
      userA,
      "tutor_explain",
      freshSignal(),
    ),
  );
  release();
  await setImmediate();
  assert.equal(f.calls.length, 0);
  assert.equal(f.closed(), 1);
});
test("quota cancellation during query or commit rejects late success without redispatch", async () => {
  for (const held of ["SELECT", "COMMIT"]) {
    const f = fixture();
    const parent = new AbortController();
    let release!: (r: QuotaResult) => void;
    let arrived!: () => void;
    const barrier = new Promise<void>((r) => {
      arrived = r;
    });
    f.setQuery(async (text) =>
      text.startsWith(held)
        ? new Promise((r) => {
            release = r;
            arrived();
          })
        : reply(text),
    );
    const result = new PostgresQuotaLimiter(f.factory).consume(
      userA,
      "start_conversation",
      parent.signal,
    );
    const rejected = failure(result);
    await barrier;
    parent.abort("PRIVATE reason");
    await rejected;
    const count = f.calls.length;
    release(reply(held));
    await setImmediate();
    assert.equal(f.calls.length, count);
    assert.equal(f.closed(), 1);
    assert.equal(getEventListeners(parent.signal, "abort").length, 0);
  }
});
test("quota monotonic deadline catches synchronous driver work that starves timers", async () => {
  const f = fixture();
  f.setConnect(async () => {
    const start = performance.now();
    while (performance.now() - start < 15) {
      /* TEST ONLY hostile synchronous driver. */
    }
  });
  await failure(
    new PostgresQuotaLimiter(f.factory, 5).consume(
      userA,
      "tutor_explain",
      freshSignal(),
    ),
  );
  assert.equal(f.calls.length, 0);
  assert.equal(f.closed(), 1);
});
test("quota pre-abort/invalid owner/op never allocates a connection", async () => {
  const f = fixture();
  const parent = new AbortController();
  parent.abort("PRIVATE");
  const limiter = new PostgresQuotaLimiter(f.factory);
  await failure(limiter.consume(userA, "tutor_explain", parent.signal));
  await failure(
    limiter.consume("bad", "tutor_explain", freshSignal()),
    "INTERNAL_ERROR",
  );
  await failure(
    limiter.consume(userA, "arbitrary" as Operation, freshSignal()),
    "INTERNAL_ERROR",
  );
  assert.equal(f.connections(), 0);
  assert.equal(getEventListeners(parent.signal, "abort").length, 0);
  for (const t of [0, 15001, NaN, 0.5])
    assert.throws(() => new PostgresQuotaLimiter(f.factory, t), {
      message: "Invalid quota timeout",
    });
});
test("quota factory failures are safe; trusted URL rejects TLS overrides and socket hosts", async () => {
  await failure(
    new PostgresQuotaLimiter(() => {
      throw new Error("PRIVATE password");
    }).consume(userA, "tutor_explain", freshSignal()),
  );
  for (const url of [
    "bad",
    "http://a:b@host/db",
    "postgres://host/db",
    "postgres://a:b@host/",
    "postgres://a:b@host/db?sslmode=disable",
    "postgres://a:b@host/db?",
    "postgres://a:b@host/db#",
    "postgres://a:b@%2Ftmp/db",
    "postgres://a:b@bad_host/db",
    " postgres://a:b@host/db",
    "postgres://a:b@host/" + "x".repeat(8192),
  ])
    assert.throws(() => createPostgresQuotaLimiter(url), {
      message: "Invalid trusted quota database configuration",
    });
  for (const url of [
    "postgres://a:b@localhost/db",
    "postgresql://a:b@[::1]:5432/db",
  ])
    assert.doesNotThrow(() => createPostgresQuotaLimiter(url));
});
test("quota closes owned independent connections for A B A with no local identity/budget cache", async () => {
  const f = fixture();
  const limiter = new PostgresQuotaLimiter(f.factory);
  for (const owner of [userA, userB, userA])
    assert.equal(
      await limiter.consume(owner, "tutor_explain", freshSignal()),
      true,
    );
  assert.equal(f.connections(), 3);
  assert.equal(f.closed(), 3);
  assert.deepEqual(
    f.calls.filter((c) => c.values).map((c) => c.values?.[0]),
    [userA, userB, userA],
  );
});
test("service cannot dispatch provider on quota denial or uncertain COMMIT", async () => {
  for (const mode of ["deny", "uncertain"]) {
    const f = fixture();
    f.setQuery(async (text) => {
      if (mode === "uncertain" && text === "COMMIT")
        throw new Error("PRIVATE lost commit ack");
      return reply(text, mode !== "deny");
    });
    const state = setup();
    state.deps.limiter = new PostgresQuotaLimiter(f.factory);
    const result = await new AiService(contracts, state.deps).execute(
      "start_conversation",
      "valid-A",
      JSON.stringify(fixtures.start_conversation_request),
    );
    assert.equal(result.ok, false);
    if (!result.ok)
      assert.equal(
        result.error.code,
        mode === "deny" ? "RATE_LIMITED" : "NETWORK_UNAVAILABLE",
      );
    assert.equal(state.calls.length, 0);
    assert.equal(state.store.rows.size, 0);
    assert.equal(f.connections(), 1);
    assert.ok(!JSON.stringify(result).includes("PRIVATE"));
  }
});
