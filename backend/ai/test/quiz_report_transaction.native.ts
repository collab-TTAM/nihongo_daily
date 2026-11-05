// TEST ONLY fixed PostgreSQL 17 database; no hosted Auth, PostgREST or learner calls.
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { Client } from "pg";
import { BoundaryError } from "../src/contracts.ts";
import {
  createQuizReportSqlTransaction,
} from "../src/quiz_report_sql.ts";
import {
  submitQuizReportInTransaction,
} from "../src/quiz_report_transaction.ts";
import type {
  QuizReportRequest,
  QuizReportResponse,
} from "../src/quiz_report.ts";
import type {
  QuizReportTransaction,
  QuizReportTransactionHost,
} from "../src/quiz_report_transaction.ts";
import type { PostgresResult } from "../src/postgres_connection.ts";

const databaseUrl = process.env.TEST_DATABASE_URL;
if (databaseUrl !== "postgresql://postgres:postgres@localhost:5432/nihongo_test") {
  throw new Error("Native quiz coordinator requires the fixed disposable CI database");
}
const root = new URL("../../../contracts/quiz/v1/", import.meta.url);
const schema = JSON.parse(readFileSync(new URL("schema.json", root), "utf8"));
const fixtures = JSON.parse(
  readFileSync(new URL("fixtures.json", root), "utf8"),
) as Array<{ request: QuizReportRequest; response: QuizReportResponse }>;

type Trace = { operations: string[]; transactionIds: string[] };
type Validator = (request: QuizReportRequest) => Promise<void>;

function client() {
  const connection = new Client({
    connectionString: databaseUrl,
    ssl: false,
    application_name: "nd-quiz-coordinator-native",
    connectionTimeoutMillis: 2000,
    query_timeout: 3000,
    pipeline: false,
  });
  connection.on("error", () => {});
  return connection;
}

function tableFor(request: QuizReportRequest) {
  return request.quiz_type === "vocabulary_reading"
    ? "public.vocabulary"
    : "public.grammar";
}

function remap(request: QuizReportRequest): QuizReportRequest {
  const ids = new Set(request.answers.flatMap((answer) => [...answer.choices]));
  const replacements = new Map([...ids].map((id) => [id, randomUUID()]));
  return {
    ...request,
    client_event_id: randomUUID(),
    answers: request.answers.map((answer) => ({
      ...answer,
      item_id: replacements.get(answer.item_id)!,
      selected_id: replacements.get(answer.selected_id)!,
      choices: answer.choices.map((id) => replacements.get(id)!),
    })),
  };
}

async function seedContent(
  connection: Client,
  request: QuizReportRequest,
) {
  for (const id of new Set(request.answers.flatMap((answer) => [...answer.choices]))) {
    if (request.quiz_type === "vocabulary_reading") {
      await connection.query(
        "INSERT INTO public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,expression,reading,meaning_vi,part_of_speech,usage_context_vi) VALUES($1::uuid,$2::public.jlpt_level,0.2,1,true,$3,$4,'nghĩa','noun','native quiz TEST ONLY')",
        [id, request.jlpt_level, "語" + id.slice(0, 8), "ご" + id.slice(0, 8)],
      );
    } else {
      await connection.query(
        "INSERT INTO public.grammar(id,jlpt_level,difficulty,content_version,is_active,title,pattern,meaning_vi,explanation_vi) VALUES($1::uuid,$2::public.jlpt_level,0.2,1,true,$3,$4,'nghĩa','giải thích')",
        [id, request.jlpt_level, "文法" + id.slice(0, 8), "N" + id.slice(0, 8)],
      );
    }
  }
}

async function setActive(
  connection: Client,
  request: QuizReportRequest,
  itemId: string,
  active: boolean,
) {
  await connection.query(
    `UPDATE ${tableFor(request)} SET is_active=$2 WHERE id=$1::uuid`,
    [itemId, active],
  );
}

