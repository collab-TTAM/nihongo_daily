import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { BoundaryError } from "../src/contracts.ts";
import {
  createQuizReportV2Decoder,
  createQuizReportV2ResponseDecoder,
  type QuizReportV2Request,
  type QuizReportV2Response,
} from "../src/quiz_report_v2.ts";

interface Fixture {
  readonly name: string;
  readonly request: QuizReportV2Request;
  readonly response: QuizReportV2Response;
}

interface MutableAnswer {
  item_id: string;
  content_version: number;
  selected_id: string;
  choices: string[];
  choice_content_versions: number[];
}

interface MutableRequest {
  client_event_id: string;
  quiz_type: "vocabulary_reading" | "grammar_meaning";
  practice_kind: null | "primary" | "correction";
  jlpt_level: "N5" | "N4";
  completed_at: string;
  answers: MutableAnswer[];
}

const root = new URL("../../../contracts/quiz/v2/", import.meta.url);
const schema = JSON.parse(
  readFileSync(new URL("schema.json", root), "utf8"),
) as Record<string, unknown>;
const fixtures = JSON.parse(
  readFileSync(new URL("fixtures.json", root), "utf8"),
) as Fixture[];
const decode = createQuizReportV2Decoder(schema);
const encode = (value: unknown) =>
  new TextEncoder().encode(JSON.stringify(value));
const fresh = () =>
  structuredClone(fixtures[0]!.request) as unknown as MutableRequest;

const invalid = (raw: Uint8Array) =>
  assert.throws(
    () => decode(raw),
    (error: unknown) =>
      error instanceof BoundaryError &&
      error.code === "VALIDATION_FAILURE" &&
      error.message === "VALIDATION_FAILURE",
  );

const invalidResponse = (
  response: (raw: Uint8Array) => QuizReportV2Response,
  raw: Uint8Array,
) =>
  assert.throws(
    () => response(raw),
    (error: unknown) =>
      error instanceof BoundaryError &&
      error.code === "INTERNAL_ERROR" &&
      error.message === "INTERNAL_ERROR",
  );

test("quiz v2 decoder preserves every canonical fixture and target version slot", () => {
  for (const fixture of fixtures) {
    assert.deepEqual(decode(encode(fixture.request)), fixture.request);
  }
});

test("quiz v2 decoder rejects unknown fields and invalid choice versions", () => {
  for (const field of Object.keys(fresh())) {
    const value = fresh() as unknown as Record<string, unknown>;
    delete value[field];
    invalid(encode(value));
  }
  invalid(encode({ ...fresh(), user_id: "PRIVATE TOKEN" }));

  for (const version of [true, "1", 0, 1.5, 2147483648]) {
    const value = fresh();
    value.answers[0]!.choice_content_versions[0] = version as number;
    invalid(encode(value));
  }

  const targetMismatch = fresh();
  const targetIndex = targetMismatch.answers[0]!.choices.indexOf(
    targetMismatch.answers[0]!.item_id,
  );
  targetMismatch.answers[0]!.choice_content_versions[targetIndex] = 2;
  invalid(encode(targetMismatch));
});

test("quiz v2 decoder rejects duplicate targets, choices and unoffered selections", () => {
  const repeated = fresh();
  repeated.answers.push(structuredClone(repeated.answers[0]!));
  invalid(encode(repeated));

  const duplicateChoice = fresh();
  duplicateChoice.answers[0]!.choices[1] =
    duplicateChoice.answers[0]!.choices[0]!;
  invalid(encode(duplicateChoice));

  const missingTarget = fresh();
  missingTarget.answers[0]!.choices[0] =
    "ffffffff-ffff-4fff-8fff-ffffffffffff";
  invalid(encode(missingTarget));

  const unofferedSelection = fresh();
  unofferedSelection.answers[0]!.selected_id =
    "ffffffff-ffff-4fff-8fff-ffffffffffff";
  invalid(encode(unofferedSelection));
});

test("quiz v2 decoder enforces quiz-kind and real UTC calendar", () => {
  for (const practice_kind of ["primary", "correction"] as const) {
    invalid(
      encode({
        ...fresh(),
        quiz_type: "vocabulary_reading",
        practice_kind,
      }),
    );
  }
  invalid(
    encode({
      ...fresh(),
      quiz_type: "grammar_meaning",
      practice_kind: null,
    }),
  );

  for (const completed_at of [
    "2025-02-29T00:00:00Z",
    "2100-02-29T00:00:00Z",
    "2026-04-31T00:00:00Z",
    "2026-01-01T24:00:00Z",
    "2026-01-01T23:59:60Z",
    "2026-01-01T00:00:00+00:00",
    "2026-01-01T00:00:00.1234567Z",
    "2026-01-01T00:00:00Z\n",
  ]) {
    invalid(encode({ ...fresh(), completed_at }));
  }

  const completed_at = "2024-02-29T23:59:59.000001Z";
  assert.equal(
    decode(encode({ ...fresh(), completed_at })).completed_at,
    completed_at,
  );
});

