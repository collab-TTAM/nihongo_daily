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
  createQuizReportV2Decoder,
  createQuizReportV2ResponseDecoder,
  type QuizReportV2Request,
  type QuizReportV2Response,
} from "./quiz_report_v2.ts";
import { parseQuizReportJsonBody } from "./strict_json.ts";
import type { TrustedQuizReportV2Configuration } from "./quiz_report_v2_host.ts";

export interface QuizReportV2HistoryCursor {
  readonly received_at: string;
  readonly client_event_id: string;
}

export interface QuizReportV2HistoryRequest {
  readonly jlpt_level: "N5" | "N4" | null;
  readonly quiz_type: "vocabulary_reading" | "grammar_meaning" | null;
  readonly limit: number;
  readonly cursor: QuizReportV2HistoryCursor | null;
}

export interface QuizReportV2HistoryEntry {
  readonly received_at: string;
  readonly request: QuizReportV2Request;
  readonly response: QuizReportV2Response;
}

export interface QuizReportV2HistoryPage {
  readonly items: readonly QuizReportV2HistoryEntry[];
  readonly next_cursor: QuizReportV2HistoryCursor | null;
}

export interface QuizReportV2HistoryDependencies {
  readonly auth: AuthVerifier;
  readonly connections: () => PostgresConnection;
  readonly timeoutMs?: number;
}

export type QuizReportV2HistoryReader = (
  accessToken: string,
  raw: Uint8Array,
  signal?: AbortSignal,
) => Promise<QuizReportV2HistoryPage>;

const permissionSql =
  "SELECT has_schema_privilege(current_user, 'private', 'USAGE') AS schema_usage, " +
  "has_table_privilege(current_user, 'private.quiz_report_receipts', 'SELECT') AS receipt_select, " +
  "(SELECT relrowsecurity FROM pg_class WHERE oid = 'private.quiz_report_receipts'::regclass) AS rls_enabled";

const historySql =
  "SELECT client_event_id::text AS client_event_id, " +
  "to_char(received_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS.US\"Z\"') AS received_at, " +
  "request_json::text AS request_json, response_json::text AS response_json " +
  "FROM private.quiz_report_receipts " +
  "WHERE user_id = auth.uid() " +
  "AND ($1 = '' OR request_json->>'jlpt_level' = $1) " +
  "AND ($2 = '' OR request_json->>'quiz_type' = $2) " +
  "AND ($3 = '' OR (received_at, client_event_id) < " +
  "(NULLIF($3, '')::timestamptz, NULLIF($4, '')::uuid)) " +
  "ORDER BY received_at DESC, client_event_id DESC LIMIT $5::integer";

const setupSql = [
  ["SET LOCAL lock_timeout = '1000ms'", "SET"],
  ["SET LOCAL statement_timeout = '2500ms'", "SET"],
  ["SET LOCAL idle_in_transaction_session_timeout = '3000ms'", "SET"],
] as const;

const internal = () => new BoundaryError("INTERNAL_ERROR");
const invalid = () => new BoundaryError("VALIDATION_FAILURE");
const unavailable = () => new BoundaryError("NETWORK_UNAVAILABLE");

function exactKeys(value: Record<string, unknown>, keys: readonly string[]) {
  return (
    Object.keys(value).sort().join("\u0000") === [...keys].sort().join("\u0000")
  );
}

function validReceivedAt(value: unknown): value is string {
  if (
    typeof value !== "string" ||
    !/^(20[0-9]{2}|2100)-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{6}Z$/.test(
      value,
    )
  ) {
    return false;
  }
  const instant = new Date(value);
  return (
    Number.isFinite(instant.getTime()) &&
    instant.toISOString().slice(0, 19) === value.slice(0, 19)
  );
}

function parseHistoryCursor(value: unknown): QuizReportV2HistoryCursor | null {
  if (value === null) return null;
  if (
    typeof value !== "object" ||
    Array.isArray(value) ||
    value === undefined
  ) {
    throw invalid();
  }
  const cursor = value as Record<string, unknown>;
  if (
    !exactKeys(cursor, ["client_event_id", "received_at"]) ||
    typeof cursor.client_event_id !== "string" ||
    !UUID.test(cursor.client_event_id) ||
    cursor.client_event_id !== cursor.client_event_id.toLowerCase() ||
    !validReceivedAt(cursor.received_at)
  ) {
    throw invalid();
  }
  return Object.freeze({
    received_at: cursor.received_at,
    client_event_id: cursor.client_event_id,
  });
}

