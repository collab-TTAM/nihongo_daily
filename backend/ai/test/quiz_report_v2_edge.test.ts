import { test } from "node:test";
import assert from "node:assert/strict";
import {
  createQuizReportV2EdgeHandler,
  parseQuizReportV2AllowedOrigins,
  readQuizReportV2EdgeConfiguration,
} from "../edge/quiz_report_v2_edge.ts";

const browserOrigin = "https://learn.example";
const trustedOrigins = [browserOrigin, "http://localhost:3000"] as const;

function request(
  method: string,
  headers: Record<string, string> = {},
): Request {
  return new Request("https://project.example/functions/v1/quiz-report-v2", {
    method,
    headers,
  });
}

function baseHandler(calls: { count: number }) {
  return async (_request: Request) => {
    calls.count++;
    return new Response(JSON.stringify({ accepted: true }), {
      status: 200,
      headers: {
        "content-type": "application/json",
        "cache-control": "no-store",
        "x-content-type-options": "nosniff",
      },
    });
  };
}

test("rejects wildcard, credentials, paths and non-HTTPS public origins", () => {
  for (const value of [
    "",
    "*",
    "null",
    "http://learn.example",
    "https://user:password@learn.example",
    "https://learn.example/path",
    "https://learn.example?query=1",
    "https://learn.example#fragment",
    "https://learn.example/",
    "https://learn.example,https://learn.example",
  ]) {
    assert.throws(() => parseQuizReportV2AllowedOrigins(value));
  }
  assert.deepEqual(
    parseQuizReportV2AllowedOrigins(
      "https://learn.example,http://localhost:3000",
    ),
    trustedOrigins,
  );
});

test("reads only fixed server environment names and rejects missing or padded values", () => {
  const values = new Map([
    ["ND_QUIZ_REPORT_SUPABASE_URL", "https://project.supabase.co"],
    [
      "ND_QUIZ_REPORT_SUPABASE_PUBLIC_KEY",
      "sb_publishable_TEST_ONLY_1234567890",
    ],
    [
      "ND_QUIZ_REPORT_DATABASE_URL",
      "postgresql://quiz_backend:TEST_ONLY@db.example:5432/postgres",
    ],
    ["ND_QUIZ_REPORT_ALLOWED_ORIGINS", browserOrigin],
  ]);
  const reads: string[] = [];
  const configuration = readQuizReportV2EdgeConfiguration((name) => {
    reads.push(name);
    return values.get(name);
  });
  assert.deepEqual(reads, [
    "ND_QUIZ_REPORT_SUPABASE_URL",
    "ND_QUIZ_REPORT_SUPABASE_PUBLIC_KEY",
    "ND_QUIZ_REPORT_DATABASE_URL",
    "ND_QUIZ_REPORT_ALLOWED_ORIGINS",
  ]);
  assert.deepEqual(configuration.allowedOrigins, [browserOrigin]);
  assert.equal(configuration.trusted.projectUrl, "https://project.supabase.co");
  assert.equal(
    configuration.trusted.publicKey,
    values.get("ND_QUIZ_REPORT_SUPABASE_PUBLIC_KEY"),
  );
  assert.equal(Object.isFrozen(configuration), true);
  assert.equal(Object.isFrozen(configuration.trusted), true);

  assert.throws(
    () =>
      readQuizReportV2EdgeConfiguration((name) =>
        name === "ND_QUIZ_REPORT_ALLOWED_ORIGINS" ? browserOrigin : undefined,
      ),
    /Invalid trusted quiz report v2 server configuration/,
  );
  assert.throws(
    () =>
      readQuizReportV2EdgeConfiguration((name) =>
        name === "ND_QUIZ_REPORT_SUPABASE_URL"
          ? " https://project.supabase.co "
          : values.get(name),
      ),
    /Invalid trusted quiz report v2 server configuration/,
  );
});

test("preflight echoes only exact allowlisted origin and required headers", async () => {
  const calls = { count: 0 };
  const handler = createQuizReportV2EdgeHandler(
    baseHandler(calls),
    trustedOrigins,
  );
  const response = await handler(
    request("OPTIONS", {
      origin: browserOrigin,
      "access-control-request-method": "POST",
      "access-control-request-headers":
        "authorization, apikey, content-type, x-client-info",
    }),
  );
  assert.equal(response.status, 204);
  assert.equal(
    response.headers.get("access-control-allow-origin"),
    browserOrigin,
  );
  assert.equal(
    response.headers.get("access-control-allow-methods"),
    "POST, OPTIONS",
  );
  assert.equal(
    response.headers.get("access-control-allow-headers"),
    "authorization, apikey, content-type, x-client-info",
  );
  assert.equal(response.headers.get("access-control-allow-credentials"), null);
  assert.match(response.headers.get("vary") ?? "", /Origin/i);
  assert.match(
    response.headers.get("vary") ?? "",
    /Access-Control-Request-Method/i,
  );
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(calls.count, 0);
});

test("disallowed origin and unsupported preflight headers never reach submitter", async () => {
  const calls = { count: 0 };
  const handler = createQuizReportV2EdgeHandler(
    baseHandler(calls),
    trustedOrigins,
  );
  const denied = await handler(
    request("POST", { origin: "https://attacker.example" }),
  );
  assert.equal(denied.status, 403);
  assert.equal(denied.headers.get("access-control-allow-origin"), null);
  assert.equal(denied.headers.get("cache-control"), "no-store");

  const unsupported = await handler(
    request("OPTIONS", {
      origin: browserOrigin,
      "access-control-request-method": "POST",
      "access-control-request-headers": "authorization, x-private-header",
    }),
  );
  assert.equal(unsupported.status, 403);
  assert.equal(
    unsupported.headers.get("access-control-allow-origin"),
    browserOrigin,
  );
  assert.equal(calls.count, 0);
});

