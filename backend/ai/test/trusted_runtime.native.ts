// TEST ONLY fixed disposable PostgreSQL17/plaintext, Auth HTTP and provider.
// Exercises actual assembled Request/Response handlers and SQL, not hosted/Edge.
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { setTimeout as delay } from "node:timers/promises";
import { Client } from "pg";
import { assemblePostgresAiHandlers } from "../src/trusted_runtime.ts";
import { SupabaseAuthVerifier } from "../src/supabase_auth.ts";
import type { Operation, Responses } from "../src/contracts.ts";
import type { ProviderInput } from "../src/ports.ts";
import type {
  PostgresConnection,
  PostgresResult,
} from "../src/postgres_connection.ts";
import { contracts, fixtures } from "./support.ts";
const databaseUrl = process.env.TEST_DATABASE_URL;
if (
  databaseUrl !== "postgresql://postgres:postgres@localhost:5432/nihongo_test"
)
  throw Error("Native assembly requires the fixed disposable CI database");
function client(name = "nd-assembly-admin") {
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
async function fixture() {
  const user = randomUUID(),
    other = randomUUID(),
    scenario = randomUUID(),
    grammar = randomUUID();
  for (const id of [user, other]) {
    await admin("INSERT INTO auth.users(id) VALUES($1::uuid)", [id]);
    await admin(
      "INSERT INTO public.profiles(id,preferred_jlpt) VALUES($1::uuid,'N5')",
      [id],
    );
  }
  await admin(
    "INSERT INTO public.conversation_scenarios(id,jlpt_level,difficulty,content_version,is_active,title_vi,title_ja,description_vi,system_context) VALUES($1::uuid,'N5',0,1,true,'fixture','会話','fixture','固定文脈')",
    [scenario],
  );
  await admin(
    "INSERT INTO public.grammar(id,jlpt_level,difficulty,content_version,is_active,title,pattern,meaning_vi,explanation_vi) VALUES($1::uuid,'N5',0.2,1,true,'文法','～です','nghĩa','giải thích')",
    [grammar],
  );
  return { user, other, scenario, grammar };
}
type Fixture = Awaited<ReturnType<typeof fixture>>;
type Observe = (
  lane: string,
  phase: string,
  text: string,
  execute: () => Promise<PostgresResult>,
) => Promise<PostgresResult>;
function transport(observe?: Observe) {
  let opened = 0,
    closed = 0;
  const name = "nd-assembly-" + randomUUID();
  const lane = (kind: string) => (): PostgresConnection => {
    const c = client(name);
    let phase = "";
    opened++;
    return {
      connect: async () => {
        await c.connect();
      },
      query: async (text, values) => {
        if (text.startsWith("SELECT")) phase = text;
        const execute = async () => {
          const result = await c.query(text, values);
          if (text === "COMMIT") assert.equal(c.getTransactionStatus(), "I");
          return result;
        };
        return observe ? observe(kind, phase, text, execute) : execute();
      },
      close: () => {
        closed++;
        void c.end().catch(() => {});
      },
    };
  };
  return {
    name,
    connections: {
      quota: lane("quota"),
      text: lane("text"),
      conversation: lane("conversation"),
    },
    opened: () => opened,
    closed: () => closed,
  };
}
function generated(input: ProviderInput): unknown {
  if (input.operation === "tutor_explain")
    return fixtures.tutor_explain_response;
  if (input.operation === "correct_sentence")
    return fixtures.correct_sentence_response;
  if (input.operation === "finish_conversation")
    return {
      scores: { grammar: 80, vocabulary: 90, fluency: 75 },
      errors: [],
      strengths_vi: [],
      focus_next_vi: [],
      srs_recommendations: [],
    };
  const assistant_message = {
    id: input.context.messageId!,
    role: "assistant",
    text_ja: "こんにちは",
    text_vi: null,
    audio_ref: null,
    sequence_no: input.context.sequenceNo!,
  };
  return input.operation === "start_conversation"
    ? { session_id: input.context.sessionId!, assistant_message }
    : { assistant_message };
}
function assembly(
  f: Fixture,
  t = transport(),
  custom?: (input: ProviderInput) => Promise<string>,
) {
  const calls: ProviderInput[] = [];
  let authCalls = 0;
  const auth = new SupabaseAuthVerifier(
    "https://fixture.supabase.co",
    "sb_publishable_TESTONLY0000000000",
    async (url, init) => {
      authCalls++;
      assert.equal(url, "https://fixture.supabase.co/auth/v1/user");
      const bearer = new Headers(init?.headers).get("authorization");
      if (bearer !== "Bearer fixture-A" && bearer !== "Bearer fixture-B")
        return Response.json({}, { status: 401 });
      return Response.json({
        id: bearer === "Bearer fixture-A" ? f.user : f.other,
        aud: "authenticated",
      });
    },
  );
  const handlers = assemblePostgresAiHandlers(contracts, {
    auth,
    connections: t.connections,
    provider: {
      generate: async (input) => {
        calls.push(input);
        assert.equal(t.opened(), t.closed());
        assert.equal(
          (
            await admin(
              "SELECT count(*)::int AS n FROM pg_stat_activity WHERE application_name=$1 AND xact_start IS NOT NULL",
              [t.name],
            )
          ).rows[0]?.n,
          0,
        );
        assert.equal(JSON.stringify(input).includes("fixture-A"), false);
        return custom ? custom(input) : JSON.stringify(generated(input));
      },
    },
  });
  return {
    calls,
    authCalls: () => authCalls,
    t,
    run: async (op: Operation, body: object, bearer = "fixture-A") => {
      const r = await handlers[op](
        new Request("https://untrusted.invalid/?operation=other", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            authorization: `Bearer ${bearer}`,
          },
          body: JSON.stringify(body),
        }),
      );
      assert.equal(r.headers.get("cache-control"), "no-store");
      const value = (await r.json()) as unknown;
      assert.equal(JSON.stringify(value).includes("PRIVATE"), false);
      return { status: r.status, value };
    },
  };
}
const start = (f: Fixture) => ({
  scenario_id: f.scenario,
  jlpt_level: "N5",
  client_event_id: randomUUID(),
});
async function barrier(ready: () => boolean) {
  const end = performance.now() + 3000;
  while (!ready() && performance.now() < end) await delay(5);
  assert.ok(ready(), "Native assembly barrier not reached within bound");
}
async function receipt(f: Fixture, event: string) {
  return (
    await admin(
      "SELECT status,response_json FROM public.operation_receipts WHERE user_id=$1::uuid AND client_event_id=$2::uuid",
      [f.user, event],
    )
  ).rows;
}

