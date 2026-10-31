// TEST ONLY HTTP/Auth responses; actual Fetch Response/streams/adapter/service.
import { test } from "node:test";
import assert from "node:assert/strict";
import { getEventListeners } from "node:events";
import { setImmediate } from "node:timers/promises";
import { SupabaseAuthVerifier } from "../src/supabase_auth.ts";
import { BoundaryError } from "../src/contracts.ts";
import { AiService } from "../src/service.ts";
import { createAiHttpHandler } from "../src/http.ts";
import { setup, contracts, fixtures, userA, userB } from "./support.ts";
const project = "https://auth-fixture.invalid";
const publicKey = "sb_publishable_TEST_ONLY_PUBLIC_KEY";
const encode = (s: string) => new TextEncoder().encode(s);
const signal = () => new AbortController().signal;
const user = (id = userA) => ({ id, aud: "authenticated" });
const json = (value: unknown = user(), status = 200) =>
  new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
const auth = (fetcher: typeof fetch, timeoutMs = 5000) =>
  new SupabaseAuthVerifier(project, publicKey, fetcher, timeoutMs);
async function fails(work: Promise<unknown>, code = "NETWORK_UNAVAILABLE") {
  await assert.rejects(work, (error: unknown) => {
    assert.ok(error instanceof BoundaryError);
    assert.equal(error.code, code);
    assert.equal(error.message, code);
    assert.ok(!JSON.stringify(error).includes("PRIVATE"));
    return true;
  });
}
test("fixed project GET sends only configured public key and caller token; returns only server identity", async () => {
  const token = `${btoa("{}").replace(/=+$/, "")}.${btoa(JSON.stringify({ sub: userA })).replace(/=+$/, "")}.UNVERIFIED`;
  const verifier = auth(async (url, init) => {
    assert.equal(url, project + "/auth/v1/user");
    assert.equal(init?.method, "GET");
    assert.equal(init?.redirect, "error");
    assert.equal(init?.credentials, "omit");
    assert.equal(init?.cache, "no-store");
    assert.equal(init?.body, undefined);
    assert.deepEqual(init?.headers, {
      apikey: publicKey,
      authorization: `Bearer ${token}`,
      accept: "application/json",
    });
    assert.ok(init?.signal instanceof AbortSignal);
    return json({
      ...user(userB.toUpperCase()),
      user_metadata: { id: userA, role: "service_role" },
      email: "PRIVATE",
    });
  });
  assert.deepEqual(await verifier.verify(token, signal()), { id: userB });
});
test("configuration rejects non-origin URLs and private/malformed keys before I/O", () => {
  for (const url of [
    "http://auth-fixture.invalid",
    project + "/path",
    project + "?",
    project + "#",
    " https://auth-fixture.invalid",
    "https://a:b@auth-fixture.invalid",
    "bad",
    "https://" + "a".repeat(2048),
  ])
    assert.throws(() => new SupabaseAuthVerifier(url, publicKey), {
      message: "Invalid trusted Supabase public configuration",
    });
  const jwt = (role: string) =>
    `e30.${btoa(JSON.stringify({ role }))}.TEST_ONLY`;
  for (const key of [
    "",
    "PRIVATE",
    "sb_secret_PRIVATE",
    jwt("service_role"),
    jwt("authenticated"),
    "a.b.c",
    "a..c",
    publicKey + "\n",
  ])
    assert.throws(() => new SupabaseAuthVerifier(project, key), {
      message: "Invalid trusted Supabase public configuration",
    });
  assert.doesNotThrow(
    () => new SupabaseAuthVerifier(project + "/", jwt("anon")),
  );
  for (const timeout of [0, -1, 15001, NaN, 1.5])
    assert.throws(() => auth(async () => json(), timeout), {
      message: "Invalid Auth timeout",
    });
});
test("missing, oversized and header-injection tokens never reach HTTP", async () => {
  let calls = 0;
  const verifier = auth(async () => {
    calls++;
    return json();
  });
  for (const token of [
    "",
    "x".repeat(8193),
    "Bearer token",
    "PRIVATE\r\nX: value",
    "a,b",
    "a\tb",
  ])
    assert.equal(await verifier.verify(token, signal()), null);
  assert.equal(calls, 0);
});
for (const status of [401, 403])
  test(`Auth ${status} denies before limiter/context/receipt/provider and cancels without reading details`, async () => {
    let cancelled = false;
    const state = setup();
    state.deps.auth = auth(
      async () =>
        new Response(
          new ReadableStream({
            cancel() {
              cancelled = true;
              return new Promise(() => {});
            },
          }),
          { status },
        ),
    );
    state.deps.limiter.consume = async () => {
      assert.fail("limiter ran before verified Auth");
    };
    const handler = createAiHttpHandler(
      new AiService(contracts, state.deps),
      "start_conversation",
    );
    const response = await handler(
      new Request(project, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: "Bearer PRIVATE",
        },
        body: JSON.stringify(fixtures.start_conversation_request),
      }),
    );
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), {
      code: "UNAUTHORIZED",
      message_vi: "Phiên đăng nhập không hợp lệ. Hãy đăng nhập lại.",
      retryable: false,
    });
    assert.equal(cancelled, true);
    assert.equal(state.calls.length, 0);
    assert.equal(state.store.rows.size, 0);
  });
