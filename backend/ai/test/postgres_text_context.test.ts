// TEST ONLY protocol replies/faults/downstream ports, not hosted identity/content.
import { test } from "node:test";
import assert from "node:assert/strict";
import { getEventListeners } from "node:events";
import { setImmediate } from "node:timers/promises";
import {
  PostgresTextContextRepository,
  createPostgresTextContextRepository,
} from "../src/postgres_text_context.ts";
import type {
  PostgresConnection,
  PostgresResult,
} from "../src/postgres_connection.ts";
import type { Operation } from "../src/contracts.ts";
import { BoundaryError } from "../src/contracts.ts";
import type { PreparedContext } from "../src/ports.ts";
import { AiService } from "../src/service.ts";
import { contracts, fixtures, setup, userA, userB } from "./support.ts";
const signal = () => new AbortController().signal;
const op = "correct_sentence";
const request = () =>
  contracts.request(op, structuredClone(fixtures.correct_sentence_request));
const response = () =>
  contracts.response(op, structuredClone(fixtures.correct_sentence_response));
const ref = {
  item_type: "GRAMMAR" as const,
  item_id: "a1000000-0000-4000-8000-000000000001",
};
const context = (): PreparedContext => ({
  instruction: '{"jlpt_level":"N5","curriculum":[]}',
  transcript: [],
  allowedRefs: [ref],
});
function reply(text: string): PostgresResult {
  return {
    command: text.startsWith("SELECT") ? "SELECT" : text.split(" ")[0]!,
    rowCount: text.startsWith("SELECT") ? 1 : null,
    rows: text.includes(" AS context")
      ? [{ context: context() }]
      : text.includes(" AS checked")
        ? [{ checked: "" }]
        : [],
  };
}
function fixture() {
  let opened = 0,
    closed = 0;
  const calls: { text: string; values?: string[]; connection: number }[] = [];
  let connect = async () => {};
  let query = async (
    text: string,
    _values?: string[],
  ): Promise<PostgresResult> => reply(text);
  const factory = (): PostgresConnection => {
    const id = ++opened;
    return {
      connect: () => connect(),
      query: async (text, values) => {
        calls.push({ text, values, connection: id });
        return query(text, values);
      },
      close: () => {
        closed++;
      },
    };
  };
  return {
    factory,
    calls,
    setQuery: (fn: typeof query) => {
      query = fn;
    },
    setConnect: (fn: typeof connect) => {
      connect = fn;
    },
    opened: () => opened,
    closed: () => closed,
    repo: (timeout = 5000) =>
      new PostgresTextContextRepository(contracts, factory, timeout),
  };
}
async function failure(work: Promise<unknown>, code = "NETWORK_UNAVAILABLE") {
  await assert.rejects(work, (error: unknown) => {
    assert.ok(error instanceof BoundaryError);
    assert.equal(error.code, code);
    assert.equal(error.message, code);
    assert.ok(!JSON.stringify(error).includes("PRIVATE"));
    return true;
  });
}
test("text prepare and validation use fresh owned READ ONLY transactions with captured parameters", async () => {
  const f = fixture(),
    parent = new AbortController(),
    repo = f.repo();
  const ctx = await repo.prepare(
    userA.toUpperCase(),
    op,
    request(),
    parent.signal,
  );
  await repo.validateResult(
    userA,
    op,
    request(),
    response(),
    ctx,
    parent.signal,
  );
  assert.deepEqual(
    f.calls.slice(0, 5).map((c) => c.text),
    [
      "BEGIN ISOLATION LEVEL READ COMMITTED READ ONLY",
      "SET LOCAL ROLE service_role",
      "SET LOCAL lock_timeout = '1000ms'",
      "SET LOCAL statement_timeout = '2000ms'",
      "SET LOCAL idle_in_transaction_session_timeout = '3000ms'",
    ],
  );
  assert.deepEqual(f.calls[5]?.values, [userA, op, JSON.stringify(request())]);
  assert.equal(f.calls[6]?.text, "COMMIT");
  assert.deepEqual(f.calls[12]?.values, [
    userA,
    op,
    JSON.stringify(request()),
    JSON.stringify(ctx),
  ]);
  assert.equal(f.calls[13]?.text, "COMMIT");
  assert.equal(f.opened(), 2);
  assert.equal(f.closed(), 2);
  assert.equal(parent.signal.aborted, false);
  assert.equal(getEventListeners(parent.signal, "abort").length, 0);
  assert.ok(
    Object.isFrozen(ctx) &&
      Object.isFrozen(ctx.allowedRefs) &&
      Object.isFrozen(ctx.allowedRefs[0]),
  );
});
test("both text operations compose with service without retaining a connection during provider IO", async () => {
  for (const operation of ["tutor_explain", "correct_sentence"] as const) {
    const f = fixture(),
      s = setup();
    s.deps.context = f.repo();
    const old = s.deps.provider.generate;
    s.deps.provider.generate = async (input, parent) => {
      assert.equal(f.opened(), 1);
      assert.equal(f.closed(), 1);
      assert.equal(f.calls.at(-1)?.text, "COMMIT");
      assert.equal(input.context.sessionId, undefined);
      return old(input, parent);
    };
    const result = await new AiService(contracts, s.deps).execute(
      operation,
      "valid-A",
      JSON.stringify(fixtures[`${operation}_request`]),
    );
    assert.equal(result.ok, true);
    assert.equal(s.calls.length, 1);
    assert.equal(f.opened(), 2);
    assert.equal(f.closed(), 2);
    assert.equal(s.store.rows.size, 0);
  }
});
test("text request and returned context are independent captured snapshots", async () => {
  const f = fixture(),
    original = request(),
    stored = { ...context(), allowedRefs: [{ ...ref }] };
  let release!: () => void, arrived!: () => void;
  const barrier = new Promise<void>((r) => {
    arrived = r;
  });
  f.setConnect(
    async () =>
      new Promise<void>((r) => {
        release = r;
        arrived();
      }),
  );
  f.setQuery(async (text) =>
    text.includes(" AS context")
      ? { command: "SELECT", rowCount: 1, rows: [{ context: stored }] }
      : reply(text),
  );
  const work = f.repo().prepare(userA, op, original, signal());
  await barrier;
  (original as { sentence_ja: string }).sentence_ja = "PRIVATE changed";
  release();
  const result = await work;
  stored.allowedRefs[0]!.item_id = userB;
  assert.notEqual(
    JSON.parse(f.calls[5]!.values![2]!).sentence_ja,
    "PRIVATE changed",
  );
  assert.equal(result.allowedRefs[0]?.item_id, ref.item_id);
});
test("text pre-abort invalid identity request or unsupported mutation never allocates a connection", async () => {
  const f = fixture(),
    parent = new AbortController();
  parent.abort("PRIVATE");
  await failure(f.repo().prepare(userA, op, request(), parent.signal));
  await failure(
    f.repo().prepare("bad", op, request(), signal()),
    "INTERNAL_ERROR",
  );
  await failure(
    f
      .repo()
      .prepare(
        userA,
        op,
        { ...request(), user_id: userB } as ReturnType<typeof request>,
        signal(),
      ),
    "VALIDATION_FAILURE",
  );
  for (const operation of [
    "start_conversation",
    "conversation_turn",
    "finish_conversation",
    "other",
  ] as Operation[])
    await failure(
      f
        .repo()
        .prepare(
          userA,
          operation,
          contracts.request(
            "start_conversation",
            fixtures.start_conversation_request,
          ),
          signal(),
        ),
      "PROVIDER_UNAVAILABLE",
    );
  assert.equal(f.opened(), 0);
  assert.equal(getEventListeners(parent.signal, "abort").length, 0);
  for (const timeout of [0, 15001, NaN, 0.1])
    assert.throws(() => f.repo(timeout), {
      message: "Invalid text context timeout",
    });
});
for (let phase = -1; phase < 7; phase++)
  test(`text protocol failure at phase${phase} closes without retry or provider dispatch`, async () => {
    const f = fixture();
    let index = 0;
    if (phase < 0)
      f.setConnect(async () => {
        throw new Error("PRIVATE credentials");
      });
    f.setQuery(async (text) => {
      if (index++ === phase)
        throw Object.assign(new Error("PRIVATE SQL"), { code: "42501" });
      return reply(text);
    });
    const state = setup();
    state.deps.context = f.repo();
    const outcome = await new AiService(contracts, state.deps).execute(
      op,
      "valid-A",
      JSON.stringify(request()),
    );
    assert.equal(outcome.ok, false);
    if (!outcome.ok) assert.equal(outcome.error.code, "NETWORK_UNAVAILABLE");
    assert.equal(state.calls.length, 0);
    assert.equal(f.opened(), 1);
    assert.equal(f.closed(), 1);
    assert.equal(f.calls.length, phase < 0 ? 0 : phase + 1);
    assert.ok(!JSON.stringify(outcome).includes("PRIVATE"));
  });
