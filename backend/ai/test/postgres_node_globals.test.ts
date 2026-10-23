import { test } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { Buffer } from "node:buffer";
import process from "node:process";
import { installPostgresNodeGlobals } from "../edge/postgres_node_globals.ts";

test("cold bundled CommonJS pg graph needs real Node globals before evaluation and preserves runtime bindings", () => {
  const require = createRequire(import.meta.url);
  const originals = ["Buffer", "process"].map(
    (name) =>
      [name, Object.getOwnPropertyDescriptor(globalThis, name)] as const,
  );
  try {
    for (const [name] of originals)
      assert.equal(Reflect.deleteProperty(globalThis, name), true);
    // Actual pinned postgres-bytea module fails at import exactly like the Edge log.
    // This is synchronous: restore globals before yielding to the test harness.
    assert.throws(() => require("postgres-bytea"), /Buffer is not defined/);
    installPostgresNodeGlobals();
    assert.equal(Reflect.get(globalThis, "Buffer"), Buffer);
    assert.equal(Reflect.get(globalThis, "process"), process);
    const pg = require("pg") as {
      Client: unknown;
      types: { getTypeParser(id: number): (text: string) => unknown };
    };
    assert.equal(typeof pg.Client, "function");
    const decoded = pg.types.getTypeParser(17)("\\x41e38182");
    assert.ok(Buffer.isBuffer(decoded));
    assert.equal(decoded.toString("utf8"), "Aあ");
    assert.deepEqual([...decoded], [0x41, 0xe3, 0x81, 0x82]);
    // Re-entry must preserve bindings already supplied by the runtime/host.
    const supplied = {
      Buffer: Object.freeze({ marker: "runtime-buffer" }),
      process: Object.freeze({ marker: "runtime-process" }),
    };
    const before = Object.getOwnPropertyDescriptors(supplied);
    installPostgresNodeGlobals(supplied);
    installPostgresNodeGlobals(supplied);
    assert.deepEqual(Object.getOwnPropertyDescriptors(supplied), before);
  } finally {
    for (const [name, descriptor] of originals) {
      if (descriptor) Object.defineProperty(globalThis, name, descriptor);
      else Reflect.deleteProperty(globalThis, name);
    }
  }
});
