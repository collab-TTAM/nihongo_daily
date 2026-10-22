// TEST ONLY disposable PostgreSQL17/plaintext, Auth and provider; never hosted proof.
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { setTimeout as delay } from "node:timers/promises";
import { Client } from "pg";
import {
  PostgresConversationStore,
  createPostgresConversationStore,
} from "../src/postgres_conversation.ts";
import { PostgresQuotaLimiter } from "../src/postgres_quota.ts";
import type {
  PostgresConnection,
  PostgresResult,
} from "../src/postgres_connection.ts";
import type { Mutation, Requests, Responses } from "../src/contracts.ts";
import type { ProviderInput } from "../src/ports.ts";
import { BoundaryError } from "../src/contracts.ts";
import { AiService } from "../src/service.ts";
import { contracts, setup } from "./support.ts";
const databaseUrl = process.env.TEST_DATABASE_URL;
if (
  databaseUrl !== "postgresql://postgres:postgres@localhost:5432/nihongo_test"
)
  throw Error("Native conversation requires the fixed disposable CI database");
function client(name = "nd-conv-admin") {
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
type Observe = (
  phase: number,
  text: string,
  execute: () => Promise<PostgresResult>,
) => Promise<PostgresResult>;
function transport(observe?: Observe) {
  let opened = 0,
    closed = 0;
  const name = "nd-conv-native-" + randomUUID();
  const factory = (): PostgresConnection => {
    const c = client(name),
      phase = ++opened;
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
        return observe ? observe(phase, text, execute) : execute();
      },
      close: () => {
        closed++;
        void c.end().catch(() => {});
      },
    };
  };
  return { factory, name, opened: () => opened, closed: () => closed };
}
async function fixture(level = "N5") {
  const user = randomUUID(),
    scenario = randomUUID();
  await admin("INSERT INTO auth.users(id) VALUES($1::uuid)", [user]);
  await admin(
    "INSERT INTO public.profiles(id,preferred_jlpt) VALUES($1::uuid,$2::public.jlpt_level)",
    [user, level],
  );
  await admin(
    "INSERT INTO public.conversation_scenarios(id,jlpt_level,difficulty,content_version,is_active,title_vi,title_ja,description_vi,system_context) VALUES($1::uuid,$2::public.jlpt_level,0,1,true,'fixture','会話','fixture','固定文脈')",
    [scenario, level],
  );
  return { user, scenario, level };
}
function start(
  f: Awaited<ReturnType<typeof fixture>>,
): Requests["start_conversation"] {
  return {
    scenario_id: f.scenario,
    jlpt_level: f.level as "N5",
    client_event_id: randomUUID(),
  };
}
function generated(input: ProviderInput): Responses[Mutation] {
  if (input.operation === "finish_conversation")
    return {
      scores: { grammar: 80, vocabulary: 90, fluency: 75 },
      errors: [],
      strengths_vi: [],
      focus_next_vi: [],
      srs_recommendations: [],
    };
  const message = {
    id: input.context.messageId!,
    role: "assistant" as const,
    text_ja: "こんにちは",
    text_vi: null,
    audio_ref: null,
    sequence_no: input.context.sequenceNo!,
  };
  return input.operation === "start_conversation"
    ? { session_id: input.context.sessionId!, assistant_message: message }
    : { assistant_message: message };
}
function service(
  f: Awaited<ReturnType<typeof fixture>>,
  t: ReturnType<typeof transport>,
  provider?: (input: ProviderInput) => Promise<string>,
) {
  const s = setup();
  const calls: ProviderInput[] = [];
  s.deps.auth = {
    verify: async (bearer) => (bearer === "fixture" ? { id: f.user } : null),
  };
  s.deps.limiter = new PostgresQuotaLimiter(t.factory);
  s.deps.conversations = new PostgresConversationStore(contracts, t.factory);
  s.deps.context = {
    prepare: async () => {
      assert.fail("split prepare");
    },
    validateResult: async () => {
      assert.fail("split validate");
    },
  };
  for (const method of ["lookup", "claim", "complete", "reconcile"] as const)
    s.store[method] = async () => {
      assert.fail("legacy receipt used");
    };
  s.deps.provider.generate = async (input) => {
    calls.push(input);
    assert.equal(
      (
        await admin(
          "SELECT count(*)::int AS n FROM pg_stat_activity WHERE application_name=$1 AND state LIKE 'idle in transaction%'",
          [t.name],
        )
      ).rows[0]?.n,
      0,
    );
    return provider ? provider(input) : JSON.stringify(generated(input));
  };
  const instance = new AiService(contracts, s.deps);
  return {
    calls,
    run: <O extends Mutation>(
      op: O,
      request: Requests[O],
      parent?: AbortSignal,
    ) => instance.execute(op, "fixture", JSON.stringify(request), parent),
  };
}
async function barrier(ready: () => boolean) {
  const deadline = performance.now() + 3000;
  while (!ready() && performance.now() < deadline) await delay(5);
  assert.ok(
    ready(),
    "Native conversation barrier did not arrive within its bound",
  );
}
async function waitForLock(name: string) {
  const deadline = performance.now() + 2000;
  while (performance.now() < deadline) {
    if (
      (
        await admin(
          "SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name=$1 AND wait_event_type='Lock') AS waiting",
          [name],
        )
      ).rows[0]?.waiting
    )
      return;
    await delay(10);
  }
  assert.fail(
    "Actual conversation adapter was not observed waiting on PostgreSQL lock",
  );
}