test("upstream statuses and network failures fail closed with fixed errors and no retry", async () => {
  for (const status of [204, 301, 302, 400, 404, 429, 500, 503]) {
    let calls = 0;
    const verifier = auth(async () => {
      calls++;
      return new Response(status === 204 ? null : "PRIVATE", { status });
    });
    await fails(
      verifier.verify("token", signal()),
      status === 429 ? "RATE_LIMITED" : "NETWORK_UNAVAILABLE",
    );
    assert.equal(calls, 1);
  }
  await fails(
    auth(async () => {
      throw new Error("PRIVATE token");
    }).verify("token", signal()),
  );
});
test("redirected or different-project responses cannot authorize", async () => {
  for (const field of ["redirected", "url"] as const) {
    const response = json();
    Object.defineProperty(response, field, {
      value:
        field === "redirected" ? true : "https://other.invalid/auth/v1/user",
    });
    await fails(auth(async () => response).verify("token", signal()));
    assert.equal(response.body?.locked, false);
  }
});
test("malformed user, wrong audience, malformed/BOM JSON and invalid UTF-8 fail closed", async () => {
  for (const value of [
    null,
    [],
    {},
    { id: userA },
    { ...user(), id: "bad" },
    { ...user(), aud: "service_role" },
    { ...user(), aud: ["authenticated"] },
    { user: user() },
  ])
    await fails(auth(async () => json(value)).verify("token", signal()));
  for (const payload of [
    encode(""),
    encode("{"),
    encode("\ufeff" + JSON.stringify(user())),
    new Uint8Array([0xc0, 0xaf]),
    new Uint8Array([0xe3, 0x81]),
  ])
    await fails(
      auth(
        async () =>
          new Response(payload, {
            headers: { "content-type": "application/json" },
          }),
      ).verify("token", signal()),
    );
  await fails(
    auth(async () => new Response(JSON.stringify(user()))).verify(
      "token",
      signal(),
    ),
  );
});
test("actual streamed64KiB limit accepts exact boundary and split UTF-8; ignores forged length", async () => {
  const base = JSON.stringify({ ...user(), display_name: "日本語" });
  const bytes = encode(base + " ".repeat(65536 - encode(base).byteLength));
  let offset = 0;
  const response = new Response(
    new ReadableStream<Uint8Array>({
      pull(controller) {
        if (offset === bytes.length) controller.close();
        else controller.enqueue(bytes.slice(offset, ++offset));
      },
    }),
    { headers: { "content-type": "application/json", "content-length": "1" } },
  );
  assert.deepEqual(await auth(async () => response).verify("token", signal()), {
    id: userA,
  });
  assert.equal(response.body?.locked, false);
  for (const length of [null, "1"]) {
    const headers: Record<string, string> = {
      "content-type": "application/json",
    };
    if (length) headers["content-length"] = length;
    await fails(
      auth(
        async () => new Response(encode(base + " ".repeat(65536)), { headers }),
      ).verify("token", signal()),
    );
  }
});
test("failed reads are redacted and reader lock released", async () => {
  const response = new Response(
    new ReadableStream({
      start(controller) {
        controller.error(new Error("PRIVATE"));
      },
    }),
    { headers: { "content-type": "application/json" } },
  );
  await fails(auth(async () => response).verify("token", signal()));
  assert.equal(response.body?.locked, false);
});
test("pre-abort invokes no fetch and removes listeners", async () => {
  const controller = new AbortController();
  controller.abort("PRIVATE");
  await fails(
    auth(async () => {
      assert.fail("pre-aborted fetch");
    }).verify("token", controller.signal),
  );
  assert.equal(getEventListeners(controller.signal, "abort").length, 0);
});
test("deadline bounds ignored fetch abort; late response is cancelled without reading", async () => {
  let resolve!: (response: Response) => void;
  let cancelled = false;
  const controller = new AbortController();
  const result = auth(
    async () =>
      new Promise<Response>((r) => {
        resolve = r;
      }),
    5,
  ).verify("token", controller.signal);
  await fails(result);
  resolve(
    new Response(
      new ReadableStream({
        cancel() {
          cancelled = true;
          return new Promise(() => {});
        },
      }),
    ),
  );
  await setImmediate();
  assert.equal(cancelled, true);
  assert.equal(getEventListeners(controller.signal, "abort").length, 0);
});
test("caller abort bounds uncooperative fetch and handles synchronous abort/rejection", async () => {
  const controller = new AbortController();
  await fails(
    auth(async () => {
      controller.abort("PRIVATE");
      throw new Error("PRIVATE");
    }).verify("token", controller.signal),
  );
  await setImmediate();
  assert.equal(getEventListeners(controller.signal, "abort").length, 0);
});
test("deadline bounds stalled body and never awaits source cancellation", async () => {
  let cancelled = false;
  const response = new Response(
    new ReadableStream({
      cancel() {
        cancelled = true;
        return new Promise(() => {});
      },
    }),
    { headers: { "content-type": "application/json" } },
  );
  await fails(auth(async () => response, 5).verify("token", signal()));
  assert.equal(cancelled, true);
  assert.equal(response.body?.locked, false);
});
test("caller abort during body rejects identity and cleans caller listener", async () => {
  const controller = new AbortController();
  const response: Response = new Response(
    new ReadableStream(
      {
        pull() {
          assert.equal(response.body?.locked, true);
          controller.abort("PRIVATE");
        },
      },
      { highWaterMark: 0 },
    ),
    { headers: { "content-type": "application/json" } },
  );
  await fails(auth(async () => response).verify("token", controller.signal));
  assert.equal(getEventListeners(controller.signal, "abort").length, 0);
  assert.equal(response.body?.locked, false);
});
test("monotonic deadline rejects synchronous pull that starves timers", async () => {
  const response = new Response(
    new ReadableStream({
      pull(controller) {
        const start = performance.now();
        while (performance.now() - start < 15) {
          /* TEST ONLY hostile pull. */
        }
        controller.enqueue(encode(JSON.stringify(user())));
        controller.close();
      },
    }),
    { headers: { "content-type": "application/json" } },
  );
  await fails(auth(async () => response, 5).verify("token", signal()));
});
test("empty chunk flood is bounded even without bytes", async () => {
  let pulls = 0;
  const response = new Response(
    new ReadableStream({
      pull(controller) {
        pulls++;
        controller.enqueue(new Uint8Array());
      },
    }),
    { headers: { "content-type": "application/json" } },
  );
  await fails(auth(async () => response).verify("token", signal()));
  assert.ok(pulls <= 65539);
  assert.equal(response.body?.locked, false);
});
test("concurrent accounts and later Auth rejection recheck HTTP without identity/session cache", async () => {
  let calls = 0;
  const seen: string[] = [];
  const verifier = auth(async (_url, init) => {
    const call = ++calls;
    const bearer = new Headers(init?.headers).get("authorization")!;
    seen.push(bearer);
    await setImmediate();
    if (call > 2) return json({ detail: "PRIVATE" }, 401);
    return json(user(bearer === "Bearer A" ? userA : userB));
  });
  const [a, b] = await Promise.all([
    verifier.verify("A", signal()),
    verifier.verify("B", signal()),
  ]);
  assert.deepEqual(a, { id: userA });
  assert.deepEqual(b, { id: userB });
  assert.equal(await verifier.verify("A", signal()), null);
  assert.deepEqual(seen, ["Bearer A", "Bearer B", "Bearer A"]);
});
test("service uses Auth UUID as limiter/context/receipt owner; token never reaches provider", async () => {
  const state = setup();
  state.deps.auth = auth(async () => json(user(userB)));
  const owners: string[] = [];
  state.deps.limiter.consume = async (owner) => {
    owners.push(owner);
    return true;
  };
  const prepare = state.deps.context.prepare;
  state.deps.context.prepare = async (...args) => {
    owners.push(args[0]);
    return prepare(...args);
  };
  const result = await new AiService(contracts, state.deps).execute(
    "start_conversation",
    "PRIVATE",
    JSON.stringify(fixtures.start_conversation_request),
  );
  assert.equal(result.ok, true);
  assert.deepEqual(owners, [userB, userB]);
  assert.equal(state.calls.length, 1);
  assert.ok(!JSON.stringify(state.calls).includes("PRIVATE"));
  assert.equal(state.store.rows.size, 1);
  assert.ok(
    [...state.store.rows.keys()].every((k) => k.startsWith(userB + "/")),
  );
});
test("successful Auth cleans listeners and aborts only its private completed signal", async () => {
  const parent = new AbortController();
  let child!: AbortSignal;
  const verifier = auth(async (_url, init) => {
    child = init!.signal!;
    return json();
  });
  assert.deepEqual(await verifier.verify("token", parent.signal), {
    id: userA,
  });
  assert.equal(parent.signal.aborted, false);
  assert.equal(child.aborted, true);
  assert.equal(getEventListeners(parent.signal, "abort").length, 0);
});
test("Auth timeout and malformed response cannot advance service or dispatch after late HTTP", async () => {
  for (const late of [false, true]) {
    const state = setup();
    let resolve!: (response: Response) => void;
    let cancelled = false;
    state.deps.auth = auth(
      async () =>
        late
          ? new Promise<Response>((r) => {
              resolve = r;
            })
          : json({ id: userA, aud: "PRIVATE" }),
      5,
    );
    let limiterCalls = 0;
    state.deps.limiter.consume = async () => {
      limiterCalls++;
      return true;
    };
    const result = await new AiService(contracts, state.deps).execute(
      "start_conversation",
      "PRIVATE",
      JSON.stringify(fixtures.start_conversation_request),
    );
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "NETWORK_UNAVAILABLE");
      assert.ok(!JSON.stringify(result).includes("PRIVATE"));
    }
    if (late) {
      resolve(
        new Response(
          new ReadableStream({
            cancel() {
              cancelled = true;
            },
          }),
        ),
      );
      await setImmediate();
      assert.equal(cancelled, true);
    }
    assert.equal(limiterCalls, 0);
    assert.equal(state.store.rows.size, 0);
    assert.equal(state.calls.length, 0);
  }
});
