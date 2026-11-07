import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { BoundaryError } from "../src/contracts.ts";
import {
  validateCurrentQuizReportContent,
  type QuizReportContentQuery,
} from "../src/quiz_report_content.ts";
import type { QuizReportRequest } from "../src/quiz_report.ts";
import type { QuizReportCurrentContentValidator } from "../src/quiz_report_host.ts";
import type { PostgresResult } from "../src/postgres_connection.ts";

const root = new URL("../../../contracts/quiz/v1/", import.meta.url);
const fixtures = JSON.parse(
  readFileSync(new URL("fixtures.json", root), "utf8"),
) as Array<{ request: QuizReportRequest }>;
const vocabulary = fixtures[0]!.request;
const grammarPrimary = fixtures[1]!.request;
const grammarCorrection = fixtures[2]!.request;
const validateHostContent: QuizReportCurrentContentValidator =
  validateCurrentQuizReportContent;

function rowsFor(
  request: QuizReportRequest,
  grammar = false,
): Record<string, unknown>[] {
  const ids = [
    ...new Set(request.answers.flatMap((answer) => [...answer.choices])),
  ];
  const versions = new Map(
    request.answers.map((answer) => [answer.item_id, answer.content_version]),
  );
  return ids.map((id, index) => ({
    id,
    content_version: versions.get(id) ?? 1,
    heading: grammar ? `文法項目${index}` : `日本語項目${index}`,
    ...(grammar
      ? { meaning_vi: `Nghĩa ${index}` }
      : { reading: `よみ${index}` }),
  }));
}

function queryFor(rows: Record<string, unknown>[]) {
  const calls: Array<{ sql: string; values?: string[] }> = [];
  const query: QuizReportContentQuery = async (sql, values) => {
    calls.push({ sql, values });
    return {
      command: "SELECT",
      rowCount: rows.length,
      rows,
    } satisfies PostgresResult;
  };
  return { query, calls };
}

function requestCopy(request: QuizReportRequest): QuizReportRequest {
  return structuredClone(request);
}

async function rejectsCode(work: Promise<void>, code: string): Promise<void> {
  await assert.rejects(
    work,
    (error: unknown) =>
      error instanceof BoundaryError &&
      error.code === code &&
      error.message === code,
  );
}

test("accepts active same-level vocabulary choices and target content version", async () => {
  const rows = rowsFor(vocabulary);
  const { query, calls } = queryFor(rows);
  await validateHostContent(query, vocabulary, new AbortController().signal);
  assert.equal(calls.length, 1);
  assert.match(calls[0]!.sql, /public\.vocabulary/);
  assert.deepEqual(calls[0]!.values, ["N5"]);
  assert.match(calls[0]!.sql, /is_active = true/);
  assert.match(calls[0]!.sql, /LIMIT 5001/);
});

test("accepts grammar primary and correction reports from active content", async () => {
  for (const request of [grammarPrimary, grammarCorrection]) {
    const { query, calls } = queryFor(rowsFor(request, true));
    await validateHostContent(query, request, new AbortController().signal);
    assert.match(calls[0]!.sql, /public\.grammar/);
    assert.deepEqual(calls[0]!.values, ["N5"]);
  }
});

test("rejects missing, retired or foreign-level quiz choices", async () => {
  const rows = rowsFor(vocabulary).slice(1);
  const { query } = queryFor(rows);
  await rejectsCode(
    validateHostContent(query, vocabulary, new AbortController().signal),
    "VALIDATION_FAILURE",
  );
});

test("rejects a target whose active content version changed", async () => {
  const request = requestCopy(vocabulary);
  const rows = rowsFor(request);
  rows[0] = {
    ...rows[0]!,
    content_version: request.answers[0]!.content_version + 1,
  };
  const { query } = queryFor(rows);
  await rejectsCode(
    validateHostContent(query, request, new AbortController().signal),
    "VALIDATION_FAILURE",
  );
});

test("rejects vocabulary targets without a unique Kanji heading", async () => {
  const request = requestCopy(vocabulary);
  const rows = rowsFor(request);
  rows[0] = { ...rows[0]!, heading: "かなだけ" };
  const { query } = queryFor(rows);
  await rejectsCode(
    validateHostContent(query, request, new AbortController().signal),
    "VALIDATION_FAILURE",
  );
});

test("rejects ambiguous vocabulary readings in displayed choices", async () => {
  const rows = rowsFor(vocabulary);
  rows[1] = { ...rows[1]!, reading: rows[0]!.reading };
  const { query } = queryFor(rows);
  await rejectsCode(
    validateHostContent(query, vocabulary, new AbortController().signal),
    "VALIDATION_FAILURE",
  );
});

test("rejects grammar targets without a unique heading or meaning", async () => {
  const rows = rowsFor(grammarPrimary, true);
  rows[0] = { ...rows[0]!, heading: rows[1]!.heading };
  const { query } = queryFor(rows);
  await rejectsCode(
    validateHostContent(query, grammarPrimary, new AbortController().signal),
    "VALIDATION_FAILURE",
  );
});

test("rejects ambiguous grammar meanings in displayed choices", async () => {
  const rows = rowsFor(grammarPrimary, true);
  rows[1] = { ...rows[1]!, meaning_vi: rows[0]!.meaning_vi };
  const { query } = queryFor(rows);
  await rejectsCode(
    validateHostContent(query, grammarPrimary, new AbortController().signal),
    "VALIDATION_FAILURE",
  );
});

test("rejects malformed or oversized active-content projections", async () => {
  const malformed = rowsFor(vocabulary);
  malformed[0] = { ...malformed[0]!, unexpected: "private" };
  const malformedQuery = queryFor(malformed);
  await rejectsCode(
    validateHostContent(
      malformedQuery.query,
      vocabulary,
      new AbortController().signal,
    ),
    "INTERNAL_ERROR",
  );
  const oversizedQuery = queryFor(
    Array.from({ length: 5001 }, (_, index) => ({
      id: `a2000000-0000-4000-8000-${String(index).padStart(12, "0")}`,
      content_version: 1,
      heading: `日本語${index}`,
      reading: `よみ${index}`,
    })),
  );
  await rejectsCode(
    validateHostContent(
      oversizedQuery.query,
      vocabulary,
      new AbortController().signal,
    ),
    "INTERNAL_ERROR",
  );
});

test("aborted validation never dispatches a content query", async () => {
  const controller = new AbortController();
  controller.abort();
  const { query, calls } = queryFor(rowsFor(vocabulary));
  await rejectsCode(
    validateCurrentQuizReportContent(query, vocabulary, controller.signal),
    "NETWORK_UNAVAILABLE",
  );
  assert.equal(calls.length, 0);
});

test("redacts content-query failures", async () => {
  const query: QuizReportContentQuery = async () => {
    throw new Error("PRIVATE DATABASE PASSWORD");
  };
  await rejectsCode(
    validateHostContent(query, vocabulary, new AbortController().signal),
    "INTERNAL_ERROR",
  );
});
