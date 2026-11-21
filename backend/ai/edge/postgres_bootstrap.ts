// TEST ONLY: initialize CommonJS globals BEFORE evaluating the pg dependency graph.
import { installPostgresNodeGlobals } from "./postgres_node_globals.ts";
installPostgresNodeGlobals();
// Dynamic import is inlined by the checked bundle; no runtime npm/remote loading.
await import("./postgres_worker.ts");
