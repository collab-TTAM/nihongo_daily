# Owned PostgreSQL recovery driver — Issue #31

`PostgresConversationStore` additionally implements the separate host-only
`ConversationRecoveryStore` port. It calls the existing private reconciliation SQL
through `lookupRecovery` and `reconcile`. This is a database component, not a provider
verifier or an enabled default recovery flow. The separate optional
[runtime binding](AI_CONVERSATION_RECOVERY_RUNTIME.md) requires a trusted authenticated
lookup adapter; no real upstream adapter is configured and default pending fails closed. No endpoint, provider, paid call, Auth
strategy, public wire field, database migration/grant or deployment is introduced.

## Original binding and transaction order

`lookupRecovery(key, originalRequest, signal)` uses a fresh owned READ COMMITTED
READ ONLY transaction and fixed parameterized private helper. Strict original
request validation preserves its supplied UUID casing; canonical verified owner,
operation and event supply the lookup key. Immutable input is captured before I/O.
Missing and legacy pending return only kind; completed returns a cloned/frozen,
original-schema checked response. Never fabricate a context or dispatch capability.

Atomic pending requires exactly kind/correlation/context. Correlation has exactly
receipt_id, user_id, operation, client_event_id and idempotency_key: canonical receipt
UUID and exact captured owner/operation/event/full existing canonical key. Context
passes the same <=64KiB, exact-field, bounded instruction/transcript/typed-ref,
owned-session and server-slot checks as normal acquisition. Pending envelope is
bounded to66KiB/correlation1KiB. All returned values are cloned/frozen and withheld
until confirmed COMMIT. The original dispatch token never appears in these values.

`reconcile(key, originalRequest, correlation, savedContext, verifiedResponse, signal)`
captures all arguments as fixed serialized parameters before I/O. It validates
correlation, original context and the unchanged output schema,1MiB UTF-8 bound,
reserved session/message/sequence, null audio and typed allowed refs before opening
SQL. Normal token-bound completion and reconciliation share that same validation.
Use the captured original receipt UUID/key/context, not a later source snapshot.

Reconciliation calls only the seven-argument private helper in a fresh owned write
transaction. SQL authoritatively checks exact owned receipt/request/key/context and
revalidates source/session/schema before atomic public writes + receipt + release;
its original token remains entirely inside SQL. The driver validates the returned
original response and semantic JSON equality before COMMIT. No claim/acquire/renew,
retry, expiry/delete/takeover or provider operation is called by either method.

Both methods reuse the strict trusted server URL/TLS factory, exclusive fresh
connections, service_role and1s lock/2s statement/3s idle limits with bounded5s phase
deadline (constructor1–15000ms). Confirmed COMMIT/ReadyForQuery is required before
exposing results/success. Exact controlled SQLSTATE/message pairs remain the only
mapped helper errors; unknown commands/results/storage/transport/commit failures
are safe NETWORK_UNAVAILABLE. No SQL/token/context/credential logs. Parent abort,
monotonic deadline and uncooperative late replies cannot advance to another phase;
owned connection closes once and listeners/timers are removed. No retry on ambiguity.
A fresh lookup can distinguish committed completion from pending after lost delivery.

## Trust boundary still required

Stored correlation and structural JSON equality are database identity bindings.
They do NOT prove genuine upstream output. Before calling reconcile, a trusted
lookup-only provider adapter must authenticate its transport and prove stable
owner/operation/event/key, original request/context and result association. A type,
SQL role, learner/model echo or legacy PendingRecovery object supplies no such proof.
The optional explicit runtime binding requires this SAME coherent store and a
trusted authenticated lookup port. Never wire legacy recovery directly here or use
absence/unknown to authorize another dispatch. No real upstream lookup/authentication
adapter is configured; types/metadata equality cannot prove genuine provenance.

## Evidence and next step

Local pinned Node24 formatter/strict TypeScript and152 tests passed (138 retained,
14 new; zero failures/skips/cancellations); production dependency audit0 findings.
New protocol cases cover allthree operations/exact SQL parameters/no token/claim,
missing/legacy/completed, malformed/cross-owner correlation/context/output/refs,
UTF-8 size limits/canonical key vs original casing, deep snapshots, semantic JSON,
COMMIT visibility/ambiguity, pre-abort/deadline/late settlement/listener cleanup and
A/B/A connections. Fixtures do not prove upstream authentication or durable SQL.

Eight additional native PostgreSQL17 driver cases are included in the existing
required database CI command, retaining allten original runtime cases: fresh
start→turn→finish/replay after closure/retirement/profile change; actual lookup and
reconcile COMMIT with TEST ONLY lost-delivery injection/fresh lookup; actual COMMIT
delivery gates for both methods; observed lock-wait abort/no late persistence;
post-SQL-write failure with rollback/fresh exactly-once retry; A/B/A same-event
isolation, borrowed receipt/changed context/request denial and retired-source
pending. They use the real pg driver/SQL and fixed disposable database. No local
PostgreSQL binary is installed; authored/typechecked, native execution awaits this
head's CI. Plaintext/generated-result/delivery-injection fixtures are not hosted
TLS/CA/JWT/provider/real partition or learner proof.

Parent9b9283f1c8ae0f2bcd59a0f5633b52d238efe62b passed allfive jobs/every step in
[CI39813007245](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39813007245),
latest attempt1, including72 SQL reconciliation assertions/eight native SQL races
and allten runtime native cases. This resolves the parent's platform pending state;
a new source requires its own full checks. Next inspect exact-head CI/native18,
then implement trusted lookup-only verifier and explicit bounded runtime recovery
without legacy fallback, token borrowing or redispatch. Hosted/Edge/Deno/provider
proof and all14 Personal Alpha learner release groups remain pending; #41 draft,
#31 open. No release acceptance or schedule change.

Parent d8eeebc passed allfive jobs/every step in CI39822068710/attempt1; completed
database log verifies all18 native pg cases, including all eight driver additions.
That resolves this driver's native/platform pending checkpoint. The next source
adds [opt-in correlated recovery runtime](AI_CONVERSATION_RECOVERY_RUNTIME.md); its
new tests need separate exact-head CI and do not authenticate a real upstream.
