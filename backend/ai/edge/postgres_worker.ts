// TEST ONLY disposable localhost PostgreSQL17/plaintext, Auth HTTP and provider.
// Never a deployable binding: fixed fixtures, no environment or learner config.
import { Client } from "pg";
import schema from "../../../contracts/v0.1/models.schema.json" with {
  type: "json",
};
import fixtures from "../../../contracts/v0.1/fixtures.json" with {
  type: "json",
};
import { Contracts, operations } from "../src/contracts.ts";
import type { Operation } from "../src/contracts.ts";
import type { ProviderInput } from "../src/ports.ts";
import type { PostgresConnection } from "../src/postgres_connection.ts";
import { assemblePostgresAiHandlers } from "../src/trusted_runtime.ts";
import { SupabaseAuthVerifier } from "../src/supabase_auth.ts";

const contracts = new Contracts(schema);
const data = fixtures as Record<string, unknown>;
const owners: Record<string, string> = Object.fromEntries(
  ["A", "B", "text", "acquire", "complete", "malformed", "held"].map((
    name,
    i,
  ) => [
    `fixture-${name}`,
    `71000000-0000-4000-8000-00000000000${i + 1}`,
  ]),
);
const metrics: Record<
  string,
  { calls: number; opened: number; closed: number; injected: boolean }
> = {};
let release: (() => void) | undefined;
function generated(input: ProviderInput): unknown {
  if (input.operation === "tutor_explain") return data.tutor_explain_response;
  if (input.operation === "correct_sentence") {
    return data.correct_sentence_response;
  }
  if (input.operation === "finish_conversation") {
    return {
      scores: { grammar: 80, vocabulary: 90, fluency: 75 },
      errors: [],
      strengths_vi: [],
      focus_next_vi: [],
      srs_recommendations: [],
    };
  }
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
const auth = new SupabaseAuthVerifier(
  "https://fixture.supabase.co",
  "sb_publishable_TESTONLY0000000000",
  async (url, init) => {
    if (url !== "https://fixture.supabase.co/auth/v1/user") {
      throw Error("TEST ONLY Auth origin");
    }
    const bearer = new Headers(init?.headers).get("authorization") ?? "";
    const id = owners[bearer.replace(/^Bearer /, "")];
    return id
      ? Response.json({ id, aud: "authenticated" })
      : Response.json({}, { status: 401 });
  },
);
type Mode = "normal" | "acquire" | "complete" | "malformed" | "held";
function bind(mode: Mode) {
  const counts = { calls: 0, opened: 0, closed: 0, injected: false };
  metrics[mode] = counts;
  const factory = (): PostgresConnection => {
    const c = new Client({
      host: "127.0.0.1",
      port: 5432,
      user: "postgres",
      password: "postgres",
      database: "nihongo_test",
      ssl: false,
      application_name: "nd-edge-pg",
      connectionTimeoutMillis: 2000,
      query_timeout: 3000,
      pipeline: false,
    });
    c.on("error", () => {});
    counts.opened++;
    let phase = "";
    return {
      connect: async () => {
        await c.connect();
      },
      query: async (text, values) => {
        if (text.startsWith("SELECT")) phase = text;
        const result = await c.query(text, values);
        if (text === "COMMIT") {
          if (c.getTransactionStatus() !== "I") {
            throw Error("TEST ONLY COMMIT not idle");
          }
          if (
            !counts.injected && (mode === "acquire" || mode === "complete") &&
            phase.includes(
              mode === "acquire"
                ? "ai_conversation_reserve"
                : "ai_conversation_complete",
            )
          ) {
            counts.injected = true;
            throw Error("PRIVATE TEST ONLY lost committed delivery");
          }
        }
        return result;
      },
      close: () => {
        counts.closed++;
        void c.end().catch(() => {});
      },
    };
  };
  return assemblePostgresAiHandlers(contracts, {
    auth,
    connections: { quota: factory, text: factory, conversation: factory },
    provider: {
      generate: async (input) => {
        counts.calls++;
        if (counts.opened !== counts.closed) {
          throw Error("PRIVATE TEST ONLY open transaction during provider");
        }
        if (mode === "malformed") {
          return '{"PRIVATE":"TEST ONLY invalid provider"}';
        }
        const result = JSON.stringify(generated(input));
        if (mode === "held") {
          return await new Promise<string>((resolve, reject) => {
            const timer = setTimeout(
              () => reject(Error("TEST ONLY held timeout")),
              5000,
            );
            release = () => {
              clearTimeout(timer);
              resolve(result);
            };
          });
        }
        return result;
      },
    },
  });
}
const normal = bind("normal"),
  handlers = new Map<string, (r: Request) => Promise<Response>>();
for (const op of operations) handlers.set(`/${op}`, normal[op]);
for (const mode of ["acquire", "complete", "malformed", "held"] as const) {
  handlers.set(`/${mode}`, bind(mode).start_conversation);
}
Deno.serve(async (request) => {
  const path = new URL(request.url).pathname;
  if (request.method === "GET" && path === "/__probe/release") {
    release?.();
    release = undefined;
    return Response.json({ fixtureOnly: true });
  }
  if (request.method === "GET" && path === "/__probe") {
    return Response.json({
      fixtureOnly: true,
      lane: "postgres-user-worker",
      runtime: Deno.version,
      metrics,
    });
  }
  const handler = handlers.get(path as `/${Operation}`);
  return handler
    ? await handler(request)
    : new Response("TEST ONLY unknown route", { status: 404 });
});