test(
  "native conversation real quota and all three atomic mutations persist and replay after closure retirement and profile change",
  { timeout: 20000 },
  async () => {
    const f = await fixture(),
      t = transport(),
      s = service(f, t);
    const req = start(f);
    const first = await s.run("start_conversation", req);
    assert.equal(first.ok, true);
    if (!first.ok) assert.fail();
    const turn = {
      session_id: first.response.session_id,
      client_event_id: randomUUID(),
      text_ja: "猫です",
    };
    const second = await s.run("conversation_turn", turn);
    assert.equal(second.ok, true);
    if (second.ok)
      assert.equal(second.response.assistant_message.sequence_no, 2);
    const finish = {
      session_id: first.response.session_id,
      client_event_id: randomUUID(),
    };
    const third = await s.run("finish_conversation", finish);
    assert.equal(third.ok, true);
    const state = await admin(
      "SELECT s.ended_at IS NOT NULL AS closed,(SELECT count(*)::int FROM public.conversation_messages m WHERE m.conversation_session_id=s.id) AS messages,(SELECT count(*)::int FROM public.operation_receipts o JOIN private.ai_conversation_reservations r ON r.receipt_id=o.id WHERE o.user_id=s.user_id AND o.status='COMPLETED' AND r.is_completed) AS receipts FROM public.conversation_sessions s WHERE s.id=$1::uuid",
      [first.response.session_id],
    );
    assert.deepEqual(state.rows, [{ closed: true, messages: 3, receipts: 3 }]);
    await admin(
      "UPDATE public.profiles SET preferred_jlpt='N4' WHERE id=$1::uuid",
      [f.user],
    );
    await admin(
      "UPDATE public.conversation_scenarios SET is_active=false WHERE id=$1::uuid",
      [f.scenario],
    );
    const restarted = service(f, transport());
    assert.deepEqual(await restarted.run("start_conversation", req), first);
    assert.deepEqual(await restarted.run("conversation_turn", turn), second);
    assert.deepEqual(await restarted.run("finish_conversation", finish), third);
    assert.equal(restarted.calls.length, 0);
    assert.equal(s.calls.length, 3);
    assert.equal(t.closed(), t.opened());
  },
);
test(
  "native same event pending and distinct turns or finish cannot overtake a real provider interval",
  { timeout: 20000 },
  async () => {
    const f = await fixture(),
      t = transport();
    let release!: (value: string) => void;
    let held: ProviderInput | undefined;
    const s = service(f, t, async (input) => {
      held = input;
      return new Promise((resolve) => {
        release = resolve;
      });
    });
    const req = start(f),
      work = s.run("start_conversation", req);
    await barrier(() => Boolean(release));
    const other = service(f, transport());
    const duplicate = await other.run("start_conversation", req);
    assert.equal(duplicate.ok, false);
    assert.equal(other.calls.length, 0);
    release(JSON.stringify(generated(held!)));
    const started = await work;
    assert.equal(started.ok, true);
    if (!started.ok) assert.fail();
    release = undefined!;
    const turn = {
      session_id: started.response.session_id,
      client_event_id: randomUUID(),
      text_ja: "文",
    };
    const work2 = s.run("conversation_turn", turn);
    await barrier(() => Boolean(release));
    const distinct = await other.run("conversation_turn", {
      ...turn,
      client_event_id: randomUUID(),
    });
    assert.equal(distinct.ok, false);
    if (!distinct.ok) assert.equal(distinct.error.code, "SYNC_CONFLICT");
    const finish = await other.run("finish_conversation", {
      session_id: turn.session_id,
      client_event_id: randomUUID(),
    });
    assert.equal(finish.ok, false);
    if (!finish.ok) assert.equal(finish.error.code, "SYNC_CONFLICT");
    assert.equal(other.calls.length, 0);
    release(JSON.stringify(generated(held!)));
    assert.equal((await work2).ok, true);
    assert.equal(
      (
        await admin(
          "SELECT count(*)::int AS n FROM public.conversation_messages WHERE conversation_session_id=$1::uuid",
          [turn.session_id],
        )
      ).rows[0]?.n,
      3,
    );
  },
);
for (const phase of [3, 4])
  test(
    `native actual COMMIT with injected lost delivery in ${phase === 3 ? "acquisition" : "completion"} never redispatches on fresh retry`,
    { timeout: 15000 },
    async () => {
      const f = await fixture();
      let lost = false;
      const t = transport(async (index, text, execute) => {
        const r = await execute();
        if (index === phase && text === "COMMIT") {
          lost = true;
          throw Error("TEST_ONLY_LOST_COMMIT_DELIVERY");
        }
        return r;
      });
      const s = service(f, t),
        req = start(f);
      const result = await s.run("start_conversation", req);
      assert.equal(lost, true);
      assert.equal(result.ok, false);
      if (!result.ok) assert.equal(result.error.code, "NETWORK_UNAVAILABLE");
      assert.equal(s.calls.length, phase === 3 ? 0 : 1);
      const retry = service(f, transport());
      const after = await retry.run("start_conversation", req);
      assert.equal(after.ok, phase === 4);
      assert.equal(retry.calls.length, 0);
      const rows = await admin(
        "SELECT o.status,r.is_completed,(SELECT count(*)::int FROM public.conversation_sessions s WHERE s.user_id=o.user_id) AS sessions FROM public.operation_receipts o JOIN private.ai_conversation_reservations r ON r.receipt_id=o.id WHERE o.user_id=$1::uuid",
        [f.user],
      );
      assert.deepEqual(rows.rows, [
        {
          status: phase === 3 ? "PENDING" : "COMPLETED",
          is_completed: phase === 4,
          sessions: phase === 3 ? 0 : 1,
        },
      ]);
    },
  );
