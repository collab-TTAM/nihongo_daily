import { readFileSync } from "node:fs";
import { BoundaryError, Contracts } from "../src/contracts.ts";
import type { Mutation, Requests, Responses } from "../src/contracts.ts";
import type {
  AiDependencies,
  PreparedContext,
  ReceiptKey,
  ReceiptStore,
  ReceiptLookup,
  ReceiptClaim,
  ProviderInput,
} from "../src/ports.ts";

export const fixtures = JSON.parse(
  readFileSync(
    new URL("../../../contracts/v0.1/fixtures.json", import.meta.url),
    "utf8",
  ),
) as Record<string, unknown>;
const schema = JSON.parse(
  readFileSync(
    new URL("../../../contracts/v0.1/models.schema.json", import.meta.url),
    "utf8",
  ),
);
export const contracts = new Contracts(schema);
export const userA = "10000000-0000-4000-8000-000000000001";
export const userB = "10000000-0000-4000-8000-000000000002";
export const context: PreparedContext = {
  instruction: "N5; backend scenario context",
  transcript: [],
  allowedRefs: [],
  sessionId: (
    fixtures.start_conversation_response as Responses["start_conversation"]
  ).session_id,
  messageId: (
    fixtures.start_conversation_response as Responses["start_conversation"]
  ).assistant_message.id,
  sequenceNo: (
    fixtures.start_conversation_response as Responses["start_conversation"]
  ).assistant_message.sequence_no,
};
export function canonical(value: unknown): string {
  if (Array.isArray(value)) return "[" + value.map(canonical).join(",") + "]";
  if (value !== null && typeof value === "object")
    return (
      "{" +
      Object.keys(value)
        .sort()
        .map(
          (k) =>
            JSON.stringify(k) +
            ":" +
            canonical((value as Record<string, unknown>)[k]),
        )
        .join(",") +
      "}"
    );
  return JSON.stringify(value);
}
/** Explicit TEST ONLY store. It is not exported with the deployable service. */
export class TestReceiptStore implements ReceiptStore {
  rows = new Map<
    string,
    { request: string; token: string; response?: unknown }
  >();
  completions = 0;
  key(k: ReceiptKey): string {
    return `${k.userId}/${k.operation}/${k.eventId}`;
  }
  async lookup(
    key: ReceiptKey,
    request: Requests[Mutation],
  ): Promise<ReceiptLookup> {
    const row = this.rows.get(this.key(key));
    if (!row) return { kind: "missing" };
    if (row.request !== canonical(request))
      throw new BoundaryError("SYNC_CONFLICT");
    return row.response
      ? { kind: "completed", response: structuredClone(row.response) }
      : { kind: "pending" };
  }
  async claim(
    key: ReceiptKey,
    request: Requests[Mutation],
  ): Promise<ReceiptClaim> {
    const row = this.rows.get(this.key(key));
    if (row) {
      if (row.request !== canonical(request))
        throw new BoundaryError("SYNC_CONFLICT");
      return row.response
        ? { kind: "completed", response: structuredClone(row.response) }
        : { kind: "pending" };
    }
    const token = "test-dispatch-owner";
    this.rows.set(this.key(key), { request: canonical(request), token });
    return { kind: "acquired", token };
  }
  async complete(
    key: ReceiptKey,
    token: string,
    response: Responses[Mutation],
    _context: PreparedContext,
    signal: AbortSignal,
  ): Promise<void> {
    const row = this.rows.get(this.key(key));
    if (!row || token !== row.token || signal.aborted)
      throw new BoundaryError("FORBIDDEN");
    if (row.response && canonical(row.response) !== canonical(response))
      throw new BoundaryError("SYNC_CONFLICT");
    if (!row.response) {
      row.response = structuredClone(response);
      this.completions++;
    }
  }
  async reconcile(
    key: ReceiptKey,
    response: Responses[Mutation],
    context: PreparedContext,
    signal: AbortSignal,
  ): Promise<void> {
    await this.complete(
      key,
      this.rows.get(this.key(key))!.token,
      response,
      context,
      signal,
    );
  }
}
export function setup() {
  const store = new TestReceiptStore();
  const calls: ProviderInput[] = [];
  const deps: AiDependencies = {
    auth: {
      verify: async (token) =>
        token === "valid-A"
          ? { id: userA }
          : token === "valid-B"
            ? { id: userB }
            : null,
    },
    limiter: { consume: async () => true },
    context: {
      prepare: async (_userId, op) =>
        op === "conversation_turn"
          ? {
              ...context,
              messageId: (
                fixtures.conversation_turn_response as Responses["conversation_turn"]
              ).assistant_message.id,
              sequenceNo: (
                fixtures.conversation_turn_response as Responses["conversation_turn"]
              ).assistant_message.sequence_no,
            }
          : context,
      validateResult: async () => {},
    },
    provider: {
      generate: async (input) => {
        calls.push(input);
        return JSON.stringify(fixtures[`${input.operation}_response`]);
      },
    },
    receipts: store,
  };
  return { store, calls, deps };
}
