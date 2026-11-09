import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { BoundaryError } from "../src/contracts.ts";
import {
  validateCurrentQuizReportContentV2,
  type QuizReportContentV2Query,
  type QuizReportV2Request,
} from "../src/quiz_report_content_v2.ts";
import type { PostgresResult } from "../src/postgres_connection.ts";

const root = new URL("../../../contracts/quiz/v2/", import.meta.url);
const fixtures = JSON.parse(readFileSync(new URL("fixtures.json", root), "utf8")) as Array<{
  request: QuizReportV2Request;
}>;
const vocabulary = fixtures[0]!.request;
const grammarPrimary = fixtures[1]!.request;
const grammarCorrection = fixtures[2]!.request;

type MutableQuizReportV2Request = Omit<QuizReportV2Request, "answers"> & {
  answers: Array<{
    item_id: string;
    content_version: number;
    selected_id: string;
    choices: string[];
    choice_content_versions: number[];
  }>;
};

function rowsFor(
  request: QuizReportV2Request,
  grammar = false,
): Record<string, unknown>[] {
  const answer = request.answers[0]!;
  return answer.choices.map((id, index) => ({
    id,
    source_ordinal: index,
    content_version: answer.choice_content_versions[index],
    heading: grammar ? `文法項目${index}` : `日本語項目${index}`,
    ...(grammar
      ? { meaning_vi: `Nghĩa ${index}` }
      : { reading: `よみ${index}` }),
  }));
}

function queryFor(rows: Record<string, unknown>[]) {
  const calls: Array<{ sql: string; values?: string[] }> = [];
  const query: QuizReportContentV2Query = async (sql, values) => {
    calls.push({ sql, values });
    return {
      command: "SELECT",
      rowCount: rows.length,
      rows,
    } satisfies PostgresResult;
  };
  return { query, calls };
}

