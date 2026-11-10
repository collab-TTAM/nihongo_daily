import { BoundaryError } from "./contracts.ts";
import type { QuizReportV2Submitter } from "./quiz_report_v2_host.ts";
import type { error as WireError } from "./wire.ts";

export const quizReportV2MaxRawBodyBytes = 16 * 1024;

const statusCodes: Record<WireError["code"], number> = {
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  VALIDATION_FAILURE: 400,
  RATE_LIMITED: 429,
  NETWORK_UNAVAILABLE: 503,
  PROVIDER_UNAVAILABLE: 503,
  SYNC_CONFLICT: 409,
  INTERNAL_ERROR: 500,
};

const messages: Record<WireError["code"], string> = {
  UNAUTHORIZED: "Phiên đăng nhập không hợp lệ. Hãy đăng nhập lại.",
  FORBIDDEN: "Bạn không có quyền lưu kết quả này.",
  NOT_FOUND: "Không tìm thấy nội dung bài kiểm tra.",
  VALIDATION_FAILURE: "Dữ liệu bài kiểm tra không hợp lệ.",
  RATE_LIMITED: "Bạn thao tác quá nhanh. Hãy thử lại sau.",
  NETWORK_UNAVAILABLE:
    "Kết nối chưa khả dụng. Kết quả có thể chưa xác định; hãy kiểm tra lịch sử trước khi gửi lại.",
  PROVIDER_UNAVAILABLE: "Dịch vụ hiện chưa khả dụng. Hãy thử lại sau.",
  SYNC_CONFLICT:
    "Bài kiểm tra đã thay đổi. Hãy tải lại nội dung trước khi thử lại.",
  INTERNAL_ERROR: "Không xử lý được bài kiểm tra. Hãy thử lại sau.",
};

class HttpFailure extends Error {
  readonly status: number;
  readonly code: WireError["code"];

  constructor(status: number, code: WireError["code"]) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      ...(status === 401 ? { "www-authenticate": "Bearer" } : {}),
      ...(status === 405 ? { allow: "POST" } : {}),
    },
  });
}

function failure(
  code: WireError["code"],
  status = statusCodes[code],
): Response {
  const body: WireError = {
    code,
    message_vi: messages[code],
    retryable:
      code === "RATE_LIMITED" ||
      code === "NETWORK_UNAVAILABLE" ||
      code === "PROVIDER_UNAVAILABLE",
  };
  return json(body, status);
}

async function readNext(
  reader: ReadableStreamDefaultReader<Uint8Array>,
  signal: AbortSignal,
): Promise<ReadableStreamReadResult<Uint8Array>> {
  if (signal.aborted) throw new BoundaryError("NETWORK_UNAVAILABLE");
  let abort: (() => void) | undefined;
  try {
    return await new Promise<ReadableStreamReadResult<Uint8Array>>(
      (resolve, reject) => {
        abort = () => reject(new BoundaryError("NETWORK_UNAVAILABLE"));
        signal.addEventListener("abort", abort, { once: true });
        void reader.read().then(resolve, reject);
      },
    );
  } finally {
    if (abort) signal.removeEventListener("abort", abort);
  }
}

async function readBoundedBytes(
  request: Request,
  signal: AbortSignal,
  declaredLength: number | null,
  alive: () => void,
): Promise<Uint8Array> {
  if (!request.body || request.bodyUsed || request.body.locked) {
    throw new HttpFailure(400, "VALIDATION_FAILURE");
  }
  if (signal.aborted) throw new BoundaryError("NETWORK_UNAVAILABLE");

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let byteLength = 0;
  let reads = 0;
  let complete = false;
  try {
    while (true) {
      alive();
      if (++reads > quizReportV2MaxRawBodyBytes + 1) {
        throw new HttpFailure(400, "VALIDATION_FAILURE");
      }
      const { value, done } = await readNext(reader, signal);
      alive();
      if (done) {
        complete = true;
        break;
      }
      if (!(value instanceof Uint8Array)) {
        throw new HttpFailure(400, "VALIDATION_FAILURE");
      }
      byteLength += value.byteLength;
      if (byteLength > quizReportV2MaxRawBodyBytes) {
        throw new HttpFailure(413, "VALIDATION_FAILURE");
      }
      if (value.byteLength > 0) chunks.push(value.slice());
    }
    if (declaredLength !== null && declaredLength !== byteLength) {
      throw new HttpFailure(400, "VALIDATION_FAILURE");
    }
    const raw = new Uint8Array(byteLength);
    let offset = 0;
    for (const chunk of chunks) {
      raw.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return raw;
  } catch (error) {
    if (error instanceof HttpFailure || error instanceof BoundaryError) {
      throw error;
    }
    throw new BoundaryError("NETWORK_UNAVAILABLE");
  } finally {
    if (!complete) void reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}

function awaitWithSignal<T>(work: Promise<T>, signal: AbortSignal): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    let settled = false;
    let abort: (() => void) | undefined;
    const finish = (action: () => void) => {
      if (settled) return;
      settled = true;
      if (abort) signal.removeEventListener("abort", abort);
      action();
    };
    abort = () =>
      finish(() => reject(new BoundaryError("NETWORK_UNAVAILABLE")));
    signal.addEventListener("abort", abort, { once: true });
    if (signal.aborted) abort();
    void work.then(
      (value) => finish(() => resolve(value)),
      (error: unknown) => finish(() => reject(error)),
    );
  });
}

