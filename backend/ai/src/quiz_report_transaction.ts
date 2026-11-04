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
  ): Promise<QuizReportResponse>;
}

export async function submitQuizReportInTransaction(
  schema: AnySchemaObject,
  raw: Uint8Array,
  host: QuizReportTransactionHost,
): Promise<QuizReportResponse> {
  try {
    const request = createQuizReportDecoder(schema)(raw);
    const decodeResponse = createQuizReportResponseDecoder(schema, raw);
    return await host.run(async (tx) => {
      const replay = await tx.replay(request);
      if (replay !== null) return decodeResponse(replay);
      await tx.validateCurrentContent(request);
      return decodeResponse(await tx.store(request));
    });
  } catch (error) {
    // Reconstruct safe errors; never forward mutable messages/SQL details.
    if (
      error instanceof BoundaryError &&
      ["VALIDATION_FAILURE", "SYNC_CONFLICT", "UNAUTHORIZED"].includes(
        error.code,
      )
    )
      throw new BoundaryError(error.code);
    throw new BoundaryError("INTERNAL_ERROR");
  }
}
