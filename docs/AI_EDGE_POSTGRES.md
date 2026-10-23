# TEST ONLY full PostgreSQL assembly in Edge user isolates (#31)

This separate compatibility probe bundles `assemblePostgresAiHandlers` with the
original strict Contracts/Ajv, SupabaseAuthVerifier, pg8.23.1 quota/text/atomic
conversation drivers, AiService and all five fixed HTTP handlers. It retains the
existing memory-port Edge7 probe unchanged. Neither probe installs an app endpoint,
Supabase function, default binding, production migration or live provider.

## Actual boundary and fixed fixtures

Deno2.9.6 builds a self-contained checked ESM bundle from the existing npm-ci manual
node_modules and unchanged package-lock. The new task `bundle:edge-postgres` forbids
remote resolution and bundles npm/static schema/fixtures. Local observed build:
148 modules/581994 bytes, SHA256
`afd0290c6945909cced1d1abb98477de6cce874042d796979e390a80a647ff79`;
bundle compilation is not actual Edge execution. The direct registry download
for the Deno SDK internal esbuild helper was unavailable locally; the exact
0.25.5 helper was obtained through npm and copied atomically to the SDK cache.
No application dependency/lock, bundled source or CI resolution was overridden.
`edge/postgres_main.ts` uses the already pinned v1.77.4 userWorkers.create/fetch API
with fixed `/probe/worker`, no npm/remote loading, no forwarded environment, bounded
CPU/wall time and 150 MiB worker memory. The main/user crossing is real, not a
standalone main worker running service logic.

`edge/postgres_worker.ts` calls the actual composition seam. Each database phase
owns a fresh pg Client and the unchanged short SQL transaction. Test-only factories
use 127.0.0.1:5432/nihongo_test with disposable postgres credentials and plaintext;
there is no URL/key/environment input or production TLS-off option. Actual COMMIT
must reach ReadyForQuery idle before the test simulates a lost delivery. Provider
entry asserts every previously acquired connection closed. The host separately
queries pg_stat_activity while a provider is held, requiring no transaction open.
Actual SupabaseAuthVerifier receives a fixed injected Auth HTTP fixture. Provider
results and lost delivery are test fixtures, never paid calls or real JWT proof.

Seven original fixture accounts keep each scenario below the unchanged shared
burst10 quota; quota is neither disabled nor reset. SQL fixture rows are seeded
only after the runner verifies the exact disposable TEST_DATABASE_URL. UUIDs from
HTTP responses are strictly checked before host observation SQL. No arbitrary SQL,
worker path, production config or learner request can select a database. The
fixtures are not curriculum exports and do not modify Pro/N4 content.

## Containers and mandatory evidence

`scripts/verify_edge_postgres.py` pulls the same official fixed v1.77.4 image,
records registry digest/local immutable ID and strict CLI version, then starts two
independent capped containers and replaces the first with a fresh container.
Only captured container IDs are removed, in bounded cleanup; no broad pruning.
No host environment is passed, bundles are mounted read-only, capabilities dropped,
no-new-privileges enabled, each container capped at 512 MiB/2 CPU/128 PIDs.

