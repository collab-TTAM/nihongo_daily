import { BoundaryError, Contracts, parseBounded } from "./contracts.ts";
import type { Mutation, Requests, Responses } from "./contracts.ts";
import type {
  ConversationRecoveryStore,
  AuthenticatedConversationLookup,
  ReceiptKey,
} from "./ports.ts";
import {
  serialized,
  object,
  canonicalUuid,
  freeze,
  context,
  correlation,
  same,
  completion,
} from "./conversation_validation.ts";
const unavailable = () => new BoundaryError("PROVIDER_UNAVAILABLE");
/** Explicit server-only orchestration. A real authenticated lookup adapter is
 * mandatory/injected; this class verifies association, not upstream transport.
 * Never acquires/dispatches/renews or calls the legacy recovery port.
 */
export class CorrelatedConversationRecovery {
  private readonly contracts: Contracts;
  private readonly store: ConversationRecoveryStore;
  private readonly lookup: AuthenticatedConversationLookup;
  private readonly timeoutMs: number;
  constructor(
    contracts: Contracts,
    store: ConversationRecoveryStore,
    lookup: AuthenticatedConversationLookup,
    timeoutMs = 10000,
  ) {
    if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 15000)
      throw Error("Invalid recovery timeout");
    this.contracts = contracts;
    this.store = store;
    this.lookup = lookup;
    this.timeoutMs = timeoutMs;
  }
  async recover(
    key: ReceiptKey,
    originalRequest: Requests[Mutation],
    parent: AbortSignal,
  ): Promise<Responses[Mutation]> {
    const controller = new AbortController(),
      deadline = performance.now() + this.timeoutMs;
    const stop = () => controller.abort();
    const alive = () => {
      if (performance.now() >= deadline) stop();
      if (controller.signal.aborted) throw unavailable();
    };
    const wait = async <T>(work: Promise<T>): Promise<T> => {
      let abort: (() => void) | undefined;
      try {
        if (controller.signal.aborted) {
          void work.catch(() => {});
          throw unavailable();
        }
        const value = await new Promise<T>((resolve, reject) => {
          abort = () => reject(unavailable());
          controller.signal.addEventListener("abort", abort, { once: true });
          void work.then(resolve, reject);
        });
        alive();
        return value;
      } finally {
        if (abort) controller.signal.removeEventListener("abort", abort);
      }
    };
    const timer = setTimeout(stop, this.timeoutMs);
    parent.addEventListener("abort", stop, { once: true });
    try {
      if (parent.aborted) stop();
      alive();
      const capturedKey = freeze(structuredClone(key));
      if (
        !canonicalUuid(capturedKey.userId) ||
        !canonicalUuid(capturedKey.eventId) ||
        ![
          "start_conversation",
          "conversation_turn",
          "finish_conversation",
        ].includes(capturedKey.operation)
      )
        throw new BoundaryError("VALIDATION_FAILURE");
      const request = freeze(
        this.contracts.request(
          capturedKey.operation,
          structuredClone(originalRequest),
        ),
      );
      serialized(request, 32768);
      if (request.client_event_id.toLowerCase() !== capturedKey.eventId)
        throw new BoundaryError("SYNC_CONFLICT");
      alive();
      const found = object(
        await wait(
          this.store.lookupRecovery(capturedKey, request, controller.signal),
        ),
      );
      serialized(found, 2097152);
      if (
        found.kind === "completed" &&
        Object.keys(found).length === 2 &&
        "response" in found
      ) {
        serialized(found.response, 1048576);
        const replay = freeze(
          structuredClone(
            this.contracts.response(capturedKey.operation, found.response),
          ),
        );
        alive();
        return replay;
      }
      if (
        found.kind !== "pending" ||
        Object.keys(found).length !== 3 ||
        !("correlation" in found) ||
        !("context" in found)
      )
        throw unavailable();
      const bound = correlation(found.correlation, capturedKey);
      const capturedContext = context(
        found.context,
        capturedKey.operation,
        request,
      );
      const input = freeze({
        key: capturedKey,
        request,
        context: capturedContext,
        idempotencyKey: bound.idempotency_key,
      });
      alive();
      let raw: string | null;
      try {
        raw = await wait(this.lookup.lookupExisting(input, controller.signal));
      } catch {
        throw unavailable();
      }
      alive();
      if (typeof raw !== "string") throw unavailable();
      let valid: Responses[Mutation];
      try {
        const record = object(
          parseBounded(raw, 2097152, "PROVIDER_UNAVAILABLE"),
        );
        if (
          Object.keys(record).length !== 7 ||
          record.user_id !== capturedKey.userId ||
          record.operation !== capturedKey.operation ||
          record.client_event_id !== capturedKey.eventId ||
          record.idempotency_key !== bound.idempotency_key ||
          !same(record.request, request) ||
          !same(record.context, capturedContext) ||
          !Object.hasOwn(record, "response")
        )
          throw unavailable();
        valid = completion(
          this.contracts,
          { key: capturedKey, request },
          capturedContext,
          record.response as Responses[Mutation],
        ).valid;
      } catch {
        throw unavailable();
      }
      alive();
      await wait(
        this.store.reconcile(
          capturedKey,
          request,
          bound,
          capturedContext,
          valid,
          controller.signal,
        ),
      );
      alive();
      return valid;
    } catch (error) {
      if (error instanceof BoundaryError) throw error;
      throw unavailable();
    } finally {
      clearTimeout(timer);
      parent.removeEventListener("abort", stop);
      stop();
    }
  }
}
