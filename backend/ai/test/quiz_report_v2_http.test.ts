import { test } from "node:test";
import assert from "node:assert/strict";
import { BoundaryError } from "../src/contracts.ts";
import {
  createQuizReportV2HttpHandler,
  quizReportV2MaxRawBodyBytes,
} from "../src/quiz_report_v2_http.ts";
import type { QuizReportV2Submitter } from "../src/quiz_report_v2_host.ts";
import type { QuizReportV2Response } from "../src/quiz_report_v2.ts";

const encoder = new TextEncoder();
const rawBody = encoder.encode('{"duplicate":"first","duplicate":"second","jp":"あ"}');
const saved: QuizReportV2Response = {
  client_event_id: "e4200000-0000-4000-8000-000000000001",
  quiz_type: "vocabulary_reading",
  practice_kind: null,
  jlpt_level: "N5",
  completed_at: "2026-11-10T15:00:00Z",
  answer_count: 1,
  correct_count: 1,
};

function request(
  payload: BodyInit | null = rawBody,
  headers: Record<string, string> = {},
  signal?: AbortSignal,
  method = "POST",
): Request {
  const init: RequestInit & { duplex: "half" } = {
    method,
    body: payload,
    signal,
    headers: {
      "content-type": "application/json; charset=utf-8",
      authorization: "Bearer fixture-token",
      ...headers,
    },
    duplex: "half",
  };
  return new Request(
    "https://untrusted.invalid/quiz?user_id=forged",
    init,
  );
}

async function safeError(
  response: Response,
  status: number,
  code: string,
  retryable: boolean,
): Promise<void> {
  assert.equal(response.status, status);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
  if (status === 401) {
    assert.equal(response.headers.get("www-authenticate"), "Bearer");
  }
  const text = await response.text();
  assert.doesNotMatch(text, /PRIVATE|fixture-token|SQL TOKEN/);
  const value = JSON.parse(text);
  assert.deepEqual(Object.keys(value).sort(), [
    "code",
    "message_vi",
    "retryable",
  ]);
  assert.equal(value.code, code);
  assert.equal(value.retryable, retryable);
}

test("forwards exact raw bytes to the trusted submitter", async () => {
  let receivedToken: string | undefined;
  let receivedBytes: Uint8Array | undefined;
  let receivedSignal: AbortSignal | undefined;
  const submit: QuizReportV2Submitter = async (token, raw, signal) => {
    receivedToken = token;
    receivedBytes = raw.slice();
    receivedSignal = signal;
    return saved;
  };
  const handler = createQuizReportV2HttpHandler(submit);
  const chunks = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(rawBody.slice(0, 7));
      controller.enqueue(rawBody.slice(7, 19));
      controller.enqueue(rawBody.slice(19));
      controller.close();
    },
  });
  const response = await handler(
    request(chunks, { "content-length": String(rawBody.byteLength) }),
  );
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
  assert.deepEqual(await response.json(), saved);
  assert.equal(receivedToken, "fixture-token");
  assert.deepEqual(receivedBytes, rawBody);
  assert.equal(receivedSignal?.aborted, true);
});

test("rejects method, media type, encoding and bearer before submitter", async () => {
  let calls = 0;
  const handler = createQuizReportV2HttpHandler(async () => {
    calls++;
    return saved;
  });
  const cases: Array<[Request, number, string]> = [
    [request(null, {}, undefined, "GET"), 405, "VALIDATION_FAILURE"],
    [request(rawBody, { "content-type": "text/plain" }), 415, "VALIDATION_FAILURE"],
    [request(rawBody, { "content-encoding": "gzip" }), 415, "VALIDATION_FAILURE"],
    [request(rawBody, { authorization: "" }), 401, "UNAUTHORIZED"],
    [
      request(rawBody, { authorization: "Bearer fixture-token,other" }),
      401,
      "UNAUTHORIZED",
    ],
    [request(null), 400, "VALIDATION_FAILURE"],
    [request(rawBody, { "content-length": "01" }), 400, "VALIDATION_FAILURE"],
  ];
  for (const [candidate, status, code] of cases) {
    await safeError(await handler(candidate), status, code, false);
  }
  assert.equal(calls, 0);
});

