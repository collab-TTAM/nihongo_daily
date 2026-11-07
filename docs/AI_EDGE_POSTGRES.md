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


## Transport preflight and bounded diagnostic stage (2026-10-23)

Exact d875fd335f3bd9ae843c705a7ed474220c591525
[CI39882989584](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39882989584)
latest attempt1 completed/failure. Both actual user isolates now initialize and
pass pinned metadata checks; SQL fixture seeding runs. This confirms the Buffer
boot correction in that scope. First assembled tutor request then returns503 with
empty safe container logs: its failure phase/root cause is still unknown. Native
Node8/Deno50 pass, but full new Edge/SQL groups, artifact/projections and Flutter
do not pass. No claim that the503 is fixed is made by this diagnostic increment.

New TEST ONLY postgres_probe.ts extracts the unchanged fixed pg factory from the
fixture worker, retaining disposable localhost config/timeouts/pipeline:false,
fresh ownership, COMMIT-idle fence and acquire/complete lost-delivery injection.
It adds bounded fixed phase/failure-kind metrics. Exceptions are rethrown to the
unchanged safe driver path; categories contain no raw message/code/stack/URL/token/
SQL/user input. At most eight distinct phase/kind pairs per fixture lane are stored.
Hostile getters map to unknown; no diagnostic can authorize success or a retry.
Production source/TLS/Auth/quota/default bindings are untouched.

GET /__probe/transport is TEST ONLY, immutable fixed SELECT1 through the same owned
factory. Real command SELECT/rowCount1/numeric probe1 plus actual pg idle
ReadyForQuery are required; connection closes in finally. No caller SQL/config,
Auth/provider request, quota mutation or application write occurs. The runner
requires it in each actual user isolate before seeding, and after a fresh-container
restart. This adds one transport group before the original seven full-handler
groups, which remain unchanged and mandatory. Successful transport never substitutes
for Auth/quota/context/receipt/COMMIT/concurrency/replay tests or hosted proof.

On failure the host fetches fixture metadata, strictly validates lane names, exact
fields, integer counters0..1000, phase/category enums and eight-pair bound before
printing only that snapshot. Unknown fields/raw error text are rejected, and
snapshot failure prints one fixed message without details. Both captured containers
still receive cleanup attempts. The prior empty logs now have a safe way to locate
construct/connect/query/commit failures without enabling raw exception logging.

Three new Node/Deno unit cases cover bounded redaction/deduplication/hostile getters,
checked preflight result+one close, and no query after connect failure/close on query
failure/constructor failure. One added QA test rejects unknown/private snapshot
fields/categories, booleans-as-counters and excessive sizes; snapshot exceptions
never leak their message. The existing getTransactionStatus executable QA anchor
moves to the extracted helper; the assertion is retained. All other old QA cases,
findings/gates, seven full Edge/SQL assertions and runtime permissions remain.
Local Node184/Deno184 and QA44 pass; this is fixture/logic assurance, not native
Edge transport execution. New exact-head official-container CI must run the actual
SELECT1 and complete eight groups before acceptance. All14 release groups pending.


## Actual constructor missing global alias (2026-10-23)

Exact parent464360edea1bca0e2e2869ced0f9716183e86918
[CI39889372926](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39889372926)
latest attempt1 completed/failure: actual SELECT1 preflight503 before seeding;
allowlisted snapshot proves construct/missing-global, opened0. AI/repo-sanity/windows
pass; database fails; Edge artifact/profile projections and Flutter skipped. Native
Node8/Deno50 pass independently; full Edge SQL acceptance remains pending.

The pinned pg8.23.1 Client constructor reads c.Promise || global.Promise after
module evaluation. TEST ONLY bootstrap now supplies absent global as actual
globalThis alongside the existing actual Buffer/process bindings, preserving any
runtime-supplied value and throwing on forbidden definitions. No Promise stub,
host environment copy or additional permissions. Checked inlined bundle still
initializes globals before its pg/worker graph. Production source/factories/TLS,
SQL/Auth/quota/receipt guards and all eight actual transport/full-handler groups
remain unchanged.

