import { BoundaryError } from "./contracts.ts";
import type { QuizReportTransaction } from "./quiz_report_transaction.ts";

const safe = (error: unknown): BoundaryError => {
  if (
    error instanceof BoundaryError &&
    [
      "UNAUTHORIZED",
      "VALIDATION_FAILURE",
      "SYNC_CONFLICT",
      "NETWORK_UNAVAILABLE",
    ].includes(error.code)
  )
    return new BoundaryError(error.code);
  return new BoundaryError("INTERNAL_ERROR");
};

/** Scope an already-open verified-owner transaction's capabilities. The host
 * must await this function BEFORE commit/rollback, and supply bounded operations.
 * This does not open a transaction, verify identity or cancel native SQL.
 */
export async function withQuizReportTransactionScope<T>(
  source: QuizReportTransaction,
  work: (tx: QuizReportTransaction) => Promise<T>,
): Promise<T> {
  let active = true;
  let pending: Promise<void> | undefined;
  let failed: BoundaryError | undefined;
  function call<R>(operation: () => Promise<R>): Promise<R> {
    if (!active || pending || failed) {
      failed ??= new BoundaryError("INTERNAL_ERROR");
      const rejected = Promise.reject<R>(failed);
      void rejected.catch(() => {});
      return rejected;
    }
    // Defer dispatch until pending has been installed, including reentrant ports.
    const result = Promise.resolve()
      .then(() => {
        // The callback can throw synchronously before this microtask dispatches.
        // Revocation must also fence already-queued, not-yet-started operations.
        if (!active) throw new BoundaryError("INTERNAL_ERROR");
        return operation();
      })
      .catch((error: unknown) => {
        failed ??= safe(error);
        throw failed;
      });
    const settled = result.then(
      () => {
        pending = undefined;
      },
      () => {
        pending = undefined;
      },
    );
    pending = settled;
    return result;
  }
  const tx: QuizReportTransaction = Object.freeze<QuizReportTransaction>({
    replay: (request) => call(() => source.replay(request)),
    validateCurrentContent: (request) =>
      call(() => source.validateCurrentContent(request)),
    store: (request) => call(() => source.store(request)),
  });
  let result: T;
  try {
    result = await work(tx);
  } catch (error) {
    failed ??= safe(error);
  } finally {
    active = false;
    // Forgotten awaits are a protocol failure even if the operation succeeds.
    // Drain before returning authority to the host; never orphan a SQL promise.
    if (pending) {
      failed ??= new BoundaryError("INTERNAL_ERROR");
      await pending;
    }
  }
  if (failed) throw failed;
  return result!;
}