test(
  "native source retirement after dispatch leaves pending and no public partial writes",
  { timeout: 15000 },
  async () => {
    const f = await fixture(),
      t = transport();
    const s = service(f, t, async (input) => {
      await admin(
        "UPDATE public.conversation_scenarios SET is_active=false WHERE id=$1::uuid",
        [f.scenario],
      );
      return JSON.stringify(generated(input));
    });
    const req = start(f),
      result = await s.run("start_conversation", req);
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.error.code, "NOT_FOUND");
    const retry = service(f, transport());
    assert.equal((await retry.run("start_conversation", req)).ok, false);
    assert.equal(retry.calls.length, 0);
    assert.equal(
      (
        await admin(
          "SELECT count(*)::int AS n FROM public.conversation_sessions WHERE user_id=$1::uuid",
          [f.user],
        )
      ).rows[0]?.n,
      0,
    );
    assert.equal(
      (
        await admin(
          "SELECT status FROM public.operation_receipts WHERE user_id=$1::uuid",
          [f.user],
        )
      ).rows[0]?.status,
      "PENDING",
    );
  },
);
test(
  "native cancellation of observed blocked acquisition terminates owned connection without late provider work",
  { timeout: 15000 },
  async () => {
    const f = await fixture(),
      t = transport(),
      s = service(f, t),
      parent = new AbortController(),
      locker = client();
    await locker.connect();
    try {
      await locker.query("BEGIN");
      await locker.query(
        "SELECT pg_advisory_xact_lock(hashtextextended('nihongo-ai-conversation:'||$1::text,0))",
        [f.user],
      );
      const work = s.run("start_conversation", start(f), parent.signal);
      await waitForLock(t.name);
      parent.abort();
      const result = await work;
      assert.equal(result.ok, false);
      await locker.query("ROLLBACK");
      await delay(30);
      assert.equal(s.calls.length, 0);
      assert.equal(
        (
          await admin(
            "SELECT count(*)::int AS n FROM public.operation_receipts WHERE user_id=$1::uuid",
            [f.user],
          )
        ).rows[0]?.n,
        0,
      );
      assert.equal(t.closed(), t.opened());
    } finally {
      await locker.end();
    }
  },
);
test(
  "native owners A B A stay isolated and cross-owner parent rejects before provider",
  { timeout: 20000 },
  async () => {
    const a = await fixture(),
      b = await fixture("N4"),
      t = transport();
    const sa = service(a, t),
      sb = service(b, t);
    const first = await sa.run("start_conversation", start(a));
    const other = await sb.run("start_conversation", start(b));
    assert.equal(first.ok, true);
    assert.equal(other.ok, true);
    if (!first.ok) assert.fail();
    const denied = await sb.run("conversation_turn", {
      session_id: first.response.session_id,
      client_event_id: randomUUID(),
      text_ja: "文",
    });
    assert.equal(denied.ok, false);
    if (!denied.ok) assert.equal(denied.error.code, "NOT_FOUND");
    assert.equal(sb.calls.length, 1);
    assert.equal(
      (
        await sa.run("conversation_turn", {
          session_id: first.response.session_id,
          client_event_id: randomUUID(),
          text_ja: "文",
        })
      ).ok,
      true,
    );
    assert.equal(sa.calls.length, 2);
    assert.equal(t.closed(), t.opened());
  },
);
test(
  "native production conversation TLS factory fails closed against disposable plaintext server",
  { timeout: 10000 },
  async () => {
    const f = await fixture(),
      req = start(f);
    const repo = createPostgresConversationStore(contracts, databaseUrl!);
    await assert.rejects(
      repo.acquire(
        {
          userId: f.user,
          operation: "start_conversation",
          eventId: req.client_event_id,
        },
        req,
        new AbortController().signal,
      ),
      (error: unknown) => {
        assert.ok(error instanceof BoundaryError);
        assert.equal(error.code, "NETWORK_UNAVAILABLE");
        return true;
      },
    );
  },
);
for (const phase of [3, 4])
  test(
    `native confirmed COMMIT delivery gates ${phase === 3 ? "provider" : "success"} with no open provider transaction`,
    { timeout: 15000 },
    async () => {
      const f = await fixture();
      let release!: (r: PostgresResult) => void;
      let committed: PostgresResult | undefined;
      const t = transport(async (index, text, execute) => {
        const r = await execute();
        if (index === phase && text === "COMMIT") {
          committed = r;
          return new Promise((resolve) => {
            release = resolve;
          });
        }
        return r;
      });
      const s = service(f, t);
      let done = false;
      const work = s.run("start_conversation", start(f)).then((r) => {
        done = true;
        return r;
      });
      await barrier(() => Boolean(release));
      assert.equal(done, false);
      assert.equal(s.calls.length, phase === 3 ? 0 : 1);
      const rows = await admin(
        "SELECT status FROM public.operation_receipts WHERE user_id=$1::uuid",
        [f.user],
      );
      assert.deepEqual(rows.rows, [
        { status: phase === 3 ? "PENDING" : "COMPLETED" },
      ]);
      release(committed!);
      assert.equal((await work).ok, true);
      assert.equal(s.calls.length, 1);
      assert.equal(t.closed(), t.opened());
    },
  );

