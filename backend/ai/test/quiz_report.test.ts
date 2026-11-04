import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { BoundaryError } from "../src/contracts.ts";
import { createQuizReportDecoder } from "../src/quiz_report.ts";

const root = new URL("../../../contracts/quiz/v1/", import.meta.url);
const schema = JSON.parse(readFileSync(new URL("schema.json", root), "utf8"));
const fixtures = JSON.parse(
  readFileSync(new URL("fixtures.json", root), "utf8"),
);
const decode = createQuizReportDecoder(schema);
const encode = (value: unknown) =>
  new TextEncoder().encode(JSON.stringify(value));
const fresh = () => structuredClone(fixtures[0].request);
const invalid = (raw: Uint8Array) =>
  assert.throws(
    () => decode(raw),
    (error: unknown) =>
      error instanceof BoundaryError &&
      error.code === "VALIDATION_FAILURE" &&
      error.message === "VALIDATION_FAILURE",
  );

test("quiz decoder preserves all canonical fixtures", () => {
  for (const fixture of fixtures)
    assert.deepEqual(decode(encode(fixture.request)), fixture.request);
});
test("quiz decoder rejects unknown/missing fields and coercion", () => {
  for (const field of Object.keys(fresh())) {
    const value = fresh();
    delete value[field];
    invalid(encode(value));
  }
  invalid(encode({ ...fresh(), user_id: "PRIVATE TOKEN" }));
  for (const version of [true, "1", 0, 2147483648]) {
    const value = fresh();
    value.answers[0].content_version = version;
    invalid(encode(value));
  }
  const value = fresh();
  value.answers[0].metadata = "PRIVATE SQL";
  invalid(encode(value));
});
test("quiz decoder rejects repeated targets and invalid choices", () => {
  const repeated = fresh();
  repeated.answers.push(structuredClone(repeated.answers[0]));
  invalid(encode(repeated));
  for (const field of ["item_id", "selected_id"]) {
    const value = fresh();
    value.answers[0][field] = "ffffffff-ffff-4fff-8fff-ffffffffffff";
    invalid(encode(value));
  }
  const value = fresh();
  value.answers[0].choices[1] = value.answers[0].choices[0];
  invalid(encode(value));
  for (const answers of [[], Array(11).fill(fresh().answers[0])])
    invalid(encode({ ...fresh(), answers }));
});
test("quiz decoder enforces kind and real UTC calendar", () => {
  for (const practice_kind of ["primary", "correction"])
    invalid(
      encode({ ...fresh(), quiz_type: "vocabulary_reading", practice_kind }),
    );
  invalid(
    encode({ ...fresh(), quiz_type: "grammar_meaning", practice_kind: null }),
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
  ])
    invalid(encode({ ...fresh(), completed_at }));
  const completed_at = "2024-02-29T23:59:59.000001Z";
  assert.equal(
    decode(encode({ ...fresh(), completed_at })).completed_at,
    completed_at,
  );
});
test("quiz decoder applies raw guard before schema", () => {
  const raw = JSON.stringify(fresh());
  for (const text of [
    raw + "{}",
    raw.replace('"content_version":1', '"content_version":1e0'),
    raw.replace(
      '"content_version":1',
      '"content_version":1,"content_version":1',
    ),
  ]) {
    assert.notEqual(text, raw);
    invalid(new TextEncoder().encode(text));
  }
  invalid(new Uint8Array([255]));
  invalid(new Uint8Array(16385));
});
test("quiz decoder freezes nested identity without raw byte aliases", () => {
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
  }
  assert.equal(Reflect.set(result.answers[0]!.choices, "0", "changed"), false);
  assert.deepEqual(result, expected);
});

test("quiz decoder refuses an asynchronous schema at construction", () => {
  assert.throws(
    () => createQuizReportDecoder({ ...schema, $async: true }),
    /Quiz schema must be synchronous/,
  );
});
