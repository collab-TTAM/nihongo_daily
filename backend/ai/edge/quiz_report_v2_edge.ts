import type { TrustedQuizReportV2Configuration } from "../src/quiz_report_v2_host.ts";

export interface QuizReportV2EdgeConfiguration {
  readonly trusted: TrustedQuizReportV2Configuration;
  readonly allowedOrigins: readonly string[];
}

type EnvironmentReader = (name: string) => string | undefined;
type RequestHandler = (request: Request) => Promise<Response>;

const configurationError = () =>
  new Error("Invalid trusted quiz report v2 server configuration");

function requiredEnvironmentValue(
  read: EnvironmentReader,
  name: string,
  maximumLength: number,
): string {
  const value = read(name);
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length > maximumLength ||
    value !== value.trim()
  ) {
    throw configurationError();
  }
  return value;
}

/** Exact origins only; HTTP is accepted solely for explicit loopback development. */
export function parseQuizReportV2AllowedOrigins(
  raw: string,
): readonly string[] {
  if (
    typeof raw !== "string" ||
    raw.length === 0 ||
    raw.length > 4096 ||
    raw !== raw.trim()
  ) {
    throw configurationError();
  }
  const origins = raw.split(",").map((value) => value.trim());
  if (
    origins.length === 0 ||
    origins.length > 20 ||
    origins.some((value) => value.length === 0 || value.length > 512) ||
    new Set(origins).size !== origins.length
  ) {
    throw configurationError();
  }

  for (const origin of origins) {
    let url: URL;
    try {
      url = new URL(origin);
    } catch {
      throw configurationError();
    }
    const hostname = url.hostname.toLowerCase();
    const loopback = hostname === "localhost" ||
      hostname === "127.0.0.1" ||
      hostname === "[::1]" ||
      hostname === "::1";
    if (
      url.origin !== origin ||
      url.username.length > 0 ||
      url.password.length > 0 ||
      url.pathname !== "/" ||
      url.search.length > 0 ||
      url.hash.length > 0 ||
      (url.protocol !== "https:" && !(url.protocol === "http:" && loopback))
    ) {
      throw configurationError();
    }
  }
  return Object.freeze(origins);
}

/** Reads only fixed deployment variables; request fields never select a project or key. */
export function readQuizReportV2EdgeConfiguration(
  read: EnvironmentReader,
): QuizReportV2EdgeConfiguration {
  if (typeof read !== "function") throw configurationError();
  const projectUrl = requiredEnvironmentValue(
    read,
    "ND_QUIZ_REPORT_SUPABASE_URL",
    2048,
  );
  const publicKey = requiredEnvironmentValue(
    read,
    "ND_QUIZ_REPORT_SUPABASE_PUBLIC_KEY",
    8192,
  );
  const databaseUrl = requiredEnvironmentValue(
    read,
    "ND_QUIZ_REPORT_DATABASE_URL",
    8192,
  );
  const allowedOrigins = parseQuizReportV2AllowedOrigins(
    requiredEnvironmentValue(read, "ND_QUIZ_REPORT_ALLOWED_ORIGINS", 4096),
  );
  return Object.freeze({
    trusted: Object.freeze({ projectUrl, publicKey, databaseUrl }),
    allowedOrigins,
  });
}

const allowedRequestHeaders = new Set([
  "authorization",
  "apikey",
  "content-type",
  "x-client-info",
]);
const allowedRequestHeaderValue =
  "authorization, apikey, content-type, x-client-info";

function appendVary(headers: Headers, values: readonly string[]): void {
  const current = (headers.get("vary") ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
  const seen = new Set(current.map((value) => value.toLowerCase()));
  for (const value of values) {
    if (!seen.has(value.toLowerCase())) {
      current.push(value);
      seen.add(value.toLowerCase());
    }
  }
  headers.set("vary", current.join(", "));
}

function failure(
  status: number,
  code: "FORBIDDEN" | "VALIDATION_FAILURE" | "INTERNAL_ERROR",
  message: string,
): Response {
  const headers = new Headers({
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
  });
  if (status === 405) headers.set("allow", "POST, OPTIONS");
  return new Response(
    JSON.stringify({ code, message_vi: message, retryable: false }),
    { status, headers },
  );
}

function withCors(
  response: Response,
  origin: string,
  preflight = false,
): Response {
  const headers = new Headers(response.headers);
  headers.set("access-control-allow-origin", origin);
  headers.set("access-control-allow-methods", "POST, OPTIONS");
  headers.set("access-control-allow-headers", allowedRequestHeaderValue);
  headers.set("access-control-max-age", "600");
  appendVary(
    headers,
    preflight
      ? [
        "Origin",
        "Access-Control-Request-Method",
        "Access-Control-Request-Headers",
      ]
      : ["Origin"],
  );
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

/** CORS is exact-origin, credential-free and separate from JWT/owner authorization. */
export function createQuizReportV2EdgeHandler(
  handler: RequestHandler,
  allowedOrigins: readonly string[],
): RequestHandler {
  if (typeof handler !== "function" || !Array.isArray(allowedOrigins)) {
    throw configurationError();
  }
  const validatedOrigins = parseQuizReportV2AllowedOrigins(
    allowedOrigins.join(","),
  );
  const allowed = new Set(validatedOrigins);

  return async (request) => {
    const origin = request.headers.get("origin");
    if (origin !== null && !allowed.has(origin)) {
      const denied = failure(
        403,
        "FORBIDDEN",
        "Nguồn truy cập không được phép.",
      );
      const headers = new Headers(denied.headers);
      appendVary(headers, ["Origin"]);
      return new Response(denied.body, {
        status: denied.status,
        headers,
      });
    }

    if (request.method === "OPTIONS") {
      if (origin === null) {
        return failure(
          405,
          "VALIDATION_FAILURE",
          "Phương thức yêu cầu không được hỗ trợ.",
        );
      }
      if (request.headers.get("access-control-request-method") !== "POST") {
        return withCors(
          failure(
            405,
            "VALIDATION_FAILURE",
            "Phương thức yêu cầu không được hỗ trợ.",
          ),
          origin,
          true,
        );
      }
      const requested = request.headers.get("access-control-request-headers");
      const names = requested === null || requested.trim().length === 0
        ? []
        : requested.split(",").map((value) => value.trim().toLowerCase());
      if (
        names.some(
          (name) => name.length === 0 || !allowedRequestHeaders.has(name),
        )
      ) {
        return withCors(
          failure(
            403,
            "FORBIDDEN",
            "Tiêu đề yêu cầu không được phép.",
          ),
          origin,
          true,
        );
      }
      return withCors(
        new Response(null, {
          status: 204,
          headers: {
            "cache-control": "no-store",
            "x-content-type-options": "nosniff",
          },
        }),
        origin,
        true,
      );
    }

    let response: Response;
    try {
      response = await handler(request);
      if (!(response instanceof Response)) throw new Error();
    } catch {
      response = failure(
        500,
        "INTERNAL_ERROR",
        "Không xử lý được yêu cầu.",
      );
    }
    return origin === null ? response : withCors(response, origin);
  };
}
