# Committed PostgreSQL quota adapter

`backend/ai/src/postgres_quota.ts` implements the existing mandatory RateLimiter
port with the private quota in AI_POSTGRES_QUOTA.md. It is opt-in server code,
not a deployed Edge endpoint or a Flutter default. The host supplies it through
AiDependencies; existing Auth, context/receipt ownership and provider ports remain
mandatory. Node24/pg8.23.1 execution does not establish Deno/Edge compatibility.

## Trusted configuration and lifetime

`createPostgresQuotaLimiter(databaseUrl)` captures only trusted deployment
configuration, never learner JSON/forms/query strings or decoded JWT claims.
The PostgreSQL URL must include explicit host/database/user/password, have no
query/fragment, and use a DNS/IP host; encoded Unix-socket hosts are rejected.
There is no TLS-off option. The factory uses a fresh pg Client for each call,
verified TLS (`rejectUnauthorized: true`), no pipeline, a2s connection timeout,
2.5s client query timeout and fixed application name. URL SSL/options overrides
are rejected because pg can otherwise replace an explicit SSL object. Deployment
must configure the intended project, trusted CA chain and a dedicated backend
login allowed to SET ROLE service_role; never ship database credentials to Flutter
or provide them in chat. No credentials are installed by this change.

PostgresQuotaLimiter also accepts an explicit trusted connection factory for host
assembly/tests. That capability must create exclusively owned clients and resolve
queries only after actual protocol completion/ReadyForQuery. A shared pooled
client, learner-controlled factory or optimistic commit acknowledgement violates
the contract. The ordinary deployment helper always constructs the real driver;
there is no in-memory quota fallback. Host inbound concurrency/database connection
limits remain necessary before enabling an endpoint.

Each call owns and closes its connection. The parent signal and an independent
5s overall deadline (bounded1–15000ms) cover allocation, connect and every query.
Monotonic checks reject timer-starving synchronous work. Per-query abort listeners,
parent listeners and timers are removed. Cancellation/error initiates connection
termination without waiting indefinitely for network close; pg's non-pipeline
active-query end destroys the stream, and the server rolls back an open transaction
when disconnected. Connect/query/idle-transaction deadlines bound remaining I/O.
This is not an instantaneous remote-cancellation or power-loss guarantee.

## Transaction and authorization

Validate UUID/operation before allocation. Execute only fixed statements on that
owned connection: BEGIN ISOLATION LEVEL READ COMMITTED; SET LOCAL ROLE service_role;
1s lock_timeout,2s statement_timeout and3s idle_in_transaction_session_timeout;
then `SELECT private.consume_ai_quota($1::uuid,$2::text) AS allowed`. Only the
verified Auth UUID and trusted operation are parameters; normalize UUID case.
No request token, model text, arbitrary SQL or learner rate reaches the driver.
Require exactly one SELECT row/boolean and no extra fields, then send COMMIT.
Return true/false only after a COMMIT command result and completed protocol query.
A ROLLBACK response to COMMIT is failure. No provider can run while this transaction
is still open through the normal AiService limiter barrier.

All driver/setup/query/commit/resource faults map to fixed NETWORK_UNAVAILABLE;
quota denial remains false and AiService maps it to RATE_LIMITED. No SQL/vendor/
credential/abort-reason logs or raw errors are emitted. Idle driver error events
are handled; pending operations still reject. Errors close the connection, never
reissue consumption, refund, or authorize from a late response. A COMMIT may have
succeeded before its delivery failed; that capacity remains spent and no provider
is permitted by an uncertain result. Manual later requests are separately rate
limited, while existing event receipts still prevent duplicate provider dispatch.

## Verification

From backend/ai, pinned install/format/check/npm test/audit exercise19 new protocol-
fault/service-composition tests plus79 existing tests. Unit connection responses
are TEST ONLY fault probes, not durable quota or real network evidence. Cases cover
ordered fixed SQL/parameters, delayed COMMIT, denial, each failing phase, malformed
results/COMMIT-as-ROLLBACK, ignored deadlines/late connect/query/commit, synchronous
starvation, pre-abort, configuration/TLS-override/socket rejection, A/B/A ownership,
cleanup and no provider dispatch on quota denial or uncertain COMMIT.

The database Actions job retains every prior migration/SQL/native/profile/export
step and adds Node24 pinned install plus `npm run test:postgres-quota`. This runs
five real-driver/native PostgreSQL17 cases after migrations. It refuses any URL
other than the fixed disposable CI database; the test-only transport disables TLS
solely because that container has no TLS. Production helper has no such setting.

