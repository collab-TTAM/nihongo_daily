// TEST ONLY disposable PostgreSQL17 transport, Auth and provider. No hosted calls.
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { setTimeout as delay, setImmediate } from "node:timers/promises";
import { Client } from "pg";
import {
  PostgresTextContextRepository,
  createPostgresTextContextRepository,
} from "../src/postgres_text_context.ts";
import { PostgresQuotaLimiter } from "../src/postgres_quota.ts";
import type {
  PostgresConnection,
  PostgresResult,
} from "../src/postgres_connection.ts";
import { BoundaryError } from "../src/contracts.ts";
import { AiService } from "../src/service.ts";
import { contracts, fixtures, setup } from "./support.ts";
const databaseUrl = process.env.TEST_DATABASE_URL;
if (
  databaseUrl !== "postgresql://postgres:postgres@localhost:5432/nihongo_test"
)
  throw new Error(
    "Native text context requires the fixed disposable CI database",
  );
const signal = () => new AbortController().signal;
function client(name = "nd-text-native-admin") {
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
async function fixture(level = "N5") {
  const user = randomUUID(),
    grammar = randomUUID(),
    vocabulary = randomUUID();
  await admin("INSERT INTO auth.users(id) VALUES($1::uuid)", [user]);
  await admin(
    "INSERT INTO public.profiles(id,preferred_jlpt) VALUES($1::uuid,$2::public.jlpt_level)",
    [user, level],
  );
  await admin(
    "INSERT INTO public.grammar(id,jlpt_level,difficulty,content_version,is_active,title,pattern,meaning_vi,explanation_vi) VALUES($1::uuid,$2::public.jlpt_level,0.2,1,true,'文法','～です','nghĩa','giải thích')",
    [grammar, level],
  );
  await admin(
    "INSERT INTO public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,expression,reading,meaning_vi,part_of_speech,usage_context_vi) VALUES($1::uuid,$2::public.jlpt_level,0.2,1,true,'猫','ねこ','mèo','noun','fixture')",
    [vocabulary, level],
  );
  const request = {
    jlpt_level: level,
    question_vi: "Giải thích",
    context: {
      recent_grammar_ids: [grammar],
      recent_vocabulary_ids: [vocabulary],
    },
  };
  return { user, grammar, vocabulary, request, level };
}
type Observe = (
  phase: number,
  text: string,
  execute: () => Promise<PostgresResult>,
) => Promise<PostgresResult>;
function transport(name = "nd-text-native-" + randomUUID(), observe?: Observe) {
  let created = 0,
    closed = 0;
  const factory = (): PostgresConnection => {
    const phase = ++created,
      c = client(name);
    return {
      connect: async () => {
        await c.connect();
      },
      query: async (text, values) => {
        const execute = async () => {
          const result = await c.query(text, values);
          if (text === "COMMIT") assert.equal(c.getTransactionStatus(), "I");
          if (text.includes("READ ONLY"))
            assert.equal(
              (await c.query("SHOW transaction_read_only")).rows[0]
                ?.transaction_read_only,
              "on",
            );
          return result;
        };
        return observe ? observe(phase, text, execute) : execute();
      },
      close: () => {
        closed++;
        void c.end().catch(() => {});
      },
    };
  };
  return { factory, name, created: () => created, closed: () => closed };
}
function repository(t: ReturnType<typeof transport>) {
  return new PostgresTextContextRepository(contracts, t.factory);
}
async function safeFailure(
  work: Promise<unknown>,
  code = "NETWORK_UNAVAILABLE",
) {
  await assert.rejects(work, (error: unknown) => {
    assert.ok(error instanceof BoundaryError);
    assert.equal(error.code, code);
    assert.equal(error.message, code);
    return true;
  });
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
      ).rows[0]?.waiting === true
    )
      return;
    await delay(10);
  }
  assert.fail(
    "Actual text context was not observed waiting on its PostgreSQL lock",
  );
}
test(
  "native text service composes real quota/context/validation for both frozen text operations",
  { timeout: 15000 },
  async () => {
    const f = await fixture();
    for (const op of ["tutor_explain", "correct_sentence"] as const) {
      const t = transport(),
        s = setup();
      s.deps.auth.verify = async () => ({ id: f.user });
      s.deps.context = repository(t);
      s.deps.limiter = new PostgresQuotaLimiter(transport().factory);
      const original = s.deps.provider.generate;
      s.deps.provider.generate = async (input, parent) => {
        assert.equal(t.created(), 1);
        assert.equal(t.closed(), 1);
        const instruction = JSON.parse(input.context.instruction);
        assert.equal(instruction.jlpt_level, "N5");
        assert.ok(instruction.curriculum.length > 0);
        assert.ok(Object.isFrozen(input.context));
        assert.equal(
          (
            await admin(
              "SELECT count(*)::integer AS n FROM pg_stat_activity WHERE application_name=$1 AND xact_start IS NOT NULL",
              [t.name],
            )
          ).rows[0]?.n,
          0,
        );
        return original(input, parent);
      };
      const request =
        op === "tutor_explain"
          ? f.request
          : { jlpt_level: "N5", sentence_ja: "猫です" };
      const result = await new AiService(contracts, s.deps).execute(
        op,
        "TEST_ONLY",
        JSON.stringify(request),
      );
      assert.equal(result.ok, true);
      if (result.ok) contracts.response(op, result.response);
      assert.equal(s.calls.length, 1);
      assert.equal(t.created(), 2);
      assert.equal(t.closed(), 2);
      assert.equal(s.store.rows.size, 0);
    }
    assert.equal(
      (
        await admin(
          "SELECT used_today FROM private.ai_rate_buckets WHERE user_id=$1",
          [f.user],
        )
      ).rows[0]?.used_today,
      2,
    );
    assert.equal(
      (
        await admin(
          "SELECT count(*)::integer AS n FROM public.operation_receipts WHERE user_id=$1",
          [f.user],
        )
      ).rows[0]?.n,
      0,
    );
  },
);
test(
  "native fresh A B A text context keeps profile levels and typed curriculum checks",
  { timeout: 15000 },
  async () => {
    const a = await fixture(),
      b = await fixture("N4"),
      t = transport(),
      repo = repository(t);
    for (const f of [a, b, a]) {
      const request = contracts.request("tutor_explain", f.request);
      const ctx = await repo.prepare(
        f.user,
        "tutor_explain",
        request,
        signal(),
      );
      assert.equal(JSON.parse(ctx.instruction).jlpt_level, f.level);
      assert.deepEqual(ctx.allowedRefs, [
        { item_type: "GRAMMAR", item_id: f.grammar },
        { item_type: "VOCABULARY", item_id: f.vocabulary },
      ]);
      await repo.validateResult(
        f.user,
        "tutor_explain",
        request,
        contracts.response("tutor_explain", fixtures.tutor_explain_response),
        ctx,
        signal(),
      );
    }
    await safeFailure(
      repo.prepare(
        b.user,
        "tutor_explain",
        contracts.request("tutor_explain", a.request),
        signal(),
      ),
      "FORBIDDEN",
    );
    assert.equal(t.created(), 7);
    assert.equal(t.closed(), 7);
  },
);
test(
  "native late provider context is rejected after actual content retirement or version change",
  { timeout: 15000 },
  async () => {
    for (const mode of ["retired", "changed"]) {
      const f = await fixture(),
        t = transport(),
        s = setup();
      s.deps.auth.verify = async () => ({ id: f.user });
      s.deps.context = repository(t);
      const original = s.deps.provider.generate;
      s.deps.provider.generate = async (input, parent) => {
        await admin(
          mode === "retired"
            ? "UPDATE public.grammar SET is_active=false WHERE id=$1"
            : "UPDATE public.grammar SET meaning_vi='đã thay đổi',content_version=2 WHERE id=$1",
          [f.grammar],
        );
        return original(input, parent);
      };
      const outcome = await new AiService(contracts, s.deps).execute(
        "tutor_explain",
        "TEST_ONLY",
        JSON.stringify(f.request),
      );
      assert.equal(outcome.ok, false);
      if (!outcome.ok)
        assert.equal(
          outcome.error.code,
          mode === "retired" ? "NOT_FOUND" : "SYNC_CONFLICT",
        );
      assert.equal(s.calls.length, 1);
      assert.equal(t.created(), 2);
      assert.equal(t.closed(), 2);
      assert.equal(s.store.rows.size, 0);
      assert.ok(!JSON.stringify(outcome).includes(f.grammar));
    }
  },
);
test(
  "native profile switch after provider dispatch rejects old level without retaining a read snapshot",
  { timeout: 15000 },
  async () => {
    const f = await fixture(),
      t = transport(),
      s = setup();
    s.deps.auth.verify = async () => ({ id: f.user });
    s.deps.context = repository(t);
    const original = s.deps.provider.generate;
    s.deps.provider.generate = async (input, parent) => {
      await admin(
        "UPDATE public.profiles SET preferred_jlpt='N4' WHERE id=$1",
        [f.user],
      );
      return original(input, parent);
    };
    const outcome = await new AiService(contracts, s.deps).execute(
      "tutor_explain",
      "TEST_ONLY",
      JSON.stringify(f.request),
    );
    assert.equal(outcome.ok, false);
    if (!outcome.ok) assert.equal(outcome.error.code, "FORBIDDEN");
    assert.equal(t.closed(), 2);
    assert.equal(s.calls.length, 1);
    const ctx = await repository(transport()).prepare(
      f.user,
      "correct_sentence",
      { jlpt_level: "N4", sentence_ja: "文" },
      signal(),
    );
    assert.equal(JSON.parse(ctx.instruction).jlpt_level, "N4");
  },
);
test(
  "native text COMMIT barriers fence both provider dispatch and final success",
  { timeout: 15000 },
  async () => {
    for (const heldPhase of [1, 2]) {
      const f = await fixture();
      let arrived!: () => void, release!: () => void;
      const barrier = new Promise<void>((r) => {
          arrived = r;
        }),
        gate = new Promise<void>((r) => {
          release = r;
        });
      const t = transport(undefined, async (phase, text, execute) => {
        if (phase === heldPhase && text === "COMMIT") {
          arrived();
          await gate;
        }
        return execute();
      });
      const s = setup();
      s.deps.auth.verify = async () => ({ id: f.user });
      s.deps.context = repository(t);
      let settled = false;
      const work = new AiService(contracts, s.deps)
        .execute("tutor_explain", "TEST_ONLY", JSON.stringify(f.request))
        .then((outcome) => {
          settled = true;
          return outcome;
        });
      try {
        await Promise.race([
          barrier,
          work.then(() =>
            assert.fail(
              "Text service completed before actual native COMMIT barrier",
            ),
          ),
        ]);
        await setImmediate();
        assert.equal(settled, false);
        assert.equal(s.calls.length, heldPhase - 1);
      } finally {
        release();
      }
      assert.equal((await work).ok, true);
      assert.equal(s.calls.length, 1);
      assert.equal(t.closed(), 2);
    }
  },
);
test(
  "native cancelled locked text query cannot dispatch or retain a transaction after release",
  { timeout: 15000 },
  async () => {
    const f = await fixture(),
      blocker = client();
    await blocker.connect();
    await blocker.query("BEGIN");
    await blocker.query("LOCK TABLE public.profiles IN ACCESS EXCLUSIVE MODE");
    const t = transport(),
      s = setup(),
      parent = new AbortController();
    s.deps.auth.verify = async () => ({ id: f.user });
    s.deps.context = repository(t);
    const work = new AiService(contracts, s.deps).execute(
      "tutor_explain",
      "TEST_ONLY",
      JSON.stringify(f.request),
      parent.signal,
    );
    try {
      await waitForLock(t.name);
      parent.abort("TEST_ONLY");
      assert.equal((await work).ok, false);
    } finally {
      parent.abort();
      await blocker.query("COMMIT");
      await blocker.end();
    }
    assert.equal(s.calls.length, 0);
    assert.equal(t.closed(), 1);
    assert.equal(t.created(), 1);
    // A fresh read succeeds after release; the cancelled owner must retain no transaction.
    const follow = await repository(transport()).prepare(
      f.user,
      "tutor_explain",
      contracts.request("tutor_explain", f.request),
      signal(),
    );
    assert.equal(follow.allowedRefs.length, 2);
    assert.equal(s.calls.length, 0);
    assert.equal(
      (
        await admin(
          "SELECT count(*)::integer AS n FROM pg_stat_activity WHERE application_name=$1 AND xact_start IS NOT NULL",
          [t.name],
        )
      ).rows[0]?.n,
      0,
    );
  },
);
test(
  "native actual text COMMIT with injected lost delivery never returns success or retries",
  { timeout: 15000 },
  async () => {
    for (const lostPhase of [1, 2]) {
      const f = await fixture();
      let reads = 0;
      const t = transport(undefined, async (phase, text, execute) => {
        const r = await execute();
        if (text.startsWith("SELECT private.ai_")) reads++;
        if (phase === lostPhase && text === "COMMIT")
          throw new Error("TEST_ONLY lost delivery after actual commit");
        return r;
      });
      const s = setup();
      s.deps.auth.verify = async () => ({ id: f.user });
      s.deps.context = repository(t);
      const outcome = await new AiService(contracts, s.deps).execute(
        "tutor_explain",
        "TEST_ONLY",
        JSON.stringify(f.request),
      );
      assert.equal(outcome.ok, false);
      if (!outcome.ok) assert.equal(outcome.error.code, "NETWORK_UNAVAILABLE");
      assert.equal(reads, lostPhase);
      assert.equal(t.created(), lostPhase);
      assert.equal(t.closed(), lostPhase);
      assert.equal(s.calls.length, lostPhase - 1);
      assert.equal(s.store.rows.size, 0);
    }
  },
);
test(
  "native missing profile and inactive requested curriculum fail before provider with safe errors",
  { timeout: 15000 },
  async () => {
    const f = await fixture();
    await admin("UPDATE public.grammar SET is_active=false WHERE id=$1", [
      f.grammar,
    ]);
    const s = setup();
    s.deps.auth.verify = async () => ({ id: f.user });
    s.deps.context = repository(transport());
    const outcome = await new AiService(contracts, s.deps).execute(
      "tutor_explain",
      "TEST_ONLY",
      JSON.stringify(f.request),
    );
    assert.equal(outcome.ok, false);
    if (!outcome.ok) assert.equal(outcome.error.code, "NOT_FOUND");
    assert.equal(s.calls.length, 0);
    const user = randomUUID();
    await admin("INSERT INTO auth.users(id) VALUES($1::uuid)", [user]);
    await safeFailure(
      repository(transport()).prepare(
        user,
        "correct_sentence",
        { jlpt_level: "N5", sentence_ja: "文" },
        signal(),
      ),
      "NOT_FOUND",
    );
    assert.ok(!JSON.stringify(outcome).includes(f.grammar));
  },
);
test(
  "native text deployment factory rejects plaintext PostgreSQL with no fallback",
  { timeout: 15000 },
  async () => {
    const f = await fixture();
    await safeFailure(
      createPostgresTextContextRepository(contracts, databaseUrl!).prepare(
        f.user,
        "tutor_explain",
        contracts.request("tutor_explain", f.request),
        signal(),
      ),
    );
  },
);