async function validateCurrentContent(
  connection: Client,
  request: QuizReportRequest,
) {
  const table = tableFor(request);
  const choices = [...new Set(request.answers.flatMap((answer) => [...answer.choices]))];
  const active = await connection.query(
    `SELECT count(*)::integer AS count FROM ${table}
      WHERE id=ANY($1::uuid[]) AND jlpt_level=$2::public.jlpt_level AND is_active`,
    [choices, request.jlpt_level],
  );
  if (active.rows[0]?.count !== choices.length) {
    throw new BoundaryError("VALIDATION_FAILURE");
  }
  for (const answer of request.answers) {
    const target = await connection.query(
      `SELECT content_version FROM ${table}
        WHERE id=$1::uuid AND jlpt_level=$2::public.jlpt_level AND is_active`,
      [answer.item_id, request.jlpt_level],
    );
    if (
      target.rows.length !== 1 ||
      Number(target.rows[0]?.content_version) !== answer.content_version
    ) {
      throw new BoundaryError("VALIDATION_FAILURE");
    }
  }
}

async function transactionId(connection: Client) {
  if (connection.getTransactionStatus() !== "T") {
    throw new Error("Quiz SQL capability escaped its open transaction");
  }
  const result = await connection.query(
    "SELECT txid_current()::text AS transaction_id",
  );
  const value = result.rows[0]?.transaction_id;
  if (typeof value !== "string") {
    throw new Error("Quiz transaction identity unavailable");
  }
  return value;
}

function makeHost(
  connection: Client,
  ownerId: string,
  validator: Validator,
  trace: Trace,
): QuizReportTransactionHost {
  const query = async (sql: string, values: string[]): Promise<PostgresResult> => {
    if (
      sql !== "SELECT private.replay_quiz_report($1::jsonb)::text AS response" &&
      sql !== "SELECT private.store_quiz_report($1::jsonb)::text AS response"
    ) {
      throw new Error("Unexpected quiz SQL capability");
    }
    trace.operations.push(sql.includes("replay_quiz_report") ? "replay" : "store");
    trace.transactionIds.push(await transactionId(connection));
    const result = await connection.query(sql, values);
    return {
      command: result.command,
      rowCount: result.rowCount,
      rows: result.rows as Record<string, unknown>[],
    };
  };
  const transaction: QuizReportTransaction = createQuizReportSqlTransaction(
    query,
    async (request) => {
      trace.operations.push("content");
      trace.transactionIds.push(await transactionId(connection));
      await validator(request);
    },
  );
  return {
    async run(work) {
      await connection.query("BEGIN");
      try {
        await connection.query("SET LOCAL statement_timeout = '2500ms'");
        await connection.query(
          "SELECT set_config('request.jwt.claim.sub',$1,true)",
          [ownerId],
        );
        await connection.query("SAVEPOINT quiz_report_work");
        try {
          const result = await work(transaction);
          await connection.query("RELEASE SAVEPOINT quiz_report_work");
          await connection.query("COMMIT");
          assert.equal(connection.getTransactionStatus(), "I");
          return result;
        } catch (error) {
          await connection.query("ROLLBACK TO SAVEPOINT quiz_report_work");
          await connection.query("RELEASE SAVEPOINT quiz_report_work");
          await connection.query("COMMIT");
          assert.equal(connection.getTransactionStatus(), "I");
          throw error;
        }
      } catch (error) {
        if (connection.getTransactionStatus() !== "I") {
          await connection.query("ROLLBACK").catch(() => {});
        }
        throw error;
      }
    },
  };
}

async function submit(
  connection: Client,
  ownerId: string,
  request: QuizReportRequest,
  validator: Validator,
  trace: Trace,
) {
  const host = makeHost(connection, ownerId, validator, trace);
  const raw = new TextEncoder().encode(JSON.stringify(request));
  return submitQuizReportInTransaction(schema, raw, host);
}

async function receiptCount(
  connection: Client,
  ownerId: string,
  eventId: string,
) {
  const result = await connection.query(
    "SELECT count(*)::integer AS count FROM private.quiz_report_receipts WHERE user_id=$1::uuid AND client_event_id=$2::uuid",
    [ownerId, eventId],
  );
  return result.rows[0]?.count;
}

function assertOneNativeTransaction(trace: Trace) {
  assert.ok(trace.transactionIds.length > 0);
  assert.equal(new Set(trace.transactionIds).size, 1);
}

