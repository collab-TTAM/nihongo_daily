// TEST ONLY. Fixture ports and in-memory receipts; never a deployable Auth binding.
import schema from "../../../contracts/v0.1/models.schema.json" with {
  type: "json",
};
import fixtures from "../../../contracts/v0.1/fixtures.json" with {
  type: "json",
};
import { BoundaryError, Contracts, operations } from "../src/contracts.ts";
import type {
  Mutation,
  Operation,
  Requests,
  Responses,
} from "../src/contracts.ts";
import type {
  AiDependencies,
  PreparedContext,
  ReceiptKey,
  ReceiptLookup,
} from "../src/ports.ts";
import type { item_ref } from "../src/wire.ts";
import { AiService } from "../src/service.ts";
import { createAiHttpHandler } from "../src/http.ts";

const contracts = new Contracts(schema);
const data = fixtures as Record<string, unknown>;
const handlers = new Map<string, (req: Request) => Promise<Response>>();
const metrics: Record<
  string,
  { auth: number; calls: number; completions: number; aborted: boolean }
> = {};
let releaseLate: (() => void) | undefined;

function add(
  path: string,
  op: Operation,
  mode: "normal" | "late" | "malformed" = "normal",
) {
  const counts = { auth: 0, calls: 0, completions: 0, aborted: false };
  metrics[path] = counts;
  const rows = new Map<
    string,
    { request: string; response?: Responses[Mutation] }
  >();
  const key = (k: ReceiptKey) => `${k.userId}/${k.operation}/${k.eventId}`;
  const lookup = async (
    k: ReceiptKey,
    request: Requests[Mutation],
  ): Promise<ReceiptLookup> => {
    const row = rows.get(key(k));
    if (!row) return { kind: "missing" };
    if (row.request !== JSON.stringify(request)) {
      throw new BoundaryError("SYNC_CONFLICT");
    }
    return row.response
      ? { kind: "completed", response: structuredClone(row.response) }
      : { kind: "pending" };
  };
  const response = data[`${op}_response`] as Record<string, unknown>;
  const message = response.assistant_message as {
    id: string;
    sequence_no: number;
  } | undefined;
  const refs: item_ref[] = [
    ...((response.srs_recommendations ?? []) as item_ref[]),
    ...["grammar_errors", "vocabulary_errors", "errors", "live_feedback"]
      .flatMap(
        (field) =>
          ((response[field] ?? []) as { item_refs: item_ref[] }[]).flatMap(
            (c) => c.item_refs,
          ),
      ),
  ];
  const context: PreparedContext = {
    instruction: "TEST ONLY N5 bundled context",
    transcript: [],
    allowedRefs: refs,
    sessionId: String(
      response.session_id ??
        (data.start_conversation_response as { session_id: string }).session_id,
    ),
    ...(message
      ? { messageId: message.id, sequenceNo: message.sequence_no }
      : {}),
  };
  const deps: AiDependencies = {
    auth: {
      verify: async (token) => {
        counts.auth++;
        return token === "fixture-A"
          ? { id: "10000000-0000-4000-8000-000000000001" }
          : token === "fixture-B"
          ? { id: "10000000-0000-4000-8000-000000000002" }
          : null;
      },
    },
    limiter: { consume: async () => true },
    context: { prepare: async () => context, validateResult: async () => {} },
    provider: {
      generate: async (_input, signal) => {
        counts.calls++;
        if (
          mode === "malformed"
        ) return '{"secret":"TEST ONLY must never escape"}';
        if (mode === "late") {
          return await new Promise<string>((resolve) => {
            signal.addEventListener("abort", () => {
              counts.aborted = true;
            }, { once: true });
            releaseLate = () => resolve(JSON.stringify(response));
          });
        }
        return JSON.stringify(response);
      },
    },
    receipts: {
      lookup,
      claim: async (k, request) => {
        const found = await lookup(k, request);
        if (found.kind !== "missing") return found;
        rows.set(key(k), { request: JSON.stringify(request) });
        return { kind: "acquired", token: "TEST-ONLY-CLAIM" };
      },
      complete: async (k, token, result, _context, signal) => {
        const row = rows.get(key(k));
        if (!row || token !== "TEST-ONLY-CLAIM" || signal.aborted) {
          throw new BoundaryError("FORBIDDEN");
        }
        if (!row.response) {
          row.response = structuredClone(result);
          counts.completions++;
        }
      },
      reconcile: async () => {
        throw new BoundaryError("PROVIDER_UNAVAILABLE");
      },
    },
  };
  handlers.set(
    path,
    createAiHttpHandler(
      new AiService(contracts, deps),
      op,
      mode === "late" ? 200 : 2000,
    ),
  );
}
for (const op of operations) add(`/${op}`, op);
add("/late", "start_conversation", "late");
add("/malformed", "start_conversation", "malformed");
Deno.serve(async (req) => {
  const path = new URL(req.url).pathname;
  if (req.method === "GET" && path === "/__probe/release-late") {
    releaseLate?.();
    await new Promise((resolve) => setTimeout(resolve, 10));
    return Response.json({ fixtureOnly: true, metrics });
  }
  if (req.method === "GET" && path === "/__probe") {
    return Response.json({
      fixtureOnly: true,
      lane: "user-worker",
      runtime: Deno.version,
      metrics,
    });
  }
  const handle = handlers.get(path);
  return handle
    ? await handle(req)
    : new Response("TEST ONLY unknown route", { status: 404 });
});
