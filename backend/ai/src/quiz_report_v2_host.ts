import type { AnySchemaObject } from "ajv";
import { BoundaryError, UUID } from "./contracts.ts";
import type { AuthVerifier } from "./ports.ts";
import {
  createOwnedPostgresFactory,
  type PostgresConnection,
  type PostgresResult,
} from "./postgres_connection.ts";
import { SupabaseAuthVerifier } from "./supabase_auth.ts";
import {
  validateCurrentQuizReportContentV2,
  type QuizReportContentV2Query,
  type QuizReportV2Request,
} from "./quiz_report_content_v2.ts";
import {
  createQuizReportV2Decoder,
  createQuizReportV2ResponseDecoder,
  type QuizReportV2Response,
} from "./quiz_report_v2.ts";

export type QuizReportV2Query = QuizReportContentV2Query;
export type QuizReportV2CurrentContentValidator = (
  query: QuizReportV2Query,
  request: QuizReportV2Request,
  signal: AbortSignal,
) => Promise<void>;

export interface QuizReportV2Transaction {
  replay(request: QuizReportV2Request): Promise<Uint8Array | null>;
  validateCurrentContent(request: QuizReportV2Request): Promise<void>;
  store(request: QuizReportV2Request): Promise<Uint8Array>;
}

export interface QuizReportV2TransactionHost {
  run(
    work: (tx: QuizReportV2Transaction) => Promise<QuizReportV2Response>,
    signal?: AbortSignal,
  ): Promise<QuizReportV2Response>;
}

export interface QuizReportV2SubmissionDependencies {
  readonly auth: AuthVerifier;
  readonly connections: () => PostgresConnection;
  readonly validateCurrentContent: QuizReportV2CurrentContentValidator;
  readonly timeoutMs?: number;
}

export interface TrustedQuizReportV2Configuration {
  readonly projectUrl: string;
  readonly publicKey: string;
  readonly databaseUrl: string;
}

export type QuizReportV2Submitter = (
  accessToken: string,
  raw: Uint8Array,
  signal?: AbortSignal,
) => Promise<QuizReportV2Response>;

const replaySql =
  "SELECT private.replay_quiz_report_v2($1::jsonb)::text AS response";
const storeSql =
  "SELECT private.store_quiz_report_v2($1::jsonb)::text AS response";
const permissionSql =
  "SELECT " +
  "has_schema_privilege(current_user, 'private', 'USAGE') AS schema_usage, " +
  "has_function_privilege(current_user, 'private.replay_quiz_report_v2(jsonb)', 'EXECUTE') AS replay_execute, " +
  "has_function_privilege(current_user, 'private.store_quiz_report_v2(jsonb)', 'EXECUTE') AS store_execute, " +
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

/** Fixed parameterized bridge to the private v2 ledger; it opens no transaction. */
export function createQuizReportV2SqlTransaction(
  query: QuizReportV2Query,
  validateCurrentContent: QuizReportV2CurrentContentValidator,
): QuizReportV2Transaction {
  async function call(
    sql: string,
    request: QuizReportV2Request,
    allowMiss: boolean,
  ): Promise<Uint8Array | null> {
    try {
      const payload = JSON.stringify(request);
      if (!payload || new TextEncoder().encode(payload).byteLength > 16384) {
        throw internal();
      }
      const result = await query(sql, [payload]);
      const row = result.rows[0];
      if (
        result.command !== "SELECT" ||
        result.rowCount !== 1 ||
        result.rows.length !== 1 ||
        !row ||
        Object.keys(row).length !== 1 ||
        !Object.hasOwn(row, "response")
      ) {
        throw internal();
      }
      if (row.response === null && allowMiss) return null;
      if (typeof row.response !== "string") throw internal();
      const bytes = new TextEncoder().encode(row.response);
      if (bytes.byteLength === 0 || bytes.byteLength > 16384) {
        throw internal();
      }
      return bytes;
    } catch (error) {
      if (error && typeof error === "object") {
        const value = error as { code?: unknown; message?: unknown };
        if (value.code === "P0001") {
          for (const code of [
            "UNAUTHORIZED",
            "VALIDATION_FAILURE",
            "SYNC_CONFLICT",
          ] as const) {
            if (value.message === code) throw new BoundaryError(code);
          }
        }
      }
      throw internal();
    }
  }

  return Object.freeze({
    replay: (request: QuizReportV2Request) =>
      call(replaySql, request, true),
    validateCurrentContent,
    store: async (request: QuizReportV2Request) => {
      const response = await call(storeSql, request, false);
      if (response === null) throw internal();
      return response;
    },
  });
}

