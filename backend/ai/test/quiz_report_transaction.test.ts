import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { BoundaryError } from "../src/contracts.ts";
import {
  submitQuizReportInTransaction as submit,
  type QuizReportTransaction,
  type QuizReportTransactionHost,
} from "../src/quiz_report_transaction.ts";
const root = new URL("../../../contracts/quiz/v1/", import.meta.url);
const schema = JSON.parse(readFileSync(new URL("schema.json", root), "utf8"));
const fixtures = JSON.parse(
  readFileSync(new URL("fixtures.json", root), "utf8"),
);
const encode = (v: unknown) => new TextEncoder().encode(JSON.stringify(v));
// TEST ONLY trace: no DB, Auth or persistence implementation.
function harness(
  f: (typeof fixtures)[number],
  overrides: Partial<QuizReportTransaction> = {},
) {
  const calls: string[] = [];
  const tx: QuizReportTransaction = {
    async replay() {
      calls.push("replay");
      return null;
    },
    async validateCurrentContent() {
      calls.push("content");
    },
    async store() {
      calls.push("store");
      return encode(f.response);
    },
    ...overrides,
  };
  const host: QuizReportTransactionHost = {
    async run(work) {
      calls.push("begin");
      try {
        const result = await work(tx);
        calls.push("commit");
        return result;
      } catch (error) {
        calls.push("rollback");
        throw error;
      }
    },
  };
  return { calls, host };
}
test("quiz transaction validates new reports before commit", async () => {
  for (const f of fixtures) {
    const h = harness(f);
    const result = await submit(schema, encode(f.request), h.host);
    assert.deepEqual(result, f.response);
    assert.ok(Object.isFrozen(result));
    assert.deepEqual(h.calls, [
      "begin",
      "replay",
      "content",
      "store",
      "commit",
    ]);
  }
});
test("quiz replay skips current content and store", async () => {
  const f = fixtures[0];
  const h = harness(f, {
    async replay() {
      h.calls.push("replay");
      return encode(f.response);
    },
  });
  assert.deepEqual(await submit(schema, encode(f.request), h.host), f.response);
  assert.deepEqual(h.calls, ["begin", "replay", "commit"]);
});
test("quiz invalid ingress never opens transaction", async () => {
  const h = harness(fixtures[0]);
  await assert.rejects(
    submit(
      schema,
      encode({ ...fixtures[0].request, user_id: "forged" }),
      h.host,
    ),
    /^Error: VALIDATION_FAILURE$/,
  );
  assert.deepEqual(h.calls, []);
});
test("quiz lookup failure or unknown never authorizes store", async () => {
  for (const mode of ["throw", "unknown"]) {
    const h = harness(fixtures[0], {
      async replay() {
        h.calls.push("replay");
        if (mode === "throw") throw new Error("private SQL token");
        return undefined as unknown as null;
      },
    });
    await assert.rejects(
      submit(schema, encode(fixtures[0].request), h.host),
      /^Error: INTERNAL_ERROR$/,
    );
    assert.deepEqual(h.calls, ["begin", "replay", "rollback"]);
  }
});
test("quiz conflict/content errors rollback with safe reconstructed errors", async () => {
  for (const phase of ["replay", "validateCurrentContent"] as const) {
    const error = new BoundaryError(
      phase === "replay" ? "SYNC_CONFLICT" : "VALIDATION_FAILURE",
    );
    error.message = "private SQL token";
    const h = harness(fixtures[0], {
      async [phase]() {
        h.calls.push("failure");
        throw error;
      },
    });
    await assert.rejects(
      submit(schema, encode(fixtures[0].request), h.host),
      new RegExp(`^Error: ${error.code}$`),
    );
    assert.ok(!h.calls.includes("store"));
    assert.equal(h.calls.at(-1), "rollback");
  }
});
test("quiz malformed replay/store responses rollback before commit", async () => {
  for (const phase of ["replay", "store"] as const) {
    const h = harness(fixtures[0], {
      async [phase]() {
        h.calls.push("bad-response");
        return encode({ ...fixtures[0].response, correct_count: 99 });
      },
    });
    await assert.rejects(
      submit(schema, encode(fixtures[0].request), h.host),
      /^Error: INTERNAL_ERROR$/,
    );
    assert.equal(h.calls.at(-1), "rollback");
    assert.ok(!h.calls.includes("commit"));
    if (phase === "replay") assert.ok(!h.calls.includes("content"));
  }
});
test("quiz captures bytes before await and does not hide commit failure", async () => {
  const f = fixtures[0];
  const raw = encode(f.request);
  const h = harness(f, {
    async replay(request) {
      await Promise.resolve();
      raw.fill(0);
      assert.deepEqual(request, f.request);
      const first = request.answers[0];
      assert.ok(first);
      assert.ok(Object.isFrozen(first.choices));
      return null;
    },
  });
  assert.deepEqual(await submit(schema, raw, h.host), f.response);
  await assert.rejects(
    submit(schema, encode(f.request), {
      async run(work) {
        await h.host.run(work);
        throw new Error("commit SQL token");
      },
    }),
    /^Error: INTERNAL_ERROR$/,
  );
});