test("allowed browser POST forwards request and preserves safe headers", async () => {
  const calls = { count: 0 };
  const handler = createQuizReportV2EdgeHandler(
    baseHandler(calls),
    trustedOrigins,
  );
  const response = await handler(request("POST", { origin: browserOrigin }));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { accepted: true });
  assert.equal(
    response.headers.get("access-control-allow-origin"),
    browserOrigin,
  );
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
  assert.match(response.headers.get("vary") ?? "", /Origin/i);
  assert.equal(calls.count, 1);
});

test("native request without Origin reaches the fixed handler without CORS reflection", async () => {
  const calls = { count: 0 };
  const handler = createQuizReportV2EdgeHandler(
    baseHandler(calls),
    trustedOrigins,
  );
  const response = await handler(request("POST"));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("access-control-allow-origin"), null);
  assert.equal(calls.count, 1);
});

test("preflight rejects methods other than POST", async () => {
  const handler = createQuizReportV2EdgeHandler(
    baseHandler({ count: 0 }),
    trustedOrigins,
  );
  const response = await handler(
    request("OPTIONS", {
      origin: browserOrigin,
      "access-control-request-method": "DELETE",
    }),
  );
  assert.equal(response.status, 405);
  assert.equal(response.headers.get("allow"), "POST, OPTIONS");
  assert.equal(
    response.headers.get("access-control-allow-origin"),
    browserOrigin,
  );
});

test("unexpected handler errors are redacted and CORS-readable", async () => {
  const handler = createQuizReportV2EdgeHandler(async () => {
    throw new Error("PRIVATE DATABASE URL AND TOKEN");
  }, trustedOrigins);
  const response = await handler(request("POST", { origin: browserOrigin }));
  assert.equal(response.status, 500);
  assert.equal(
    response.headers.get("access-control-allow-origin"),
    browserOrigin,
  );
  const body = await response.text();
  assert.doesNotMatch(body, /PRIVATE DATABASE URL AND TOKEN/);
  assert.match(body, /INTERNAL_ERROR/);
});

for (const [label, method, headers, status] of [
  ["denied origin", "POST", { origin: "https://attacker.example" }, 403],
  ["native OPTIONS", "OPTIONS", {}, 405],
  [
    "wrong preflight method",
    "OPTIONS",
    { origin: browserOrigin, "access-control-request-method": "DELETE" },
    405,
  ],
  [
    "wrong preflight header",
    "OPTIONS",
    {
      origin: browserOrigin,
      "access-control-request-method": "POST",
      "access-control-request-headers": "x-private",
    },
    403,
  ],
  [
    "accepted preflight",
    "OPTIONS",
    { origin: browserOrigin, "access-control-request-method": "POST" },
    204,
  ],
] as const) {
  test(`cancels unread body on ${label} without dispatch`, async () => {
    let cancellations = 0;
    let dispatches = 0;
    const body = new ReadableStream<Uint8Array>({
      cancel() {
        cancellations++;
      },
    });
    const init: RequestInit & { duplex: "half" } = {
      method,
      headers,
      body,
      duplex: "half",
    };
    const candidate = new Request(
      "https://project.example/functions/v1/quiz-report-v2",
      init,
    );
    const handler = createQuizReportV2EdgeHandler(async () => {
      dispatches++;
      throw new Error("must not dispatch");
    }, trustedOrigins);
    const response = await handler(candidate);
    assert.equal(response.status, status);
    assert.equal(cancellations, 1);
    assert.equal(dispatches, 0);
  });
}

test("cleanup cannot delay or replace the safe handler failure", async () => {
  for (const mode of ["reject", "stall"] as const) {
    let cancelled = false;
    const body = new ReadableStream<Uint8Array>({
      cancel() {
        cancelled = true;
        return mode === "reject"
          ? Promise.reject(new Error("PRIVATE CANCEL"))
          : new Promise<void>(() => {});
      },
    });
    const init: RequestInit & { duplex: "half" } = {
      method: "POST",
      headers: { origin: browserOrigin },
      body,
      duplex: "half",
    };
    const handler = createQuizReportV2EdgeHandler(async () => {
      throw new Error("PRIVATE HANDLER");
    }, trustedOrigins);
    const response = await handler(
      new Request("https://project.example/functions/v1/quiz-report-v2", init),
    );
    assert.equal(cancelled, true);
    assert.equal(response.status, 500);
    assert.equal(
      response.headers.get("access-control-allow-origin"),
      browserOrigin,
    );
    assert.doesNotMatch(await response.text(), /PRIVATE/);
    await new Promise<void>((resolve) => setImmediate(resolve));
  }
});

test("accepted body remains readable byte-for-byte until handler settles", async () => {
  const bytes = new TextEncoder().encode(
    '{"duplicate":1,"duplicate":2,"jp":"あ"}',
  );
  let cancellations = 0;
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(bytes);
      controller.close();
    },
    cancel() {
      cancellations++;
    },
  });
  const init: RequestInit & { duplex: "half" } = {
    method: "POST",
    headers: { origin: browserOrigin },
    body,
    duplex: "half",
  };
  const candidate = new Request(
    "https://project.example/functions/v1/quiz-report-v2",
    init,
  );
  const handler = createQuizReportV2EdgeHandler(async (received) => {
    await Promise.resolve();
    assert.equal(received, candidate);
    assert.equal(cancellations, 0);
    assert.deepEqual(new Uint8Array(await received.arrayBuffer()), bytes);
    return new Response("{}", { headers: { "cache-control": "no-store" } });
  }, trustedOrigins);
  assert.equal((await handler(candidate)).status, 200);
  assert.equal(cancellations, 0);
});
