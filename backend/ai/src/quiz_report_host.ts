import type { AnySchemaObject } from "ajv";
import { BoundaryError, UUID } from "./contracts.ts";
import type { AuthVerifier } from "./ports.ts";
import {
  createOwnedPostgresFactory,
  type PostgresConnection,
  type PostgresResult,
} from "./postgres_connection.ts";
import { SupabaseAuthVerifier } from "./supabase_auth.ts";
import type { QuizReportRequest, QuizReportResponse } from "./quiz_report.ts";
import { createQuizReportSqlTransaction } from "./quiz_report_sql.ts";
import { submitQuizReportInTransaction } from "./quiz_report_transaction.ts";
import type {
  QuizReportTransaction,
  QuizReportTransactionHost,
} from "./quiz_report_transaction.ts";

export type QuizReportQuery = (
  sql: string,
  values?: string[],
) => Promise<PostgresResult>;

export type QuizReportCurrentContentValidator = (
  query: QuizReportQuery,
  request: QuizReportRequest,
  signal: AbortSignal,
) => Promise<void>;

export interface QuizReportSubmissionDependencies {
  readonly auth: AuthVerifier;
  readonly connections: () => PostgresConnection;
  /** Required: there is deliberately no default-success content validator. */
  readonly validateCurrentContent: QuizReportCurrentContentValidator;
  readonly timeoutMs?: number;
}

export interface TrustedQuizReportConfiguration {
  readonly projectUrl: string;
  readonly publicKey: string;
  readonly databaseUrl: string;
}

export type QuizReportSubmitter = (
  accessToken: string,
  raw: Uint8Array,
  signal?: AbortSignal,
) => Promise<QuizReportResponse>;

const permissionSql =
  "SELECT " +
  "has_schema_privilege(current_user, 'private', 'USAGE') AS schema_usage, " +
  "has_function_privilege(current_user, 'private.replay_quiz_report(jsonb)', 'EXECUTE') AS replay_execute, " +
  "has_function_privilege(current_user, 'private.store_quiz_report(jsonb)', 'EXECUTE') AS store_execute, " +
  "has_table_privilege(current_user, 'private.quiz_report_receipts', 'SELECT') AS receipt_select, " +
  "has_table_privilege(current_user, 'private.quiz_report_receipts', 'INSERT') AS receipt_insert";

const setupSql = [
  ["SET LOCAL lock_timeout = '1000ms'", "SET"],
  ["SET LOCAL statement_timeout = '2500ms'", "SET"],
  ["SET LOCAL idle_in_transaction_session_timeout = '3000ms'", "SET"],
] as const;

const internal = () => new BoundaryError("INTERNAL_ERROR");
const unavailable = () => new BoundaryError("NETWORK_UNAVAILABLE");
const transactionCodes: ReadonlySet<string> = new Set([
  "VALIDATION_FAILURE",
  "SYNC_CONFLICT",
  "UNAUTHORIZED",
  "NETWORK_UNAVAILABLE",
]);
const authCodes: ReadonlySet<string> = new Set([
  "RATE_LIMITED",
  "NETWORK_UNAVAILABLE",
]);

function safeTransactionError(error: unknown): BoundaryError {
  if (error instanceof BoundaryError && transactionCodes.has(error.code)) {
    return new BoundaryError(error.code);
  }
  return internal();
}

function safeAuthError(error: unknown): BoundaryError {
  if (error instanceof BoundaryError && authCodes.has(error.code)) {
    return new BoundaryError(error.code);
  }
  return unavailable();
}

function oneRow(
  result: PostgresResult,
  fields: readonly string[],
): Record<string, unknown> {
  const row = result.rows[0];
  const expected = [...fields].sort().join("\u0000");
  const actual = row ? Object.keys(row).sort().join("\u0000") : "";
  if (
    result.command !== "SELECT" ||
    result.rowCount !== 1 ||
    result.rows.length !== 1 ||
    !row ||
    actual !== expected
  ) {
    throw internal();
  }
  return row;
}