The disposable Actions database job uses Linux host networking solely to reach
its fixed loopback pg service. The main HTTP listener is explicitly 127.0.0.1
with a selected ephemeral port; pinned CLI `--ip`/`--port` are checked against
[v1.77.4 flags.rs](https://github.com/supabase/edge-runtime/blob/v1.77.4/cli/src/flags.rs).
This is an isolated CI topology, not a hosted network/deployment recommendation.
Readiness, HTTP, SQL and Docker commands all have finite bounds; no AI mutation
is automatically retried. Polling observes fixture readiness only.

The new mandatory database gate `Verify bundled Edge PostgreSQL assembly` runs
after retained Node native8 and Deno native50 checks; all original steps remain.
`Publish Edge PostgreSQL assembly evidence` must upload ai-edge-postgres-assembly
with failure on missing file. QA rejects either step missing/skipped/failed/pending.
Evidence contains source/checkout heads, image identity, bundle hash, runtime
metadata and seven group labels; it logs no bearer/claim/provider body. Runtime
fingerprint uses the exact branded bootstrap tuple documented in AI_EDGE_USER_WORKER;
reported V8/TypeScript labels are not direct engine/compiler measurements.

Seven groups require actual HTTP and separate SQL assertions:

1. Both real user isolates report the pinned runtime and fixture lane.
2. All five fixed operations retain wire behavior; actual ended session, ordered
   message slots0/1/2 and three completed receipts/reservations persist together.
3. Foreign owner gets existing NOT_FOUND404, forged owner/invalid Auth fail; another
   instance replays original lifecycle after source retirement/profile change
   without provider dispatch.
4. Actual acquire/complete COMMIT succeeds before simulated lost delivery; public
   response fails safely and separate SQL shows PENDING/COMPLETED respectively.
5. Malformed output leaves PENDING, no public session write or raw fixture leak.
6. Concurrent HTTP across independent isolates produces one dispatch; pending
   reservation is durable and no SQL transaction remains during provider wait.
7. Fresh-container restart returns committed originals and keeps uncertain pending
   unavailable, with zero dispatch and all acquired connections closed.

## Observed parent and remaining limits

Parent source c7ec35bb546752e9c883864d58207ed1b6a89aad has observed
[CI39870924303](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39870924303),
latest attempt1 completed/success/allfive jobs/every step/no skips. Completed
database log proves native full assembly8/8 on Node24 and combined native50/50 on
Deno2.9.6. Those native results are independent of this new actual-Edge SQL probe.

Local Docker/PostgreSQL is absent: the new seven groups must execute successfully
in NEW exact-head Actions before they count as Edge PostgreSQL evidence. Local
format/type/bundle/Node/Deno/QA checks cannot substitute. The production verified
TLS factory, SQL/RLS/grants, frozen contracts, old tests and default app are unchanged.
Even a successful official-container fixture run does not prove hosted TLS/CA,
Supabase JWT signatures/issuer/expiry/PostgREST, real authenticated upstream lookup,
approved provider/cost/voice, proxy disconnect behavior or learner acceptance.
All14 release groups pending; #31 open/#41 draft; no Personal Alpha sign-off.


## Cold CommonJS bootstrap correction (2026-10-23)

Exact source8ef704f7dc8eadfb9915698391a3095f650af6e5
[CI39877892790](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39877892790)
latest attempt1 completed/failure. AI/repo-sanity/windows passed, but database failed
at new Edge PostgreSQL startup; artifact/profile projections and Flutter skipped.
Completed DB log still proves native Node8 and Deno50 passed. This is not a full-CI
pass or completion of any new actual Edge/SQL group.

The actual user isolate fails while evaluating pinned postgres-bytea, before any
fixture seeding: `ReferenceError: Buffer is not defined`; metadata GET returns502.
Bundled CommonJS dependencies lack the npm loader's global setup. Pinned pg/pgpass
sources also contain unbound process access. A type-correct ESM bundle alone did
not establish that runtime initialization order.

New TEST ONLY postgres_bootstrap.ts imports an explicit initializer using actual
node:buffer Buffer and node:process. It defines only absent globals, preserves any
existing runtime bindings and lets forbidden definitions fail. It copies no host
environment, installs no fake process/SQL/provider and changes no runtime permission.
After initialization it dynamically imports unchanged postgres_worker.ts. Deno's
checked bundler inlines that dynamic dependency graph; no runtime network/npm/module
path is enabled. Only bundle:edge-postgres's entry changes; production source,
verified TLS factories, SQL/roles, old worker/probe/CI assertions and defaults stay
unchanged.

One new cold CommonJS regression runs with the existing Node/Deno unit globs and
unchanged permissions. It synchronously removes the two globals, reproduces the
actual pinned postgres-bytea import failure, initializes actual Node builtins, then
loads actual pg and verifies its real bytea parser returns UTF8/binary expected
bytes. It also verifies repeated initialization preserves existing binding
identities/descriptors; a finally block restores original global descriptors before
yielding to the harness. No database/network/child process is used. Observed
Node181/181 and Deno181/181 passed; this is module compatibility, not actual Edge.

The seven actual Edge/PostgreSQL groups, runtime fingerprint/SQL assertions,
no-redispatch/quota fences and evidence publication gates remain mandatory and
unchanged. New exact-head official-container execution must pass; no hosted JWT,
TLS/CA/PostgREST/provider/authenticated lookup/learner acceptance is inferred.


Local corrected build: 150 modules/594983 bytes, SHA256
`df6ba27afc49b40be3589b2186514faf1b2f80158e5c04056ee86a544ce40de5`.
Separate bundle inspection confirms installPostgresNodeGlobals executes before
inlined init_postgres_worker. An additional local standalone Deno cold import,
with both globals absent and Deno.serve intercepted, returned fixture metadata200
with zero DB/provider calls under denied net/write/run/ffi/sys and bounded read.
That checks bundled module order only; it is not a real supervisor/user-isolate,
PostgreSQL or hosted-service test. Direct helper registry unavailable locally;
exact npm esbuild0.25.5 restored to SDK cache, no application lock/CI override.