test("text SQL errors map only exact fixed helper code and message pairs", async () => {
  for (const [code, message] of [
    ["22023", "VALIDATION_FAILURE"],
    ["42501", "FORBIDDEN"],
    ["P0002", "NOT_FOUND"],
    ["P0001", "SYNC_CONFLICT"],
  ]) {
    const f = fixture();
    f.setQuery(async (text) => {
      if (text.startsWith("SELECT"))
        throw Object.assign(new Error(message), { code });
      return reply(text);
    });
    await failure(f.repo().prepare(userA, op, request(), signal()), message);
    assert.equal(f.calls.at(-1)?.text.startsWith("SELECT"), true);
    assert.equal(f.closed(), 1);
    f.setQuery(async (text) => {
      if (text.startsWith("SELECT"))
        throw Object.assign(new Error("PRIVATE details"), { code });
      return reply(text);
    });
    await failure(f.repo().prepare(userA, op, request(), signal()));
  }
});
test("text malformed SQL projection and COMMIT-as-ROLLBACK never return context", async () => {
  for (const value of [
    null,
    [],
    {},
    { ...context(), sessionId: userB },
    { ...context(), instruction: 1 },
    { ...context(), transcript: [{ role: "user", text_ja: "PRIVATE" }] },
    { ...context(), allowedRefs: [{ ...ref, item_type: "KANJI" }] },
    { ...context(), allowedRefs: [{ ...ref, item_id: "bad" }] },
    { ...context(), allowedRefs: [ref, ref] },
    { ...context(), allowedRefs: Array.from({ length: 201 }, () => ref) },
    { ...context(), instruction: "x".repeat(10001) },
  ]) {
    const f = fixture();
    f.setQuery(async (text) =>
      text.startsWith("SELECT")
        ? { command: "SELECT", rowCount: 1, rows: [{ context: value }] }
        : reply(text),
    );
    await failure(f.repo().prepare(userA, op, request(), signal()));
    assert.equal(f.closed(), 1);
    assert.ok(!f.calls.some((c) => c.text === "COMMIT"));
  }
  for (const r of [
    { command: "SELECT", rowCount: 0, rows: [] },
    {
      command: "SELECT",
      rowCount: 1,
      rows: [{ context: context(), owner: userB }],
    },
    { command: "UPDATE", rowCount: 1, rows: [{ context: context() }] },
  ]) {
    const f = fixture();
    f.setQuery(async (text) => (text.startsWith("SELECT") ? r : reply(text)));
    await failure(f.repo().prepare(userA, op, request(), signal()));
  }
  const f = fixture();
  f.setQuery(async (text) =>
    text === "COMMIT" ? reply("ROLLBACK") : reply(text),
  );
  await failure(f.repo().prepare(userA, op, request(), signal()));
  assert.equal(f.closed(), 1);
});
test("text deadline bounds ignored connect and timer-starving synchronous work", async () => {
  const f = fixture();
  let release!: () => void;
  f.setConnect(
    async () =>
      new Promise<void>((r) => {
        release = r;
      }),
  );
  await failure(f.repo(5).prepare(userA, op, request(), signal()));
  release();
  await setImmediate();
  assert.equal(f.calls.length, 0);
  assert.equal(f.closed(), 1);
  const g = fixture();
  g.setConnect(async () => {
    const t = performance.now();
    while (performance.now() - t < 15) {
      /* TEST ONLY */
    }
  });
  await failure(g.repo(5).prepare(userA, op, request(), signal()));
  assert.equal(g.calls.length, 0);
  assert.equal(g.closed(), 1);
});
test("text abort during SELECT or COMMIT rejects late completion and cleans listeners", async () => {
  for (const held of ["SELECT", "COMMIT"]) {
    const f = fixture(),
      parent = new AbortController();
    let release!: (r: PostgresResult) => void, arrived!: () => void;
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
    const work = f.repo().prepare(userA, op, request(), parent.signal),
      rejected = failure(work);
    await barrier;
    parent.abort("PRIVATE");
    await rejected;
    const count = f.calls.length;
    release(
      reply(
        held === "SELECT" ? "SELECT private.ai_text_context AS context" : held,
      ),
    );
    await setImmediate();
    assert.equal(f.calls.length, count);
    assert.equal(f.closed(), 1);
    assert.equal(getEventListeners(parent.signal, "abort").length, 0);
  }
});
test("text validation rejects invalid wire response and non-allowlisted refs before SQL", async () => {
  const f = fixture(),
    invalid = {
      ...response(),
      grammar_errors: [
        {
          original_text: "文",
          corrected_text: "文",
          explanation_vi: "sửa",
          item_refs: [{ ...ref, item_id: userB }],
        },
      ],
    };
  await failure(
    f.repo().validateResult(userA, op, request(), invalid, context(), signal()),
    "PROVIDER_UNAVAILABLE",
  );
  await failure(
    f
      .repo()
      .validateResult(
        userA,
        op,
        request(),
        { ...response(), corrected_sentence: 0 } as unknown as ReturnType<
          typeof response
        >,
        context(),
        signal(),
      ),
    "PROVIDER_UNAVAILABLE",
  );
  assert.equal(f.opened(), 0);
});
test("text revalidation waits for commit and never accepts malformed confirmation", async () => {
  const f = fixture();
  f.setQuery(async (text) =>
    text.includes(" AS checked")
      ? { command: "SELECT", rowCount: 1, rows: [{ checked: true }] }
      : reply(text),
  );
  await failure(
    f
      .repo()
      .validateResult(userA, op, request(), response(), context(), signal()),
  );
  assert.ok(!f.calls.some((c) => c.text === "COMMIT"));
  for (const mode of ["conflict", "lost-commit"]) {
    const g = fixture();
    g.setQuery(async (text) => {
      if (text.includes(" AS checked") && mode === "conflict")
        throw Object.assign(new Error("SYNC_CONFLICT"), { code: "P0001" });
      if (text === "COMMIT" && g.opened() === 2 && mode === "lost-commit")
        throw new Error("PRIVATE lost delivery");
      return reply(text);
    });
    const s = setup();
    s.deps.context = g.repo();
    const outcome = await new AiService(contracts, s.deps).execute(
      op,
      "valid-A",
      JSON.stringify(request()),
    );
    assert.equal(outcome.ok, false);
    if (!outcome.ok)
      assert.equal(
        outcome.error.code,
        mode === "conflict" ? "SYNC_CONFLICT" : "NETWORK_UNAVAILABLE",
      );
    assert.equal(s.calls.length, 1);
    assert.equal(g.opened(), 2);
    assert.equal(g.closed(), 2);
    assert.equal(s.store.rows.size, 0);
  }
});
test("text A B A calls have no identity/context cache and share fixed verified-TLS configuration", async () => {
  const f = fixture(),
    repo = f.repo();
  for (const user of [userA, userB, userA])
    await repo.prepare(user, op, request(), signal());
  assert.deepEqual(
    f.calls.filter((c) => c.values).map((c) => c.values![0]),
    [userA, userB, userA],
  );
  assert.equal(f.opened(), 3);
  assert.equal(f.closed(), 3);
  for (const url of [
    "bad",
    "postgres://host/db",
    "postgres://a:b@host/db?sslmode=disable",
    "postgres://a:b@host/db#",
    "postgres://a:b@%2Ftmp/db",
  ])
    assert.throws(() => createPostgresTextContextRepository(contracts, url), {
      message: "Invalid trusted PostgreSQL configuration",
    });
  assert.doesNotThrow(() =>
    createPostgresTextContextRepository(
      contracts,
      "postgres://a:b@localhost/db",
    ),
  );
  await failure(
    new PostgresTextContextRepository(contracts, () => {
      throw new Error("PRIVATE allocation");
    }).prepare(userA, op, request(), signal()),
  );
});