// TEST ONLY structured result. No provider transport/authentication is exercised.
const recoverySignal = () => new AbortController().signal;
function recoveryKey(user: string, op: Mutation, request: Requests[Mutation]) {
  return {
    userId: user,
    operation: op,
    eventId: request.client_event_id.toLowerCase(),
  };
}
function recoveryStore(t = transport()) {
  return new PostgresConversationStore(contracts, t.factory);
}
async function pendingRecord(
  repo: PostgresConversationStore,
  key: ReturnType<typeof recoveryKey>,
  request: Requests[Mutation],
) {
  const found = await repo.lookupRecovery(key, request, recoverySignal());
  assert.equal(found.kind, "pending");
  if (found.kind !== "pending" || !("correlation" in found)) assert.fail();
  assert.deepEqual(Object.keys(found).sort(), [
    "context",
    "correlation",
    "kind",
  ]);
  assert.deepEqual(Object.keys(found.correlation).sort(), [
    "client_event_id",
    "idempotency_key",
    "operation",
    "receipt_id",
    "user_id",
  ]);
  assert.equal(
    found.correlation.idempotency_key,
    `${key.userId}/${key.operation}/${key.eventId}`,
  );
  return found;
}
function recoveredOutput(
  op: Mutation,
  request: Requests[Mutation],
  record: Awaited<ReturnType<typeof pendingRecord>>,
) {
  return generated({
    operation: op,
    systemInstruction: "TEST ONLY",
    request,
    context: record.context,
    idempotencyKey: record.correlation.idempotency_key,
  });
}
async function recoveryFailure(work: Promise<unknown>, code: string) {
  await assert.rejects(work, (e: unknown) => {
    assert.ok(e instanceof BoundaryError);
    assert.equal(e.code, code);
    assert.equal(e.message, code);
    return true;
  });
}
test(
  "native recovery driver all three mutations reconcile once and replay after closure retirement profile change",
  { timeout: 20000 },
  async () => {
    const f = await fixture(),
      req = start(f),
      k = recoveryKey(f.user, "start_conversation", req);
    assert.deepEqual(
      await recoveryStore().lookupRecovery(k, req, recoverySignal()),
      { kind: "missing" },
    );
    await recoveryStore().acquire(k, req, recoverySignal());
    const startRecord = await pendingRecord(recoveryStore(), k, req);
    const startResult = recoveredOutput(
      k.operation,
      req,
      startRecord,
    ) as Responses["start_conversation"];
    await recoveryStore().reconcile(
      k,
      req,
      startRecord.correlation,
      startRecord.context,
      startResult,
      recoverySignal(),
    );
    const turn: Requests["conversation_turn"] = {
      session_id: startResult.session_id,
      client_event_id: randomUUID(),
      text_ja: "原文",
    };
    const finish: Requests["finish_conversation"] = {
      session_id: startResult.session_id,
      client_event_id: randomUUID(),
    };
    const records: {
      key: ReturnType<typeof recoveryKey>;
      request: Requests[Mutation];
      record: Awaited<ReturnType<typeof pendingRecord>>;
      result: Responses[Mutation];
    }[] = [{ key: k, request: req, record: startRecord, result: startResult }];
    for (const [op, request] of [
      ["conversation_turn", turn],
      ["finish_conversation", finish],
    ] as const) {
      const key = recoveryKey(f.user, op, request);
      await recoveryStore().acquire(key, request, recoverySignal());
      const record = await pendingRecord(recoveryStore(), key, request),
        result = recoveredOutput(op, request, record);
      await recoveryStore().reconcile(
        key,
        request,
        record.correlation,
        record.context,
        result,
        recoverySignal(),
      );
      records.push({ key, request, record, result });
    }
    await admin(
      "UPDATE public.profiles SET preferred_jlpt='N4' WHERE id=$1::uuid",
      [f.user],
    );
    await admin(
      "UPDATE public.conversation_scenarios SET is_active=false WHERE id=$1::uuid",
      [f.scenario],
    );
    for (const { key, request, record, result } of records) {
      await recoveryStore().reconcile(
        key,
        request,
        record.correlation,
        record.context,
        result,
        recoverySignal(),
      );
      assert.deepEqual(
        await recoveryStore().lookupRecovery(key, request, recoverySignal()),
        { kind: "completed", response: result },
      );
    }
    const state = await admin(
      "SELECT s.ended_at IS NOT NULL AS closed,(SELECT count(*)::int FROM public.conversation_messages m WHERE m.conversation_session_id=s.id) AS messages,(SELECT count(*)::int FROM public.operation_receipts o JOIN private.ai_conversation_reservations r ON r.receipt_id=o.id WHERE o.user_id=s.user_id AND o.status='COMPLETED' AND r.is_completed) AS receipts FROM public.conversation_sessions s WHERE s.user_id=$1::uuid",
      [f.user],
    );
    assert.deepEqual(state.rows, [{ closed: true, messages: 3, receipts: 3 }]);
  },
);
for (const method of ["lookup", "reconcile"] as const)
  test(
    `native recovery ${method} actual COMMIT with injected lost delivery requires fresh lookup without claim renewal`,
    { timeout: 15000 },
    async () => {
      const f = await fixture(),
        req = start(f),
        key = recoveryKey(f.user, "start_conversation", req);
      await recoveryStore().acquire(key, req, recoverySignal());
      const record = await pendingRecord(recoveryStore(), key, req),
        result = recoveredOutput(key.operation, req, record);
      let lost = false;
      const t = transport(async (_phase, text, execute) => {
          const r = await execute();
          if (text === "COMMIT") {
            lost = true;
            throw Error("TEST_ONLY_LOST_DELIVERY");
          }
          return r;
        }),
        repo = recoveryStore(t);
      await recoveryFailure(
        method === "lookup"
          ? repo.lookupRecovery(key, req, recoverySignal())
          : repo.reconcile(
              key,
              req,
              record.correlation,
              record.context,
              result,
              recoverySignal(),
            ),
        "NETWORK_UNAVAILABLE",
      );
      assert.equal(lost, true);
      assert.equal(t.opened(), 1);
      assert.equal(t.closed(), 1);
      const found = await recoveryStore().lookupRecovery(
        key,
        req,
        recoverySignal(),
      );
      assert.equal(found.kind, method === "lookup" ? "pending" : "completed");
      if (found.kind === "pending" && "correlation" in found)
        assert.deepEqual(found.correlation, record.correlation);
      if (found.kind === "completed") assert.deepEqual(found.response, result);
      const state = await admin(
        "SELECT o.status,r.is_completed,(SELECT count(*)::int FROM public.conversation_sessions s WHERE s.user_id=o.user_id) AS sessions FROM public.operation_receipts o JOIN private.ai_conversation_reservations r ON r.receipt_id=o.id WHERE o.user_id=$1::uuid",
        [f.user],
      );
      assert.deepEqual(state.rows, [
        {
          status: method === "lookup" ? "PENDING" : "COMPLETED",
          is_completed: method === "reconcile",
          sessions: method === "lookup" ? 0 : 1,
        },
      ]);
    },
  );
