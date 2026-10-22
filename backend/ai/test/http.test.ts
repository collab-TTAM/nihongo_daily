// TEST ONLY Auth/context/provider/receipt ports. Native Request/streams/service.
import { test } from "node:test";
import assert from "node:assert/strict";
import { setImmediate } from "node:timers/promises";
import { createAiHttpHandler } from "../src/http.ts";
import { AiService } from "../src/service.ts";
import { operations } from "../src/contracts.ts";
import type { Operation } from "../src/contracts.ts";
import type { item_ref } from "../src/wire.ts";
import { contracts, fixtures, setup, userA } from "./support.ts";

const encode = (s: string) => new TextEncoder().encode(s);
const body = (op: Operation = "start_conversation") =>
  JSON.stringify(fixtures[`${op}_request`]);
function request(
  payload: BodyInit | null = body(),
  headers: Record<string, string> = {},
  signal?: AbortSignal,
  method = "POST",
) {
  const init: RequestInit & { duplex: "half" } = {
    method,
    body: payload,
    signal,
    headers: {
      "content-type": "application/json; charset=utf-8",
      authorization: "Bearer valid-A",
      ...headers,
    },
    duplex: "half",
  };
  return new Request("https://example.invalid/untrusted?operation=tutor", init);
}
function boundary(op: Operation = "start_conversation", timeoutMs = 15000) {
  const state = setup();
  const prepare = state.deps.context.prepare;
  const response = fixtures[`${op}_response`] as Record<string, unknown>;
  const refs = [
    ...((response.srs_recommendations ?? []) as item_ref[]),
    ...[
      "grammar_errors",
      "vocabulary_errors",
      "errors",
      "live_feedback",
    ].flatMap((field) =>
      ((response[field] ?? []) as { item_refs: item_ref[] }[]).flatMap(
        (e) => e.item_refs,
      ),
    ),
  ];
  state.deps.context.prepare = async (...args) => ({
    ...(await prepare(...args)),
    allowedRefs: refs,
  });
  const service = new AiService(contracts, state.deps);
  return {
    ...state,
    service,
    handle: createAiHttpHandler(service, op, timeoutMs),
  };
}
async function safeError(response: Response, status: number, code: string) {
  assert.equal(response.status, status);
  assert.equal(response.headers.get("cache-control"), "no-store");
  if (status === 401)
    assert.equal(response.headers.get("www-authenticate"), "Bearer");
  const text = await response.text();
  assert.ok(!/PRIVATE|valid-A|TEST_SECRET/.test(text));
  const value = JSON.parse(text);
  assert.deepEqual(Object.keys(value).sort(), [
    "code",
    "message_vi",
    "retryable",
  ]);
  assert.equal(value.code, code);
  assert.equal(typeof value.message_vi, "string");
  assert.equal(typeof value.retryable, "boolean");
}

for (const op of operations) {
  test(`HTTP ${op} preserves frozen request/response and trusted operation`, async () => {
    const b = boundary(op);
    const response = await b.handle(request(body(op)));
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.equal(response.headers.get("x-content-type-options"), "nosniff");
    assert.deepEqual(await response.json(), fixtures[`${op}_response`]);
    assert.equal(b.calls.length, 1);
    assert.equal(b.calls[0]!.operation, op);
    assert.ok(!JSON.stringify(b.calls).includes("valid-A"));
  });
}

test("HTTP rejects invalid envelope before Auth/provider and cancels body", async () => {
  const b = boundary();
  let verifications = 0;
  b.deps.auth.verify = async () => {
    verifications++;
    return { id: userA };
  };
  const cases: [Record<string, string>, number, string][] = [
    [{ "content-type": "text/plain" }, 415, "VALIDATION_FAILURE"],
    [
      { "content-type": "application/json; charset=latin1" },
      415,
      "VALIDATION_FAILURE",
    ],
    [{ "content-encoding": "gzip" }, 415, "VALIDATION_FAILURE"],
    [{ authorization: "" }, 401, "UNAUTHORIZED"],
    [{ authorization: "Basic PRIVATE" }, 401, "UNAUTHORIZED"],
    [{ authorization: "Bearer valid-A,PRIVATE" }, 401, "UNAUTHORIZED"],
    [{ authorization: `Bearer ${"a".repeat(8193)}` }, 401, "UNAUTHORIZED"],
    [{ "content-length": "32769" }, 413, "VALIDATION_FAILURE"],
    [{ "content-length": "01" }, 400, "VALIDATION_FAILURE"],
    [{ "content-length": "2,2" }, 400, "VALIDATION_FAILURE"],
  ];
  for (const [headers, status, code] of cases) {
    let cancelled = false;
    const stream = new ReadableStream<Uint8Array>({
      cancel() {
        cancelled = true;
        return new Promise<void>(() => {});
      },
    });
    await safeError(await b.handle(request(stream, headers)), status, code);
    assert.equal(cancelled, true);
  }
  const wrongMethod = await b.handle(request(null, {}, undefined, "GET"));
  assert.equal(wrongMethod.headers.get("allow"), "POST");
  await safeError(wrongMethod, 405, "VALIDATION_FAILURE");
  assert.equal(verifications, 0);
  assert.equal(b.calls.length, 0);
  assert.equal(b.store.rows.size, 0);
});