test(
  "native quiz coordinator rolls back a rejected current-content attempt to its savepoint, then retries",
  { timeout: 30000 },
  async () => {
    for (const fixture of fixtures) {
      const connection = client();
      await connection.connect();
      try {
        const ownerA = randomUUID();
        const ownerB = randomUUID();
        const request = remap(fixture.request);
        const first = request.answers[0];
        assert.ok(first);
        await connection.query("INSERT INTO auth.users(id) VALUES($1::uuid)", [ownerA]);
        await seedContent(connection, request);

        await setActive(connection, request, first.item_id, false);
        const rejectedTrace: Trace = { operations: [], transactionIds: [] };
        await assert.rejects(
          submit(connection, ownerA, request, (value) => validateCurrentContent(connection, value), rejectedTrace),
          (error: unknown) => {
            assert.ok(error instanceof BoundaryError);
            assert.equal(error.code, "VALIDATION_FAILURE");
            assert.equal(error.message, "VALIDATION_FAILURE");
            return true;
          },
        );
        assert.deepEqual(rejectedTrace.operations, ["replay", "content"]);
        assertOneNativeTransaction(rejectedTrace);
        assert.equal(await receiptCount(connection, ownerA, request.client_event_id), 0);

        await setActive(connection, request, first.item_id, true);
        const savedTrace: Trace = { operations: [], transactionIds: [] };
        const expected: QuizReportResponse = {
          ...fixture.response,
          client_event_id: request.client_event_id,
        };
        assert.deepEqual(
          await submit(
            connection,
            ownerA,
            request,
            (value) => validateCurrentContent(connection, value),
            savedTrace,
          ),
          expected,
        );
        assert.deepEqual(savedTrace.operations, ["replay", "content", "store"]);
        assertOneNativeTransaction(savedTrace);
        assert.equal(await receiptCount(connection, ownerA, request.client_event_id), 1);

        await setActive(connection, request, first.item_id, false);
        const replayTrace: Trace = { operations: [], transactionIds: [] };
        assert.deepEqual(
          await submit(
            connection,
            ownerA,
            request,
            async () => assert.fail("Exact replay must skip current-content validation"),
            replayTrace,
          ),
          expected,
        );
        assert.deepEqual(replayTrace.operations, ["replay"]);
        assertOneNativeTransaction(replayTrace);

        const changed: QuizReportRequest = {
          ...request,
          answers: request.answers.map((answer, index) =>
            index === 0
              ? {
                  ...answer,
                  selected_id: answer.choices.find((id) => id !== answer.selected_id)!,
                }
              : answer,
          ),
        };
        const conflictTrace: Trace = { operations: [], transactionIds: [] };
        await assert.rejects(
          submit(
            connection,
            ownerA,
            changed,
            async () => assert.fail("Changed replay must conflict before content validation"),
            conflictTrace,
          ),
          (error: unknown) => {
            assert.ok(error instanceof BoundaryError);
            assert.equal(error.code, "SYNC_CONFLICT");
            assert.equal(error.message, "SYNC_CONFLICT");
            return true;
          },
        );
        assert.deepEqual(conflictTrace.operations, ["replay"]);
        assertOneNativeTransaction(conflictTrace);
        assert.equal(await receiptCount(connection, ownerA, request.client_event_id), 1);

        await setActive(connection, request, first.item_id, true);
        await connection.query("INSERT INTO auth.users(id) VALUES($1::uuid)", [ownerB]);
        const ownerBTrace: Trace = { operations: [], transactionIds: [] };
        assert.deepEqual(
          await submit(
            connection,
            ownerB,
            request,
            (value) => validateCurrentContent(connection, value),
            ownerBTrace,
          ),
          expected,
        );
        assert.deepEqual(ownerBTrace.operations, ["replay", "content", "store"]);
        assertOneNativeTransaction(ownerBTrace);
        assert.equal(await receiptCount(connection, ownerA, request.client_event_id), 1);
        assert.equal(await receiptCount(connection, ownerB, request.client_event_id), 1);
        assert.equal(connection.getTransactionStatus(), "I");
        console.log(
          `PASS: native quiz coordinator ${request.quiz_type}/${request.practice_kind ?? "none"} rollback, retry, original replay and A/B isolation (TEST ONLY)`,
        );
      } finally {
        await connection.end();
      }
    }
  },
);

