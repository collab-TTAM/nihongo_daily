// TEST ONLY CommonJS bootstrap. Actual Node builtins, no stubs or host env copy.
import { Buffer } from "node:buffer";
import process from "node:process";

export function installPostgresNodeGlobals(target: object = globalThis): void {
  for (
    const [name, value] of [["Buffer", Buffer], ["process", process]] as const
  ) {
    // Preserve an existing runtime binding. A forbidden definition throws;
    // never hide bootstrap failure or replace it with simulated SQL success.
    if (Reflect.get(target, name) === undefined) {
      Object.defineProperty(target, name, {
        value,
        writable: true,
        configurable: true,
      });
    }
  }
}