/** One fresh connection, verified owner claim and transaction per report.
 * The database credential is trusted server configuration, never learner input.
 * This class opens no public route and creates no SQL grants.
 */
class PostgresQuizReportHost implements QuizReportTransactionHost {
  private readonly ownerId: string;
  private readonly connections: () => PostgresConnection;
  private readonly validateCurrentContent: QuizReportCurrentContentValidator;
  private readonly timeoutMs: number;

  constructor(
    ownerId: string,
    connections: () => PostgresConnection,
    validateCurrentContent: QuizReportCurrentContentValidator,
    timeoutMs: number,
  ) {
    if (
      !UUID.test(ownerId) ||
      ownerId !== ownerId.toLowerCase() ||
      typeof connections !== "function" ||
      typeof validateCurrentContent !== "function" ||
      !Number.isInteger(timeoutMs) ||
      timeoutMs < 1 ||
      timeoutMs > 15000
    ) {
      throw new Error("Invalid trusted quiz report host");
    }
    this.ownerId = ownerId;
    this.connections = connections;
    this.validateCurrentContent = validateCurrentContent;
    this.timeoutMs = timeoutMs;
  }

  async run(
    work: (tx: QuizReportTransaction) => Promise<QuizReportResponse>,
    parentSignal?: AbortSignal,
  ): Promise<QuizReportResponse> {
    const controller = new AbortController();
    let connection: PostgresConnection | undefined;
    let closed = false;
    let transactionOpen = false;
    let commitStarted = false;

    const close = () => {
      if (closed || !connection) return;
      closed = true;
      try {
        connection.close();
      } catch {
        // Never expose driver details or connection configuration.
      }
    };
    const stop = () => {
      controller.abort();
      close();
    };
    const deadline = performance.now() + this.timeoutMs;
    const alive = () => {
      if (performance.now() >= deadline) stop();
      if (controller.signal.aborted) throw unavailable();
    };
    const wait = async <T>(pending: Promise<T>): Promise<T> => {
      if (controller.signal.aborted) {
        void pending.catch(() => {});
        throw unavailable();
      }
      let abort: (() => void) | undefined;
      try {
        return await new Promise<T>((resolve, reject) => {
          abort = () => reject(unavailable());
          controller.signal.addEventListener("abort", abort, { once: true });
          void pending.then(resolve, reject);
        });
      } finally {
        if (abort) controller.signal.removeEventListener("abort", abort);
      }
    };
    const query: QuizReportQuery = async (sql, values) => {
      alive();
      if (!connection) throw unavailable();
      const result = await wait(connection.query(sql, values));
      alive();
      return result;
    };

    const timer = setTimeout(stop, this.timeoutMs);
    parentSignal?.addEventListener("abort", stop, { once: true });
    try {
      if (parentSignal?.aborted) stop();
      alive();
      connection = this.connections();
      alive();
      await wait(connection.connect());
      alive();

      const permissions = oneRow(await query(permissionSql), [
        "schema_usage",
        "replay_execute",
        "store_execute",
        "receipt_select",
        "receipt_insert",
      ]);
      if (
        permissions.schema_usage !== true ||
        permissions.replay_execute !== true ||
        permissions.store_execute !== true ||
        permissions.receipt_select !== true ||
        permissions.receipt_insert !== true
      ) {
        throw internal();
      }

      const begun = await query("BEGIN ISOLATION LEVEL READ COMMITTED");
      if (begun.command !== "BEGIN") throw unavailable();
      transactionOpen = true;
      for (const [sql, command] of setupSql) {
        const result = await query(sql);
        if (result.command !== command) throw unavailable();
      }

      const identity = oneRow(
        await query(
          "SELECT set_config('request.jwt.claim.sub',$1,true) AS owner_id",
          [this.ownerId],
        ),
        ["owner_id"],
      );
      if (identity.owner_id !== this.ownerId) throw internal();

      const transaction = createQuizReportSqlTransaction(
        (sql, values) => query(sql, values),
        async (request) => {
          alive();
          await wait(
            this.validateCurrentContent(query, request, controller.signal),
          );
          alive();
        },
      );
      const result = await work(transaction);
      alive();

      // A failed/ambiguous COMMIT is never retried or reported as saved.
      commitStarted = true;
      const committed = await query("COMMIT");
      if (committed.command !== "COMMIT") throw unavailable();
      transactionOpen = false;
      alive();
      return result;
    } catch (error) {
      if (transactionOpen && !commitStarted && !controller.signal.aborted) {
        try {
          const rolledBack = await query("ROLLBACK");
          if (rolledBack.command === "ROLLBACK") {
            transactionOpen = false;
          } else {
            stop();
          }
        } catch {
          stop();
        }
      } else if (transactionOpen || commitStarted) {
        stop();
      }
      throw safeTransactionError(error);
    } finally {
      clearTimeout(timer);
      parentSignal?.removeEventListener("abort", stop);
      close();
    }
  }
}

