// TEST ONLY SQL replies/traces; no native PostgreSQL, identity or content proof.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createQuizReportSqlTransaction } from "../src/quiz_report_sql.ts";
import { submitQuizReportInTransaction } from "../src/quiz_report_transaction.ts";
import type { PostgresResult } from "../src/postgres_connection.ts";
const root = new URL("../../../contracts/quiz/v1/", import.meta.url);
const schema = JSON.parse(readFileSync(new URL("schema.json", root), "utf8"));
const fixtures = JSON.parse(
  readFileSync(new URL("fixtures.json", root), "utf8"),
);
const encode = (v: unknown) => new TextEncoder().encode(JSON.stringify(v));
const reply = (response: unknown): PostgresResult => ({
  command: "SELECT",
  rowCount: 1,
  rows: [{ response }],
});

test("quiz SQL bridge binds all canonical payloads and preserves replay-first order", async () => {
  for (const fixture of fixtures) {
    for (const hit of [true, false]) {
      const calls: string[] = [];
      const tx = createQuizReportSqlTransaction(
        async (sql, values) => {
          assert.equal(values.length, 1);
          assert.deepEqual(JSON.parse(values[0]!), fixture.request);
          assert.ok(
            sql ===
              "SELECT private.replay_quiz_report($1::jsonb)::text AS response" ||
              sql ===
                "SELECT private.store_quiz_report($1::jsonb)::text AS response",
          );
          const replay = sql.includes("replay_quiz");
          calls.push(replay ? "replay" : "store");
          return reply(
            replay && !hit ? null : JSON.stringify(fixture.response),
          );
        },
        async (request) => {
          assert.deepEqual(request, fixture.request);
          calls.push("content");
        },
      );
      const result = await submitQuizReportInTransaction(
        schema,
        encode(fixture.request),
        {
          async run(work) {
            return work(tx);
          },
        },
      );
      assert.deepEqual(result, fixture.response);
      assert.ok(Object.isFrozen(tx));
      assert.deepEqual(
        calls,
        hit ? ["replay"] : ["replay", "content", "store"],
      );
    }
  }
});

test("quiz SQL unknown/malformed envelope is never a lookup miss", async () => {
  const malformed: PostgresResult[] = [
    { command: "UPDATE", rowCount: 1, rows: [{ response: null }] },
    { command: "SELECT", rowCount: 0, rows: [] },
    {
      command: "SELECT",
      rowCount: 2,
      rows: [{ response: null }, { response: null }],
    },
    { command: "SELECT", rowCount: 1, rows: [{}] },
    { command: "SELECT", rowCount: 1, rows: [{ response: null, extra: true }] },
    ...[undefined, {}, 0, false, "", "x".repeat(16385), "日".repeat(6000)].map(
      reply,
    ),
  ];
  for (const result of malformed) {
    let calls = 0;
    const tx = createQuizReportSqlTransaction(
      async () => {
        calls++;
        return result;
      },
      async () => assert.fail("content on unknown lookup"),
    );
    await assert.rejects(
      submitQuizReportInTransaction(schema, encode(fixtures[0].request), {
        async run(work) {
          return work(tx);
        },
      }),
      /^Error: INTERNAL_ERROR$/,
    );
    assert.equal(calls, 1);
  }
});

test("quiz SQL null store and invalid response reject before callback success", async () => {
  for (const response of [
    null,
    "null",
    "{}",
    "{broken",
    JSON.stringify({ ...fixtures[0].response, correct_count: 99 }),
  ]) {
    let queries = 0;
    let committed = false;
    const tx = createQuizReportSqlTransaction(
      async () => reply(++queries === 1 ? null : response),
      async () => {},
    );
    await assert.rejects(
      submitQuizReportInTransaction(schema, encode(fixtures[0].request), {
        async run(work) {
          const result = await work(tx);
          committed = true;
          return result;
        },
      }),
      /^Error: INTERNAL_ERROR$/,
    );
    assert.equal(queries, 2);
    assert.equal(committed, false);
  }
});

test("quiz SQL maps only exact ledger SQLSTATE/message pairs and redacts others", async () => {
  for (const code of [
    "UNAUTHORIZED",
    "VALIDATION_FAILURE",
    "SYNC_CONFLICT",
    "PRIVATE SQL TOKEN",
  ]) {
    for (const state of ["P0001", "XX000"]) {
      const tx = createQuizReportSqlTransaction(
        async () => {
          throw { code: state, message: code, detail: "private token" };
        },
        async () => {},
      );
      const expected =
        state === "P0001" && code !== "PRIVATE SQL TOKEN"
          ? code
          : "INTERNAL_ERROR";
      await assert.rejects(
        tx.replay(fixtures[0].request),
        new RegExp(`^Error: ${expected}$`),
      );
    }
  }
});