/**
 * Internal Request/Response boundary only. The caller supplies a trusted
 * submitter assembled from server configuration; this function installs no
 * route, reads no environment, and does not authorize client-side save state.
 */
export function createQuizReportV2HttpHandler(
  submit: QuizReportV2Submitter,
  timeoutMs = 15000,
): (request: Request) => Promise<Response> {
  if (
    typeof submit !== "function" ||
    !Number.isInteger(timeoutMs) ||
    timeoutMs < 1 ||
    timeoutMs > 30000
  ) {
    throw new Error("Invalid quiz report v2 HTTP configuration");
  }

  return async (request) => {
    const controller = new AbortController();
    let stopped: "client" | "deadline" | undefined;
    const stop = (reason: typeof stopped) => {
      stopped ??= reason;
      if (!controller.signal.aborted) controller.abort();
    };
    const disconnected = () => stop("client");
    const deadline = performance.now() + timeoutMs;
    const alive = () => {
      if (performance.now() >= deadline) stop("deadline");
      if (controller.signal.aborted) {
        throw new BoundaryError("NETWORK_UNAVAILABLE");
      }
    };
    const timer = setTimeout(() => stop("deadline"), timeoutMs);
    request.signal.addEventListener("abort", disconnected, { once: true });

    try {
      if (request.signal.aborted) stop("client");
      alive();
      if (request.method !== "POST") {
        throw new HttpFailure(405, "VALIDATION_FAILURE");
      }
      const contentType = request.headers.get("content-type") ?? "";
      if (!/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(contentType)) {
        throw new HttpFailure(415, "VALIDATION_FAILURE");
      }
      const contentEncoding = request.headers.get("content-encoding");
      if (contentEncoding && contentEncoding.toLowerCase() !== "identity") {
        throw new HttpFailure(415, "VALIDATION_FAILURE");
      }

      const authorization = request.headers.get("authorization") ?? "";
      const bearer = /^Bearer ([^\s,]+)$/i.exec(authorization)?.[1];
      if (!bearer || bearer.length > 8192) {
        throw new HttpFailure(401, "UNAUTHORIZED");
      }

      const rawLength = request.headers.get("content-length");
      if (rawLength !== null && !/^(0|[1-9]\d{0,9})$/.test(rawLength)) {
        throw new HttpFailure(400, "VALIDATION_FAILURE");
      }
      const declaredLength = rawLength === null ? null : Number(rawLength);
      if (
        declaredLength !== null &&
        declaredLength > quizReportV2MaxRawBodyBytes
      ) {
        throw new HttpFailure(413, "VALIDATION_FAILURE");
      }

      const raw = await readBoundedBytes(
        request,
        controller.signal,
        declaredLength,
        alive,
      );
      alive();
      const pending = Promise.resolve().then(() =>
        submit(bearer, raw, controller.signal),
      );
      const response = await awaitWithSignal(pending, controller.signal);
      alive();
      return json(response, 200);
    } catch (error) {
      if (stopped) return failure("NETWORK_UNAVAILABLE");
      if (error instanceof HttpFailure) {
        return failure(error.code, error.status);
      }
      if (error instanceof BoundaryError) return failure(error.code);
      return failure("INTERNAL_ERROR");
    } finally {
      clearTimeout(timer);
      request.signal.removeEventListener("abort", disconnected);
      controller.abort();
      try {
        void request.body?.cancel().catch(() => {});
      } catch {
        // The body may already be consumed or locked by the stream reader.
      }
    }
  };
}
