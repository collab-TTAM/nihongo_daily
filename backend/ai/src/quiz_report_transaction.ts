import { withQuizReportTransactionScope } from "./quiz_report_scope.ts";
import type { AnySchemaObject } from "ajv";
import { BoundaryError } from "./contracts.ts";
import {
  createQuizReportDecoder,
  createQuizReportResponseDecoder,
  type QuizReportRequest,
  type QuizReportResponse,
} from "./quiz_report.ts";

/** Trusted verified-owner capabilities on one connection/transaction.
 * replay retains the owner lock through store/end. Only authoritative miss is
 * null: unknown/failure must reject. Content and clock checks stay server-owned.
 */
export interface QuizReportTransaction {
  replay(request: QuizReportRequest): Promise<Uint8Array | null>;
  validateCurrentContent(request: QuizReportRequest): Promise<void>;
  store(request: QuizReportRequest): Promise<Uint8Array>;
}
/** Commit only after callback success; rollback on rejection; propagate commit
 * failure. The caller binds verified identity. No default host is supplied.
 */
export interface QuizReportTransactionHost {
  run(
    work: (tx: QuizReportTransaction) => Promise<QuizReportResponse>,
    signal?: AbortSignal,
  ): Promise<QuizReportResponse>;
}

export async function submitQuizReportInTransaction(
  schema: AnySchemaObject,
  raw: Uint8Array,
  host: QuizReportTransactionHost,
  signal?: AbortSignal,
): Promise<QuizReportResponse> {
  const check = () => {
    if (signal?.aborted) throw new BoundaryError("NETWORK_UNAVAILABLE");
  };
  try {
    check();
    const request = createQuizReportDecoder(schema)(raw);
    const decodeResponse = createQuizReportResponseDecoder(schema, raw);
    const result = await host.run(
      (source) =>
        withQuizReportTransactionScope(source, async (tx) => {
          check();
          const replay = await tx.replay(request);
          check();
          if (replay !== null) return decodeResponse(replay);
          await tx.validateCurrentContent(request);
          check();
          const stored = await tx.store(request);
          check();
          return decodeResponse(stored);
        }),
      signal,
    );
    check();
    return result;
  } catch (error) {
    // Reconstruct safe errors; never forward mutable messages/SQL details.
    if (
      error instanceof BoundaryError &&
      [
        "VALIDATION_FAILURE",
        "SYNC_CONFLICT",
        "UNAUTHORIZED",
        "NETWORK_UNAVAILABLE",
      ].includes(error.code)
    )
      throw new BoundaryError(error.code);
    throw new BoundaryError("INTERNAL_ERROR");
  }
}
