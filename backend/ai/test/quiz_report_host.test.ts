import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { BoundaryError } from "../src/contracts.ts";
import type { AuthVerifier } from "../src/ports.ts";
import type {
  PostgresConnection,
  PostgresResult,
} from "../src/postgres_connection.ts";
import {
  submitVerifiedQuizReport,
  type QuizReportCurrentContentValidator,
} from "../src/quiz_report_host.ts";

const root = new URL("../../../contracts/quiz/v1/", import.meta.url);
const schema = JSON.parse(readFileSync(new URL("schema.json", root), "utf8"));
const fixtures = JSON.parse(
  readFileSync(new URL("fixtures.json", root), "utf8"),
);
const fixture = fixtures[0]!;
const owner = "e3100000-0000-4000-8000-000000000001";
const replaySql =
  "SELECT private.replay_quiz_report($1::jsonb)::text AS response";
const storeSql =
  "SELECT private.store_quiz_report($1::jsonb)::text AS response";

function result(
  command: string,
  rows: Record<string, unknown>[] = [],
): PostgresResult {
  return { command, rowCount: rows.length, rows };
}

class FakeConnection implements PostgresConnection {
  readonly calls: Array<{ sql: string; values?: string[] }> = [];
  closed = false;

  constructor(
    readonly mode:
      | "miss"
      | "hit"
      | "denied"
      | "permission-error"
      | "commit-rollback" = "miss",
    readonly response: unknown = fixture.response,
  ) {}

  async connect(): Promise<void> {}

  async query(sql: string, values?: string[]): Promise<PostgresResult> {
    this.calls.push({ sql, values });
    if (sql.includes("has_schema_privilege")) {
      if (this.mode === "permission-error") {
        throw new Error("PRIVATE SQL TOKEN");
      }
      return result("SELECT", [
        {
          schema_usage: true,
          replay_execute: true,
          store_execute: this.mode !== "denied",
          receipt_select: true,
          receipt_insert: true,
        },
      ]);
    }
    if (sql.startsWith("BEGIN")) return result("BEGIN");
    if (sql.startsWith("SET LOCAL")) return result("SET");
    if (sql.startsWith("SELECT set_config(")) {
      return result("SELECT", [{ owner_id: values?.[0] }]);
    }
    if (sql === replaySql) {
      return result("SELECT", [
        {
          response: this.mode === "hit" ? JSON.stringify(this.response) : null,
        },
      ]);
    }
    if (sql === "SELECT canonical current content") {
      return result("SELECT", [{ accepted: true }]);
    }
    if (sql === storeSql) {
      return result("SELECT", [{ response: JSON.stringify(this.response) }]);
    }
    if (sql === "COMMIT") {
      return result(this.mode === "commit-rollback" ? "ROLLBACK" : "COMMIT");
    }
    if (sql === "ROLLBACK") return result("ROLLBACK");
    throw new Error("PRIVATE SQL TOKEN");
  }

  close(): void {
    this.closed = true;
  }
}

function dependencies(
  connection: FakeConnection,
  verify: AuthVerifier["verify"] = async () => ({ id: owner }),
  validateCurrentContent: QuizReportCurrentContentValidator = async (query) => {
    const checked = await query("SELECT canonical current content");
    assert.equal(checked.rows[0]?.accepted, true);
  },
) {
  let opened = 0;
  return {
    opened: () => opened,
    value: {
      auth: { verify },
      connections: () => {
        opened++;
        return connection;
      },
      validateCurrentContent: async (
        query: Parameters<QuizReportCurrentContentValidator>[0],
        request: Parameters<QuizReportCurrentContentValidator>[1],
        signal: Parameters<QuizReportCurrentContentValidator>[2],
      ) => {
        assert.equal(signal.aborted, false);
        assert.equal(request.client_event_id, fixture.request.client_event_id);
        await validateCurrentContent(query, request, signal);
      },
    },
  };
}

test("verified quiz host binds Auth identity and keeps replay/content/store in one transaction", async () => {
  const connection = new FakeConnection("miss", fixture.response);
  const deps = dependencies(connection, async (token) => {
    assert.equal(token, "verified-token");
    return { id: owner };
  });
  const saved = await submitVerifiedQuizReport(
    schema,
    new TextEncoder().encode(JSON.stringify(fixture.request)),
    "verified-token",
    deps.value,
  );
  assert.deepEqual(saved, fixture.response);
  const sql = connection.calls.map((call) => call.sql);
  const replay = sql.indexOf(replaySql);
  const content = sql.indexOf("SELECT canonical current content");
  const store = sql.indexOf(storeSql);
  const commit = sql.indexOf("COMMIT");
  assert.ok(
    replay >= 0 && replay < content && content < store && store < commit,
  );
  const claim = connection.calls.find((call) =>
    call.sql.startsWith("SELECT set_config("),
  );
  assert.deepEqual(claim?.values, [owner]);
  assert.equal(connection.closed, true);
  assert.equal(deps.opened(), 1);
});