test(
  "native assembled five operations persist full lifecycle and fresh closure retirement replay",
  { timeout: 20000 },
  async () => {
    const f = await fixture(),
      s = assembly(f),
      req = start(f);
    for (const [op, body] of [
      [
        "tutor_explain",
        {
          jlpt_level: "N5",
          question_vi: "Giải thích",
          context: {
            recent_grammar_ids: [f.grammar],
            recent_vocabulary_ids: [],
          },
        },
      ],
      ["correct_sentence", { jlpt_level: "N5", sentence_ja: "水を飲みます。" }],
    ] as const)
      assert.equal((await s.run(op, body)).status, 200);
    const first = await s.run("start_conversation", req);
    assert.equal(first.status, 200);
    const body = first.value as Responses["start_conversation"];
    const turn = {
      session_id: body.session_id,
      client_event_id: randomUUID(),
      text_ja: "猫です",
    };
    const second = await s.run("conversation_turn", turn);
    assert.equal(second.status, 200);
    assert.equal(
      (second.value as Responses["conversation_turn"]).assistant_message
        .sequence_no,
      2,
    );
    const finish = {
      session_id: body.session_id,
      client_event_id: randomUUID(),
    };
    const third = await s.run("finish_conversation", finish);
    assert.equal(third.status, 200);
    const rows = (
      await admin(
        "SELECT s.ended_at IS NOT NULL AS closed,(SELECT array_agg(sequence_no ORDER BY sequence_no) FROM public.conversation_messages WHERE conversation_session_id=s.id) AS slots,(SELECT count(*)::int FROM public.operation_receipts o JOIN private.ai_conversation_reservations r ON r.receipt_id=o.id WHERE o.user_id=s.user_id AND o.status='COMPLETED' AND r.is_completed) AS receipts FROM public.conversation_sessions s WHERE s.id=$1::uuid AND s.user_id=$2::uuid",
        [body.session_id, f.user],
      )
    ).rows;
    assert.deepEqual(rows, [{ closed: true, slots: [0, 1, 2], receipts: 3 }]);
    await admin(
      "UPDATE public.conversation_scenarios SET is_active=false WHERE id=$1::uuid",
      [f.scenario],
    );
    await admin(
      "UPDATE public.profiles SET preferred_jlpt='N4' WHERE id=$1::uuid",
      [f.user],
    );
    const restarted = assembly(f);
    assert.deepEqual(await restarted.run("start_conversation", req), first);
    assert.deepEqual(await restarted.run("conversation_turn", turn), second);
    assert.deepEqual(await restarted.run("finish_conversation", finish), third);
    assert.equal(restarted.calls.length, 0);
    assert.equal(s.calls.length, 5);
    assert.equal(s.authCalls(), 5);
    assert.equal(restarted.authCalls(), 3);
    assert.equal(
      (
        await admin(
          "SELECT used_today FROM private.ai_rate_buckets WHERE user_id=$1::uuid",
          [f.user],
        )
      ).rows[0]?.used_today,
      8,
    );
    assert.equal(s.t.closed(), s.t.opened());
  },
);
test(
  "native assembled independent instances cannot redispatch same event or overtake reserved session",
  { timeout: 20000 },
  async () => {
    const f = await fixture(),
      req = start(f),
      other = assembly(f);
    let held: ProviderInput | undefined,
      release: ((value: string) => void) | undefined;
    const s = assembly(f, transport(), async (input) => {
      held = input;
      return new Promise((resolve) => {
        release = resolve;
      });
    });
    try {
      const work = s.run("start_conversation", req);
      await barrier(() => Boolean(release));
      assert.equal((await other.run("start_conversation", req)).status, 503);
      assert.equal(
        (await receipt(f, req.client_event_id))[0]?.status,
        "PENDING",
      );
      release!(JSON.stringify(generated(held!)));
      const first = await work;
      assert.equal(first.status, 200);
      const turn = {
        session_id: (first.value as Responses["start_conversation"]).session_id,
        client_event_id: randomUUID(),
        text_ja: "猫です",
      };
      release = undefined;
      const work2 = s.run("conversation_turn", turn);
      await barrier(() => Boolean(release));
      assert.equal(
        (
          await other.run("conversation_turn", {
            ...turn,
            client_event_id: randomUUID(),
          })
        ).status,
        409,
      );
      assert.equal(
        (
          await other.run("finish_conversation", {
            session_id: turn.session_id,
            client_event_id: randomUUID(),
          })
        ).status,
        409,
      );
      assert.equal(other.calls.length, 0);
      release!(JSON.stringify(generated(held!)));
      assert.equal((await work2).status, 200);
      assert.equal(s.calls.length, 2);
      assert.equal(
        (
          await admin(
            "SELECT count(*)::int AS n FROM public.conversation_messages WHERE conversation_session_id=$1::uuid",
            [turn.session_id],
          )
        ).rows[0]?.n,
        3,
      );
    } finally {
      if (release && held) release(JSON.stringify(generated(held)));
    }
  },
);
for (const stage of ["acquire", "complete"] as const)
  test(
    `native assembled actual ${stage} COMMIT lost delivery is conservative across fresh handler restart`,
    { timeout: 20000 },
    async () => {
      const f = await fixture(),
        req = start(f);
      let injected = false;
      const t = transport(async (lane, phase, text, execute) => {
        const result = await execute();
        if (
          !injected &&
          lane === "conversation" &&
          text === "COMMIT" &&
          phase.includes(
            stage === "acquire"
              ? "ai_conversation_reserve"
              : "ai_conversation_complete",
          )
        ) {
          injected = true;
          throw Error("PRIVATE simulated lost COMMIT delivery");
        }
        return result;
      });
      const s = assembly(f, t),
        result = await s.run("start_conversation", req);
      assert.equal(result.status, 503);
      assert.equal(injected, true);
      const saved = await receipt(f, req.client_event_id);
      assert.equal(
        saved[0]?.status,
        stage === "acquire" ? "PENDING" : "COMPLETED",
      );
      const fresh = assembly(f),
        replay = await fresh.run("start_conversation", req);
      assert.equal(replay.status, stage === "acquire" ? 503 : 200);
      if (stage === "complete")
        assert.deepEqual(replay.value, saved[0]?.response_json);
      assert.equal(fresh.calls.length, 0);
      assert.equal(s.calls.length, stage === "acquire" ? 0 : 1);
      assert.equal(
        (
          await admin(
            "SELECT count(*)::int AS n FROM public.conversation_sessions WHERE user_id=$1::uuid",
            [f.user],
          )
        ).rows[0]?.n,
        stage === "acquire" ? 0 : 1,
      );
      assert.equal(t.closed(), t.opened());
    },
  );
