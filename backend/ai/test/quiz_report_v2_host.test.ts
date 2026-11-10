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
  createQuizReportV2SqlTransaction,
  submitQuizReportV2InTransaction,
  submitVerifiedQuizReportV2,
  withQuizReportV2TransactionScope,
  type QuizReportV2CurrentContentValidator,
  type QuizReportV2Transaction,
} from "../src/quiz_report_v2_host.ts";
import type {
  QuizReportV2Request,
  QuizReportV2Response,
} from "../src/quiz_report_v2.ts";

interface Fixture {
  readonly request: QuizReportV2Request;
  readonly response: QuizReportV2Response;
}

const root = new URL("../../../contracts/quiz/v2/", import.meta.url);
const schema = JSON.parse(
  readFileSync(new URL("schema.json", root), "utf8"),
);
const fixtures = JSON.parse(
  readFileSync(new URL("fixtures.json", root), "utf8"),
) as Fixture[];
const fixture = fixtures[0]!;
const owner = "e3100000-0000-4000-8000-000000000001";
const replaySql =
  "SELECT private.replay_quiz_report_v2($1::jsonb)::text AS response";
const storeSql =
  "SELECT private.store_quiz_report_v2($1::jsonb)::text AS response";
const encode = (value: unknown) =>
  new TextEncoder().encode(JSON.stringify(value));

function result(
  command: string,
  rows: Record<string, unknown>[] = [],
): PostgresResult {
  return { command, rowCount: rows.length, rows };
}

class FakeConnection implements PostgresConnection {
  readonly calls: Array<{ sql: string; values?: string[] }> = [];
  closed = false;
  readonly mode:
    | "miss"
    | "hit"
    | "denied"
    | "permission-error"
    | "commit-error"
    | "identity-mismatch"
    | "bad-response";
  readonly response: unknown;

  constructor(
    mode:
      | "miss"
      | "hit"
      | "denied"
      | "permission-error"
      | "commit-error"
      | "identity-mismatch"
      | "bad-response" = "miss",
    response: unknown = fixture.response,
  ) {
    this.mode = mode;
    this.response = response;
  }

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
      return result("SELECT", [
        {
          owner_id:
            this.mode === "identity-mismatch"
              ? "e3100000-0000-4000-8000-000000000099"
              : values?.[0],
        },
      ]);
    }
    if (sql === replaySql) {
      const response =
        this.mode === "hit"
          ? JSON.stringify(this.response)
          : this.mode === "bad-response"
            ? "{}"
            : null;
      return result("SELECT", [{ response }]);
    }
    if (sql === "SELECT canonical current content") {
      return result("SELECT", [{ accepted: true }]);
    }
    if (sql === storeSql) {
      return result("SELECT", [{ response: JSON.stringify(this.response) }]);
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
  validateCurrentContent: QuizReportV2CurrentContentValidator = async (
    query,
    request,
  ) => {
    assert.equal(request.client_event_id, fixture.request.client_event_id);
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
      validateCurrentContent,
    },
  };
}

test("verified-owner v2 host binds Auth identity and runs replay/content/store on one connection", async () => {
  const connection = new FakeConnection();
  const deps = dependencies(connection, async (token) => {
    assert.equal(token, "verified-token");
    return { id: owner };
  });
  const saved = await submitVerifiedQuizReportV2(
    schema,
    encode(fixture.request),
    "verified-token",
    deps.value,
  );
  assert.deepEqual(saved, fixture.response);
  const sql = connection.calls.map((call) => call.sql);
  const replay = sql.indexOf(replaySql);
  const content = sql.indexOf("SELECT canonical current content");
  const store = sql.indexOf(storeSql);
  const commit = sql.indexOf("COMMIT");
  assert.ok(replay >= 0 && replay < content && content < store && store < commit);
  assert.ok(
    connection.calls.some(
      (call) =>
        call.sql.includes("private.replay_quiz_report_v2(jsonb)") &&
        call.sql.includes("private.store_quiz_report_v2(jsonb)"),
    ),
  );
  const claim = connection.calls.find((call) =>
    call.sql.startsWith("SELECT set_config("),
  );
  assert.deepEqual(claim?.values, [owner]);
  assert.equal(connection.closed, true);
  assert.equal(deps.opened(), 1);
});

test("exact v2 replay bypasses current content and store", async () => {
  const connection = new FakeConnection("hit");
  const deps = dependencies(
    connection,
    async () => ({ id: owner }),
    async () => assert.fail("Replay must not inspect current content"),
  );
  assert.deepEqual(
    await submitVerifiedQuizReportV2(
      schema,
      encode(fixture.request),
      "verified-token",
      deps.value,
    ),
    fixture.response,
  );
  assert.equal(connection.calls.some((call) => call.sql === storeSql), false);
  assert.equal(connection.calls.some((call) => call.sql === "COMMIT"), true);
});

test("invalid v2 raw input is rejected before Auth or PostgreSQL", async () => {
  const connection = new FakeConnection();
  let verified = 0;
  const deps = dependencies(connection, async () => {
    verified++;
    return { id: owner };
  });
  await assert.rejects(
    submitVerifiedQuizReportV2(
      schema,
      encode({ ...fixture.request, user_id: owner }),
      "verified-token",
      deps.value,
    ),
    /^Error: VALIDATION_FAILURE$/,
  );
  assert.equal(verified, 0);
  assert.equal(deps.opened(), 0);
  assert.equal(connection.calls.length, 0);
});

