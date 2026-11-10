import { Ajv2020 } from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import type { AnySchemaObject } from "ajv";
import { BoundaryError } from "./contracts.ts";
import { parseQuizReportJsonBody } from "./strict_json.ts";

export interface QuizReportV2Answer {
  readonly item_id: string;
  readonly content_version: number;
  readonly selected_id: string;
  readonly choices: readonly string[];
  readonly choice_content_versions: readonly number[];
}

export interface QuizReportV2Request {
  readonly client_event_id: string;
  readonly quiz_type: "vocabulary_reading" | "grammar_meaning";
  readonly practice_kind: null | "primary" | "correction";
  readonly jlpt_level: "N5" | "N4";
  readonly completed_at: string;
  readonly answers: readonly QuizReportV2Answer[];
}

export interface QuizReportV2Response
  extends Omit<QuizReportV2Request, "answers"> {
  readonly answer_count: number;
  readonly correct_count: number;
}

function createValidator<T>(
  schema: AnySchemaObject,
  reference: "#/$defs/request" | "#/$defs/response",
) {
  const ajv = new Ajv2020({
    strict: true,
    allErrors: false,
    coerceTypes: false,
    useDefaults: false,
    removeAdditional: false,
    strictNumbers: true,
  });
  addFormats.default(ajv);
  const validate = ajv.compile<T>({
    ...structuredClone(schema),
    $ref: reference,
  });
  if ("$async" in validate) {
    throw new Error("Quiz v2 schema must be synchronous");
  }
  return validate;
}

/**
 * Decode raw nd-quiz-report-2 bytes before any JSONB conversion.
 * This grants no Auth, current-content, transaction or persistence authority.
 */
export function createQuizReportV2Decoder(schema: AnySchemaObject) {
  const validate = createValidator<QuizReportV2Request>(
    schema,
    "#/$defs/request",
  );
  return (raw: Uint8Array): QuizReportV2Request => {
    try {
      const decoded = parseQuizReportJsonBody(raw);
      if (validate(decoded) !== true) throw new Error();
      const request = decoded as unknown as QuizReportV2Request;
      const instant = new Date(request.completed_at);
      if (
        !Number.isFinite(instant.getTime()) ||
        instant.toISOString().slice(0, 19) !== request.completed_at.slice(0, 19)
      ) {
        throw new Error();
      }

      const targets = new Set<string>();
      for (const answer of request.answers) {
        const targetIndex = answer.choices.indexOf(answer.item_id);
        if (
          targets.has(answer.item_id) ||
          targetIndex < 0 ||
          !answer.choices.includes(answer.selected_id) ||
          answer.choice_content_versions[targetIndex] !== answer.content_version
        ) {
          throw new Error();
        }
        targets.add(answer.item_id);
        Object.freeze(answer.choices);
        Object.freeze(answer.choice_content_versions);
        Object.freeze(answer);
      }
      Object.freeze(request.answers);
      return Object.freeze(request);
    } catch {
      throw new BoundaryError("VALIDATION_FAILURE");
    }
  };
}

/**
 * Correlate a strict response to the immutable raw request before accepting it.
 * A matching response is not proof of Auth ownership or durable persistence.
 */
export function createQuizReportV2ResponseDecoder(
  schema: AnySchemaObject,
  requestRaw: Uint8Array,
) {
  const request = createQuizReportV2Decoder(schema)(requestRaw);
  const validate = createValidator<QuizReportV2Response>(
    schema,
    "#/$defs/response",
  );
  const correct = request.answers.filter(
    (answer) => answer.item_id === answer.selected_id,
  ).length;
  const identity = [
    "client_event_id",
    "quiz_type",
    "practice_kind",
    "jlpt_level",
    "completed_at",
  ] as const;

  return (raw: Uint8Array): QuizReportV2Response => {
    try {
      const decoded = parseQuizReportJsonBody(raw);
      if (validate(decoded) !== true) throw new Error();
      const response = decoded as unknown as QuizReportV2Response;
      if (
        identity.some((key) => response[key] !== request[key]) ||
        response.answer_count !== request.answers.length ||
        response.correct_count !== correct
      ) {
        throw new Error();
      }
      return Object.freeze(response);
    } catch {
      throw new BoundaryError("INTERNAL_ERROR");
    }
  };
}