function copyRequest(request: QuizReportV2Request): MutableQuizReportV2Request {
  return structuredClone(request) as MutableQuizReportV2Request;
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

test("accepts exact vocabulary source order and displayed versions", async () => {
  const { query, calls } = queryFor(rowsFor(vocabulary));
  await validateCurrentQuizReportContentV2(
    query,
    vocabulary,
    new AbortController().signal,
  );
  assert.equal(calls.length, 1);
  assert.match(calls[0]!.sql, /source_ordinal/);
  assert.match(calls[0]!.sql, /ORDER BY source_ordinal ASC NULLS LAST, id/);
  assert.deepEqual(calls[0]!.values, ["N5"]);
});

test("accepts N4 reports with the same per-level source ordinal contract", async () => {
  const n4Request: QuizReportV2Request = {
    ...vocabulary,
    jlpt_level: "N4",
  };
  const { query, calls } = queryFor(rowsFor(n4Request));
  await validateCurrentQuizReportContentV2(
    query,
    n4Request,
    new AbortController().signal,
  );
  assert.deepEqual(calls[0]!.values, ["N4"]);
});

test("accepts grammar primary and correction in exact source order", async () => {
  for (const request of [grammarPrimary, grammarCorrection]) {
    const { query } = queryFor(rowsFor(request, true));
    await validateCurrentQuizReportContentV2(
      query,
      request,
      new AbortController().signal,
    );
  }
});

test("rejects reordered choice slots even when all IDs and versions are valid", async () => {
  const request = copyRequest(vocabulary);
  request.answers[0]!.choices.reverse();
  request.answers[0]!.choice_content_versions.reverse();
  const { query } = queryFor(rowsFor(vocabulary));
  await rejectsCode(
    validateCurrentQuizReportContentV2(
      query,
      request,
      new AbortController().signal,
    ),
    "VALIDATION_FAILURE",
  );
});

test("rejects a target moved away from its deterministic source slot", async () => {
  const request = copyRequest(vocabulary);
  const answer = request.answers[0]!;
  answer.choices = [
    answer.choices[1]!,
    answer.choices[0]!,
    answer.choices[2]!,
    answer.choices[3]!,
  ];
  const { query } = queryFor(rowsFor(vocabulary));
  await rejectsCode(
    validateCurrentQuizReportContentV2(
      query,
      request,
      new AbortController().signal,
    ),
    "VALIDATION_FAILURE",
  );
});

test("rejects stale target or distractor content versions", async () => {
  const targetRows = rowsFor(vocabulary);
  targetRows[0] = { ...targetRows[0]!, content_version: 2 };
  const targetQuery = queryFor(targetRows);
  await rejectsCode(
    validateCurrentQuizReportContentV2(
      targetQuery.query,
      vocabulary,
      new AbortController().signal,
    ),
    "VALIDATION_FAILURE",
  );

  const distractorRows = rowsFor(vocabulary);
  distractorRows[1] = { ...distractorRows[1]!, content_version: 2 };
  const distractorQuery = queryFor(distractorRows);
  await rejectsCode(
    validateCurrentQuizReportContentV2(
      distractorQuery.query,
      vocabulary,
      new AbortController().signal,
    ),
    "VALIDATION_FAILURE",
  );
});

test("rejects missing, duplicate and non-monotonic source ordinals", async () => {
  for (const mutate of [
    (rows: Record<string, unknown>[]) => {
      rows[0] = { ...rows[0]!, source_ordinal: null };
    },
    (rows: Record<string, unknown>[]) => {
      rows[1] = { ...rows[1]!, source_ordinal: 0 };
    },
    (rows: Record<string, unknown>[]) => rows.reverse(),
  ]) {
    const rows = rowsFor(vocabulary);
    mutate(rows);
    const { query } = queryFor(rows);
    await rejectsCode(
      validateCurrentQuizReportContentV2(
        query,
        vocabulary,
        new AbortController().signal,
      ),
      "INTERNAL_ERROR",
    );
  }
});

test("reconstructs first-occurrence duplicate readings without guessing by UUID", async () => {
  const ids = [
    "a2000000-0000-4000-8000-000000000001",
    "a2000000-0000-4000-8000-000000000002",
    "a2000000-0000-4000-8000-000000000003",
    "a2000000-0000-4000-8000-000000000004",
    "a2000000-0000-4000-8000-000000000005",
  ];
  const rows = [
    { id: ids[0]!, source_ordinal: 0, content_version: 1, heading: "日本語0", reading: "よみ0" },
    { id: ids[1]!, source_ordinal: 1, content_version: 1, heading: "日本語1", reading: "よみ1" },
    { id: ids[2]!, source_ordinal: 2, content_version: 1, heading: "日本語2", reading: "よみ1" },
    { id: ids[3]!, source_ordinal: 3, content_version: 1, heading: "日本語3", reading: "よみ2" },
    { id: ids[4]!, source_ordinal: 4, content_version: 1, heading: "日本語4", reading: "よみ3" },
  ];
  const request = copyRequest(vocabulary);
  request.answers[0]!.choices = [ids[0]!, ids[1]!, ids[3]!, ids[4]!];
  request.answers[0]!.choice_content_versions = [1, 1, 1, 1];
  const { query } = queryFor(rows);
  await validateCurrentQuizReportContentV2(
    query,
    request,
    new AbortController().signal,
  );
});

test("rejects duplicate headings and malformed active-content projections", async () => {
  const rows = rowsFor(vocabulary);
  rows[1] = { ...rows[1]!, heading: rows[0]!.heading };
  const { query } = queryFor(rows);
  await rejectsCode(
    validateCurrentQuizReportContentV2(
      query,
      vocabulary,
      new AbortController().signal,
    ),
    "VALIDATION_FAILURE",
  );

  const malformed = rowsFor(vocabulary);
  malformed[0] = { ...malformed[0]!, unexpected: "private" };
  const malformedQuery = queryFor(malformed);
  await rejectsCode(
    validateCurrentQuizReportContentV2(
      malformedQuery.query,
      vocabulary,
      new AbortController().signal,
    ),
    "INTERNAL_ERROR",
  );
});

test("aborted and failed content queries never expose private details", async () => {
  const controller = new AbortController();
  controller.abort();
  const stopped = queryFor(rowsFor(vocabulary));
  await rejectsCode(
    validateCurrentQuizReportContentV2(
      stopped.query,
      vocabulary,
      controller.signal,
    ),
    "NETWORK_UNAVAILABLE",
  );
  assert.equal(stopped.calls.length, 0);

  const query: QuizReportContentV2Query = async () => {
    throw new Error("PRIVATE DATABASE PASSWORD");
  };
  await rejectsCode(
    validateCurrentQuizReportContentV2(
      query,
      vocabulary,
      new AbortController().signal,
    ),
    "INTERNAL_ERROR",
  );
});
