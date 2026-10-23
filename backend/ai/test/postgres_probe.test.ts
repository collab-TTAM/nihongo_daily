import { test } from "node:test";
import assert from "node:assert/strict";
import {
  failureKind,
  kinds,
  newMetrics,
  recordFailure,
  verifyProbeTransport,
  PROBE_SQL,
} from "../edge/postgres_probe.ts";
import type {
  PostgresConnection,
  PostgresResult,
} from "../src/postgres_connection.ts";

test("fixture PostgreSQL diagnostic ledger is bounded deduplicated and never returns raw exception fields", () => {
  const m = newMetrics();
  for (const code of [
    "ECONNREFUSED",
    "ECONNRESET",
    "ETIMEDOUT",
    "28P01",
    "PROBE_PROTOCOL",
    "PRIVATE URL/password/bearer",
  ]) {
    const error = Object.assign(Error("PRIVATE provider text token=secret"), {
      code,
      detail: "PRIVATE SQL",
    });
    recordFailure(m, "connect", error);
    recordFailure(m, "connect", error);
    assert.ok(kinds.includes(failureKind(error)));
  }
  assert.equal(
    failureKind(new Error("PRIVATE not supported URL/key")),
    "unsupported",
  );
  assert.equal(
    failureKind(new Error("PRIVATE requires permission URL/key")),
    "permission",
  );
  assert.equal(
    failureKind(new Error("PRIVATE not implemented URL/key")),
    "unsupported",
  );
  assert.equal(
    failureKind(
      Object.assign(Error("PRIVATE requires env access"), {
        name: "NotCapable",
      }),
    ),
    "permission",
  );
  assert.equal(
    failureKind(new Error("PRIVATE global is not defined")),
    "missing-global",
  );
  assert.equal(
    failureKind({
      get code() {
        throw Error("PRIVATE getter");
      },
    }),
    "unknown",
  );
  for (let i = 0; i < 100; i++)
    recordFailure(m, "query", { code: "ECONNRESET" });
  for (const phase of ["idle", "probe", "commit", "close"] as const)
    recordFailure(m, phase, Error("PRIVATE"));
  assert.equal(m.failures.length, 8);
  assert.equal(JSON.stringify(m).includes("PRIVATE"), false);
  assert.equal(JSON.stringify(m).includes("secret"), false);
});
function connection(result: PostgresResult, fail?: "connect" | "query") {
  const calls: string[] = [];
  const c: PostgresConnection = {
    connect: async () => {
      calls.push("connect");
      if (fail === "connect") throw Error("PRIVATE connect");
    },
    query: async (sql, values) => {
      calls.push(sql);
      assert.equal(values, undefined);
      if (fail === "query") throw Error("PRIVATE query");
      return result;
    },
    close: () => {
      calls.push("close");
    },
  };
  return { calls, factory: () => c };
}
const good = (): PostgresResult => ({
  command: "SELECT",
  rowCount: 1,
  rows: [{ probe: 1 }],
});
test("fixture transport preflight requires exact SQL response before success and closes its owned connection", async () => {
  const c = connection(good());
  await verifyProbeTransport(c.factory);
  assert.deepEqual(c.calls, ["connect", PROBE_SQL, "close"]);
  for (const result of [
    { ...good(), command: "COMMIT" },
    { ...good(), rowCount: null },
    { ...good(), rows: [] },
    { ...good(), rows: [{ probe: "1" }] },
  ]) {
    const c = connection(result);
    await assert.rejects(
      verifyProbeTransport(c.factory),
      (error: unknown) => failureKind(error) === "protocol",
    );
    assert.equal(c.calls.at(-1), "close");
    assert.equal(c.calls.filter((x) => x === "close").length, 1);
  }
});
test("fixture transport preflight never queries after connect failure and closes on query failure without success", async () => {
  for (const phase of ["connect", "query"] as const) {
    const c = connection(good(), phase);
    await assert.rejects(verifyProbeTransport(c.factory), /PRIVATE/);
    assert.deepEqual(
      c.calls,
      phase === "connect"
        ? ["connect", "close"]
        : ["connect", PROBE_SQL, "close"],
    );
  }
  await assert.rejects(
    verifyProbeTransport(() => {
      throw Error("PRIVATE constructor");
    }),
    /PRIVATE constructor/,
  );
});