test("quiz v2 decoder rejects raw duplicate keys, fractional/exponent numbers and invalid UTF-8", () => {
  const raw = JSON.stringify(fresh());
  const changed = [
    raw.replace(
      '"content_version":1',
      '"content_version":1,"content_version":1',
    ),
    raw.replace('"content_version":1', '"content_version":1.0'),
    raw.replace('"content_version":1', '"content_version":1e0'),
    raw.replace('"choice_content_versions":[1', '"choice_content_versions":[1e0'),
    raw + "{}",
  ];
  for (const text of changed) {
    assert.notEqual(text, raw);
    invalid(new TextEncoder().encode(text));
  }
  invalid(new Uint8Array([255]));
  invalid(new Uint8Array(16385));
});

test("quiz v2 decoder freezes nested choices and versions without raw aliases", () => {
  const expected = fresh();
  const raw = encode(expected);
  const result = decode(raw);
  raw.fill(0);
  assert.deepEqual(result, expected);
  assert.ok(Object.isFrozen(result));
  assert.ok(Object.isFrozen(result.answers));
  for (const answer of result.answers) {
    assert.ok(Object.isFrozen(answer));
    assert.ok(Object.isFrozen(answer.choices));
    assert.ok(Object.isFrozen(answer.choice_content_versions));
    assert.equal(
      Reflect.set(answer.choice_content_versions, "0", 99),
      false,
    );
  }
  assert.deepEqual(result, expected);
});

test("quiz v2 decoder refuses an asynchronous schema", () => {
  assert.throws(
    () => createQuizReportV2Decoder({ ...schema, $async: true }),
    /Quiz v2 schema must be synchronous/,
  );
});

test("quiz v2 response decoder correlates canonical fixtures and freezes output", () => {
  for (const fixture of fixtures) {
    const request = encode(fixture.request);
    const response = createQuizReportV2ResponseDecoder(schema, request);
    request.fill(0);
    const result = response(encode(fixture.response));
    assert.deepEqual(result, fixture.response);
    assert.ok(Object.isFrozen(result));
    assert.equal(Reflect.set(result, "correct_count", 99), false);
  }
});

test("quiz v2 response rejects mismatched identity and counts", () => {
  const fixture = fixtures[0]!;
  const response = createQuizReportV2ResponseDecoder(
    schema,
    encode(fixture.request),
  );
  const changes: Array<[string, unknown]> = [
    ["client_event_id", "ffffffff-ffff-4fff-8fff-ffffffffffff"],
    ["quiz_type", "grammar_meaning"],
    ["practice_kind", "primary"],
    ["jlpt_level", "N4"],
    [
      "completed_at",
      fixture.response.completed_at.replace(".000001Z", ".000002Z"),
    ],
    ["answer_count", 2],
    ["correct_count", 1],
  ];
  for (const [key, value] of changes) {
    assert.notEqual(value, fixture.response[key as keyof QuizReportV2Response]);
    invalidResponse(response, encode({ ...fixture.response, [key]: value }));
  }
});

test("quiz v2 response applies the same raw JSON guard", () => {
  const fixture = fixtures[0]!;
  const response = createQuizReportV2ResponseDecoder(
    schema,
    encode(fixture.request),
  );
  const raw = JSON.stringify(fixture.response);
  const changed = [
    raw.replace('"answer_count":1', '"answer_count":1e0'),
    raw.replace('"answer_count":1', '"answer_count":1,"answer_count":1'),
    raw + "{}",
  ];
  for (const text of changed) {
    assert.notEqual(text, raw);
    invalidResponse(response, new TextEncoder().encode(text));
  }
  invalidResponse(response, new Uint8Array([255]));
  invalidResponse(response, new Uint8Array(16385));
});

test("quiz v2 response decoder validates the request before response use", () => {
  assert.throws(
    () =>
      createQuizReportV2ResponseDecoder(
        schema,
        encode({ ...fresh(), user_id: "forged" }),
      ),
    (error: unknown) =>
      error instanceof BoundaryError &&
      error.code === "VALIDATION_FAILURE",
  );
});