/** Strict internal filter contract; no owner, SQL, table or arbitrary query fields. */
export function decodeQuizReportV2HistoryRequest(
  raw: Uint8Array,
): QuizReportV2HistoryRequest {
  let value: Record<string, unknown>;
  try {
    value = parseQuizReportJsonBody(raw);
  } catch {
    throw invalid();
  }
  if (!exactKeys(value, ["cursor", "jlpt_level", "limit", "quiz_type"])) {
    throw invalid();
  }
  const level = value.jlpt_level;
  const quizType = value.quiz_type;
  const limit = value.limit;
  if (
    !(level === null || level === "N5" || level === "N4") ||
    !(
      quizType === null ||
      quizType === "vocabulary_reading" ||
      quizType === "grammar_meaning"
    ) ||
    typeof limit !== "number" ||
    !Number.isSafeInteger(limit) ||
    limit < 1 ||
    limit > 100
  ) {
    throw invalid();
  }
  return Object.freeze({
    jlpt_level: level,
    quiz_type: quizType,
    limit,
    cursor: parseHistoryCursor(value.cursor),
  });
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

function safeAuthError(error: unknown): BoundaryError {
  if (error instanceof BoundaryError) {
    if (error.code === "RATE_LIMITED" || error.code === "NETWORK_UNAVAILABLE") {
      return new BoundaryError(error.code);
    }
  }
  return unavailable();
}

function safeTransactionError(error: unknown): BoundaryError {
  if (error instanceof BoundaryError) {
    if (
      error.code === "VALIDATION_FAILURE" ||
      error.code === "UNAUTHORIZED" ||
      error.code === "NETWORK_UNAVAILABLE"
    ) {
      return new BoundaryError(error.code);
    }
  }
  return internal();
}

function readEntry(
  schema: AnySchemaObject,
  row: Record<string, unknown>,
  requestDecoder: ReturnType<typeof createQuizReportV2Decoder>,
  filters: QuizReportV2HistoryRequest,
): QuizReportV2HistoryEntry {
  if (
    typeof row.client_event_id !== "string" ||
    !UUID.test(row.client_event_id) ||
    row.client_event_id !== row.client_event_id.toLowerCase() ||
    !validReceivedAt(row.received_at) ||
    typeof row.request_json !== "string" ||
    row.request_json.length === 0 ||
    row.request_json.length > 16384 ||
    typeof row.response_json !== "string" ||
    row.response_json.length === 0 ||
    row.response_json.length > 16384
  ) {
    throw internal();
  }

  const requestRaw = new TextEncoder().encode(row.request_json);
  let request: QuizReportV2Request;
  try {
    request = requestDecoder(requestRaw);
  } catch {
    throw internal();
  }
  if (
    request.client_event_id !== row.client_event_id ||
    (filters.jlpt_level !== null &&
      request.jlpt_level !== filters.jlpt_level) ||
    (filters.quiz_type !== null && request.quiz_type !== filters.quiz_type)
  ) {
    throw internal();
  }

  let response: QuizReportV2Response;
  try {
    response = createQuizReportV2ResponseDecoder(
      schema,
      requestRaw,
    )(new TextEncoder().encode(row.response_json));
  } catch {
    throw internal();
  }
  return Object.freeze({
    received_at: row.received_at,
    request,
    response,
  });
}

/**
 * Read only the verified caller's immutable receipts. The owner is bound from
 * Supabase Auth into auth.uid(); filters and cursor are fixed, parameterized values.
 */
export async function readVerifiedQuizReportV2History(
  schema: AnySchemaObject,
  raw: Uint8Array,
  accessToken: string,
  dependencies: QuizReportV2HistoryDependencies,
  signal?: AbortSignal,
): Promise<QuizReportV2HistoryPage> {
  if (
    typeof accessToken !== "string" ||
    accessToken.length === 0 ||
    accessToken.length > 8192 ||
    !dependencies ||
    typeof dependencies.auth?.verify !== "function" ||
    typeof dependencies.connections !== "function"
  ) {
    throw new BoundaryError("UNAUTHORIZED");
  }
  if (!(raw instanceof Uint8Array) || raw.byteLength > 16384) {
    throw invalid();
  }
  const request = decodeQuizReportV2HistoryRequest(raw);
  const timeoutMs = dependencies.timeoutMs ?? 5000;
  if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 15000) {
    throw internal();
  }

  let requestDecoder: ReturnType<typeof createQuizReportV2Decoder>;
  try {
    requestDecoder = createQuizReportV2Decoder(schema);
  } catch {
    throw internal();
  }
  const activeSignal = signal ?? new AbortController().signal;
  if (activeSignal.aborted) throw unavailable();

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
  if (activeSignal.aborted) throw unavailable();

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
      // Driver details remain private.
    }
  };
  const stop = () => {
    controller.abort();
    close();
  };
  const deadline = performance.now() + timeoutMs;
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
  const query = async (
    sql: string,
    values?: string[],
  ): Promise<PostgresResult> => {
    alive();
    if (!connection) throw unavailable();
    const result = await wait(connection.query(sql, values));
    alive();
    return result;
  };

  const timer = setTimeout(stop, timeoutMs);
  activeSignal.addEventListener("abort", stop, { once: true });
  try {
    if (activeSignal.aborted) stop();
    alive();
    connection = dependencies.connections();
    alive();
    await wait(connection.connect());
    alive();

    const permissions = oneRow(await query(permissionSql), [
      "receipt_select",
      "rls_enabled",
      "schema_usage",
    ]);
    if (
      permissions.schema_usage !== true ||
      permissions.receipt_select !== true ||
      permissions.rls_enabled !== true
    ) {
      throw internal();
    }

    const begun = await query("BEGIN ISOLATION LEVEL READ COMMITTED READ ONLY");
    if (begun.command !== "BEGIN") throw unavailable();
    transactionOpen = true;
    for (const [sql, command] of setupSql) {
      const result = await query(sql);
      if (result.command !== command) throw unavailable();
    }

    const claimed = oneRow(
      await query(
        "SELECT set_config('request.jwt.claim.sub',$1,true) AS owner_id",
        [identity.id],
      ),
      ["owner_id"],
    );
    if (claimed.owner_id !== identity.id) throw internal();
    const currentOwner = oneRow(
      await query("SELECT auth.uid()::text AS owner_id"),
      ["owner_id"],
    );
    if (currentOwner.owner_id !== identity.id) throw internal();

    const cursor = request.cursor;
    const rows = await query(historySql, [
      request.jlpt_level ?? "",
      request.quiz_type ?? "",
      cursor?.received_at ?? "",
      cursor?.client_event_id ?? "",
      String(request.limit + 1),
    ]);
    if (
      rows.command !== "SELECT" ||
      rows.rowCount !== rows.rows.length ||
      rows.rows.length > request.limit + 1
    ) {
      throw internal();
    }
    const expected = [
      "client_event_id",
      "received_at",
      "request_json",
      "response_json",
    ]
      .sort()
      .join("\u0000");
    const seen = new Set<string>();
    const entries: QuizReportV2HistoryEntry[] = [];
    for (const row of rows.rows) {
      if (Object.keys(row).sort().join("\u0000") !== expected) {
        throw internal();
      }
      const entry = readEntry(schema, row, requestDecoder, request);
      const eventId = entry.request.client_event_id;
      if (seen.has(eventId)) throw internal();
      seen.add(eventId);
      const previous = entries.at(-1);
      if (
        previous &&
        (previous.received_at < entry.received_at ||
          (previous.received_at === entry.received_at &&
            previous.request.client_event_id <= eventId))
      ) {
        throw internal();
      }
      entries.push(entry);
    }

    const hasMore = entries.length > request.limit;
    const items = Object.freeze(entries.slice(0, request.limit));
    const last = items.at(-1);
    const nextCursor =
      hasMore && last
        ? Object.freeze({
            received_at: last.received_at,
            client_event_id: last.request.client_event_id,
          })
        : null;

    alive();
    commitStarted = true;
    const committed = await query("COMMIT");
    if (committed.command !== "COMMIT") throw unavailable();
    transactionOpen = false;
    alive();
    return Object.freeze({ items, next_cursor: nextCursor });
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
    activeSignal.removeEventListener("abort", stop);
    close();
  }
}

/** Trusted server factory only; no route, grant, environment read or default app binding. */
export function createTrustedPostgresQuizReportV2HistoryReader(
  schema: AnySchemaObject,
  configuration: TrustedQuizReportV2Configuration,
  timeoutMs = 5000,
): QuizReportV2HistoryReader {
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
      readVerifiedQuizReportV2History(
        schema,
        raw,
        accessToken,
        { auth, connections, timeoutMs },
        signal,
      );
  } catch {
    throw new Error("Invalid trusted quiz report v2 history configuration");
  }
}