test("HTTP decodes split multibyte UTF-8 and accepts exactly32KiB", async () => {
  const b = boundary("conversation_turn");
  const text = body("conversation_turn");
  const bytes = encode(text);
  const at = bytes.findIndex((byte) => byte >= 128);
  assert.ok(at >= 0);
  const stream = new ReadableStream<Uint8Array>({
    start(c) {
      c.enqueue(bytes.slice(0, at + 1));
      c.enqueue(bytes.slice(at + 1));
      c.close();
    },
  });
  assert.equal(
    (
      await b.handle(
        request(stream, { "content-length": String(bytes.length) }),
      )
    ).status,
    200,
  );
  const second = boundary("conversation_turn");
  const padded = text + " ".repeat(32768 - bytes.length);
  assert.equal(encode(padded).length, 32768);
  assert.equal(
    (await second.handle(request(padded, { "content-length": "32768" })))
      .status,
    200,
  );
});

test("HTTP actual stream byte limit ignores absent or forged length", async () => {
  const b = boundary();
  const payload = "あ".repeat(12000);
  assert.ok(payload.length < 32768 && encode(payload).length > 32768);
  const lengths: Record<string, string>[] = [{}, { "content-length": "1" }];
  for (const headers of lengths) {
    await safeError(
      await b.handle(request(payload, headers)),
      413,
      "VALIDATION_FAILURE",
    );
  }
  await safeError(
    await b.handle(request(body(), { "content-length": "1" })),
    400,
    "VALIDATION_FAILURE",
  );
  assert.equal(b.calls.length, 0);
  assert.equal(b.store.rows.size, 0);
});

test("HTTP malformed/truncated UTF-8 and byte-order mark fail closed", async () => {
  const b = boundary();
  for (const bytes of [
    new Uint8Array([0xc3, 0x28]),
    new Uint8Array([0xe3, 0x81]),
  ]) {
    await safeError(await b.handle(request(bytes)), 400, "VALIDATION_FAILURE");
  }
  await safeError(
    await b.handle(request("\ufeff" + body())),
    400,
    "VALIDATION_FAILURE",
  );
  assert.equal(b.calls.length, 0);
});

test("HTTP raw stream errors are redacted and never dispatch", async () => {
  const b = boundary();
  const stream = new ReadableStream<Uint8Array>({
    start(c) {
      c.error(new Error("PRIVATE TEST_SECRET"));
    },
  });
  await safeError(await b.handle(request(stream)), 503, "NETWORK_UNAVAILABLE");
  assert.equal(b.calls.length, 0);
});

test(
  "HTTP stalled read/dead cancellation cannot hold a worker",
  { timeout: 1000 },
  async () => {
    const b = boundary("start_conversation", 20);
    let cancelled = false;
    const stream = new ReadableStream<Uint8Array>({
      cancel() {
        cancelled = true;
        return new Promise<void>(() => {});
      },
    });
    await safeError(
      await b.handle(request(stream)),
      504,
      "PROVIDER_UNAVAILABLE",
    );
    assert.equal(cancelled, true);
    assert.equal(b.calls.length, 0);
    assert.equal(b.store.rows.size, 0);
  },
);

test("HTTP elapsed deadline fences synchronous pull before Auth", async () => {
  const b = boundary("start_conversation", 1);
  let verified = false;
  b.deps.auth.verify = async () => {
    verified = true;
    return { id: userA };
  };
  const stream = new ReadableStream<Uint8Array>(
    {
      pull(c) {
        const until = performance.now() + 5;
        while (performance.now() < until) {
          /* TEST ONLY blocking source */
        }
        c.enqueue(encode(body()));
        c.close();
      },
    },
    { highWaterMark: 0 },
  );
  await safeError(await b.handle(request(stream)), 504, "PROVIDER_UNAVAILABLE");
  assert.equal(verified, false);
  assert.equal(b.calls.length, 0);
});

test("HTTP empty-chunk floods are bounded without accumulating strings", async () => {
  const b = boundary();
  let pulls = 0;
  const stream = new ReadableStream<Uint8Array>(
    {
      pull(c) {
        pulls++;
        c.enqueue(new Uint8Array());
      },
    },
    { highWaterMark: 0 },
  );
  await safeError(await b.handle(request(stream)), 400, "VALIDATION_FAILURE");
  assert.ok(pulls <= 32769);
  assert.equal(b.calls.length, 0);
});