A new actual Client constructor regression deletes global, reproduces the precise
ReferenceError, restores the alias and verifies intrinsic Promise/not-connected
state before destroying its unconnected real socket. Synchronous finally restores
original global descriptors. Explicit hermetic constructor-only parameters avoid
environment access; no connect/query is made. Existing parser and preservation
assertions remain. Node185/Deno185 pass under unchanged unit permissions, QA44 pass.
Actual user-isolate SELECT1/ReadyForQuery/eight-group/SQL artifact success requires
NEW exact-head CI and is not claimed by constructor-only or bundle evidence. All14
release groups/hosted JWT/TLS/PostgREST/provider/voice/learner proof remain pending.

Local corrected checked bundle:151 modules/599374 bytes, SHA256
`bf62a857b3554b815c5fcd5fd52939eaaa2c59e0937ac143d8389d1da4423b81`.
SDK internal helper registry refused connection; exact npm esbuild0.25.5 verified
and atomically cached, then build passed. No application dependency/lock/CI change.
Separate diff review preserves the entire original bootstrap test except adding
the runtime-global preservation sentinel; production/SQL/old probe/CI/Pro files
byte-identical. Bundle order inspected: initializer before inlined worker graph.


## Observed eight-group success and distinct-event extension (2026-10-23)

Exact source2cc9987fbd5869b42d92999da39c3bc30e85a509
[CI39894048642](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39894048642),
latest attempt1 completed/success: complete allfive jobs/every step success/no skips.
Database120220214584 completed log proves native Node8/Deno50 and all eight actual
Edge PostgreSQL groups including fixed SELECT1/idle preflight, five-operation
lifecycle, owner denial, lost COMMIT delivery, malformed output, simultaneous
same-event fencing/no open transaction and fresh-container replay. This confirms
the global alias correction in that actual runtime/SQL scope. Artifact
ai-edge-postgres-assembly id12476550226 is non-expired/exact source head; archive
digest sha256:1e8bf982c971b0fdd30a67ed8fdcf4267ad1889ac431ee8b949ecf460df65b26.
Printed evidence reports source head2cc9987 /Actions merge checkoutdf52fc7, bundle
bf62a857b3554b815c5fcd5fd52939eaaa2c59e0937ac143d8389d1da4423b81 and pinned
supabase/edge-runtime registry digestad45164b7548bf5820ed7be714789c17ac2865edce79a09cfb4c3756c3d365a8.
Fixture Auth/provider/plaintext is not hosted JWT/TLS/PostgREST or learner proof.

Issue31 also requires distinct events for a session. A new ninth mandatory group
uses one additional fixed disposable owner, preserving all original owner IDs and
all eight prior assertions. Fixed TEST ONLY /held_turn uses the existing held
provider/real conversation_turn handler and metrics; no new production route.
While the first turn is durably reserved and waiting for provider, a second isolate
sends a different turn and finish. Both must return SYNC_CONFLICT409, dispatch no
provider and leave zero rejected receipts, only original slot0, one pending
reservation, unended session and no open SQL transaction across provider wait.
Finally releases the held provider even when an assertion fails.

After confirmed completion, explicitly retry the same rejected turn/finish IDs.
Require assistant slots2 then4, complete slots0..4, exact ordered Japanese user
texts, ended session/four completed joined reservations and zero pending. Dispatch
counts prove one held turn plus exactly two later provider calls. Fresh-container
replay returns both original turns/finish byte-equivalent with no dispatch or
connection leak. Total nine quota attempts for the new owner including restart
replays; no bucket reset, bypass, timing-dependent refill or automatic mutation
retry. Original burst/day limits remain unchanged.

Two negative Python regressions require oracle failure for orphan rejected receipt,
missing/reordered message slots/texts, residual pending, missing completion or
unended session; held-provider release is still asserted. These are mock negative
oracle checks, not concurrency/SQL proof. New exact-head actual Docker/PostgreSQL
execution plus artifact publication is required before claiming ninth-group success.
Local Docker/PostgreSQL/Flutter absent. All14 release groups/default bindings and
hosted JWT/TLS/PostgREST/provider/voice/learner acceptance remain pending.

Local checked extension bundle:151 modules/599497 bytes/SHA256
`17360c95acfbd46e947cf60488d8f688351c26d824fc5d4934d1db2b3536cd77`.
SDK helper registry refused connection; verified exact npm esbuild0.25.5 atomically
cached before successful checked build, no application dependency/lock/CI override.
Separate preservation review compares AST: all21 old probe check calls and all old
helper function bodies retained; all71 old QA case objects/gates/findings unchanged.
Only six intended files differ; new actual ninth-group pass awaits exact-head CI.
