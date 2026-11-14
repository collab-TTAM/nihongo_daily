import { BoundaryError, Contracts, UUID } from "./contracts.ts";
import type { Operation, Requests, Responses } from "./contracts.ts";
import type { ContextRepository, PreparedContext } from "./ports.ts";
import { createOwnedPostgresFactory } from "./postgres_connection.ts";
import type {
  PostgresConnection,
  PostgresResult,
} from "./postgres_connection.ts";

const prepareSql =
  "SELECT private.ai_text_context($1::uuid,$2::text,$3::jsonb) AS context";
const validateSql =
  "SELECT private.ai_validate_text_context($1::uuid,$2::text,$3::jsonb,$4::jsonb) AS checked";
const setupSql = [
  ["BEGIN ISOLATION LEVEL READ COMMITTED READ ONLY", "BEGIN"],
  ["SET LOCAL ROLE service_role", "SET"],
  ["SET LOCAL lock_timeout = '1000ms'", "SET"],
  ["SET LOCAL statement_timeout = '2000ms'", "SET"],
  ["SET LOCAL idle_in_transaction_session_timeout = '3000ms'", "SET"],
] as const;
const failure = () => new BoundaryError("NETWORK_UNAVAILABLE");
type TextOperation = "tutor_explain" | "correct_sentence";
function textOperation(op: Operation): asserts op is TextOperation {
  if (op !== "tutor_explain" && op !== "correct_sentence")
    throw new BoundaryError("PROVIDER_UNAVAILABLE");
}
function serialized(value: unknown, limit: number): string {
  const text = JSON.stringify(value);
  if (!text || new TextEncoder().encode(text).byteLength > limit)
    throw failure();
  return text;
}
function oneRow(result: PostgresResult, field: string): unknown {
  if (
    result.command !== "SELECT" ||
    result.rowCount !== 1 ||
    result.rows.length !== 1 ||
    Object.keys(result.rows[0]!).length !== 1 ||
    !(field in result.rows[0]!)
  )
    throw failure();
  return result.rows[0]![field];
}
/** The private projection has no transcript/session authority for these reads. */
function decoded(value: unknown, op: TextOperation): PreparedContext {
  serialized(value, 65536);
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw failure();
  const o = value as Record<string, unknown>;
  if (
    Object.keys(o).length !== 3 ||
    typeof o.instruction !== "string" ||
    o.instruction.length < 1 ||
    o.instruction.length > 10000 ||
    !Array.isArray(o.transcript) ||
    o.transcript.length !== 0 ||
    !Array.isArray(o.allowedRefs) ||
    o.allowedRefs.length > (op === "tutor_explain" ? 200 : 64)
  )
    throw failure();
  const keys = new Set<string>();
  const refs = o.allowedRefs.map((ref: unknown) => {
    if (!ref || typeof ref !== "object" || Array.isArray(ref)) throw failure();
    const r = ref as Record<string, unknown>;
    if (
      Object.keys(r).length !== 2 ||
      (r.item_type !== "GRAMMAR" && r.item_type !== "VOCABULARY") ||
      typeof r.item_id !== "string" ||
      !UUID.test(r.item_id) ||
      r.item_id !== r.item_id.toLowerCase()
    )
      throw failure();
    const key = `${r.item_type}/${r.item_id}`;
    if (keys.has(key)) throw failure();
    keys.add(key);
    return Object.freeze({ item_type: r.item_type, item_id: r.item_id });
  });
  return Object.freeze({
    instruction: o.instruction,
    transcript: Object.freeze([]),
    allowedRefs: Object.freeze(refs),
  });
}
function helperError(error: unknown): BoundaryError {
  if (error && typeof error === "object") {
    const e = error as { code?: unknown; message?: unknown };
    for (const [code, message] of [
      ["22023", "VALIDATION_FAILURE"],
      ["42501", "FORBIDDEN"],
      ["P0002", "NOT_FOUND"],
      ["P0001", "SYNC_CONFLICT"],
    ] as const)
      if (e.code === code && e.message === message)
        return new BoundaryError(message);
  }
  return failure();
}

/** Opt-in text-only repository. Each phase owns a fresh, read-only transaction;
 * no connection/snapshot is retained across provider I/O or between accounts.
 */