test("quiz pre-cancelled operation does not open a transaction or leak reason", async () => {
  const controller = new AbortController();
  controller.abort("private token");
  const h = harness(fixtures[0]);
  await assert.rejects(
    submit(schema, encode(fixtures[0].request), h.host, controller.signal),
    /^Error: NETWORK_UNAVAILABLE$/,
  );
  assert.deepEqual(h.calls, []);
});

test("quiz cancellation at delayed callback or awaited phases stops subsequent work", async () => {
  for (const phase of ["begin", "replay", "content", "store"] as const) {
    const controller = new AbortController();
    const calls: string[] = [];
    const cancel = async (current: string) => {
      calls.push(current);
      await Promise.resolve();
      if (current === phase) controller.abort("private token");
    };
    const host: QuizReportTransactionHost = {
      async run(work, signal) {
        assert.equal(signal, controller.signal);
        await cancel("begin");
        try {
          const result = await work({
            async replay() {
              await cancel("replay");
              return null;
            },
            async validateCurrentContent() {
              await cancel("content");
            },
            async store() {
              await cancel("store");
              return encode(fixtures[0].response);
            },
          });
          calls.push("commit");
          return result;
        } catch (error) {
          calls.push("rollback");
          throw error;
        }
      },
    };
    await assert.rejects(
      submit(schema, encode(fixtures[0].request), host, controller.signal),
      /^Error: NETWORK_UNAVAILABLE$/,
    );
    const order = ["begin", "replay", "content", "store"];
    assert.deepEqual(calls, [
      ...order.slice(0, order.indexOf(phase) + 1),
      "rollback",
    ]);
  }
});

test("quiz cancelled replay and late committed response never publish success", async () => {
  for (const phase of ["replay", "commit"] as const) {
    const controller = new AbortController();
    const f = fixtures[0];
    const calls: string[] = [];
    const host: QuizReportTransactionHost = {
      async run(work) {
        try {
          const result = await work({
            async replay() {
              calls.push("replay");
              await Promise.resolve();
              if (phase === "replay") controller.abort();
              return encode(f.response);
            },
            async validateCurrentContent() {
              assert.fail("replay content");
            },
            async store() {
              assert.fail("replay store");
            },
          });
          calls.push("commit");
          controller.abort();
          return result;
        } catch (error) {
          calls.push("rollback");
          throw error;
        }
      },
    };
    await assert.rejects(
      submit(schema, encode(f.request), host, controller.signal),
      /^Error: NETWORK_UNAVAILABLE$/,
    );
    assert.deepEqual(
      calls,
      phase === "replay" ? ["replay", "rollback"] : ["replay", "commit"],
    );
  }
});
