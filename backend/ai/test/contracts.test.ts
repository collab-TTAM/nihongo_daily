import { test } from "node:test";
import assert from "node:assert/strict";
import { contracts, fixtures } from "./support.ts";
import { operations, parseBounded } from "../src/contracts.ts";
for (const op of operations) {
  test(`${op} accepts frozen request/response fixtures`, () => {
    assert.deepEqual(
      contracts.request(op, fixtures[`${op}_request`]),
      fixtures[`${op}_request`],
    );
    assert.deepEqual(
      contracts.response(op, fixtures[`${op}_response`]),
      fixtures[`${op}_response`],
    );
  });
  test(`${op} rejects owner/unknown fields in either direction`, () => {
    assert.throws(() =>
      contracts.request(op, {
        ...(fixtures[`${op}_request`] as object),
        user_id: "forged",
      }),
    );
    assert.throws(() =>
      contracts.response(op, {
        ...(fixtures[`${op}_response`] as object),
        user_id: "forged",
      }),
    );
    assert.throws(() => contracts.response(op, { error: "secret" }));
  });
}
test("no coercion/stripping/defaults and bounded unique context", () => {
  const request = structuredClone(fixtures.tutor_explain_request) as Record<
    string,
    unknown
  >;
  request.context = { recent_grammar_ids: ["bad"], recent_vocabulary_ids: [] };
  assert.throws(() => contracts.request("tutor_explain", request));
  request.context = { recent_grammar_ids: [], recent_vocabulary_ids: [] };
  request.question_vi = "";
  assert.throws(() => contracts.request("tutor_explain", request));
  request.question_vi = "x".repeat(5001);
  assert.throws(() => contracts.request("tutor_explain", request));
  assert.throws(() =>
    contracts.request("correct_sentence", {
      jlpt_level: "N6",
      sentence_ja: "水",
    }),
  );
  assert.throws(() =>
    contracts.request("correct_sentence", {
      jlpt_level: "N5",
      sentence_ja: 10,
    }),
  );
});
test("provider role/UUID/nullable/score/nonfinite limits are strict", () => {
  const response = structuredClone(
    fixtures.conversation_turn_response,
  ) as Record<string, unknown>;
  const message = response.assistant_message as Record<string, unknown>;
  for (const [field, value] of [
    ["role", "user"],
    ["sequence_no", -1],
    ["id", "bad"],
    ["audio_ref", undefined],
  ]) {
    assert.throws(() =>
      contracts.response("conversation_turn", {
        ...response,
        assistant_message: { ...message, [String(field)]: value },
      }),
    );
  }
  const finish = fixtures.finish_conversation_response as object;
  for (const score of [-1, 101, NaN, Infinity, "100"]) {
    assert.throws(() =>
      contracts.response("finish_conversation", {
        ...finish,
        scores: { grammar: score, vocabulary: 100, fluency: 100 },
      }),
    );
  }
});
test("UTF-8 byte limits and malformed JSON", () => {
  assert.throws(() => parseBounded("あ".repeat(4), 8, "VALIDATION_FAILURE"));
  assert.throws(() => parseBounded("{broken", 100, "VALIDATION_FAILURE"));
  assert.deepEqual(parseBounded("{}", 2, "VALIDATION_FAILURE"), {});
});