test("invalid Auth identity never opens the v2 ledger connection", async () => {
  const connection = new FakeConnection();
  const deps = dependencies(connection, async () => null);
  await assert.rejects(
    submitVerifiedQuizReportV2(
      schema,
      encode(fixture.request),
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

test("current-content failure rolls back and never acknowledges a v2 report", async () => {
  const connection = new FakeConnection();
  const deps = dependencies(
    connection,
    async () => ({ id: owner }),
    async () => {
      throw new BoundaryError("VALIDATION_FAILURE");
    },
  );
  await assert.rejects(
    submitVerifiedQuizReportV2(
      schema,
      encode(fixture.request),
      "verified-token",
      deps.value,
    ),
    /^Error: VALIDATION_FAILURE$/,
  );
  assert.equal(connection.calls.some((call) => call.sql === "ROLLBACK"), true);
  assert.equal(connection.calls.some((call) => call.sql === "COMMIT"), false);
  assert.equal(connection.calls.some((call) => call.sql === storeSql), false);
  assert.equal(connection.closed, true);
});

test("database role without private v2 ledger privileges is refused before BEGIN", async () => {
  const connection = new FakeConnection("denied");
  const deps = dependencies(connection);
  await assert.rejects(
    submitVerifiedQuizReportV2(
      schema,
      encode(fixture.request),
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

test("v2 database and ambiguous commit errors are redacted", async () => {
  const permission = new FakeConnection("permission-error");
  const permissionDeps = dependencies(permission);
  await assert.rejects(
    submitVerifiedQuizReportV2(
      schema,
      encode(fixture.request),
      "verified-token",
      permissionDeps.value,
    ),
    (error: unknown) =>
      error instanceof BoundaryError &&
      error.code === "INTERNAL_ERROR" &&
      !error.message.includes("PRIVATE SQL TOKEN"),
  );

  const commit = new FakeConnection("commit-error");
  const commitDeps = dependencies(commit);
  await assert.rejects(
    submitVerifiedQuizReportV2(
      schema,
      encode(fixture.request),
      "verified-token",
      commitDeps.value,
    ),
    /^Error: NETWORK_UNAVAILABLE$/,
  );
  assert.equal(commit.calls.some((call) => call.sql === storeSql), true);
  assert.equal(commit.closed, true);
});

test("v2 response mismatch rolls back before commit", async () => {
  const connection = new FakeConnection("miss", {
    ...fixture.response,
    correct_count: 10,
  });
  const deps = dependencies(connection);
  await assert.rejects(
    submitVerifiedQuizReportV2(
      schema,
      encode(fixture.request),
      "verified-token",
      deps.value,
    ),
    /^Error: INTERNAL_ERROR$/,
  );
  assert.equal(connection.calls.some((call) => call.sql === "ROLLBACK"), true);
  assert.equal(connection.calls.some((call) => call.sql === "COMMIT"), false);
  assert.equal(connection.closed, true);
});

test("v2 cancellation during content validation closes the connection before store", async () => {
  const connection = new FakeConnection();
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
  const pending = submitVerifiedQuizReportV2(
    schema,
    encode(fixture.request),
    "verified-token",
    deps.value,
    controller.signal,
  );
  await entered;
  controller.abort("PRIVATE SQL TOKEN");
  await assert.rejects(pending, /^Error: NETWORK_UNAVAILABLE$/);
  assert.equal(connection.calls.some((call) => call.sql === storeSql), false);
  assert.equal(connection.closed, true);
});

test("v2 SQL bridge binds only fixed private functions and preserves replay-first order", async () => {
  for (const hit of [true, false]) {
    const calls: string[] = [];
    const tx = createQuizReportV2SqlTransaction(
      async (sql, values) => {
        assert.equal(values?.length, 1);
        assert.deepEqual(JSON.parse(values![0]!), fixture.request);
        calls.push(sql);
        const replay = sql === replaySql;
        return result("SELECT", [
          {
            response:
              replay && !hit
                ? null
                : JSON.stringify(fixture.response),
          },
        ]);
      },
      async () => {
        calls.push("content");
      },
    );
    const value = await submitQuizReportV2InTransaction(
      schema,
      encode(fixture.request),
      { run: (work) => work(tx) },
    );
    assert.deepEqual(value, fixture.response);
    assert.deepEqual(
      calls,
      hit ? [replaySql] : [replaySql, "content", storeSql],
    );
  }
});

test("v2 SQL bridge treats malformed lookup envelopes as internal, never as a miss", async () => {
  const tx = createQuizReportV2SqlTransaction(
    async () => ({ command: "SELECT", rowCount: 0, rows: [] }),
    async () => assert.fail("Unknown replay must not validate content"),
  );
  await assert.rejects(
    submitQuizReportV2InTransaction(
      schema,
      encode(fixture.request),
      { run: (work) => work(tx) },
    ),
    /^Error: INTERNAL_ERROR$/,
  );
});

test("v2 transaction scope revokes escaped capabilities after callback settlement", async () => {
  const calls: string[] = [];
  let escaped!: QuizReportV2Transaction;
  const source: QuizReportV2Transaction = {
    async replay() {
      calls.push("replay");
      return null;
    },
    async validateCurrentContent() {
      calls.push("content");
    },
    async store() {
      calls.push("store");
      return encode(fixture.response);
    },
  };
  await withQuizReportV2TransactionScope(source, async (tx) => {
    escaped = tx;
    assert.ok(Object.isFrozen(tx));
    assert.equal(await tx.replay(fixture.request), null);
  });
  await assert.rejects(
    escaped.store(fixture.request),
    /^Error: INTERNAL_ERROR$/,
  );
  assert.deepEqual(calls, ["replay"]);
});
