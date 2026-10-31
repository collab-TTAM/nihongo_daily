// TEST ONLY loopback server/Auth/provider/memory receipts; no hosted/Edge proof.
import assert from "node:assert/strict";
import { createAiHttpHandler } from "../src/http.ts";
import { AiService } from "../src/service.ts";
import { operations } from "../src/contracts.ts";
import type { Operation } from "../src/contracts.ts";
import type { item_ref } from "../src/wire.ts";
import { contracts, fixtures, setup } from "../test/support.ts";

function boundary(op: Operation = "start_conversation", timeout = 1000) {
  const state = setup();
  const prepare = state.deps.context.prepare;
  const result = fixtures[`${op}_response`] as Record<string, unknown>;
  const refs: item_ref[] = [
    ...((result.srs_recommendations ?? []) as item_ref[]),
    ...["grammar_errors", "vocabulary_errors", "errors", "live_feedback"]
      .flatMap(
        (field) =>
          ((result[field] ?? []) as { item_refs: item_ref[] }[]).flatMap(
            (c) => c.item_refs,
          ),
      ),
  ];
  state.deps.context.prepare = async (...args) => ({
    ...(await prepare(...args)),
    allowedRefs: refs,
  });
  const handle = createAiHttpHandler(
    new AiService(contracts, state.deps),
    op,
    timeout,
  );
  const controller = new AbortController();
  const server = Deno.serve({
    hostname: "127.0.0.1",
    port: 0,
    signal: controller.signal,
    onListen: () => {},
  }, handle);
  return {
    ...state,
    server,
    url:
      `http://127.0.0.1:${server.addr.port}/untrusted?operation=finish_conversation`,
    close: async () => {
      controller.abort();
      await server.finished;
    },
  };
}
function post(body: BodyInit, signal?: AbortSignal): RequestInit {
  return {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer valid-A",
    },
    body,
    signal,
  };
}
async function barrier(ready: () => boolean) {
  const end = performance.now() + 1000;
  while (!ready() && performance.now() < end) {
    await new Promise((r) => setTimeout(r, 2));
  }
  assert.ok(ready(), "Deno loopback barrier did not arrive within bound");
}
Deno.test("pinned Deno denies external network secrets arbitrary files writes subprocess FFI and system permissions", async () => {
  assert.equal(Deno.version.deno, "2.9.6");
  for (
    const descriptor of [
      { name: "net", host: "example.invalid:443" },
      { name: "env", variable: "ND_TEST_SECRET" },
      { name: "read", path: "/etc/passwd" },
      { name: "write", path: "deno-denied.txt" },
      { name: "run" },
      { name: "ffi" },
      { name: "sys" },
    ] as const
  ) {
    assert.notEqual(
      (await Deno.permissions.query(descriptor)).state,
      "granted",
    );
  }
  assert.throws(() => Deno.env.get("ND_TEST_SECRET"), Deno.errors.NotCapable);
  await assert.rejects(
    Deno.readTextFile("/etc/passwd"),
    Deno.errors.NotCapable,
  );
  await assert.rejects(
    fetch("https://example.invalid/"),
    Deno.errors.NotCapable,
  );
});
Deno.test("actual Deno serve and fetch preserve all five original wire operations and fixed handler binding", async () => {
  for (const op of operations) {
    const s = boundary(op);
    try {
      const r = await fetch(
        s.url,
        post(JSON.stringify(fixtures[`${op}_request`])),
      );
      assert.equal(r.status, 200);
      assert.equal(r.headers.get("cache-control"), "no-store");
      assert.equal(r.headers.get("x-content-type-options"), "nosniff");
      assert.deepEqual(await r.json(), fixtures[`${op}_response`]);
      assert.equal(s.calls.length, 1);
      assert.equal(s.calls[0]!.operation, op);
      assert.equal(JSON.stringify(s.calls).includes("valid-A"), false);
    } finally {
      await s.close();
    }
  }
});
Deno.test("actual Deno HTTP rejects unauthenticated malformed owner and wrong method without provider", async () => {
  const s = boundary();
  try {
    const unauth = await fetch(s.url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    });
    assert.equal(unauth.status, 401);
    await unauth.body?.cancel();
    const wrong = await fetch(s.url);
    assert.equal(wrong.status, 405);
    assert.equal(wrong.headers.get("allow"), "POST");
    await wrong.body?.cancel();
    const malformed = await fetch(
      s.url,
      post(
        JSON.stringify({
          ...(fixtures.start_conversation_request as object),
          user_id: "forged",
        }),
      ),
    );
    assert.equal(malformed.status, 400);
    await malformed.body?.cancel();
    assert.equal(s.calls.length, 0);
    assert.equal(s.store.rows.size, 0);
  } finally {
    await s.close();
  }
});
Deno.test("actual Deno chunked multibyte request enforces streamed32KiB before Auth and dispatch", async () => {
  const s = boundary();
  let auth = 0;
  s.deps.auth.verify = async () => {
    auth++;
    assert.fail("Oversize must reject before Auth");
  };
  try {
    const source = new ReadableStream<Uint8Array>({
      start(controller) {
        const chunk = new TextEncoder().encode("界".repeat(100));
        for (let i = 0; i < 120; i++) controller.enqueue(chunk);
        controller.close();
      },
    });
    const r = await fetch(s.url, post(source));
    assert.equal(r.status, 413);
    assert.equal((await r.json()).code, "VALIDATION_FAILURE");
    assert.equal(auth, 0);
    assert.equal(s.calls.length, 0);
    assert.equal(s.store.rows.size, 0);
  } finally {
    await s.close();
  }
});
Deno.test("actual Deno HTTP deadline rejects late provider result without completion or redispatch", async () => {
  const s = boundary("start_conversation", 250);
  let providerCalls = 0;
  let release!: () => void;
  let privateSignal!: AbortSignal;
  s.deps.provider.generate = (_input, signal) => {
    providerCalls++;
    privateSignal = signal;
    return new Promise((resolve) => {
      release = () =>
        resolve(JSON.stringify(fixtures.start_conversation_response));
    });
  };
  try {
    const work = fetch(
      s.url,
      post(JSON.stringify(fixtures.start_conversation_request)),
    );
    await barrier(() => Boolean(release));
    const r = await work;
    assert.equal(r.status, 504);
    assert.equal((await r.json()).code, "PROVIDER_UNAVAILABLE");
    assert.equal(privateSignal.aborted, true);
    release();
    await new Promise((r) => setTimeout(r, 5));
    assert.equal(s.store.completions, 0);
    const retry = await fetch(
      s.url,
      post(JSON.stringify(fixtures.start_conversation_request)),
    );
    assert.equal(retry.status, 503);
    await retry.body?.cancel();
    assert.equal(providerCalls, 1);
    assert.equal(s.store.rows.size, 1);
    assert.equal(s.store.completions, 0);
  } finally {
    if (release) release();
    await s.close();
  }
});
Deno.test("actual Deno client disconnect aborts captured provider signal and fences late completion", async () => {
  const s = boundary("start_conversation", 1500),
    parent = new AbortController();
  let release!: () => void;
  let privateSignal!: AbortSignal;
  s.deps.provider.generate = (_input, signal) => {
    privateSignal = signal;
    return new Promise((resolve) => {
      release = () =>
        resolve(JSON.stringify(fixtures.start_conversation_response));
    });
  };
  try {
    const work = fetch(
      s.url,
      post(JSON.stringify(fixtures.start_conversation_request), parent.signal),
    );
    // Attach rejection handler before aborting the real TCP client.
    const rejected = assert.rejects(
      work,
      (error: unknown) =>
        error instanceof DOMException && error.name === "AbortError",
    );
    await barrier(() => Boolean(release));
    parent.abort();
    await rejected;
    await barrier(() => privateSignal.aborted);
    release();
    await new Promise((r) => setTimeout(r, 5));
    assert.equal(s.store.completions, 0);
  } finally {
    parent.abort();
    if (release) release();
    await s.close();
  }
});
