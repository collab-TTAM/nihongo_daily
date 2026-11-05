// TEST ONLY capability/settlement traces, not native SQL rollback or Auth proof.
import { test } from "node:test";
import assert from "node:assert/strict";
import { BoundaryError } from "../src/contracts.ts";
import { withQuizReportTransactionScope } from "../src/quiz_report_scope.ts";
import type { QuizReportTransaction } from "../src/quiz_report_transaction.ts";
import type { QuizReportRequest } from "../src/quiz_report.ts";
const request = {} as QuizReportRequest; // Scope is independent of wire decoding.
const bytes = new Uint8Array([1]);
function deferred() {
  let resolve!: () => void;
  const promise = new Promise<void>((r) => {
    resolve = r;
  });
  return { promise, resolve };
}
function source(trace: string[]): QuizReportTransaction {
  return {
    async replay() {
      trace.push("replay");
      return null;
    },
    async validateCurrentContent() {
      trace.push("content");
    },
    async store() {
      trace.push("store");
      return bytes;
    },
  };
}
test("quiz scope permits awaited sequence and revokes every escaped capability", async () => {
  const trace: string[] = [];
  let escaped!: QuizReportTransaction;
  const value = await withQuizReportTransactionScope(
    source(trace),
    async (tx) => {
      escaped = tx;
      assert.ok(Object.isFrozen(tx));
      assert.equal(await tx.replay(request), null);
      await tx.validateCurrentContent(request);
      return tx.store(request);
    },
  );
  assert.equal(value, bytes);
  for (const method of ["replay", "validateCurrentContent", "store"] as const)
    await assert.rejects(escaped[method](request), /^Error: INTERNAL_ERROR$/);
  assert.deepEqual(trace, ["replay", "content", "store"]);
});
test("quiz scope revokes after callback failure and redacts private errors", async () => {
  const trace: string[] = [];
  let escaped!: QuizReportTransaction;
  await assert.rejects(
    withQuizReportTransactionScope(source(trace), async (tx) => {
      escaped = tx;
      throw new Error("private token");
    }),
    /^Error: INTERNAL_ERROR$/,
  );
  await assert.rejects(escaped.store(request), /^Error: INTERNAL_ERROR$/);
  assert.deepEqual(trace, []);
});
test("quiz scope rejects concurrent calls without dispatch and poisons caught failures", async () => {
  const trace: string[] = [];
  const gate = deferred();
  const ports = source(trace);
  ports.replay = async () => {
    trace.push("replay");
    await gate.promise;
    return null;
  };
  await assert.rejects(
    withQuizReportTransactionScope(ports, async (tx) => {
      const first = tx.replay(request);
      await assert.rejects(tx.store(request), /^Error: INTERNAL_ERROR$/);
      gate.resolve();
      await first;
      await assert.rejects(
        tx.validateCurrentContent(request),
        /^Error: INTERNAL_ERROR$/,
      );
    }),
    /^Error: INTERNAL_ERROR$/,
  );
  assert.deepEqual(trace, ["replay"]);
});
test("quiz scope drains forgotten work before settlement and rejects late calls", async () => {
  for (const throws of [false, true]) {
    const gate = deferred();
    const started = deferred();
    const trace: string[] = [];
    const ports = source(trace);
    ports.store = async () => {
      trace.push("store");
      started.resolve();
      await gate.promise;
      trace.push("settled");
      return bytes;
    };
    let escaped!: QuizReportTransaction;
    let ended = false;
    const scope = withQuizReportTransactionScope(ports, async (tx) => {
      escaped = tx;
      void tx.store(request);
      if (throws) throw new Error("private");
    });
    const checked = assert
      .rejects(scope, /^Error: INTERNAL_ERROR$/)
      .then(() => {
        ended = true;
      });
    await started.promise;
    await Promise.resolve();
    assert.equal(ended, false);
    await assert.rejects(escaped.replay(request), /^Error: INTERNAL_ERROR$/);
    gate.resolve();
    await checked;
    assert.deepEqual(trace, ["store", "settled"]);
  }
});
test("quiz scope retains safe port failure even if callback swallows rejection", async () => {
  const trace: string[] = [];
  const ports = source(trace);
  ports.replay = async () => {
    throw new BoundaryError("SYNC_CONFLICT");
  };
  await assert.rejects(
    withQuizReportTransactionScope(ports, async (tx) => {
      await assert.rejects(tx.replay(request), /^Error: SYNC_CONFLICT$/);
      await assert.rejects(tx.store(request), /^Error: SYNC_CONFLICT$/);
    }),
    /^Error: SYNC_CONFLICT$/,
  );
  assert.deepEqual(trace, []);
});

test("quiz scope never dispatches queued ports after synchronous callback failure", async () => {
  for (const method of ["replay", "validateCurrentContent", "store"] as const) {
    const trace: string[] = [];
    let queued!: Promise<unknown>;
    await assert.rejects(
      withQuizReportTransactionScope(source(trace), (tx) => {
        queued = tx[method](request);
        throw new Error("private callback failure");
      }),
      /^Error: INTERNAL_ERROR$/,
    );
    assert.deepEqual(trace, []);
    await assert.rejects(queued, /^Error: INTERNAL_ERROR$/);
  }
});