export class PostgresTextContextRepository implements ContextRepository {
  private readonly contracts: Contracts;
  private readonly factory: () => PostgresConnection;
  private readonly timeoutMs: number;
  constructor(
    contracts: Contracts,
    factory: () => PostgresConnection,
    timeoutMs = 5000,
  ) {
    if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 15000)
      throw new Error("Invalid text context timeout");
    this.contracts = contracts;
    this.factory = factory;
    this.timeoutMs = timeoutMs;
  }
  private input<O extends Operation>(
    userId: string,
    op: O,
    request: Requests[O],
  ): string[] {
    textOperation(op);
    if (!UUID.test(userId)) throw new BoundaryError("INTERNAL_ERROR");
    try {
      const snapshot = structuredClone(request);
      this.contracts.request(op, snapshot);
      return [userId.toLowerCase(), op, serialized(snapshot, 32768)];
    } catch (error) {
      if (error instanceof BoundaryError && error.code === "VALIDATION_FAILURE")
        throw error;
      throw new BoundaryError("VALIDATION_FAILURE");
    }
  }
  async prepare<O extends Operation>(
    userId: string,
    op: O,
    request: Requests[O],
    signal: AbortSignal,
  ): Promise<PreparedContext> {
    const values = this.input(userId, op, request);
    textOperation(op);
    return this.read(prepareSql, values, signal, (r) =>
      decoded(oneRow(r, "context"), op),
    );
  }
  async validateResult<O extends Operation>(
    userId: string,
    op: O,
    request: Requests[O],
    response: Responses[O],
    context: PreparedContext,
    signal: AbortSignal,
  ): Promise<void> {
    const values = this.input(userId, op, request);
    textOperation(op);
    try {
      const captured = decoded(structuredClone(context), op);
      const valid = this.contracts.response(op, structuredClone(response));
      if (op === "correct_sentence") {
        const corrected = valid as Responses["correct_sentence"];
        for (const error of [
          ...corrected.grammar_errors,
          ...corrected.vocabulary_errors,
        ])
          for (const ref of error.item_refs)
            if (
              !captured.allowedRefs.some(
                (a) =>
                  a.item_type === ref.item_type && a.item_id === ref.item_id,
              )
            )
              throw new BoundaryError("PROVIDER_UNAVAILABLE");
      }
      values.push(serialized(captured, 65536));
    } catch (error) {
      if (error instanceof BoundaryError) throw error;
      throw failure();
    }
    await this.read(validateSql, values, signal, (r) => {
      // PostgreSQL's void return is delivered as an empty string by pg.
      if (oneRow(r, "checked") !== "") throw failure();
    });
  }
  private async read<T>(
    sql: string,
    values: string[],
    parent: AbortSignal,
    decode: (r: PostgresResult) => T,
  ): Promise<T> {
    const controller = new AbortController();
    let connection: PostgresConnection | undefined;
    let closed = false;
    const stop = () => {
      controller.abort();
      if (connection && !closed) {
        closed = true;
        try {
          connection.close();
        } catch {
          /* No raw driver/credential logs. */
        }
      }
    };
    const deadline = performance.now() + this.timeoutMs;
    const alive = () => {
      if (performance.now() >= deadline) stop();
      if (controller.signal.aborted) throw failure();
    };
    const wait = async <R>(work: Promise<R>): Promise<R> => {
      let abort: (() => void) | undefined;
      try {
        if (controller.signal.aborted) {
          void work.catch(() => {});
          throw failure();
        }
        const value = await new Promise<R>((resolve, reject) => {
          abort = () => reject(failure());
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
      connection = this.factory();
      alive();
      await wait(connection.connect());
      for (const [text, command] of setupSql) {
        alive();
        const r = await wait(connection.query(text));
        if (r.command !== command) throw failure();
      }
      alive();
      let result: PostgresResult;
      try {
        result = await wait(connection.query(sql, values));
      } catch (error) {
        alive();
        throw helperError(error);
      }
      const value = decode(result);
      alive();
      const committed = await wait(connection.query("COMMIT"));
      if (committed.command !== "COMMIT") throw failure();
      alive();
      return value;
    } catch (error) {
      if (error instanceof BoundaryError) throw error;
      throw failure();
    } finally {
      clearTimeout(timer);
      parent.removeEventListener("abort", stop);
      stop();
    }
  }
}

/** Fixed trusted server configuration only. No learner URL/key or TLS-off mode. */
export function createPostgresTextContextRepository(
  contracts: Contracts,
  databaseUrl: string,
): PostgresTextContextRepository {
  return new PostgresTextContextRepository(
    contracts,
    createOwnedPostgresFactory(databaseUrl, "nihongo-ai-text-context"),
  );
}
