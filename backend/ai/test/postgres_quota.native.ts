// TEST ONLY disposable PostgreSQL17 transport/Auth/provider ports. No hosted calls.
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { setTimeout as delay } from "node:timers/promises";
import { Client } from "pg";
import {
  PostgresQuotaLimiter,
  createPostgresQuotaLimiter,
} from "../src/postgres_quota.ts";
import type { QuotaConnection, QuotaResult } from "../src/postgres_quota.ts";
import { BoundaryError, operations } from "../src/contracts.ts";
import { AiService } from "../src/service.ts";
import { setup, contracts, fixtures } from "./support.ts";
const databaseUrl = process.env.TEST_DATABASE_URL;
// Refuse hosted/prod use of this disposable fixture script.
if (
  databaseUrl !== "postgresql://postgres:postgres@localhost:5432/nihongo_test"
)
  throw new Error(
    "Native quota test requires the fixed disposable CI database",
  );
const signal = () => new AbortController().signal;
function client(name = "nd-quota-native-admin") {
  const c = new Client({
    connectionString: databaseUrl,
    ssl: false,
    application_name: name,
    connectionTimeoutMillis: 2000,
    query_timeout: 3000,
    pipeline: false,
  });
  c.on("error", () => {});
  return c;
}
async function admin(text: string, values?: string[]) {
  const c = client();
  try {
    await c.connect();
    return await c.query(text, values);
  } finally {
    await c.end();
  }
}
async function owner(lastSlot = false) {
  const id = randomUUID();
  await admin("INSERT INTO auth.users(id) VALUES($1::uuid)", [id]);
  if (lastSlot)
    await admin(
      "INSERT INTO private.ai_rate_buckets VALUES($1::uuid,10,clock_timestamp(),(clock_timestamp() AT TIME ZONE 'UTC')::date,99)",
      [id],
    );
  return id;
}
function connection(
  name = "nd-quota-native",
  observe?: (
    text: string,
    execute: () => Promise<QuotaResult>,
  ) => Promise<QuotaResult>,
): QuotaConnection {
  const c = client(name);
  return {
    connect: async () => {
      await c.connect();
    },
    query: async (text, values) => {
      const execute = async () => {
        const r = await c.query(text, values);
        if (text === "COMMIT") assert.equal(c.getTransactionStatus(), "I");
        return r;
      };
      return observe ? observe(text, execute) : execute();
    },
    close: () => {
      void c.end().catch(() => {});
    },
  };
}
async function observeWait(name: string) {
  const deadline = performance.now() + 2000;
  while (performance.now() < deadline) {
    const r = await admin(
      "SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name=$1 AND wait_event_type='Lock') AS waiting",
      [name],
    );
    if (r.rows[0]?.waiting === true) return;
    await delay(10);
  }
  assert.fail(
    "Actual limiter was not observed waiting on its native quota lock",
  );
}
function safeFailure(error: unknown) {
  assert.ok(error instanceof BoundaryError);
  assert.equal(error.code, "NETWORK_UNAVAILABLE");
  assert.equal(error.message, "NETWORK_UNAVAILABLE");
  return true;
}
test("native driver shares all five operations and A B A budgets across fresh owned clients", async () => {
  const a = await owner(),
    b = await owner();
  const limiter = new PostgresQuotaLimiter(() => connection());
  for (const op of operations)
    assert.equal(await limiter.consume(a, op, signal()), true);
  assert.equal(await limiter.consume(b, "tutor_explain", signal()), true);
  assert.equal(
    await new PostgresQuotaLimiter(() => connection()).consume(
      a,
      "finish_conversation",
      signal(),
    ),
    true,
  );
  const r = await admin(
    "SELECT user_id,used_today FROM private.ai_rate_buckets WHERE user_id IN($1::uuid,$2::uuid)",
    [a, b],
  );
  assert.equal(r.rows.length, 2);
  assert.equal(r.rows.find((v) => v.user_id === a)?.used_today, 6);
  assert.equal(r.rows.find((v) => v.user_id === b)?.used_today, 1);
});
test("native quota COMMIT barrier prevents provider dispatch and serializes the last slot", async () => {
  const a = await owner(true),
    b = await owner();
  let arrived!: () => void, release!: () => void;
  const barrier = new Promise<void>((r) => {
      arrived = r;
    }),
    gate = new Promise<void>((r) => {
      release = r;
    });
  const first = new PostgresQuotaLimiter(() =>
    connection("nd-quota-native-first", async (text, execute) => {
      if (text === "COMMIT") {
        arrived();
        await gate;
      }
      return execute();
    }),
  );
  const state = setup();
  state.deps.auth.verify = async () => ({ id: a });
  state.deps.limiter = first;
  const result = new AiService(contracts, state.deps).execute(
    "start_conversation",
    "TEST_ONLY",
    JSON.stringify(fixtures.start_conversation_request),
  );
  const name = "nd-quota-native-wait-" + randomUUID();
  let second: Promise<{ value?: boolean; error?: unknown }> | undefined;
  try {
    await Promise.race([
      barrier,
      result.then(() => {
        throw new Error(
          "First service call finished before the actual COMMIT barrier",
        );
      }),
    ]);
    assert.equal(state.calls.length, 0);
    assert.equal(state.store.rows.size, 0);
    second = new PostgresQuotaLimiter(() => connection(name))
      .consume(a, "tutor_explain", signal())
      .then(
        (value) => ({ value }),
        (error) => ({ error }),
      );
    await observeWait(name);
    assert.equal(
      await new PostgresQuotaLimiter(() => connection()).consume(
        b,
        "finish_conversation",
        signal(),
      ),
      true,
    );
    assert.equal(state.calls.length, 0);
  } finally {
    release();
  }
  assert.equal((await result).ok, true);
  assert.equal(state.calls.length, 1);
  assert.ok(second);
  assert.deepEqual(await second, { value: false });
  assert.equal(
    (
      await admin(
        "SELECT used_today FROM private.ai_rate_buckets WHERE user_id=$1",
        [a],
      )
    ).rows[0]?.used_today,
    100,
  );
  assert.equal(
    await new PostgresQuotaLimiter(() => connection()).consume(
      a,
      "finish_conversation",
      signal(),
    ),
    false,
  );
});
test("native abort while locked rolls back and cannot debit after late lock release", async () => {
  const a = await owner(true),
    blocker = client();
  await blocker.connect();
  await blocker.query("BEGIN");
  await blocker.query(
    "SELECT * FROM private.ai_rate_buckets WHERE user_id=$1 FOR UPDATE",
    [a],
  );
  const parent = new AbortController(),
    name = "nd-quota-native-abort-" + randomUUID();
  const result = new PostgresQuotaLimiter(() => connection(name)).consume(
    a,
    "conversation_turn",
    parent.signal,
  );
  const rejected = assert.rejects(result, safeFailure);
  try {
    await observeWait(name);
    parent.abort("TEST_ONLY");
    await rejected;
  } finally {
    parent.abort();
    await blocker.query("COMMIT");
    await blocker.end();
  }
  assert.equal(
    (
      await admin(
        "SELECT used_today FROM private.ai_rate_buckets WHERE user_id=$1",
        [a],
      )
    ).rows[0]?.used_today,
    99,
  );
  assert.equal(
    await new PostgresQuotaLimiter(() => connection()).consume(
      a,
      "finish_conversation",
      signal(),
    ),
    true,
  );
});
test("actual committed debit with injected lost COMMIT delivery never dispatches or retries", async () => {
  const a = await owner(true);
  let consumptions = 0;
  const limiter = new PostgresQuotaLimiter(() =>
    connection("nd-quota-native-lost-ack", async (text, execute) => {
      const r = await execute();
      if (text.startsWith("SELECT private.consume_ai_quota")) consumptions++;
      if (text === "COMMIT")
        throw new Error("TEST_ONLY lost delivery after actual commit");
      return r;
    }),
  );
  const state = setup();
  state.deps.auth.verify = async () => ({ id: a });
  state.deps.limiter = limiter;
  const outcome = await new AiService(contracts, state.deps).execute(
    "start_conversation",
    "TEST_ONLY",
    JSON.stringify(fixtures.start_conversation_request),
  );
  assert.equal(outcome.ok, false);
  if (!outcome.ok) assert.equal(outcome.error.code, "NETWORK_UNAVAILABLE");
  assert.equal(consumptions, 1);
  assert.equal(state.calls.length, 0);
  assert.equal(state.store.rows.size, 0);
  assert.equal(
    (
      await admin(
        "SELECT used_today FROM private.ai_rate_buckets WHERE user_id=$1",
        [a],
      )
    ).rows[0]?.used_today,
    100,
  );
  assert.equal(
    await new PostgresQuotaLimiter(() => connection()).consume(
      a,
      "tutor_explain",
      signal(),
    ),
    false,
  );
});
test("deployment factory refuses plaintext PostgreSQL without TLS and never falls back", async () => {
  const a = await owner();
  await assert.rejects(
    createPostgresQuotaLimiter(databaseUrl!).consume(
      a,
      "tutor_explain",
      signal(),
    ),
    safeFailure,
  );
  assert.equal(
    (
      await admin(
        "SELECT count(*)::integer AS count FROM private.ai_rate_buckets WHERE user_id=$1",
        [a],
      )
    ).rows[0]?.count,
    0,
  );
});