The tests use real driver/protocol/SQL/quota/service, with fixture Auth/context/
provider/receipt ports. They check allfive shared operations and A/B/A reconnect;
hold actual COMMIT behind an observing gate while a second worker is observed
waiting on the lock, and assert no provider until release; abort a locked query
and check no debit after release; inject lost delivery AFTER an actual COMMIT and
verify one spent slot/no provider/no automatic retry; require the production TLS
factory to reject the plaintext test server without fallback or debit. The native
wrapper also checks pg transaction status is idle after real COMMIT. Injected lost
delivery is not a real network-partition/power-loss certificate.

Local format/strict types/98 Node tests and audit passed; five new native cases
require exact-head Actions because no local PostgreSQL17 is available. Hosted TLS/
CA/project/signature/expiry/A-B learner, deployed Edge/Deno, conversation message/
receipt transaction and lookup-only provider reconciliation remain open. All14
hosted release gates stay pending; no production deployment/provider/spend change.

Primary documentation and pinned driver implementation checked2026-10-22:
- https://node-postgres.com/features/transactions
- https://node-postgres.com/features/ssl
- https://node-postgres.com/apis/client
- pg8.23.1 lib/client.js: query ReadyForQuery completion and non-pipeline end.

## Observed native driver evidence

Source cdae78b54d14c7aadff5e4a849adafa3452c47c5 passed allfive jobs/all steps
in CI39763102669 attempt1. The completed database log explicitly reports allfive
native cases above passed, including held COMMIT, locked abort, actual commit with
injected lost delivery and production-factory TLS rejection of plaintext. This
resolves that source's native-test-pending checkpoint; hosted TLS/CA/JWT/Deno/Edge,
conversation transactions and learner gates remain unverified.

The quota factory now delegates to `src/postgres_connection.ts` so the text context
adapter can reuse its exact URL/TLS/client lifetime configuration. QuotaConnection/
QuotaResult remain compatible type aliases; quota transaction logic and every
original test remain unchanged. New text phases are specified separately in
AI_TEXT_CONTEXT_RUNTIME.md and cannot consume or refund quota themselves.

## Native fixture failure diagnostics — 2026-10-28

CI40585544542 attempt1 at exact22cfddae542bc23222c614a43a723c976b8f8689
passed Windows/repo/AI but failed database; Flutter was skipped. Windows logs
confirmed the new real directory/junction stage-collision cases and retained
subprocess/staging/native markers. This is not an overall CI pass.

The quota native suite passed its first four cases. The fifth failed with Query
read timeout in owner()'s disposable auth.users INSERT, before the production TLS
factory assertion. The log does not establish the cause; this change does not
claim to repair a production quota/TLS bug or classify the failure as transient.

Each native admin call now has a unique internal application name. On failure a
separate read-only connection projects only fixed booleans: probe availability,
target visibility/activity/lock wait/blockers/idle transaction and another named
quota fixture's idle transaction. No SQL text/parameters, identity, backend PID,
connection settings or raw diagnostic errors enter this output. Connect/query/
statement limits are500ms with a separate1500ms diagnostic ceiling; failure or
late completion returns unavailable and initiates private connection termination.
The original error is rethrown, without retry, fallback or timeout extension. The
original admin closure and production connection/limiter are unchanged. These
settings are only for the existing fixed disposable CI database, not hosted use.

The existing native locked-abort case additionally requires this same projection
to observe the actual active blocked limiter and idle lock-holding fixture before
abort. All original five cases, assertions, query deadlines, TLS refusal, commit/
no-dispatch and rollback checks remain. The required new marker is
`PASS: native quota bounded boolean lock diagnostic (TEST ONLY)`. A later timeout
may occur after its server query completed/cancelled, so even an available all-
false snapshot cannot by itself prove the historical cause or remote rollback.

Local pinned install, Prettier, strict TypeScript,185 Node unit tests,46 QA
regressions and inventory151 passed. Inventory is not151 executed tests. No local
native PostgreSQL server/Windows/Flutter SDK execution; actual new diagnostic/
TLS/native behavior needs exact-head Actions/latest-attempt complete jobs/steps.
Do not infer success from a missing/skipped job. Hosted learner/provider gates
remain pending; this test-only diagnostic does not activate any learner storage.
