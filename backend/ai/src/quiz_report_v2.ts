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

export type QuizReportV2LookupResponse =
  | { readonly status: "found"; readonly response: QuizReportV2Response }
  | { readonly status: "unresolved"; readonly client_event_id: string };

function createValidator<T>(
  schema: AnySchemaObject,
  reference: "#/$defs/request" | "#/$defs/response" | "#/$defs/lookup_response",
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
function correlateQuizReportV2Response(
  request: QuizReportV2Request,
  response: QuizReportV2Response,
): QuizReportV2Response {
  const identity = [
    "client_event_id",
    "quiz_type",
    "practice_kind",
    "jlpt_level",
    "completed_at",
  ] as const;
  const correct = request.answers.filter(
    (answer) => answer.item_id === answer.selected_id,
  ).length;
  if (
    identity.some((key) => response[key] !== request[key]) ||
    response.answer_count !== request.answers.length ||
    response.correct_count !== correct
  ) {
    throw new Error();
  }
  return Object.freeze(response);
}

/**
 * Correlate a strict submit response to the immutable raw request.
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

  return (raw: Uint8Array): QuizReportV2Response => {
    try {
      const decoded = parseQuizReportJsonBody(raw);
      if (validate(decoded) !== true) throw new Error();
      return correlateQuizReportV2Response(
        request,
        decoded as unknown as QuizReportV2Response,
      );
    } catch {
      throw new BoundaryError("INTERNAL_ERROR");
    }
  };
}

/**
 * Decode the internal receipt-lookup union against the original immutable
 * request. An unresolved result is deliberately not a negative acknowledgement.
 */
export function createQuizReportV2LookupResponseDecoder(
  schema: AnySchemaObject,
  requestRaw: Uint8Array,
) {
  const request = createQuizReportV2Decoder(schema)(requestRaw);
  const validate = createValidator<QuizReportV2LookupResponse>(
    schema,
    "#/$defs/lookup_response",
  );

  return (raw: Uint8Array): QuizReportV2LookupResponse => {
    try {
      const decoded = parseQuizReportJsonBody(raw);
      if (validate(decoded) !== true) throw new Error();
      const lookup = decoded as unknown as QuizReportV2LookupResponse;
      if (lookup.status === "unresolved") {
        if (lookup.client_event_id !== request.client_event_id) {
          throw new Error();
        }
        return Object.freeze({
          status: "unresolved",
          client_event_id: request.client_event_id,
        });
      }
      return Object.freeze({
        status: "found",
        response: correlateQuizReportV2Response(request, lookup.response),
      });
    } catch {
      throw new BoundaryError("INTERNAL_ERROR");
    }
  };
}
