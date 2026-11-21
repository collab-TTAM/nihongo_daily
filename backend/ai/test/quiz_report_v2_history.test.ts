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
  readVerifiedQuizReportV2History,
  type QuizReportV2HistoryRequest,
} from "../src/quiz_report_v2_history.ts";
import type {
  QuizReportV2Request,
  QuizReportV2Response,
} from "../src/quiz_report_v2.ts";

interface Fixture {
  readonly request: QuizReportV2Request;
  readonly response: QuizReportV2Response;
}

const root = new URL("../../../contracts/quiz/v2/", import.meta.url);
const schema = JSON.parse(readFileSync(new URL("schema.json", root), "utf8"));
const fixtures = JSON.parse(
  readFileSync(new URL("fixtures.json", root), "utf8"),
) as Fixture[];
const fixture = fixtures[0]!;
const owner = "e3100000-0000-4000-8000-000000000001";
const otherOwner = "e3100000-0000-4000-8000-000000000099";
const encode = (value: unknown) =>
  new TextEncoder().encode(JSON.stringify(value));
const baseRequest: QuizReportV2HistoryRequest = {
  jlpt_level: "N5",
  quiz_type: "vocabulary_reading",
  limit: 2,
  cursor: null,
};

function result(
  command: string,
  rows: Record<string, unknown>[] = [],
): PostgresResult {
  return { command, rowCount: rows.length, rows };
}

function row(eventId: string, receivedAt: string) {
  const request: QuizReportV2Request = {
    ...fixture.request,
    client_event_id: eventId,
  };
  const response: QuizReportV2Response = {
    ...fixture.response,
    client_event_id: eventId,
  };
  return {
    client_event_id: eventId,
    received_at: receivedAt,
    request_json: JSON.stringify(request),
    response_json: JSON.stringify(response),
  };
}

type FakeMode =
  | "ok"
  | "permission-denied"
  | "identity-mismatch"
  | "query-error"
  | "commit-error";

class FakeConnection implements PostgresConnection {
  readonly calls: Array<{ sql: string; values?: string[] }> = [];
  closed = false;
  private owner = "";
  readonly rows: Record<string, unknown>[];
  readonly mode: FakeMode;
  readonly historyQuery: (() => Promise<PostgresResult>) | undefined;

  constructor(
    rows: Record<string, unknown>[] = [],
    mode: FakeMode = "ok",
    historyQuery?: () => Promise<PostgresResult>,
  ) {
    this.rows = rows;
    this.mode = mode;
    this.historyQuery = historyQuery;
  }

  async connect(): Promise<void> {}