test("rejects oversized streams and content-length mismatches", async () => {
  let calls = 0;
  let cancelled = false;
  const handler = createQuizReportV2HttpHandler(async () => {
    calls++;
    return saved;
  });
  const oversized = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array(quizReportV2MaxRawBodyBytes + 1));
    },
    cancel() {
      cancelled = true;
    },
  });
  await safeError(
    await handler(request(oversized)),
    413,
    "VALIDATION_FAILURE",
    false,
  );
  await safeError(
    await handler(
      request(rawBody, {
        "content-length": String(rawBody.byteLength - 1),
      }),
    ),
    400,
    "VALIDATION_FAILURE",
    false,
  );
  assert.equal(cancelled, true);
  assert.equal(calls, 0);
});

test("accepts the exact raw-byte limit without decoding or re-encoding", async () => {
  const exact = new Uint8Array(quizReportV2MaxRawBodyBytes);
  exact.fill(0x20);
  let receivedLength = 0;
  const handler = createQuizReportV2HttpHandler(async (_token, raw) => {
    receivedLength = raw.byteLength;
    return saved;
  });
  const response = await handler(
    request(exact, { "content-length": String(exact.byteLength) }),
  );
  assert.equal(response.status, 200);
  assert.equal(receivedLength, quizReportV2MaxRawBodyBytes);
});

test("maps only fixed boundary errors and redacts private details", async () => {
  const cases: Array<[BoundaryError, number, boolean]> = [
    [new BoundaryError("UNAUTHORIZED"), 401, false],
    [new BoundaryError("VALIDATION_FAILURE"), 400, false],
    [new BoundaryError("SYNC_CONFLICT"), 409, false],
    [new BoundaryError("RATE_LIMITED"), 429, true],
    [new BoundaryError("NETWORK_UNAVAILABLE"), 503, true],
    [new BoundaryError("INTERNAL_ERROR"), 500, false],
  ];
  for (const [error, status, retryable] of cases) {
    const handler = createQuizReportV2HttpHandler(async () => {
      throw error;
    });
    const response = await handler(request());
    await safeError(response, status, error.code, retryable);
  }
  const unexpected = createQuizReportV2HttpHandler(async () => {
    throw new Error("PRIVATE SQL TOKEN");
  });
  await safeError(await unexpected(request()), 500, "INTERNAL_ERROR", false);
});

test("aborts a pending submitter on deadline and client cancellation", async () => {
  let deadlineSignal: AbortSignal | undefined;
  const deadlineHandler = createQuizReportV2HttpHandler(
    async (_token, _raw, signal) => {
      deadlineSignal = signal;
      return new Promise<QuizReportV2Response>(() => {});
    },
    10,
  );
  await safeError(
    await deadlineHandler(request()),
    503,
    "NETWORK_UNAVAILABLE",
    true,
  );
  assert.equal(deadlineSignal?.aborted, true);

  const controller = new AbortController();
  let started!: () => void;
  const began = new Promise<void>((resolve) => {
    started = resolve;
  });
  let resolveLate!: (value: QuizReportV2Response) => void;
  const late = new Promise<QuizReportV2Response>((resolve) => {
    resolveLate = resolve;
  });
  const clientHandler = createQuizReportV2HttpHandler(async () => {
    started();
    return late;
  });
  const pending = clientHandler(request(rawBody, {}, controller.signal));
  await began;
  controller.abort();
  const response = await pending;
  resolveLate(saved);
  await Promise.resolve();
  await safeError(response, 503, "NETWORK_UNAVAILABLE", true);
});
