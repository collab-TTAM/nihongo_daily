// TEST ONLY Auth HTTP/SQL protocol/provider fixtures; not hosted/TLS/SQL evidence.
import { test } from "node:test";
import assert from "node:assert/strict";
import { setImmediate } from "node:timers/promises";
import {
  assemblePostgresAiHandlers,
  createTrustedPostgresAiHandlers,
} from "../src/trusted_runtime.ts";
import { SupabaseAuthVerifier } from "../src/supabase_auth.ts";
import { operations, isMutation } from "../src/contracts.ts";
import type { Operation, Responses } from "../src/contracts.ts";
import type {
  PostgresConnection,
  PostgresResult,
} from "../src/postgres_connection.ts";
import type { PostgresAiHost } from "../src/trusted_runtime.ts";
import type {
  AuthenticatedConversationLookup,
  PreparedContext,
} from "../src/ports.ts";
import type { item_ref } from "../src/wire.ts";
import { contracts, fixtures, userA, userB } from "./support.ts";

const publicKey = "sb_publishable_TESTONLY0000000000";
const token = "f1000000-0000-4000-8000-000000000001";
function response(op: Operation): Responses[Operation] {
  const value = structuredClone(fixtures[`${op}_response`]) as Record<
    string,
    unknown
  >;
  if (op === "conversation_turn")
    value.assistant_message = {
      ...(value.assistant_message as object),
      sequence_no: 2,
    };
  return contracts.response(op, value);
}
function context(op: Operation): PreparedContext {
  const value = response(op) as unknown as Record<string, unknown>;
  const refs: item_ref[] = [
    ...((value.srs_recommendations ?? []) as item_ref[]),
    ...[
      "grammar_errors",
      "vocabulary_errors",
      "errors",
      "live_feedback",
    ].flatMap((field) =>
      ((value[field] ?? []) as { item_refs: item_ref[] }[]).flatMap(
        (e) => e.item_refs,
      ),
    ),
  ];
  const common: PreparedContext = {
    instruction: "TEST ONLY fixed server context",
    transcript: [],
    allowedRefs: refs,
  };
  if (!isMutation(op)) return common;
  const request = fixtures[`${op}_request`] as { session_id: string };
  const message = value.assistant_message as {
    id: string;
    sequence_no: number;
  };
  return {
    ...common,
    sessionId:
      op === "start_conversation"
        ? (value.session_id as string)
        : request.session_id,
    transcript:
      op === "start_conversation"
        ? []
        : [{ role: "assistant", text_ja: "こんにちは" }],
    ...(op === "finish_conversation"
      ? {}
      : { messageId: message.id, sequenceNo: message.sequence_no }),
  };
}
function fixture() {
  const calls: { lane: string; text: string; values?: string[] }[] = [];
  const state = {
    opened: 0,
    closed: 0,
    auth: 0,
    generated: 0,
    authStatus: 200,
    allowed: true,
    failCommit: false,
    pending: false,
    hold: undefined as undefined | (() => Promise<void>),
  };
  const connections = Object.fromEntries(
    ["quota", "text", "conversation"].map((lane) => [
      lane,
      function (this: PostgresAiHost["connections"]): PostgresConnection {
        assert.equal(this, connections);
        state.opened++;
        return {
          connect: async () => {},
          query: async (text, values): Promise<PostgresResult> => {
            calls.push({ lane, text, values });
            if (text === "COMMIT") {
              if (state.hold) await state.hold();
              if (state.failCommit) throw Error("PRIVATE database credential");
            }
            let rows: Record<string, unknown>[] = [];
            const op = values?.[1] as Operation;
            if (text.includes(" AS allowed"))
              rows = [{ allowed: state.allowed }];
            if (text.includes(" AS context")) rows = [{ context: context(op) }];
            if (text.includes(" AS checked")) rows = [{ checked: "" }];
            if (text.includes("ai_receipt_lookup"))
              rows = [
                { result: { kind: state.pending ? "pending" : "missing" } },
              ];
            if (text.includes("ai_conversation_reserve"))
              rows = [
                { result: { kind: "acquired", token, context: context(op) } },
              ];
            if (text.includes("ai_conversation_complete"))
              rows = [{ result: JSON.parse(values![4]!) }];
            if (text.includes("ai_conversation_recovery_lookup")) {
              const request = JSON.parse(values![2]!) as {
                client_event_id: string;
              };
              rows = [
                {
                  result: {
                    kind: "pending",
                    context: context(op),
                    correlation: {
                      receipt_id: token,
                      user_id: values![0],
                      operation: op,
                      client_event_id: request.client_event_id,
                      idempotency_key: `${values![0]}/${op}/${request.client_event_id}`,
                    },
                  },
                },
              ];
            }
            if (text.includes("ai_conversation_reconcile"))
              rows = [{ result: JSON.parse(values![6]!) }];
            return {
              command: text.startsWith("SELECT")
                ? "SELECT"
                : text.split(" ")[0]!,
              rowCount: rows.length || null,
              rows,
            };
          },
          close: () => {
            state.closed++;
          },
        };
      },
    ]),
  ) as PostgresAiHost["connections"];
  const auth = new SupabaseAuthVerifier(
    "https://fixture.supabase.co",
    publicKey,
    async (url, init) => {
      state.auth++;
      assert.equal(url, "https://fixture.supabase.co/auth/v1/user");
      assert.equal(init?.redirect, "error");
      const headers = new Headers(init?.headers);
      assert.equal(headers.get("apikey"), publicKey);
      return Response.json(
        {
          id:
            headers.get("authorization") === "Bearer fixture-B" ? userB : userA,
          aud: "authenticated",
        },
        { status: state.authStatus },
      );
    },
  );
  const provider = {
    label: "captured-owner",
    generate: async function (
      input: Parameters<PostgresAiHost["provider"]["generate"]>[0],
    ) {
      assert.equal(this.label, "captured-owner");
      state.generated++;
      assert.equal(
        state.opened,
        state.closed,
        "No transaction may survive provider IO",
      );
      assert.equal(calls.at(-1)?.text, "COMMIT");
      assert.equal(JSON.stringify(input).includes("fixture-A"), false);
      return JSON.stringify(response(input.operation));
    },
  };
  const host = { auth, provider, connections };
  return {
    state,
    calls,
    host,
    handlers: (recovery?: AuthenticatedConversationLookup) =>
      assemblePostgresAiHandlers(contracts, {
        ...host,
        ...(recovery ? { recovery } : {}),
      }),
  };
}
function request(op: Operation, bearer = "fixture-A", signal?: AbortSignal) {
  return new Request("https://not-a-route.invalid/?operation=untrusted", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${bearer}`,
    },
    body: JSON.stringify(fixtures[`${op}_request`]),
    signal,
  });
}
for (const op of operations)
  test(`assembled ${op} verifies Supabase Auth and owned SQL commits before provider and HTTP success`, async () => {
    const f = fixture(),
      handlers = f.handlers();
    assert.deepEqual(Object.keys(handlers), [...operations]);
    assert.equal(Object.isFrozen(handlers), true);
    assert.equal(f.state.opened, 0);
    assert.equal(f.state.auth, 0);
    const result = await handlers[op](request(op));
    assert.equal(result.status, 200);
    assert.deepEqual(await result.json(), response(op));
    assert.equal(f.state.auth, 1);
    assert.equal(f.state.generated, 1);
    assert.equal(f.state.opened, isMutation(op) ? 4 : 3);
    assert.equal(f.state.closed, f.state.opened);
    assert.equal(result.headers.get("cache-control"), "no-store");
    for (const call of f.calls.filter((c) => c.text.startsWith("SELECT"))) {
      assert.equal(call.values![0], userA);
      assert.equal(call.values![1], op);
    }
    assert.equal(f.calls.at(-1)?.text, "COMMIT");
    assert.equal(
      f.calls.some((c) => c.lane === "text"),
      !isMutation(op),
    );
  });
test("trusted server assembly rejects bad/public-private configuration and missing provider without IO", () => {
  const config = {
    projectUrl: "https://fixture.supabase.co",
    publicKey,
    databaseUrl: "postgresql://server:secret@db.invalid/nihongo",
  };
  const provider = {
    generate: async () => {
      assert.fail("construction invoked provider");
    },
  };
  const handlers = createTrustedPostgresAiHandlers(contracts, config, provider);
  assert.equal(Object.isFrozen(handlers), true);
  assert.deepEqual(Object.keys(handlers), [...operations]);
  for (const change of [
    { projectUrl: "http://fixture.supabase.co" },
    { publicKey: "sb_secret_PRIVATE" },
    { databaseUrl: config.databaseUrl + "?sslmode=disable" },
  ])
    assert.throws(
      () =>
        createTrustedPostgresAiHandlers(
          contracts,
          { ...config, ...change },
          provider,
        ),
      { message: "Invalid trusted AI server configuration" },
    );
  assert.throws(
    () =>
      createTrustedPostgresAiHandlers(
        contracts,
        config,
        undefined as unknown as PostgresAiHost["provider"],
      ),
    { message: "Invalid trusted AI server configuration" },
  );
});
test("assembled Auth denial and quota denial or commit uncertainty never dispatch or use text/conversation", async () => {
  for (const mode of ["auth", "quota", "commit"] as const) {
    const f = fixture();
    if (mode === "auth") f.state.authStatus = 401;
    if (mode === "quota") f.state.allowed = false;
    if (mode === "commit") f.state.failCommit = true;
    const result = await f
      .handlers()
      .start_conversation(request("start_conversation"));
    assert.equal(
      result.status,
      mode === "auth" ? 401 : mode === "quota" ? 429 : 503,
    );
    assert.equal(f.state.generated, 0);
    assert.equal(f.state.opened, mode === "auth" ? 0 : 1);
    assert.equal(f.state.closed, f.state.opened);
    assert.equal(
      f.calls.some((c) => c.lane !== "quota"),
      false,
    );
    assert.equal(
      JSON.stringify(await result.json()).includes("PRIVATE"),
      false,
    );
  }
});
test("assembled handlers capture port methods receivers and factories before caller rebinding", async () => {
  const f = fixture(),
    host = f.host;
  const handlers = assemblePostgresAiHandlers(contracts, host);
  host.auth.verify = async () => {
    assert.fail("rebound Auth");
  };
  host.provider.generate = async () => {
    assert.fail("rebound provider");
  };
  for (const lane of ["quota", "text", "conversation"] as const)
    (host.connections as Record<string, () => PostgresConnection>)[lane] =
      () => {
        assert.fail("rebound connection factory");
      };
  const result = await handlers.start_conversation(
    request("start_conversation"),
  );
  assert.equal(result.status, 200);
  await result.body?.cancel();
  assert.equal(f.state.generated, 1);
  assert.equal(f.state.closed, 4);
});
test("assembled calls reverify A B A without owner or identity cache", async () => {
  const f = fixture(),
    handlers = f.handlers();
  for (const [bearer, owner] of [
    ["fixture-A", userA],
    ["fixture-B", userB],
    ["fixture-A", userA],
  ] as const) {
    const before = f.calls.length;
    const result = await handlers.correct_sentence(
      request("correct_sentence", bearer),
    );
    assert.equal(result.status, 200);
    await result.body?.cancel();
    for (const call of f.calls
      .slice(before)
      .filter((c) => c.text.startsWith("SELECT")))
      assert.equal(call.values![0], owner);
  }
  assert.equal(f.state.auth, 3);
  assert.equal(f.state.generated, 3);
  assert.equal(f.state.closed, 9);
});
test("assembled same-store recovery uses captured lookup without new acquisition or provider", async () => {
  const f = fixture();
  f.state.pending = true;
  let looked = 0;
  const lookup: AuthenticatedConversationLookup = {
    lookupExisting: async (input) => {
      looked++;
      assert.equal(f.state.opened, f.state.closed);
      return JSON.stringify({
        user_id: input.key.userId,
        operation: input.key.operation,
        client_event_id: input.key.eventId,
        idempotency_key: input.idempotencyKey,
        request: input.request,
        context: input.context,
        response: response(input.key.operation),
      });
    },
  };
  const handlers = f.handlers(lookup);
  lookup.lookupExisting = async () => {
    assert.fail("rebound lookup");
  };
  const result = await handlers.start_conversation(
    request("start_conversation"),
  );
  assert.equal(result.status, 200);
  assert.deepEqual(await result.json(), response("start_conversation"));
  assert.equal(looked, 1);
  assert.equal(f.state.generated, 0);
  assert.equal(
    f.calls.some((c) => c.text.includes("ai_conversation_reserve")),
    false,
  );
  assert.equal(
    f.calls.filter((c) => c.text.includes("ai_conversation_reconcile")).length,
    1,
  );
  assert.equal(f.state.closed, 4);
});
test("assembled pending without explicit recovery cannot acquire renew or dispatch", async () => {
  const f = fixture();
  f.state.pending = true;
  const result = await f
    .handlers()
    .start_conversation(request("start_conversation"));
  assert.equal(result.status, 503);
  await result.body?.cancel();
  assert.equal(f.state.generated, 0);
  assert.equal(f.state.closed, 2);
  assert.equal(
    f.calls.some((c) => /reserve|reconcile/.test(c.text)),
    false,
  );
});
test("assembled cancelled quota commit closes once and ignores late result before provider", async () => {
  const f = fixture(),
    parent = new AbortController();
  let release!: () => void;
  f.state.hold = () =>
    new Promise<void>((resolve) => {
      release = resolve;
    });
  const work = f
    .handlers()
    .start_conversation(
      request("start_conversation", "fixture-A", parent.signal),
    );
  const end = performance.now() + 1000;
  while (!release && performance.now() < end) await setImmediate();
  assert.ok(release);
  parent.abort();
  const result = await work;
  assert.equal(result.status, 499);
  await result.body?.cancel();
  release();
  await setImmediate();
  assert.equal(f.state.generated, 0);
  assert.equal(f.state.opened, 1);
  assert.equal(f.state.closed, 1);
});