for (const method of ["lookup", "reconcile"] as const)
  test(
    `native recovery ${method} waits for actual COMMIT delivery before exposing result`,
    { timeout: 15000 },
    async () => {
      const f = await fixture(),
        req = start(f),
        key = recoveryKey(f.user, "start_conversation", req);
      await recoveryStore().acquire(key, req, recoverySignal());
      const record = await pendingRecord(recoveryStore(), key, req),
        result = recoveredOutput(key.operation, req, record);
      let release!: () => void,
        done = false;
      const t = transport(async (_phase, text, execute) => {
          const r = await execute();
          if (text === "COMMIT")
            return new Promise((resolve) => {
              release = () => resolve(r);
            });
          return r;
        }),
        repo = recoveryStore(t);
      const work = (
        method === "lookup"
          ? repo.lookupRecovery(key, req, recoverySignal())
          : repo.reconcile(
              key,
              req,
              record.correlation,
              record.context,
              result,
              recoverySignal(),
            )
      ).then((r) => {
        done = true;
        return r;
      });
      await barrier(() => Boolean(release));
      assert.equal(done, false);
      const found = await recoveryStore().lookupRecovery(
        key,
        req,
        recoverySignal(),
      );
      assert.equal(found.kind, method === "lookup" ? "pending" : "completed");
      release();
      await work;
      assert.equal(t.closed(), 1);
    },
  );
