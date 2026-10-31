import { test } from "node:test";
import assert from "node:assert/strict";
import { BoundaryError, parseBounded } from "../src/contracts.ts";
import {
  MAX_QUIZ_REPORT_BYTES,
  parseQuizReportJsonBody,
  parseStrictJson,
} from "../src/strict_json.ts";

const encode = (value: string): Uint8Array => new TextEncoder().encode(value);

function quizReport() {
  return {
    client_event_id: "a3000000-0000-4000-8000-000000000001",
    quiz_type: "vocabulary_reading",
    practice_kind: null,
    jlpt_level: "N5",
    completed_at: "2026-10-31T00:00:00.000001Z",
    answers: [
      {
        item_id: "a2000000-0000-4000-8000-000000000001",
        content_version: 1,
        selected_id: "a2000000-0000-4000-8000-000000000001",
        choices: [
          "a2000000-0000-4000-8000-000000000001",
          "a2000000-0000-4000-8000-000000000002",
          "a2000000-0000-4000-8000-000000000003",
          "a2000000-0000-4000-8000-000000000004",
        ],
      },
    ],
  };
}

test("strict JSON rejects duplicate members at every depth and decoded aliases", () => {
  const slash = String.fromCharCode(92);
  const cases = [
    '{"item":1,"item":2}',
    '{"outer":{"item":1,"item":2}}',
    '{"item":1,"' + slash + 'u0069tem":2}',
    '{"items":[{"value":1,"value":2}]}',
  ];
  for (const raw of cases) {
    assert.throws(() => parseStrictJson(raw), /^Error: Invalid JSON body$/);
  }
});

test("strict JSON preserves generic JSON number semantics", () => {
  assert.deepEqual(
    parseStrictJson('{"fraction":1.25,"exponent":1e0}'),
    { fraction: 1.25, exponent: 1 },
  );
  assert.throws(
    () => parseStrictJson('{"overflow":1e400}'),
    /^Error: Invalid JSON body$/,
  );
});

test("strict JSON rejects malformed, trailing and over-deep documents", () => {
  const cases = [
    '{"item":',
    '{"item":1} trailing',
    '{"item":NaN}',
    '{"item":01}',
    "[".repeat(66) + "0" + "]".repeat(66),
  ];
  for (const raw of cases) {
    assert.throws(() => parseStrictJson(raw), /^Error: Invalid JSON body$/);
  }
});

test("AI bounded decoder maps duplicate-member failures to its fixed error", () => {
  assert.throws(
    () => parseBounded('{"event":"a","event":"b"}', 128, "VALIDATION_FAILURE"),
    (error: unknown) =>
      error instanceof BoundaryError &&
      error.code === "VALIDATION_FAILURE",
  );
});

test("quiz raw body accepts a valid bounded UTF-8 object", () => {
  const expected = quizReport();
  const raw = encode(JSON.stringify(expected));
  assert.deepEqual(parseQuizReportJsonBody(raw), expected);
});

test("quiz raw body accepts exactly 16 KiB and rejects the next byte", () => {
  const expected = quizReport();
  const raw = JSON.stringify(expected);
  const exact = raw.padEnd(MAX_QUIZ_REPORT_BYTES, " ");
  assert.equal(encode(exact).byteLength, MAX_QUIZ_REPORT_BYTES);
  assert.deepEqual(parseQuizReportJsonBody(encode(exact)), expected);
  assert.throws(
    () => parseQuizReportJsonBody(encode(exact + " ")),
    /^Error: Invalid quiz request body$/,
  );
});

test("quiz raw body rejects exponent and fractional number lexemes", () => {
  const raw = JSON.stringify(quizReport());
  for (const lexeme of ["1.0", "1e0", "1E+0"]) {
    const changed = raw.replace(
      '"content_version":1',
      '"content_version":' + lexeme,
    );
    assert.notEqual(changed, raw);
    assert.throws(
      () => parseQuizReportJsonBody(encode(changed)),
      /^Error: Invalid quiz request body$/,
    );
  }
});

test("quiz raw body rejects duplicate and escaped-alias members", () => {
  const slash = String.fromCharCode(92);
  const raw = JSON.stringify(quizReport());
  const duplicate = raw.replace(
    '"content_version":1',
    '"content_version":1,"content_version":1',
  );
  const escaped = raw.replace(
    '"content_version":1',
    '"content_version":1,"content_' + slash + 'u0076ersion":1',
  );
  for (const changed of [duplicate, escaped]) {
    assert.notEqual(changed, raw);
    assert.throws(
      () => parseQuizReportJsonBody(encode(changed)),
      /^Error: Invalid quiz request body$/,
    );
  }
});

test("quiz raw body rejects invalid UTF-8, BOM, non-object and trailing JSON", () => {
  const raw = JSON.stringify(quizReport());
  const cases = [
    new Uint8Array([0xff, 0x28]),
    encode(String.fromCharCode(0xfeff) + raw),
    encode("[]"),
    encode("null"),
    encode(raw + "{}"),
  ];
  for (const body of cases) {
    assert.throws(
      () => parseQuizReportJsonBody(body),
      /^Error: Invalid quiz request body$/,
    );
  }
});
