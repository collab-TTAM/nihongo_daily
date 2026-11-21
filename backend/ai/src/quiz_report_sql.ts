import { BoundaryError } from "./contracts.ts";
import type { PostgresResult } from "./postgres_connection.ts";
import type { QuizReportRequest } from "./quiz_report.ts";
import type { QuizReportTransaction } from "./quiz_report_transaction.ts";

type Query = (sql: string, values: string[]) => Promise<PostgresResult>;
const replaySql =
  "SELECT private.replay_quiz_report($1::jsonb)::text AS response";
const storeSql =
  "SELECT private.store_quiz_report($1::jsonb)::text AS response";
const failure = () => new BoundaryError("INTERNAL_ERROR");

/** Internal bridge only. Both capabilities MUST use the same already-open,
 * verified-owner transaction. The caller owns lock lifetime, commit/rollback,
 * cancellation/deadlines and revocation of escaped capabilities. No grants,
 * role switching, identity claims or default content success are supplied.
 * Use with submitQuizReportInTransaction for raw input and response validation.
 */
export function createQuizReportSqlTransaction(
  query: Query,
  validateCurrentContent: (request: QuizReportRequest) => Promise<void>,
): QuizReportTransaction {
  async function call(
    sql: string,
    request: QuizReportRequest,
    allowMiss: boolean,
  ): Promise<Uint8Array | null> {
    try {
      const payload = JSON.stringify(request);
      if (!payload || new TextEncoder().encode(payload).byteLength > 16384)
        throw failure();
      const result = await query(sql, [payload]);
      const row = result.rows[0];
      if (
        result.command !== "SELECT" ||
        result.rowCount !== 1 ||
        result.rows.length !== 1 ||
        !row ||
        Object.keys(row).length !== 1 ||
        !Object.hasOwn(row, "response")
      )
        throw failure();
      if (row.response === null && allowMiss) return null;
      if (typeof row.response !== "string") throw failure();
      const bytes = new TextEncoder().encode(row.response);
      if (bytes.byteLength === 0 || bytes.byteLength > 16384) throw failure();
      return bytes;
    } catch (error) {
      // Only exact application exceptions from the private ledger are mapped.
      // Driver/SQL details and all unrecognized messages stay private.
      if (error && typeof error === "object") {
        const e = error as { code?: unknown; message?: unknown };
        if (e.code === "P0001") {
          for (const code of [
            "UNAUTHORIZED",
            "VALIDATION_FAILURE",
            "SYNC_CONFLICT",
          ] as const) {
            if (e.message === code) throw new BoundaryError(code);
          }
        }
      }
      throw failure();
    }
  }
  return Object.freeze({
    replay: (request: QuizReportRequest) => call(replaySql, request, true),
    validateCurrentContent,
    store: async (request: QuizReportRequest) => {
      const result = await call(storeSql, request, false);
      if (result === null) throw failure();
      return result;
    },
  });
}
