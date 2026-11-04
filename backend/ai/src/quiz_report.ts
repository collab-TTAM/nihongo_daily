import { Ajv2020 } from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import type { AnySchemaObject } from "ajv";
import { BoundaryError } from "./contracts.ts";
import { parseQuizReportJsonBody } from "./strict_json.ts";

export interface QuizReportAnswer {
  readonly item_id: string;
  readonly content_version: number;
  readonly selected_id: string;
  readonly choices: readonly string[];
}
export interface QuizReportRequest {
  readonly client_event_id: string;
  readonly quiz_type: "vocabulary_reading" | "grammar_meaning";
  readonly practice_kind: null | "primary" | "correction";
  readonly jlpt_level: "N5" | "N4";
  readonly completed_at: string;
  readonly answers: readonly QuizReportAnswer[];
}

/** The caller supplies the trusted repository schema, never learner input.
 * Decoding confers no Auth, current-content or receipt/replay authority.
 */
export function createQuizReportDecoder(schema: AnySchemaObject) {
  const ajv = new Ajv2020({
    strict: true,
    allErrors: false,
    coerceTypes: false,
    useDefaults: false,
    removeAdditional: false,
    strictNumbers: true,
  });
  addFormats.default(ajv);
  const validate = ajv.compile<QuizReportRequest>({
    ...structuredClone(schema),
    $ref: "#/$defs/request",
  });
  if ("$async" in validate) throw new Error("Quiz schema must be synchronous");
  return (raw: Uint8Array): QuizReportRequest => {
    try {
      const decoded = parseQuizReportJsonBody(raw);
      if (validate(decoded) !== true) throw new Error();
      const request = decoded as unknown as QuizReportRequest;
      // Reject calendar overflow/leap seconds but retain exact microsecond text.
      const instant = new Date(request.completed_at);
      if (
        !Number.isFinite(instant.getTime()) ||
        instant.toISOString().slice(0, 19) !== request.completed_at.slice(0, 19)
      )
        throw new Error();
      const targets = new Set<string>();
      for (const answer of request.answers) {
        if (
          targets.has(answer.item_id) ||
          !answer.choices.includes(answer.item_id) ||
          !answer.choices.includes(answer.selected_id)
        )
          throw new Error();
        targets.add(answer.item_id);
        Object.freeze(answer.choices);
        Object.freeze(answer);
      }
      Object.freeze(request.answers);
      return Object.freeze(request);
    } catch {
      throw new BoundaryError("VALIDATION_FAILURE");
    }
  };
}

export interface QuizReportResponse extends Omit<QuizReportRequest, "answers"> {
  readonly answer_count: number;
  readonly correct_count: number;
}

/** Bind response validation to a validated snapshot before asynchronous I/O.
 * A matching response is not proof of persistence, ownership or retry authority.
 */
export function createQuizReportResponseDecoder(
  schema: AnySchemaObject,
  requestRaw: Uint8Array,
) {
  const request = createQuizReportDecoder(schema)(requestRaw);
  const ajv = new Ajv2020({
    strict: true,
    allErrors: false,
    coerceTypes: false,
    useDefaults: false,
    removeAdditional: false,
    strictNumbers: true,
  });
  addFormats.default(ajv);
  const validate = ajv.compile<QuizReportResponse>({
    ...structuredClone(schema),
    $ref: "#/$defs/response",
  });
  if ("$async" in validate) throw new Error("Quiz schema must be synchronous");
  const correct = request.answers.filter(
    (a) => a.item_id === a.selected_id,
  ).length;
  const identity = [
    "client_event_id",
    "quiz_type",
    "practice_kind",
    "jlpt_level",
    "completed_at",
  ] as const;
  return (raw: Uint8Array): QuizReportResponse => {
    try {
      const decoded = parseQuizReportJsonBody(raw);
      if (validate(decoded) !== true) throw new Error();
      const response = decoded as unknown as QuizReportResponse;
      if (
        identity.some((key) => response[key] !== request[key]) ||
        response.answer_count !== request.answers.length ||
        response.correct_count !== correct
      )
        throw new Error();
      return Object.freeze(response);
    } catch {
      throw new BoundaryError("INTERNAL_ERROR");
    }
  };
}