/** Verify the bearer with the trusted Auth server before opening PostgreSQL.
 * The request decoder and SQL bridge still enforce raw bytes/response shape.
 * A current-content validator is mandatory and runs after replay miss on the
 * same connection/transaction. No public handler/default route is installed.
 */
export async function submitVerifiedQuizReport(
  schema: AnySchemaObject,
  raw: Uint8Array,
  accessToken: string,
  dependencies: QuizReportSubmissionDependencies,
  signal?: AbortSignal,
): Promise<QuizReportResponse> {
  if (
    typeof accessToken !== "string" ||
    accessToken.length === 0 ||
    accessToken.length > 8192 ||
    !dependencies ||
    typeof dependencies.auth?.verify !== "function" ||
    typeof dependencies.connections !== "function" ||
    typeof dependencies.validateCurrentContent !== "function"
  ) {
    throw new BoundaryError("UNAUTHORIZED");
  }
  const activeSignal = signal ?? new AbortController().signal;
  let identity: { id: string } | null;
  try {
    identity = await dependencies.auth.verify(accessToken, activeSignal);
  } catch (error) {
    throw safeAuthError(error);
  }
  if (
    !identity ||
    typeof identity.id !== "string" ||
    !UUID.test(identity.id) ||
    identity.id !== identity.id.toLowerCase()
  ) {
    throw new BoundaryError("UNAUTHORIZED");
  }

  let host: PostgresQuizReportHost;
  try {
    host = new PostgresQuizReportHost(
      identity.id,
      dependencies.connections,
      dependencies.validateCurrentContent,
      dependencies.timeoutMs ?? 5000,
    );
  } catch {
    throw internal();
  }
  return submitQuizReportInTransaction(schema, raw, host, activeSignal);
}

/** Explicit trusted server factory. URL/public key/database URL are configuration,
 * not learner input. No environment reads, listener, public grant or default use.
 */
export function createTrustedPostgresQuizReportSubmitter(
  schema: AnySchemaObject,
  configuration: TrustedQuizReportConfiguration,
  validateCurrentContent: QuizReportCurrentContentValidator,
  timeoutMs = 5000,
): QuizReportSubmitter {
  try {
    const auth = new SupabaseAuthVerifier(
      configuration.projectUrl,
      configuration.publicKey,
    );
    const connections = createOwnedPostgresFactory(
      configuration.databaseUrl,
      "nihongo-ai-quiz-report",
    );
    return (accessToken, raw, signal) =>
      submitVerifiedQuizReport(
        schema,
        raw,
        accessToken,
        { auth, connections, validateCurrentContent, timeoutMs },
        signal,
      );
  } catch {
    throw new Error("Invalid trusted quiz report configuration");
  }
}
