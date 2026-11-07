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
/** Atomic mutation lane. Acquired resolves only after confirmed context+claim
 * COMMIT; pending never exposes a token. Completion atomically revalidates and
 * persists public writes + receipt + reservation release. No recovery redispatch.
 */
export type ConversationClaim =
  | { kind: "acquired"; token: string; context: PreparedContext }
  | Exclude<ReceiptLookup, { kind: "missing" }>;
export interface ConversationStore {
  lookup(
    key: ReceiptKey,
    request: Requests[Mutation],
    signal: AbortSignal,
  ): Promise<ReceiptLookup>;
  acquire(
    key: ReceiptKey,
    request: Requests[Mutation],
    signal: AbortSignal,
  ): Promise<ConversationClaim>;
  complete(
    key: ReceiptKey,
    request: Requests[Mutation],
    token: string,
    response: Responses[Mutation],
    context: PreparedContext,
    signal: AbortSignal,
  ): Promise<void>;
}
/** Database identity binding only; this is NOT upstream authenticity proof. */
export interface ConversationCorrelation {
  readonly receipt_id: string;
  readonly user_id: string;
  readonly operation: Mutation;
  readonly client_event_id: string;
  readonly idempotency_key: string;
}
export type ConversationRecoveryLookup =
  | ReceiptLookup
  | {
      kind: "pending";
      correlation: ConversationCorrelation;
      context: PreparedContext;
    };
/** Host-only prerequisite for trusted authenticated lookup-only recovery.
 * Not an AiDependencies/default binding. Never feed learner/model/legacy recovery
 * output here as proof; the host must authenticate upstream result association.
 * Missing/legacy pending never creates/renews a claim or permits redispatch.
 */
export interface ConversationRecoveryStore {
  lookupRecovery(
    key: ReceiptKey,
    request: Requests[Mutation],
    signal: AbortSignal,
  ): Promise<ConversationRecoveryLookup>;
  reconcile(
    key: ReceiptKey,
    request: Requests[Mutation],
    correlation: ConversationCorrelation,
    context: PreparedContext,
    response: Responses[Mutation],
    signal: AbortSignal,
  ): Promise<void>;
}
/** Trusted server adapter MUST authenticate upstream and verify result provenance.
 * Metadata here must come from that verified lookup, never model/learner echoes.
 * Read existing result only: no generate/reissue/claim/reset on missing or unknown.
 * Return null for absent/ambiguous; otherwise <=2MiB JSON with exactly user_id,
 * operation, client_event_id, idempotency_key, original request/context and response.
 * Structural checks in recovery do not implement transport authentication.
 */
export interface AuthenticatedConversationLookup {
  lookupExisting(
    input: {
      readonly key: Readonly<ReceiptKey>;
      readonly request: Requests[Mutation];
      readonly context: PreparedContext;
      readonly idempotencyKey: string;
    },
    signal: AbortSignal,
  ): Promise<string | null>;
}
export interface ConversationRecoveryBinding {
  /** Must be the identical captured AiDependencies.conversations object. */
  readonly store: ConversationStore & ConversationRecoveryStore;
  readonly lookup: AuthenticatedConversationLookup;
}
export interface AiDependencies {
  /** Explicit binding; never fall back to split claim or legacy recovery when set. */
  conversations?: ConversationStore;
  /** Explicit opt-in only; no adapter/default/legacy fallback is supplied. */
  conversationRecovery?: ConversationRecoveryBinding;
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
