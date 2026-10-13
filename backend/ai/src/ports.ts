import type { Operation, Mutation, Requests, Responses } from "./contracts.ts";
import type { item_ref, error as WireError } from "./wire.ts";

/** This is a verified identity, not decoded/unverified JWT claims or client JSON. */
export interface AuthVerifier {
  verify(bearer: string, signal: AbortSignal): Promise<{ id: string } | null>;
}
/** Implement globally/atomically across workers; denial or failure must fail closed. */
export interface RateLimiter {
  consume(userId: string, op: Operation, signal: AbortSignal): Promise<boolean>;
}

export interface PreparedContext {
  readonly instruction: string;
  readonly transcript: ReadonlyArray<{
    readonly role: "user" | "assistant";
    readonly text_ja: string;
  }>;
  readonly allowedRefs: ReadonlyArray<item_ref>;
  readonly sessionId?: string;
  readonly messageId?: string;
  readonly sequenceNo?: number;
}
/** Trusted repository authorizes owner/active level/content and reserves server IDs.
 * Session reservations/sequence allocation must serialize distinct mutation events
 * and complete atomically with messages/session changes + receipt, never via AI SQL.
 */
export interface ContextRepository {
  prepare<O extends Operation>(
    userId: string,
    op: O,
    request: Requests[O],
    signal: AbortSignal,
  ): Promise<PreparedContext>;
  validateResult<O extends Operation>(
    userId: string,
    op: O,
    request: Requests[O],
    response: Responses[O],
    context: PreparedContext,
    signal: AbortSignal,
  ): Promise<void>;
}

export interface ProviderInput<O extends Operation = Operation> {
  readonly operation: O;
  readonly systemInstruction: string;
  readonly request: Requests[O];
  readonly context: PreparedContext;
  readonly idempotencyKey?: string;
}
export interface AiProvider {
  generate(input: ProviderInput, signal: AbortSignal): Promise<string>;
}
/** Recovery may inspect an existing provider result, never dispatch the operation.
 * Unknown/not-found is NOT evidence that it is safe to reissue or delete a receipt.
 */
export interface PendingRecovery {
  lookup(
    key: ReceiptKey,
    signal: AbortSignal,
  ): Promise<{ response: string; context: PreparedContext } | null>;
}
export interface ReceiptKey {
  userId: string;
  operation: Mutation;
  eventId: string;
}
export type ReceiptLookup =
  | { kind: "missing" }
  | { kind: "pending" }
  | { kind: "completed"; response: unknown };
export type ReceiptClaim =
  | { kind: "acquired"; token: string }
  | Exclude<ReceiptLookup, { kind: "missing" }>;
export interface ReceiptStore {
  /** Compare full immutable request; changed input throws SYNC_CONFLICT. */
  lookup(
    key: ReceiptKey,
    request: Requests[Mutation],
    signal: AbortSignal,
  ): Promise<ReceiptLookup>;
  claim(
    key: ReceiptKey,
    request: Requests[Mutation],
    signal: AbortSignal,
  ): Promise<ReceiptClaim>;
  /** Within a trusted transaction: persist validated messages/session and receipt. */
  complete(
    key: ReceiptKey,
    token: string,
    response: Responses[Mutation],
    context: PreparedContext,
    signal: AbortSignal,
  ): Promise<void>;
  /** Recovery completion must recheck pending state + immutable provider correlation
   * and take a row lock; never create/renew a dispatch claim or expose its token. */
  reconcile(
    key: ReceiptKey,
    response: Responses[Mutation],
    context: PreparedContext,
    signal: AbortSignal,
  ): Promise<void>;
}
export interface AiDependencies {
  auth: AuthVerifier;
  limiter: RateLimiter;
  context: ContextRepository;
  provider: AiProvider;
  receipts: ReceiptStore;
  recovery?: PendingRecovery;
}
export type Outcome<O extends Operation = Operation> =
  | { ok: true; response: Responses[O] }
  | { ok: false; error: WireError };
