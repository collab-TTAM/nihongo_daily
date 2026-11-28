// TEST ONLY fixed disposable CI transport; bounded categories, never raw errors.
import { Client } from "pg";
import type { PostgresConnection } from "../src/postgres_connection.ts";
export const phases = [
  "none",
  "construct",
  "connect",
  "begin",
  "setup",
  "quota",
  "lookup",
  "reserve",
  "complete",
  "text",
  "commit",
  "probe",
  "query",
  "close",
  "idle",
] as const;
export const kinds = [
  "unknown",
  "refused",
  "reset",
  "timeout",
  "permission",
  "unsupported",
  "missing-global",
  "auth",
  "protocol",
  "injected",
] as const;
export type Phase = typeof phases[number];
export type Kind = typeof kinds[number];
export interface ProbeMetrics {
  calls: number;
  opened: number;
  closed: number;
  injected: boolean;
  phase: Phase;
  failures: { phase: Phase; kind: Kind }[];
}
export const newMetrics = (): ProbeMetrics => ({
  calls: 0,
  opened: 0,
  closed: 0,
  injected: false,
  phase: "none",
  failures: [],
});
export function failureKind(error: unknown): Kind {
  try {
    if (!error || typeof error !== "object") return "unknown";
    const code = Reflect.get(error, "code");
    if (code === "ECONNREFUSED") return "refused";
    if (code === "ECONNRESET") return "reset";
    if (code === "ETIMEDOUT") return "timeout";
    if (code === "28P01" || code === "28000") return "auth";
    if (code === "PROBE_PROTOCOL") return "protocol";
    if (error instanceof Error) {
      const message = error.message.slice(0, 256).toLowerCase();
      if (message.includes("not defined")) return "missing-global";
      if (
        message.includes("not supported") ||
        message.includes("not implemented") ||
        error.name === "NotSupportedError"
      ) return "unsupported";
      if (
        message.includes("permission") ||
        message.includes("requires env access") ||
        error.name === "PermissionDenied" || error.name === "NotCapable"
      ) {
        return "permission";
      }
      if (message.includes("timeout") || message.includes("timed out")) {
        return "timeout";
      }
    }
  } catch { /* Hostile getters must not change the public error path. */ }
  return "unknown";
}
export function recordFailure(
  metrics: ProbeMetrics,
  phase: Phase,
  error: unknown,
  injected = false,
): void {
  const kind = injected ? "injected" : failureKind(error);
  if (
    metrics.failures.length < 8 &&
    !metrics.failures.some((x) => x.phase === phase && x.kind === kind)
  ) {
    metrics.failures.push({ phase, kind });
  }
}
export const PROBE_SQL = "SELECT 1 AS probe";
function queryPhase(text: string): Phase {
  if (text === PROBE_SQL) return "probe";
  if (text === "COMMIT") return "commit";
  if (text.startsWith("BEGIN")) return "begin";
  if (text.startsWith("SET LOCAL")) return "setup";
  if (text.includes("consume_ai_quota")) return "quota";
  if (text.includes("ai_receipt_lookup")) return "lookup";
  if (text.includes("ai_conversation_reserve")) return "reserve";
  if (text.includes("ai_conversation_complete")) return "complete";
  if (
    text.includes("ai_text_context") ||
    text.includes("ai_validate_text_context")
  ) return "text";
  return "query";
}
export function createProbeFactory(
  metrics: ProbeMetrics,
  mode: string,
): () => PostgresConnection {
  return () => {
    metrics.phase = "construct";
    let c: Client;
    try {
      c = new Client({
        host: "127.0.0.1",
        port: 5432,
        user: "postgres",
        password: "postgres",
        database: "nihongo_test",
        ssl: false,
        application_name: "nd-edge-pg",
        connectionTimeoutMillis: 2000,
        query_timeout: 3000,
        pipeline: false,
      });
    } catch (error) {
      recordFailure(metrics, "construct", error);
      throw error;
    }
    c.on("error", (error) => recordFailure(metrics, "idle", error));
    metrics.opened++;
    let selected = "";
    return {
      connect: async () => {
        metrics.phase = "connect";
        try {
          await c.connect();
        } catch (error) {
          recordFailure(metrics, "connect", error);
          throw error;
        }
      },
      query: async (text, values) => {
        const phase = queryPhase(text);
        metrics.phase = phase;
        if (text.startsWith("SELECT")) selected = text;
        let injected = false;
        try {
          const result = await c.query(text, values);
          if (text === "COMMIT" || text === PROBE_SQL) {
            if (c.getTransactionStatus() !== "I") {
              throw Object.assign(Error("TEST ONLY PostgreSQL not idle"), {
                code: "PROBE_PROTOCOL",
              });
            }
          }
          if (
            text === "COMMIT" && !metrics.injected &&
            (mode === "acquire" || mode === "complete") &&
            selected.includes(
              mode === "acquire"
                ? "ai_conversation_reserve"
                : "ai_conversation_complete",
            )
          ) {
            metrics.injected = true;
            injected = true;
            throw Error("PRIVATE TEST ONLY lost committed delivery");
          }
          return result;
        } catch (error) {
          recordFailure(metrics, phase, error, injected);
          throw error;
        }
      },
      close: () => {
        metrics.closed++;
        metrics.phase = "close";
        void c.end().catch((error) => recordFailure(metrics, "close", error));
      },
    };
  };
}
/** Explicit fixed read, no caller SQL, transaction, Auth, quota or provider work.
 * A confirmed real pg result and idle ReadyForQuery are required; always close.
 */
export async function verifyProbeTransport(
  factory: () => PostgresConnection,
): Promise<void> {
  let c: PostgresConnection | undefined;
  try {
    c = factory();
    await c.connect();
    const result = await c.query(PROBE_SQL);
    if (
      result.command !== "SELECT" || result.rowCount !== 1 ||
      result.rows.length !== 1 || result.rows[0]?.probe !== 1
    ) {
      throw Object.assign(Error("TEST ONLY invalid PostgreSQL probe result"), {
        code: "PROBE_PROTOCOL",
      });
    }
  } finally {
    c?.close();
  }
}
