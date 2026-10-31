import { operations } from "./contracts.ts";
import type { Operation } from "./contracts.ts";
import type { AiService } from "./service.ts";
import type { error as WireError } from "./wire.ts";

const maxBytes = 32768;
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
const messages = {
  UNAUTHORIZED: "Phiên đăng nhập không hợp lệ. Hãy đăng nhập lại.",
  VALIDATION_FAILURE: "Dữ liệu gửi lên không hợp lệ.",
  NETWORK_UNAVAILABLE: "Kết nối chưa khả dụng. Hãy thử lại sau.",
  PROVIDER_UNAVAILABLE: "Trợ lý AI chưa khả dụng. Hãy thử lại sau.",
  INTERNAL_ERROR: "Không xử lý được yêu cầu. Hãy thử lại sau.",
} as const;
class HttpFailure extends Error {
  readonly status: number;
  readonly code: keyof typeof messages;
  constructor(status: number, code: keyof typeof messages) {
    super(code);
    this.status = status;
    this.code = code;
  }
}
function json(body: unknown, status: number, allowPost = false): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      ...(allowPost ? { allow: "POST" } : {}),
      ...(status === 401 ? { "www-authenticate": "Bearer" } : {}),
    },
  });
}
function failure(error: HttpFailure): Response {
  return json(
    {
      code: error.code,
      message_vi: messages[error.code],
      retryable: ["NETWORK_UNAVAILABLE", "PROVIDER_UNAVAILABLE"].includes(
        error.code,
      ),
    } satisfies WireError,
    error.status,
    error.status === 405,
  );
}

async function readNext(
  reader: ReadableStreamDefaultReader<Uint8Array>,
  signal: AbortSignal,
): Promise<ReadableStreamReadResult<Uint8Array>> {
  if (signal.aborted) throw new HttpFailure(503, "NETWORK_UNAVAILABLE");
  let abort: (() => void) | undefined;
  try {
    return await new Promise((resolve, reject) => {
      abort = () => reject(new HttpFailure(503, "NETWORK_UNAVAILABLE"));
      signal.addEventListener("abort", abort, { once: true });
      void reader.read().then(resolve, reject);
    });
  } finally {
    if (abort) signal.removeEventListener("abort", abort);
  }
}

async function readBounded(
  request: Request,
  signal: AbortSignal,
  declared: number | null,
  alive: () => void,
): Promise<string> {
  if (!request.body || request.bodyUsed || request.body.locked)
    throw new HttpFailure(400, "VALIDATION_FAILURE");
  if (signal.aborted) throw new HttpFailure(503, "NETWORK_UNAVAILABLE");
  const reader = request.body.getReader();
  const decoder = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });
  const parts: string[] = [];
  let bytes = 0;
  let reads = 0;
  let complete = false;
  try {
    while (true) {
      alive();
      if (++reads > maxBytes + 1)
        throw new HttpFailure(400, "VALIDATION_FAILURE");
      const { value, done } = await readNext(reader, signal);
      alive();
      if (done) {
        complete = true;
        break;
      }
      if (!(value instanceof Uint8Array))
        throw new HttpFailure(400, "VALIDATION_FAILURE");
      bytes += value.byteLength;
      if (bytes > maxBytes) throw new HttpFailure(413, "VALIDATION_FAILURE");
      if (value.byteLength === 0) continue;
      try {
        parts.push(decoder.decode(value, { stream: true }));
      } catch {
        throw new HttpFailure(400, "VALIDATION_FAILURE");
      }
    }
    if (declared !== null && declared !== bytes)
      throw new HttpFailure(400, "VALIDATION_FAILURE");
    try {
      parts.push(decoder.decode());
    } catch {
      throw new HttpFailure(400, "VALIDATION_FAILURE");
    }
    return parts.join("");
  } catch (error) {
    if (error instanceof HttpFailure) throw error;
    throw new HttpFailure(503, "NETWORK_UNAVAILABLE");
  } finally {
    if (!complete) void reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}

/** Server-only adapter. The caller binds one operation and supplies the existing
 * mandatory verified Auth/limiter/transaction/provider ports through AiService.
 * No endpoint, JWT-verification setting, CORS policy or live provider is installed.
 */
export function createAiHttpHandler(
  service: AiService,
  operation: Operation,
  timeoutMs = 15000,
): (request: Request) => Promise<Response> {
  if (
    !operations.includes(operation) ||
    !Number.isInteger(timeoutMs) ||
    timeoutMs < 1 ||
    timeoutMs > 30000
  )
    throw new Error("Invalid HTTP boundary configuration");
  return async (request) => {
    const controller = new AbortController();
    let stopped: "client" | "deadline" | undefined;
    const stop = (reason: typeof stopped) => {
      stopped ??= reason;
      controller.abort();
    };
    const disconnected = () => stop("client");
    const deadline = performance.now() + timeoutMs;
    const alive = () => {
      if (performance.now() >= deadline) stop("deadline");
      if (controller.signal.aborted)
        throw new HttpFailure(503, "NETWORK_UNAVAILABLE");
    };
    const timer = setTimeout(() => stop("deadline"), timeoutMs);
    request.signal.addEventListener("abort", disconnected, { once: true });
    try {
      if (request.signal.aborted) {
        disconnected();
        throw new HttpFailure(499, "NETWORK_UNAVAILABLE");
      }
      if (request.method !== "POST")
        throw new HttpFailure(405, "VALIDATION_FAILURE");
      const type = request.headers.get("content-type") ?? "";
      if (!/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(type))
        throw new HttpFailure(415, "VALIDATION_FAILURE");
      const encoding = request.headers.get("content-encoding");
      if (encoding && encoding.toLowerCase() !== "identity")
        throw new HttpFailure(415, "VALIDATION_FAILURE");
      const authorization = request.headers.get("authorization") ?? "";
      const bearer = /^Bearer ([^\s,]+)$/i.exec(authorization)?.[1];
      if (!bearer || bearer.length > 8192)
        throw new HttpFailure(401, "UNAUTHORIZED");
      const length = request.headers.get("content-length");
      if (length !== null && !/^(0|[1-9]\d{0,9})$/.test(length))
        throw new HttpFailure(400, "VALIDATION_FAILURE");
      const declared = length === null ? null : Number(length);
      if (declared !== null && declared > maxBytes)
        throw new HttpFailure(413, "VALIDATION_FAILURE");
      alive();
      const text = await readBounded(
        request,
        controller.signal,
        declared,
        alive,
      );
      alive();
      const outcome = await service.execute(
        operation,
        bearer,
        text,
        controller.signal,
      );
      alive();
      const response = outcome.ok
        ? json(outcome.response, 200)
        : json(outcome.error, statusCodes[outcome.error.code]);
      alive();
      return response;
    } catch (error) {
      if (stopped)
        return failure(
          stopped === "client"
            ? new HttpFailure(499, "NETWORK_UNAVAILABLE")
            : new HttpFailure(504, "PROVIDER_UNAVAILABLE"),
        );
      return failure(
        error instanceof HttpFailure
          ? error
          : new HttpFailure(500, "INTERNAL_ERROR"),
      );
    } finally {
      clearTimeout(timer);
      request.signal.removeEventListener("abort", disconnected);
      controller.abort();
      void request.body?.cancel().catch(() => {});
    }
  };
}