test(
  "native assembled Supabase verifier identity isolates foreign session and rejects forged owner invalid Auth",
  { timeout: 15000 },
  async () => {
    const f = await fixture(),
      s = assembly(f),
      req = start(f),
      first = await s.run("start_conversation", req);
    assert.equal(first.status, 200);
    const turn = {
      session_id: (first.value as Responses["start_conversation"]).session_id,
      client_event_id: randomUUID(),
      text_ja: "文",
    };
    assert.equal(
      (await s.run("conversation_turn", turn, "fixture-B")).status,
      404,
    );
    assert.equal(
      (await s.run("start_conversation", { ...start(f), user_id: f.other }))
        .status,
      400,
    );
    assert.equal(
      (await s.run("start_conversation", start(f), "invalid")).status,
      401,
    );
    assert.equal(s.calls.length, 1);
    assert.equal(
      (
        await admin(
          "SELECT count(*)::int AS n FROM public.conversation_sessions WHERE user_id=$1::uuid",
          [f.other],
        )
      ).rows[0]?.n,
      0,
    );
    assert.equal(s.t.closed(), s.t.opened());
  },
);
test(
  "native assembled malformed provider leaves durable pending without public writes or restart redispatch",
  { timeout: 15000 },
  async () => {
    const f = await fixture(),
      req = start(f),
      s = assembly(f, transport(), async () => '{"PRIVATE":"invalid result"}');
    const failed = await s.run("start_conversation", req);
    assert.equal(failed.status, 503);
    assert.equal((await receipt(f, req.client_event_id))[0]?.status, "PENDING");
    assert.equal(
      (
        await admin(
          "SELECT count(*)::int AS n FROM public.conversation_sessions WHERE user_id=$1::uuid",
          [f.user],
        )
      ).rows[0]?.n,
      0,
    );
    const fresh = assembly(f);
    assert.equal((await fresh.run("start_conversation", req)).status, 503);
    assert.equal(s.calls.length, 1);
    assert.equal(fresh.calls.length, 0);
  },
);
test(
  "native assembled text source retirement after provider fails final validation transaction",
  { timeout: 15000 },
  async () => {
    const f = await fixture(),
      s = assembly(f, transport(), async (input) => {
        await admin(
          "UPDATE public.grammar SET is_active=false WHERE id=$1::uuid",
          [f.grammar],
        );
        return JSON.stringify(generated(input));
      });
    const result = await s.run("tutor_explain", {
      jlpt_level: "N5",
      question_vi: "Giải thích",
      context: { recent_grammar_ids: [f.grammar], recent_vocabulary_ids: [] },
    });
    assert.equal(result.status, 404);
    assert.equal(s.calls.length, 1);
    assert.equal(s.t.opened(), 3);
    assert.equal(s.t.closed(), 3);
    assert.equal(
      (
        await admin(
          "SELECT count(*)::int AS n FROM public.operation_receipts WHERE user_id=$1::uuid",
          [f.user],
        )
      ).rows[0]?.n,
      0,
    );
  },
);
test(
  "native assembled exhausted committed daily quota rejects before context receipt or provider",
  { timeout: 15000 },
  async () => {
    const f = await fixture();
    await admin(
      "INSERT INTO private.ai_rate_buckets(user_id,tokens,refilled_at,budget_day,used_today) VALUES($1::uuid,10,clock_timestamp(),(clock_timestamp() AT TIME ZONE 'UTC')::date,100)",
      [f.user],
    );
    const s = assembly(f),
      result = await s.run("start_conversation", start(f));
    assert.equal(result.status, 429);
    assert.equal(s.calls.length, 0);
    assert.equal(s.t.opened(), 1);
    assert.equal(s.t.closed(), 1);
    assert.equal(
      (
        await admin(
          "SELECT count(*)::int AS n FROM public.operation_receipts WHERE user_id=$1::uuid",
          [f.user],
        )
      ).rows[0]?.n,
      0,
    );
  },
);
