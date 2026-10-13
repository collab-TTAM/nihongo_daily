import { Ajv2020 } from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import type { ValidateFunction, AnySchemaObject } from "ajv";
import type * as Wire from "./wire.ts";

export const operations = [
  "tutor_explain",
  "correct_sentence",
  "start_conversation",
  "conversation_turn",
  "finish_conversation",
] as const;
export type Operation = (typeof operations)[number];
export type Mutation = Exclude<Operation, "tutor_explain" | "correct_sentence">;
export type Requests = {
  tutor_explain: Wire.tutor_explain_request;
  correct_sentence: Wire.correct_sentence_request;
  start_conversation: Wire.start_conversation_request;
  conversation_turn: Wire.conversation_turn_request;
  finish_conversation: Wire.finish_conversation_request;
};
export type Responses = {
  tutor_explain: Wire.tutor_explain_response;
  correct_sentence: Wire.correct_sentence_response;
  start_conversation: Wire.start_conversation_response;
  conversation_turn: Wire.conversation_turn_response;
  finish_conversation: Wire.finish_conversation_response;
};
export function isMutation(op: Operation): op is Mutation {
  return op !== "tutor_explain" && op !== "correct_sentence";
}

export class BoundaryError extends Error {
  readonly code: Wire.error["code"];
  constructor(code: Wire.error["code"]) {
    super(code);
    this.code = code;
  }
}

/** No stripping unknown fields, coercion, defaults or remote schema resolution. */
export class Contracts {
  private readonly validators = new Map<string, ValidateFunction>();
  constructor(schema: AnySchemaObject) {
    const ajv = new Ajv2020({
      strict: true,
      allErrors: false,
      coerceTypes: false,
      useDefaults: false,
      removeAdditional: false,
      strictNumbers: true,
    });
    addFormats.default(ajv);
    for (const operation of operations) {
      for (const direction of ["request", "response"]) {
        const model = `${operation}_${direction}`;
        const selected = {
          ...schema,
          $id: `urn:nihongo:ai:${model}`,
          $ref: `#/$defs/${model}`,
        };
        this.validators.set(model, ajv.compile(selected));
      }
    }
  }
  request<O extends Operation>(op: O, value: unknown): Requests[O] {
    return this.check(
      `${op}_request`,
      value,
      "VALIDATION_FAILURE",
    ) as Requests[O];
  }
  response<O extends Operation>(op: O, value: unknown): Responses[O] {
    return this.check(
      `${op}_response`,
      value,
      "PROVIDER_UNAVAILABLE",
    ) as Responses[O];
  }
  private check(
    name: string,
    value: unknown,
    code: Wire.error["code"],
  ): unknown {
    if (!this.validators.get(name)?.(value)) throw new BoundaryError(code);
    return value;
  }
}

export const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function parseBounded(
  text: string,
  maxBytes: number,
  code: Wire.error["code"],
): unknown {
  if (new TextEncoder().encode(text).byteLength > maxBytes)
    throw new BoundaryError(code);
  try {
    return JSON.parse(text) as unknown;
  } catch {
    throw new BoundaryError(code);
  }
}