/** Revokes escaped transaction capabilities and drains every started operation. */
export async function withQuizReportV2TransactionScope<T>(
  source: QuizReportV2Transaction,
  work: (tx: QuizReportV2Transaction) => Promise<T>,
): Promise<T> {
  let active = true;
  let pending: Promise<void> | undefined;
  let failed: BoundaryError | undefined;

  function call<R>(operation: () => Promise<R>): Promise<R> {
    if (!active || pending || failed) {
      failed ??= internal();
      const rejected = Promise.reject<R>(failed);
      void rejected.catch(() => {});
      return rejected;
    }
    const result = Promise.resolve()
      .then(() => {
        if (!active) throw internal();
        return operation();
      })
      .catch((error: unknown) => {
        failed ??= safeTransactionError(error);
        throw failed;
      });
    pending = result.then(
      () => {
        pending = undefined;
      },
      () => {
        pending = undefined;
      },
    );
    return result;
  }

  const scoped: QuizReportV2Transaction =
    Object.freeze<QuizReportV2Transaction>({
      replay: (request) => call(() => source.replay(request)),
      validateCurrentContent: (request) =>
        call(() => source.validateCurrentContent(request)),
      store: (request) => call(() => source.store(request)),
    });

  let result!: T;
  try {
    result = await work(scoped);
  } catch (error) {
    failed ??= safeTransactionError(error);
  } finally {
    active = false;
    if (pending) {
      failed ??= internal();
      await pending;
    }
  }
  if (failed) throw failed;
  return result;
}

/** Captures raw bytes before async work and validates replay/store responses. */
export async function submitQuizReportV2InTransaction(
  schema: AnySchemaObject,
  raw: Uint8Array,
  host: QuizReportV2TransactionHost,
  signal?: AbortSignal,
): Promise<QuizReportV2Response> {
  const check = () => {
    if (signal?.aborted) throw unavailable();
  };
  try {
    check();
    if (!(raw instanceof Uint8Array) || raw.byteLength > 16384) {
      throw new BoundaryError("VALIDATION_FAILURE");
    }
    const captured = raw.slice();
    const request = createQuizReportV2Decoder(schema)(captured);
    const decodeResponse = createQuizReportV2ResponseDecoder(schema, captured);
    const result = await host.run(
      (source) =>
        withQuizReportV2TransactionScope(source, async (tx) => {
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
    throw safeTransactionError(error);
  }
}

/** One fresh owned connection, verified owner claim and replay/content/store transaction. */
class PostgresQuizReportV2Host implements QuizReportV2TransactionHost {
  private readonly ownerId: string;
  private readonly connections: () => PostgresConnection;
  private readonly validateCurrentContent: QuizReportV2CurrentContentValidator;
  private readonly timeoutMs: number;

  constructor(
    ownerId: string,
    connections: () => PostgresConnection,
    validateCurrentContent: QuizReportV2CurrentContentValidator,
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
      throw new Error("Invalid trusted quiz report v2 host");
    }
    this.ownerId = ownerId;
    this.connections = connections;
    this.validateCurrentContent = validateCurrentContent;
    this.timeoutMs = timeoutMs;
  }

  async run(
    work: (tx: QuizReportV2Transaction) => Promise<QuizReportV2Response>,
    parentSignal?: AbortSignal,
  ): Promise<QuizReportV2Response> {
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
        // Driver details and connection configuration stay private.
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
    const query: QuizReportV2Query = async (sql, values) => {
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

      const transaction = createQuizReportV2SqlTransaction(
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

/** Verify Supabase Auth before PostgreSQL; learner input cannot select schema, owner or database. */
export async function submitVerifiedQuizReportV2(
  schema: AnySchemaObject,
  raw: Uint8Array,
  accessToken: string,
  dependencies: QuizReportV2SubmissionDependencies,
  signal?: AbortSignal,
): Promise<QuizReportV2Response> {
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

  if (!(raw instanceof Uint8Array) || raw.byteLength > 16384) {
    throw new BoundaryError("VALIDATION_FAILURE");
  }
  const captured = raw.slice();
  try {
    createQuizReportV2Decoder(schema)(captured);
  } catch (error) {
    if (error instanceof BoundaryError) throw new BoundaryError(error.code);
    throw internal();
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

  let host: PostgresQuizReportV2Host;
  try {
    host = new PostgresQuizReportV2Host(
      identity.id,
      dependencies.connections,
      dependencies.validateCurrentContent,
      dependencies.timeoutMs ?? 5000,
    );
  } catch {
    throw internal();
  }
  return submitQuizReportV2InTransaction(schema, captured, host, activeSignal);
}

/** Trusted server factory only; it installs no route, grant, listener or default app save. */
export function createTrustedPostgresQuizReportV2Submitter(
  schema: AnySchemaObject,
  configuration: TrustedQuizReportV2Configuration,
  timeoutMs = 5000,
): QuizReportV2Submitter {
  try {
    if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 15000) {
      throw new Error();
    }
    const auth = new SupabaseAuthVerifier(
      configuration.projectUrl,
      configuration.publicKey,
    );
    const connections = createOwnedPostgresFactory(
      configuration.databaseUrl,
      "nihongo-ai-quiz-report",
    );
    return (accessToken, raw, signal) =>
      submitVerifiedQuizReportV2(
        schema,
        raw,
        accessToken,
        {
          auth,
          connections,
          validateCurrentContent: (
            query,
            request,
            activeSignal,
          ) =>
            validateCurrentQuizReportContentV2(
              query,
              request,
              activeSignal,
            ),
          timeoutMs,
        },
        signal,
      );
  } catch {
    throw new Error("Invalid trusted quiz report v2 configuration");
  }
}