test("HTTP pre-abort and disconnect during Auth fence late identity", async () => {
  const b = boundary();
  const pre = new AbortController();
  pre.abort("PRIVATE TEST_SECRET");
  await safeError(
    await b.handle(request(body(), {}, pre.signal)),
    499,
    "NETWORK_UNAVAILABLE",
  );
  let enter!: () => void;
  let release!: (id: { id: string }) => void;
  let seen: AbortSignal | undefined;
  const entered = new Promise<void>((resolve) => {
    enter = resolve;
  });
  b.deps.auth.verify = async (_, signal) => {
    seen = signal;
    enter();
    return new Promise<{ id: string }>((resolve) => {
      release = resolve;
    });
  };
  const client = new AbortController();
  const pending = b.handle(request(body(), {}, client.signal));
  await entered;
  client.abort("PRIVATE TEST_SECRET");
  await safeError(await pending, 499, "NETWORK_UNAVAILABLE");
  assert.equal(seen!.aborted, true);
  release({ id: userA });
  await setImmediate();
  assert.equal(b.calls.length, 0);
  assert.equal(b.store.rows.size, 0);
});

test("HTTP disconnect during stream read cancels without awaiting source", async () => {
  const b = boundary();
  const client = new AbortController();
  let entered!: () => void;
  let cancelled = false;
  const reading = new Promise<void>((resolve) => {
    entered = resolve;
  });
  const stream = new ReadableStream<Uint8Array>(
    {
      pull() {
        entered();
      },
      cancel() {
        cancelled = true;
        return new Promise<void>(() => {});
      },
    },
    { highWaterMark: 0 },
  );
  const pending = b.handle(request(stream, {}, client.signal));
  await reading;
  client.abort("PRIVATE TEST_SECRET");
  await safeError(await pending, 499, "NETWORK_UNAVAILABLE");
  assert.equal(cancelled, true);
  assert.equal(b.calls.length, 0);
  assert.equal(b.store.rows.size, 0);
});

test("HTTP deadline retains uncertain receipt and never redispatches late result", async () => {
  const b = boundary("start_conversation", 20);
  let enter!: () => void;
  let release!: (text: string) => void;
  let dispatched = 0;
  let seen: AbortSignal | undefined;
  const entered = new Promise<void>((resolve) => {
    enter = resolve;
  });
  b.deps.provider.generate = async (_, signal) => {
    dispatched++;
    seen = signal;
    enter();
    return new Promise<string>((resolve) => {
      release = resolve;
    });
  };
  const pending = b.handle(request());
  await entered;
  await safeError(await pending, 504, "PROVIDER_UNAVAILABLE");
  assert.equal(seen!.aborted, true);
  assert.equal(b.store.rows.size, 1);
  release(JSON.stringify(fixtures.start_conversation_response));
  await setImmediate();
  assert.equal(b.store.completions, 0);
  await safeError(await b.handle(request()), 503, "PROVIDER_UNAVAILABLE");
  assert.equal(dispatched, 1);
  assert.equal(b.store.completions, 0);
});

test("HTTP identical mutation replay and changed payload preserve receipt rules", async () => {
  const b = boundary();
  const first = await b.handle(request());
  assert.equal(first.status, 200);
  const expected = await first.json();
  assert.deepEqual(await (await b.handle(request())).json(), expected);
  const changed = {
    ...(fixtures.start_conversation_request as object),
    jlpt_level: "N4",
  };
  await safeError(
    await b.handle(request(JSON.stringify(changed))),
    409,
    "SYNC_CONFLICT",
  );
  assert.equal(b.calls.length, 1);
  assert.equal(b.store.completions, 1);
});

test("HTTP contract/Auth/rate failures retain safe service errors", async () => {
  const b = boundary();
  await safeError(
    await b.handle(request(body(), { authorization: "Bearer forged" })),
    401,
    "UNAUTHORIZED",
  );
  await safeError(
    await b.handle(
      request(
        JSON.stringify({
          ...(fixtures.start_conversation_request as object),
          user_id: userA,
        }),
      ),
    ),
    400,
    "VALIDATION_FAILURE",
  );
  b.deps.limiter.consume = async () => false;
  await safeError(await b.handle(request()), 429, "RATE_LIMITED");
  b.deps.limiter.consume = async () => {
    throw new Error("PRIVATE TEST_SECRET");
  };
  await safeError(await b.handle(request()), 500, "INTERNAL_ERROR");
  assert.equal(b.calls.length, 0);
  assert.equal(b.store.rows.size, 0);
});

test("service optional parent cancellation is safe before dispatch", async () => {
  const b = boundary();
  let verified = false;
  b.deps.auth.verify = async () => {
    verified = true;
    return { id: userA };
  };
  const parent = new AbortController();
  parent.abort("PRIVATE TEST_SECRET");
  const result = await b.service.execute(
    "start_conversation",
    "valid-A",
    body(),
    parent.signal,
  );
  assert.equal(result.ok, false);
  assert.equal(verified, false);
  assert.equal(b.calls.length, 0);
  assert.equal(b.store.rows.size, 0);
  assert.ok(!JSON.stringify(result).includes("PRIVATE"));
});

test("HTTP trusted configuration bounds reject invalid deadline or operation", () => {
  const b = boundary();
  for (const timeout of [0, -1, 30001, NaN, 1.5])
    assert.throws(() =>
      createAiHttpHandler(b.service, "start_conversation", timeout),
    );
  assert.throws(() => createAiHttpHandler(b.service, "unknown" as Operation));
});
