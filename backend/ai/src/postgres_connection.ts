import { Client } from "pg";
import { isIP } from "node:net";

export interface PostgresResult {
  command: string;
  rowCount: number | null;
  rows: Record<string, unknown>[];
}
/** A fresh, exclusively owned connection. close must initiate termination without
 * waiting for pending I/O. A resolved query must include ReadyForQuery, not merely
 * an optimistic application acknowledgement. Never return pooled/shared clients.
 */
export interface PostgresConnection {
  connect(): Promise<void>;
  query(text: string, values?: string[]): Promise<PostgresResult>;
  close(): void;
}
/** Trusted deployment only: fixed TLS, no URL overrides, fresh owned clients. */
export function createOwnedPostgresFactory(
  databaseUrl: string,
  applicationName: "nihongo-ai-quota" | "nihongo-ai-text-context",
): () => PostgresConnection {
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
    throw new Error("Invalid trusted PostgreSQL configuration");
  }
  return () => {
    const client = new Client({
      connectionString: databaseUrl,
      ssl: { rejectUnauthorized: true },
      connectionTimeoutMillis: 2000,
      query_timeout: 2500,
      application_name: applicationName,
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
  };
}