test(
  "native recovery observed blocked reconciliation cancellation cannot persist after lock release",
  { timeout: 15000 },
  async () => {
    const f = await fixture(),
      req = start(f),
      key = recoveryKey(f.user, "start_conversation", req);
    await recoveryStore().acquire(key, req, recoverySignal());
    const record = await pendingRecord(recoveryStore(), key, req),
      result = recoveredOutput(key.operation, req, record);
    const t = transport(),
      parent = new AbortController(),
      locker = client();
    await locker.connect();
    try {
      await locker.query("BEGIN");
      await locker.query(
        "SELECT pg_advisory_xact_lock(hashtextextended('nihongo-ai-conversation:'||$1::text,0))",
        [f.user],
      );
      const work = recoveryStore(t).reconcile(
        key,
        req,
        record.correlation,
        record.context,
        result,
        parent.signal,
      );
      await waitForLock(t.name);
      parent.abort();
      await recoveryFailure(work, "NETWORK_UNAVAILABLE");
      await locker.query("ROLLBACK");
      await delay(30);
      assert.deepEqual(
        (await pendingRecord(recoveryStore(), key, req)).correlation,
        record.correlation,
      );
      assert.equal(
        (
          await admin(
            "SELECT count(*)::int AS n FROM public.conversation_sessions WHERE user_id=$1::uuid",
            [f.user],
          )
        ).rows[0]?.n,
        0,
      );
      assert.equal(t.opened(), 1);
      assert.equal(t.closed(), 1);
    } finally {
      await locker.end();
    }
  },
);
test(
  "native recovery failure after SQL writes rolls back and fresh reconciliation completes exactly once",
  { timeout: 15000 },
  async () => {
    const f = await fixture(),
      req = start(f),
      key = recoveryKey(f.user, "start_conversation", req);
    await recoveryStore().acquire(key, req, recoverySignal());
    const record = await pendingRecord(recoveryStore(), key, req),
      result = recoveredOutput(key.operation, req, record);
    let injected = false;
    const t = transport(async (_phase, text, execute) => {
      const r = await execute();
      if (text.includes("ai_conversation_reconcile")) {
        injected = true;
        throw Error("TEST_ONLY_POST_WRITE_FAILURE");
      }
      return r;
    });
    await recoveryFailure(
      recoveryStore(t).reconcile(
        key,
        req,
        record.correlation,
        record.context,
        result,
        recoverySignal(),
      ),
      "NETWORK_UNAVAILABLE",
    );
    assert.equal(injected, true);
    assert.deepEqual(
      (await pendingRecord(recoveryStore(), key, req)).correlation,
      record.correlation,
    );
    assert.equal(
      (
        await admin(
          "SELECT count(*)::int AS n FROM public.conversation_sessions WHERE user_id=$1::uuid",
          [f.user],
        )
      ).rows[0]?.n,
      0,
    );
    // Fresh writer waits for server disconnect/rollback, not a local memory result.
    await recoveryStore().reconcile(
      key,
      req,
      record.correlation,
      record.context,
      result,
      recoverySignal(),
    );
    await recoveryStore().reconcile(
      key,
      req,
      record.correlation,
      record.context,
      result,
      recoverySignal(),
    );
    assert.deepEqual(
      await recoveryStore().lookupRecovery(key, req, recoverySignal()),
      { kind: "completed", response: result },
    );
    assert.equal(
      (
        await admin(
          "SELECT count(*)::int AS n FROM public.conversation_messages m JOIN public.conversation_sessions s ON s.id=m.conversation_session_id WHERE s.user_id=$1::uuid",
          [f.user],
        )
      ).rows[0]?.n,
      1,
    );
    assert.equal(t.opened(), 1);
    assert.equal(t.closed(), 1);
  },
);
test(
  "native recovery A B A immutable association and source retirement never overwrite or borrow another receipt",
  { timeout: 20000 },
  async () => {
    const a = await fixture(),
      b = await fixture("N4"),
      ra = start(a),
      rb = { ...start(b), client_event_id: ra.client_event_id };
    const ka = recoveryKey(a.user, "start_conversation", ra),
      kb = recoveryKey(b.user, "start_conversation", rb);
    await recoveryStore().acquire(ka, ra, recoverySignal());
    await recoveryStore().acquire(kb, rb, recoverySignal());
    const ar = await pendingRecord(recoveryStore(), ka, ra),
      br = await pendingRecord(recoveryStore(), kb, rb);
    assert.notEqual(ar.correlation.receipt_id, br.correlation.receipt_id);
    assert.notEqual(ar.context.sessionId, br.context.sessionId);
    const out = recoveredOutput(ka.operation, ra, ar);
    await recoveryFailure(
      recoveryStore().reconcile(
        ka,
        ra,
        { ...ar.correlation, receipt_id: br.correlation.receipt_id },
        ar.context,
        out,
        recoverySignal(),
      ),
      "FORBIDDEN",
    );
    await recoveryFailure(
      recoveryStore().reconcile(
        ka,
        ra,
        ar.correlation,
        { ...ar.context, instruction: "変更" },
        out,
        recoverySignal(),
      ),
      "SYNC_CONFLICT",
    );
    await recoveryFailure(
      recoveryStore().lookupRecovery(
        ka,
        { ...ra, scenario_id: b.scenario },
        recoverySignal(),
      ),
      "SYNC_CONFLICT",
    );
    await admin(
      "UPDATE public.conversation_scenarios SET is_active=false WHERE id=$1::uuid",
      [a.scenario],
    );
    assert.deepEqual(await pendingRecord(recoveryStore(), ka, ra), ar);
    await recoveryFailure(
      recoveryStore().reconcile(
        ka,
        ra,
        ar.correlation,
        ar.context,
        out,
        recoverySignal(),
      ),
      "NOT_FOUND",
    );
    await recoveryStore().reconcile(
      kb,
      rb,
      br.correlation,
      br.context,
      recoveredOutput(kb.operation, rb, br),
      recoverySignal(),
    );
    assert.deepEqual(await pendingRecord(recoveryStore(), ka, ra), ar);
    assert.equal(
      (
        await admin(
          "SELECT count(*)::int AS n FROM public.conversation_sessions WHERE user_id=$1::uuid",
          [a.user],
        )
      ).rows[0]?.n,
      0,
    );
  },
);