  async query(sql: string, values?: string[]): Promise<PostgresResult> {
    this.calls.push({ sql, values });
    if (sql.includes("has_schema_privilege")) {
      return result("SELECT", [
        {
          schema_usage: true,
          receipt_select: this.mode !== "permission-denied",
          rls_enabled: this.mode !== "permission-denied",
        },
      ]);
    }
    if (sql.startsWith("BEGIN")) return result("BEGIN");
    if (sql.startsWith("SET LOCAL")) return result("SET");
    if (sql.startsWith("SELECT set_config(")) {
      this.owner = values?.[0] ?? "";
      return result("SELECT", [{ owner_id: this.owner }]);
    }
    if (sql === "SELECT auth.uid()::text AS owner_id") {
      return result("SELECT", [
        {
          owner_id: this.mode === "identity-mismatch" ? otherOwner : this.owner,
        },
      ]);
    }
    if (sql.includes("FROM private.quiz_report_receipts")) {
      if (this.mode === "query-error") throw new Error("PRIVATE SQL TOKEN");
      if (this.historyQuery) return this.historyQuery();
      return result("SELECT", this.rows);
    }
    if (sql === "COMMIT") {
      return result(this.mode === "commit-error" ? "ROLLBACK" : "COMMIT");
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
) {
  let opened = 0;
  let verified = 0;
  return {
    opened: () => opened,
    verified: () => verified,
    value: {
      auth: {
        verify: async (token: string, signal: AbortSignal) => {
          verified++;
          return verify(token, signal);
        },
      },
      connections: () => {
        opened++;
        return connection;
      },
    },
  };
}

test("history rejects owner-supplied fields, invalid filters, cursors and limits before Auth or PostgreSQL", async () => {
  const connection = new FakeConnection();
  const deps = dependencies(connection);
  const invalid = [
    encode({ ...baseRequest, owner_id: owner }),
    encode({ ...baseRequest, limit: 0 }),
    encode({ ...baseRequest, limit: 101 }),
    encode({ ...baseRequest, jlpt_level: "N3" }),
    encode({ ...baseRequest, quiz_type: "arbitrary_sql" }),
    encode({
      ...baseRequest,
      cursor: {
        received_at: "2026-11-15T12:00:00Z",
        client_event_id: fixture.request.client_event_id,
      },
    }),
    new TextEncoder().encode(
      '{"jlpt_level":"N5","quiz_type":"vocabulary_reading","limit":1,"limit":2,"cursor":null}',
    ),
  ];
  for (const raw of invalid) {
    await assert.rejects(
      readVerifiedQuizReportV2History(
        schema,
        raw,
        "verified-token",
        deps.value,
      ),
      /^Error: VALIDATION_FAILURE$/,
    );
  }
  assert.equal(deps.verified(), 0);
  assert.equal(deps.opened(), 0);
  assert.equal(connection.calls.length, 0);
});

test("invalid Auth never opens the owner-scoped history connection", async () => {
  const connection = new FakeConnection();
  const deps = dependencies(connection, async () => null);
  await assert.rejects(
    readVerifiedQuizReportV2History(
      schema,
      encode(baseRequest),
      "invalid-token",
      deps.value,
    ),
    (error: unknown) =>
      error instanceof BoundaryError && error.code === "UNAUTHORIZED",
  );
  assert.equal(deps.verified(), 1);
  assert.equal(deps.opened(), 0);
  assert.equal(connection.calls.length, 0);
});

test("history uses verified auth.uid, fixed filters and bounded keyset pages", async () => {
  const rows = [
    row("e3100000-0000-4000-8000-000000000011", "2026-11-15T12:00:00.000001Z"),
    row("e3100000-0000-4000-8000-000000000012", "2026-11-15T11:00:00.000001Z"),
    row("e3100000-0000-4000-8000-000000000013", "2026-11-15T10:00:00.000001Z"),
  ];
  const firstConnection = new FakeConnection(rows);
  const firstDeps = dependencies(firstConnection, async (token) => {
    assert.equal(token, "verified-token");
    return { id: owner };
  });
  const first = await readVerifiedQuizReportV2History(
    schema,
    encode(baseRequest),
    "verified-token",
    firstDeps.value,
  );
  assert.deepEqual(
    first.items.map((entry) => entry.request.client_event_id),
    [rows[0]!.client_event_id, rows[1]!.client_event_id],
  );
  assert.deepEqual(first.items[0]!.response, {
    ...fixture.response,
    client_event_id: rows[0]!.client_event_id,
  });
  assert.deepEqual(first.next_cursor, {
    received_at: rows[1]!.received_at,
    client_event_id: rows[1]!.client_event_id,
  });
  const firstHistoryCall = firstConnection.calls.find((call) =>
    call.sql.includes("FROM private.quiz_report_receipts"),
  );
  assert.ok(firstHistoryCall);
  assert.match(firstHistoryCall.sql, /user_id = auth\.uid\(\)/);
  assert.match(
    firstHistoryCall.sql,
    /ORDER BY received_at DESC, client_event_id DESC/,
  );
  assert.deepEqual(firstHistoryCall.values, [
    "N5",
    "vocabulary_reading",
    "",
    "",
    "3",
  ]);
  assert.ok(
    firstConnection.calls.some(
      (call) => call.sql === "BEGIN ISOLATION LEVEL READ COMMITTED READ ONLY",
    ),
  );
  assert.ok(
    !firstConnection.calls.some((call) =>
      /^\s*(INSERT|UPDATE|DELETE|TRUNCATE)\b/i.test(call.sql),
    ),
  );
  assert.equal(firstConnection.closed, true);

  const secondRequest: QuizReportV2HistoryRequest = {
    ...baseRequest,
    cursor: first.next_cursor,
  };
  const secondConnection = new FakeConnection([rows[2]!]);
  const secondDeps = dependencies(secondConnection);
  const second = await readVerifiedQuizReportV2History(
    schema,
    encode(secondRequest),
    "verified-token",
    secondDeps.value,
  );
  assert.deepEqual(
    second.items.map((entry) => entry.request.client_event_id),
    [rows[2]!.client_event_id],
  );
  assert.equal(second.next_cursor, null);
  const secondHistoryCall = secondConnection.calls.find((call) =>
    call.sql.includes("FROM private.quiz_report_receipts"),
  );
  assert.deepEqual(secondHistoryCall?.values, [
    "N5",
    "vocabulary_reading",
    rows[1]!.received_at,
    rows[1]!.client_event_id,
    "3",
  ]);
});

test("history fails closed on mismatched stored request, response or filter", async () => {
  const original = row(
    "e3100000-0000-4000-8000-000000000021",
    "2026-11-15T12:00:00.000001Z",
  );
  const mismatchedEvent = {
    ...original,
    client_event_id: "e3100000-0000-4000-8000-000000000022",
  };
  const badResponse = {
    ...original,
    response_json: JSON.stringify({
      ...fixture.response,
      client_event_id: original.client_event_id,
      correct_count: fixture.response.correct_count === 0 ? 1 : 0,
    }),
  };
  const wrongFilterRequest = baseRequest;
  for (const rows of [[mismatchedEvent], [badResponse]]) {
    const connection = new FakeConnection(rows);
    const deps = dependencies(connection);
    await assert.rejects(
      readVerifiedQuizReportV2History(
        schema,
        encode(baseRequest),
        "verified-token",
        deps.value,
      ),
      /^Error: INTERNAL_ERROR$/,
    );
    assert.ok(connection.calls.some((call) => call.sql === "ROLLBACK"));
    assert.ok(!connection.calls.some((call) => call.sql === "COMMIT"));
    assert.equal(connection.closed, true);
  }
  const wrongFilter = row(
    "e3100000-0000-4000-8000-000000000023",
    "2026-11-15T12:00:00.000001Z",
  );
  const request = {
    ...fixture.request,
    client_event_id: wrongFilter.client_event_id,
    jlpt_level: "N4" as const,
  };
  const response = {
    ...fixture.response,
    client_event_id: wrongFilter.client_event_id,
    jlpt_level: "N4" as const,
  };
  const filteredConnection = new FakeConnection([
    {
      ...wrongFilter,
      request_json: JSON.stringify(request),
      response_json: JSON.stringify(response),
    },
  ]);
  const filteredDeps = dependencies(filteredConnection);
  await assert.rejects(
    readVerifiedQuizReportV2History(
      schema,
      encode(wrongFilterRequest),
      "verified-token",
      filteredDeps.value,
    ),
    /^Error: INTERNAL_ERROR$/,
  );
  assert.ok(filteredConnection.calls.some((call) => call.sql === "ROLLBACK"));
});

test("history requires schema/table read permission and enabled RLS", async () => {
  const connection = new FakeConnection([], "permission-denied");
  const deps = dependencies(connection);
  await assert.rejects(
    readVerifiedQuizReportV2History(
      schema,
      encode(baseRequest),
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

test("history verifies auth.uid before selecting and rolls back identity mismatch", async () => {
  const connection = new FakeConnection([], "identity-mismatch");
  const deps = dependencies(connection);
  await assert.rejects(
    readVerifiedQuizReportV2History(
      schema,
      encode(baseRequest),
      "verified-token",
      deps.value,
    ),
    /^Error: INTERNAL_ERROR$/,
  );
  assert.ok(connection.calls.some((call) => call.sql === "ROLLBACK"));
  assert.ok(
    !connection.calls.some((call) =>
      call.sql.includes("FROM private.quiz_report_receipts"),
    ),
  );
  assert.equal(connection.closed, true);
});

test("history cancellation during SELECT closes without commit", async () => {
  let releaseHistory!: () => void;
  let historyStarted!: () => void;
  const entered = new Promise<void>((resolve) => {
    historyStarted = resolve;
  });
  const pendingHistory = new Promise<PostgresResult>((resolve) => {
    releaseHistory = () => resolve(result("SELECT", []));
  });
  const connection = new FakeConnection([], "ok", async () => {
    historyStarted();
    return pendingHistory;
  });
  const deps = dependencies(connection);
  const controller = new AbortController();
  const pending = readVerifiedQuizReportV2History(
    schema,
    encode(baseRequest),
    "verified-token",
    deps.value,
    controller.signal,
  );
  await entered;
  controller.abort("PRIVATE DATABASE DETAIL");
  await assert.rejects(pending, /^Error: NETWORK_UNAVAILABLE$/);
  assert.equal(connection.closed, true);
  assert.ok(!connection.calls.some((call) => call.sql === "COMMIT"));
  releaseHistory();
  await Promise.resolve();
});
