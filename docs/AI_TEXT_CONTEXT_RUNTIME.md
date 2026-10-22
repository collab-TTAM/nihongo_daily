# PostgreSQL text context runtime — Issue #31

`PostgresTextContextRepository` implements the existing ContextRepository port
for tutor_explain and correct_sentence through the private SQL helpers described
in AI_TEXT_CONTEXT.md. It is opt-in server code, not a configured endpoint, provider
or application default. Host assembly still supplies verified Supabase Auth,
distributed limiter, original Contracts, provider and receipt ports. Conversation
operations throw PROVIDER_UNAVAILABLE before allocation; this repository cannot
reserve conversation IDs/sequences or complete messages/session receipts.

## Captured input, connection and transaction

The host passes the same original Contracts instance/schema used by AiService.
Before I/O, clone and validate the parsed text request, reject invalid verified-user
UUID/unsupported operations, bound serialized UTF-8 to32KiB and canonicalize the
owner UUID. SQL receives only parameterized owner/operation/frozen-request JSON,
plus captured context JSON during revalidation. Bearer tokens and model text are
never database arguments; only provider wire schema/ref checks run in process.

Every prepare and validateResult call creates an exclusively owned connection and
short `BEGIN ISOLATION LEVEL READ COMMITTED READ ONLY` transaction. Set local
service_role and fixed1s lock,2s statement,3s idle-transaction deadlines. Execute
only the corresponding private helper SELECT; require exactly one expected row
and field. Validate the prepared object against the text-only shape: bounded
instruction, empty transcript, no session/message/sequence fields and unique
canonical grammar/vocabulary refs within200 tutor/64 correction entries. Return
a detached frozen snapshot. Revalidation accepts the pg empty-string void value
only, not an optimistic boolean. Require COMMIT command/ReadyForQuery before
returning context or final validation success; COMMIT returning ROLLBACK fails.

The connection is closed on every exit. No connection, transaction, user/context
cache or repeatable-read snapshot crosses provider I/O or account changes. The
fresh revalidation statement therefore sees subsequently committed profile,
retirement, version or selected-content changes. SQL revalidation is a read check
at that instant, not a lock preventing future edits or a linguistic accuracy claim.
AiService continues to validate output schema and allowlisted refs; validateResult
also checks those before sending captured context to SQL. Neither method writes
learning errors, recommendations, progress, sessions or receipts.

Each phase has an independent default5s monotonic deadline (host bounds1–15000ms)
and caller AbortSignal. Cancellation/deadline closes the owned connection without
waiting for uncooperative I/O; late connect/query/COMMIT cannot advance the phase.
Always remove timers/listeners. After actual commit with lost delivery, return no
success and never retry the SQL/provider automatically. The two text wire requests
have no event key: a later separate request may invoke a new paid call; this adapter
does not claim exactly-once provider behavior for them.

## Deployment and safe failures

`createPostgresTextContextRepository(contracts,databaseUrl)` uses the same extracted
`createOwnedPostgresFactory` as the quota deployment helper. Original quota exports
remain compatible via type aliases and its fixed configuration error is retained.
URL validation, fresh pg8.23.1 clients, fixed application names, verified TLS,
no pipeline,2s connect/2.5s query timeouts and idle-error suppression are unchanged.
No TLS-off, SSL/options override, learner URL/key, socket-host or plaintext/memory
fallback is added. Trusted host configuration must select the intended project/CA
and backend login allowed to SET ROLE; no credentials are installed here.

Map SQL helper errors only for exact SQLSTATE plus fixed message pairs:
22023/VALIDATION_FAILURE,42501/FORBIDDEN,P0002/NOT_FOUND,P0001/SYNC_CONFLICT. Apply
that mapping only around the actual helper query. Permission/configuration/setup,
unknown/malformed output, transport/cancel/commit/late results fail closed with
NETWORK_UNAVAILABLE. Response schema/ref faults retain PROVIDER_UNAVAILABLE.
No SQL detail, text, key, token, owner or abort reason is logged/returned. No Auth
strategy, provider, collection, production deployment or paid-spend change occurs.

## Verification and limits

Local pinned Node24 install/formatter/strict TypeScript passes117 tests:98 retained
and19 new protocol/service cases. All original quota tests remain text-identical.
Coverage includes fixed read-only SQL/parameters, independent prepare/validation,
captured input/frozen output, both operations/no open provider transaction, A/B/A,
all setup/query/commit failures, exact safe error mapping, malformed context/rows,
COMMIT-as-ROLLBACK, ignored connect/deadline/synchronous starvation, abort during
SELECT/COMMIT, late completion, rejected output refs and failed post-provider
revalidation/commit. These unit connection replies and downstream ports are TEST ONLY.

The new required database step runs `npm run test:postgres-text` after the retained
SQL/RLS/concurrency and native quota steps. Nine native cases use actual pg,
PostgreSQL17, helper queries and AiService. They cover real quota + both text wire
operations, no transaction during provider I/O, A/B/A profile/curriculum selection,
content retirement/version and profile change after dispatch, actual COMMIT
barriers before dispatch and final success, observed table-lock wait + abort,
actual commit with injected lost delivery in both phases, missing profile/inactive
content and production-factory plaintext rejection. The harness refuses every URL
except the fixed disposable CI database. Plaintext transport, Auth/provider/receipt
ports and injected lost delivery are TEST ONLY; not hosted TLS/CA/JWT or actual
network-partition/power-loss evidence. Native cases await exact-head CI; no local
PostgreSQL17 was available. Node is not Deno/Edge compatibility evidence.

Parent a16bdb4a03b16f1d01dabfcf89961a2d5cde18d9 passed allfive jobs/every step
in [CI39770572353](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39770572353),
attempt1, including59 native text SQL assertions and allfive prior quota native
cases. That source's full CI pending checkpoint is resolved; this adapter still
requires its own exact-head run. All14 hosted release groups remain pending.

Next: inspect exact-head CI/all latest-attempt jobs, then implement coherent
conversation reservation+claim and validated session/message+token receipt
completion transactions, distinct-event serialization and lookup-only recovery.
Do not bind the text repository as a fabricated conversation implementation.

Primary PostgreSQL void output implementation reviewed2026-10-22:
https://doxygen.postgresql.org/pseudotypes_8c.html (void_out)
