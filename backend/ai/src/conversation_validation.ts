// Internal pure validation shared by owned SQL driver and opt-in recovery.
import { BoundaryError, Contracts, UUID } from "./contracts.ts";
import type { Mutation, Requests, Responses } from "./contracts.ts";
import type {
  PreparedContext,
  ReceiptKey,
  ConversationCorrelation,
} from "./ports.ts";
const failure = () => new BoundaryError("NETWORK_UNAVAILABLE");
export const bytes = (text: string) =>
  new TextEncoder().encode(text).byteLength;
export function serialized(value: unknown, limit: number): string {
  const text = JSON.stringify(value);
  if (!text || bytes(text) > limit) throw failure();
  return text;
}
export function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw failure();
  return value as Record<string, unknown>;
}
export function canonicalUuid(value: unknown): value is string {
  return (
    typeof value === "string" &&
    UUID.test(value) &&
    value === value.toLowerCase()
  );
}
export function freeze<T>(value: T): T {
  if (value !== null && typeof value === "object") {
    Object.freeze(value);
    for (const child of Object.values(value)) freeze(child);
  }
  return value;
}
export function context(
  value: unknown,
  op: Mutation,
  request: Requests[Mutation],
): PreparedContext {
  serialized(value, 65536);
  const o = object(value),
    finish = op === "finish_conversation";
  if (
    Object.keys(o).length !== (finish ? 4 : 6) ||
    !canonicalUuid(o.sessionId) ||
    typeof o.instruction !== "string" ||
    bytes(o.instruction) < 1 ||
    bytes(o.instruction) > 10000 ||
    !Array.isArray(o.transcript) ||
    o.transcript.length > 99 ||
    !Array.isArray(o.allowedRefs) ||
    o.allowedRefs.length > 1000 ||
    (!finish &&
      (!canonicalUuid(o.messageId) ||
        !Number.isSafeInteger(o.sequenceNo) ||
        (o.sequenceNo as number) < 0)) ||
    (finish && ("messageId" in o || "sequenceNo" in o))
  )
    throw failure();
  if (
    op !== "start_conversation" &&
    o.sessionId !==
      (request as Requests["conversation_turn"]).session_id.toLowerCase()
  )
    throw failure();
  if (
    op === "start_conversation"
      ? o.transcript.length !== 0 || o.sequenceNo !== 0
      : o.transcript.length === 0 || o.transcript.length % 2 !== 1
  )
    throw failure();
  for (const [index, value] of o.transcript.entries()) {
    const message = object(value);
    if (
      Object.keys(message).length !== 2 ||
      message.role !== (index % 2 === 0 ? "assistant" : "user") ||
      typeof message.text_ja !== "string" ||
      [...message.text_ja].length < 1 ||
      [...message.text_ja].length > 5000
    )
      throw failure();
  }
  if (
    op === "conversation_turn" &&
    (o.transcript.length > 97 || o.sequenceNo !== o.transcript.length + 1)
  )
    throw failure();
  const refs = new Set<string>();
  for (const value of o.allowedRefs) {
    const ref = object(value);
    if (
      Object.keys(ref).length !== 2 ||
      !["GRAMMAR", "VOCABULARY"].includes(ref.item_type as string) ||
      !canonicalUuid(ref.item_id)
    )
      throw failure();
    const key = `${ref.item_type}/${ref.item_id}`;
    if (refs.has(key)) throw failure();
    refs.add(key);
  }
  return freeze(structuredClone(o)) as unknown as PreparedContext;
}
export function correlation(
  value: unknown,
  key: ReceiptKey,
): ConversationCorrelation {
  serialized(value, 1024);
  const o = object(value);
  if (Object.keys(o).length !== 5 || !canonicalUuid(o.receipt_id))
    throw new BoundaryError("FORBIDDEN");
  if (
    o.user_id !== key.userId ||
    o.operation !== key.operation ||
    o.client_event_id !== key.eventId ||
    o.idempotency_key !== `${key.userId}/${key.operation}/${key.eventId}`
  )
    throw new BoundaryError("FORBIDDEN");
  return freeze(structuredClone(o)) as unknown as ConversationCorrelation;
}
export function same(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (
    !a ||
    !b ||
    typeof a !== "object" ||
    typeof b !== "object" ||
    Array.isArray(a) !== Array.isArray(b)
  )
    return false;
  const x = Object.keys(a),
    y = Object.keys(b);
  return (
    x.length === y.length &&
    x.every(
      (k) =>
        Object.hasOwn(b, k) &&
        same(
          (a as Record<string, unknown>)[k],
          (b as Record<string, unknown>)[k],
        ),
    )
  );
}
export function completion(
  contracts: Contracts,
  input: { key: ReceiptKey; request: Requests[Mutation] },
  captured: PreparedContext,
  response: Responses[Mutation],
): { ctx: PreparedContext; valid: Responses[Mutation] } {
  const ctx = context(
    structuredClone(captured),
    input.key.operation,
    input.request,
  );
  const valid = freeze(
    structuredClone(
      contracts.response(input.key.operation, structuredClone(response)),
    ),
  );
  const o = valid as unknown as Record<string, unknown>;
  if (input.key.operation !== "finish_conversation") {
    const message =
      o.assistant_message as Responses["conversation_turn"]["assistant_message"];
    if (
      message.id !== ctx.messageId ||
      message.sequence_no !== ctx.sequenceNo ||
      message.audio_ref !== null ||
      (input.key.operation === "start_conversation" &&
        o.session_id !== ctx.sessionId)
    )
      throw new BoundaryError("PROVIDER_UNAVAILABLE");
  }
  const refs: { item_type: string; item_id: string }[] = [];
  for (const field of ["live_feedback", "errors"])
    for (const correction of (o[field] ?? []) as { item_refs: typeof refs }[])
      refs.push(...correction.item_refs);
  refs.push(...((o.srs_recommendations ?? []) as typeof refs));
  if (
    refs.some(
      (ref) =>
        !ctx.allowedRefs.some(
          (a) => a.item_type === ref.item_type && a.item_id === ref.item_id,
        ),
    )
  )
    throw new BoundaryError("PROVIDER_UNAVAILABLE");
  serialized(valid, 1048576);
  return { ctx, valid };
}
