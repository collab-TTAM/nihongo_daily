import { Client } from "pg";
import { isIP } from "node:net";
import { BoundaryError, UUID, operations } from "./contracts.ts";
import type { Operation } from "./contracts.ts";
import type { RateLimiter } from "./ports.ts";

export interface QuotaResult {
  command: string;
  rowCount: number | null;
  rows: Record<string, unknown>[];
}
/** A fresh, exclusively owned connection. close must initiate termination without
 * waiting for pending I/O. A resolved query must include ReadyForQuery, not merely
 * an optimistic application acknowledgement. Never return pooled/shared clients.
 */
export interface QuotaConnection {
  connect(): Promise<void>;
  query(text: string, values?: string[]): Promise<QuotaResult>;
  close(): void;
}
const failure = () => new BoundaryError("NETWORK_UNAVAILABLE");
const consumeSql =
  "SELECT private.consume_ai_quota($1::uuid,$2::text) AS allowed";
const setupSql = [
  ["BEGIN ISOLATION LEVEL READ COMMITTED", "BEGIN"],
  ["SET LOCAL ROLE service_role", "SET"],
  ["SET LOCAL lock_timeout = '1000ms'", "SET"],
  ["SET LOCAL statement_timeout = '2000ms'", "SET"],
  ["SET LOCAL idle_in_transaction_session_timeout = '3000ms'", "SET"],
] as const;

export class PostgresQuotaLimiter implements RateLimiter {
  private readonly factory: () => QuotaConnection;
  private readonly timeoutMs: number;
  constructor(factory: () => QuotaConnection, timeoutMs = 5000) {
    if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 15000)
      throw new Error("Invalid quota timeout");
    this.factory = factory;
    this.timeoutMs = timeoutMs;
  }
  async consume(
    userId: string,
    op: Operation,
    parent: AbortSignal,
  ): Promise<boolean> {
    if (!UUID.test(userId) || !operations.includes(op))
      throw new BoundaryError("INTERNAL_ERROR");
    const controller = new AbortController();
    let connection: QuotaConnection | undefined;
    let closed = false;
    const close = () => {
      if (!closed && connection) {
        closed = true;
        try {
          connection.close();
        } catch {
          /* Never leak driver/credential details. */
        }
      }
    };
    const stop = () => {
      controller.abort();
      close();
    };
    const deadline = performance.now() + this.timeoutMs;
    const alive = () => {
      if (performance.now() >= deadline) stop();
      if (controller.signal.aborted) throw failure();
    };
    const wait = async <T>(work: Promise<T>): Promise<T> => {
      let abort: (() => void) | undefined;
      try {
        if (controller.signal.aborted) {
          void work.catch(() => {});
          throw failure();
        }
        const value = await new Promise<T>((resolve, reject) => {
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
        const result = await wait(connection.query(text));
        if (result.command !== command) throw failure();
      }
      alive();
      const result = await wait(
        connection.query(consumeSql, [userId.toLowerCase(), op]),
      );
      if (
        result.command !== "SELECT" ||
        result.rowCount !== 1 ||
        result.rows.length !== 1 ||
        Object.keys(result.rows[0]!).length !== 1 ||
        typeof result.rows[0]!.allowed !== "boolean"
      )
        throw failure();
      const allowed = result.rows[0]!.allowed;
      alive();
      // PostgreSQL can answer COMMIT with ROLLBACK for an aborted transaction.
      // Only a successful COMMIT/ReadyForQuery response permits dispatch.
      const committed = await wait(connection.query("COMMIT"));
      if (committed.command !== "COMMIT") throw failure();
      alive();
      return allowed;
    } catch {
      // Unknown COMMIT may have consumed quota. Never retry/refund or allow it.
      throw failure();
    } finally {
      clearTimeout(timer);
      parent.removeEventListener("abort", stop);
      stop();
    }
  }
}

/** Trusted server deployment configuration only. No learner URL/key or TLS-off
 * setting; pg connection-string SSL/options overrides are deliberately rejected.
 */
export function createPostgresQuotaLimiter(
  databaseUrl: string,
): PostgresQuotaLimiter {
  try {
    const url = new URL(databaseUrl);
    const host = url.hostname.replace(/^\[|\]$/g, "");
    const dnsHost =
      host.length <= 253 &&
      host
        .split(".")
        .every(
          (label) =>
            label.length <= 63 &&
            /^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$/.test(label),
        );
    if (
      databaseUrl.length > 8192 ||
      databaseUrl !== databaseUrl.trim() ||
      !["postgres:", "postgresql:"].includes(url.protocol) ||
      !url.hostname ||
      (!isIP(host) && !dnsHost) ||
      !url.username ||
      !url.password ||
      url.pathname.length <= 1 ||
      url.search ||
      url.hash ||
      databaseUrl.includes("?") ||
      databaseUrl.includes("#")
    )
      throw new Error();
  } catch {
    throw new Error("Invalid trusted quota database configuration");
  }
  return new PostgresQuotaLimiter(() => {
    const client = new Client({
      connectionString: databaseUrl,
      ssl: { rejectUnauthorized: true },
      connectionTimeoutMillis: 2000,
      query_timeout: 2500,
      application_name: "nihongo-ai-quota",
      pipeline: false,
    });
    // pg may emit an idle connection error outside a query promise. It must never
    // become an uncaught event or a raw log. Pending operations still reject.
    client.on("error", () => {});
    return {
      connect: async () => {
        await client.connect();
      },
      query: async (text, values) => client.query(text, values),
      close: () => {
        void client.end().catch(() => {});
      },
    };
  });
}