test("exact replay bypasses content and store but commits the original response", async () => {
  const connection = new FakeConnection("hit", fixture.response);
  const deps = dependencies(
    connection,
    async () => ({ id: owner }),
    async () => assert.fail("Replay must not inspect changed current content"),
  );
  const saved = await submitVerifiedQuizReport(
    schema,
    new TextEncoder().encode(JSON.stringify(fixture.request)),
    "verified-token",
    deps.value,
  );
  assert.deepEqual(saved, fixture.response);
  assert.equal(
    connection.calls.some((call) => call.sql === storeSql),
    false,
  );
  assert.equal(
    connection.calls.some((call) => call.sql === "COMMIT"),
    true,
  );
});

test("invalid Auth identity never opens a database connection", async () => {
  const connection = new FakeConnection();
  const deps = dependencies(connection, async () => null);
  await assert.rejects(
    submitVerifiedQuizReport(
      schema,
      new TextEncoder().encode(JSON.stringify(fixture.request)),
      "invalid-token",
      deps.value,
    ),
    (error: unknown) =>
      error instanceof BoundaryError &&
      error.code === "UNAUTHORIZED" &&
      error.message === "UNAUTHORIZED",
  );
  assert.equal(deps.opened(), 0);
  assert.equal(connection.calls.length, 0);
});

test("unknown learner owner fields fail closed before PostgreSQL", async () => {
  const connection = new FakeConnection();
  const deps = dependencies(connection);
  const forged = { ...fixture.request, user_id: owner };
  await assert.rejects(
    submitVerifiedQuizReport(
      schema,
      new TextEncoder().encode(JSON.stringify(forged)),
      "verified-token",
      deps.value,
    ),
    /^Error: VALIDATION_FAILURE$/,
  );
  assert.equal(deps.opened(), 0);
  assert.equal(connection.calls.length, 0);
});

test("current-content rejection rolls back without a saved acknowledgement", async () => {
  const connection = new FakeConnection();
  const deps = dependencies(
    connection,
    async () => ({ id: owner }),
    async () => {
      throw new BoundaryError("VALIDATION_FAILURE");
    },
  );
  await assert.rejects(
    submitVerifiedQuizReport(
      schema,
      new TextEncoder().encode(JSON.stringify(fixture.request)),
      "verified-token",
      deps.value,
    ),
    /^Error: VALIDATION_FAILURE$/,
  );
  assert.equal(
    connection.calls.some((call) => call.sql === "ROLLBACK"),
    true,
  );
  assert.equal(
    connection.calls.some((call) => call.sql === "COMMIT"),
    false,
  );
  assert.equal(
    connection.calls.some((call) => call.sql === storeSql),
    false,
  );
  assert.equal(connection.closed, true);
});

test("database role without the closed ledger privileges is refused before BEGIN", async () => {
  const connection = new FakeConnection("denied");
  const deps = dependencies(connection);
  await assert.rejects(
    submitVerifiedQuizReport(
      schema,
      new TextEncoder().encode(JSON.stringify(fixture.request)),
      "verified-token",
      deps.value,
    ),
    /^Error: INTERNAL_ERROR$/,
  );
  assert.equal(
    connection.calls.some((call) => call.sql.startsWith("BEGIN")),
    false,
  );
  assert.equal(connection.closed, true);
});

test("database and commit errors are redacted and never treated as a retry success", async () => {
  const permission = new FakeConnection("permission-error");
  const permissionDeps = dependencies(permission);
  await assert.rejects(
    submitVerifiedQuizReport(
      schema,
      new TextEncoder().encode(JSON.stringify(fixture.request)),
      "verified-token",
      permissionDeps.value,
    ),
    (error: unknown) =>
      error instanceof BoundaryError &&
      error.code === "INTERNAL_ERROR" &&
      !error.message.includes("PRIVATE SQL TOKEN"),
  );
  const commit = new FakeConnection("commit-rollback", fixture.response);
  const commitDeps = dependencies(commit);
  await assert.rejects(
    submitVerifiedQuizReport(
      schema,
      new TextEncoder().encode(JSON.stringify(fixture.request)),
      "verified-token",
      commitDeps.value,
    ),
    /^Error: NETWORK_UNAVAILABLE$/,
  );
  assert.equal(
    commit.calls.some((call) => call.sql === storeSql),
    true,
  );
  assert.equal(commit.closed, true);
});

test("cancellation during current-content validation closes the owned connection before store", async () => {
  const connection = new FakeConnection("miss", fixture.response);
  const controller = new AbortController();
  let started!: () => void;
  const entered = new Promise<void>((resolve) => {
    started = resolve;
  });
  const deps = dependencies(
    connection,
    async () => ({ id: owner }),
    async (_query, _request, signal) => {
      started();
      await new Promise<void>((resolve) => {
        signal.addEventListener("abort", () => resolve(), { once: true });
      });
    },
  );
  const pending = submitVerifiedQuizReport(
    schema,
    new TextEncoder().encode(JSON.stringify(fixture.request)),
    "verified-token",
    deps.value,
    controller.signal,
  );
  await entered;
  controller.abort();
  await assert.rejects(pending, /^Error: NETWORK_UNAVAILABLE$/);
  assert.equal(
    connection.calls.some((call) => call.sql === storeSql),
    false,
  );
  assert.equal(
    connection.calls.some((call) => call.sql === "COMMIT"),
    false,
  );
  assert.equal(connection.closed, true);
});
