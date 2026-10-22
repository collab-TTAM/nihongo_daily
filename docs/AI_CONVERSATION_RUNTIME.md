# Opt-in atomic PostgreSQL conversation runtime — Issue #31

`PostgresConversationStore` implements the explicit `ConversationStore` port through
private SQL lookup/reserve/complete. `AiDependencies.conversations` selects this
coherent lane for the three original conversation mutations. It is never installed
by default and creates no HTTP/Edge endpoint, live provider, Flutter success state
or recovery dispatcher. The existing verified Supabase Auth, distributed quota,
bounded HTTP/deadline and original contracts remain required host dependencies.

## Dispatch and completion order

After verified Auth and rate limiting, AiService freezes the user/operation/event
key and original request. The opt-in lane first looks up the immutable receipt.
Completed returns the original schema-checked result before active source checks;
pending fails safely without calling a provider. Missing proceeds to acquire,
which reserves the source context/IDs and original dispatch claim together in one
short owned PostgreSQL transaction. A losing acquire returns only pending or the
original completed result; it never borrows another worker's token.

Only confirmed COMMIT/ReadyForQuery from acquire exposes its capability/context.
Then AiService captures the token, clones/freezes context and calls the provider
once with the existing scoped idempotency key. It uses the shared original response
schema/ID/sequence/audio/ref validation. Atomic conversation completion supplies the
source revalidation; the split text ContextRepository is not called for this lane.
Completion receives the exact captured original request and token and calls the
[validated atomic SQL completion](AI_CONVERSATION_COMPLETION.md). This transaction
persists session/messages, original receipt and guarded release together. Require
confirmed COMMIT before final success. No transaction is held across provider I/O.

The original text-operation path and legacy injected test-port behavior are
preserved. When conversations is provided, no mutation falls back to the old
prepare/claim/receipt/recovery methods. The legacy receipt dependency remains in
the constructor for compatibility; it is not a production conversation store.
Hosts must supply the coherent binding explicitly, not a memory success fixture.

## Owned connection and validation boundaries

The trusted factory uses pinned pg and the existing strict server URL/TLS policy:
certificate verification enabled, no URL query/fragment/SSL overrides, no learner
configuration, fresh exclusively owned clients with fixed application name. Lookup
uses READ COMMITTED READ ONLY; acquire and completion use READ COMMITTED writes.
Every phase sets service_role,1s lock/2s statement/3s idle-transaction limits and
has its own bounded5s deadline (constructor1–15000ms). Unknown commands/results,
transport/storage failure or COMMIT delivery uncertainty fail closed and terminate
the owned connection, without retry. No raw SQL/credentials/token/context logging.

The adapter snapshots/validates original requests before asynchronous I/O. Key
owner/event must be canonical UUIDs; original client_event_id may preserve its
wire casing and must match the normalized key. Only the three mutation operations
are accepted. Parameterized fixed SQL accepts no table name, role, owner override,
server ID/sequence or SQL chosen by model/client. Each reply must be exactly one
SELECT row with one result field. Pending has no extra fields/capability. Completed
passes the original operation's strict schema and1MiB bound. Acquired requires an
exact three-field reply, canonical UUID token and strict bounded saved context.

Context enforces exact keys, canonical session/message UUIDs, requested session
binding, <=64KiB JSON,1–10000 instruction UTF-8 bytes, <=1000 unique complete typed
GRAMMAR/VOCABULARY refs, <=99 nonempty bounded alternating transcript messages and
server slot rules. Start has empty transcript/assistant0; turn has at most97 prior
messages and next assistant=count+1; finish has no fabricated message fields.
All exposed results are cloned/frozen. Completion additionally rechecks schema,
ID/sequence/audio/ref membership before SQL and requires the returned original
response to match semantically before sending COMMIT. Authoritative owner/source/
reservation/token checks still execute inside SQL; local checks do not replace them.

## Cancellation and conservative pending state

Parent abort, deadline or a late/uncooperative connect/query/COMMIT response cannot
advance to another phase. A monotonic deadline guards both sides of every await;
listeners/timers are removed, close initiates once and never waits for ignored I/O.
Only exact controlled SQLSTATE/message pairs map to the four documented helper
errors. Unknown failures map to safe NETWORK_UNAVAILABLE without raw error text.

Ambiguous acquisition may have committed a pending claim even though no provider
was called. Ambiguous completion may have committed the original success. A fresh
lookup distinguishes completed from pending, but pending/absence of an upstream
result never authorizes reissue. No expiry/delete/reset/takeover/refund is introduced.
Even if legacy PendingRecovery is configured, this lane does not call it. A future
lookup-only correlated recovery port must prove owner/operation/event/provider
correlation and revalidate captured reservation/context without exposing another
worker's dispatch capability. Until then availability is intentionally conservative.

## Evidence and remaining work

Local pinned Node24: formatter, strict TypeScript and138 tests passed (117 retained,
21 new;0 failures/skips/cancellations), production audit0 findings. Protocol fixtures
exercise allthree operations/parameters/transactions, strict context/reply/refs,
key/request/capability fencing, source snapshot immutability, COMMIT gates, safe
helper errors, pending/completed replay/no legacy fallback, provider failures,
unknown commits, abort/timeout/late responses and independent account connections.
These are explicit fixture tests, not durable SQL or hosted learner proof.

Ten native PostgreSQL17 cases use the actual pg adapter, existing SQL and quota:
start→turn→finish/original replay after source retirement/profile change; same-event
pending and distinct-event/finish serialization during provider I/O; actual acquire
and completion COMMIT with TEST ONLY lost-delivery injection plus fresh retry;
retired source rollback/pending; observed lock-wait cancellation/no late provider;
A/B/A isolation and foreign-parent denial; production TLS factory rejects plaintext;
actual COMMIT delivery gates before provider and final success. Native fixtures
refuse all but the disposable CI database. The plaintext/Auth/provider/lost-delivery
injections are TEST ONLY. Compiled locally, native execution requires exact-head CI.

Parent e621c9d074bdcbc8f8c551433e7e7f67dfb5183b passed allfive jobs/every step in
[CI39795974325](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39795974325),
latest attempt1. Database logs prove99 SQL completion assertions and all8 native
SQL races. That resolves its pending checkpoint, not this new runtime's CI.

Next inspect this runtime's exact-head full CI and native logs, fixing actual failures
without weakening assertions. Then add correlated lookup-only reconciliation and
observed Deno/Edge compatibility/hosted TLS/CA/JWT/PostgREST/provider integration.
No production endpoint/default should be installed before those remaining guards
and applicable release gates. All14 hosted learner groups remain pending; fixture
roles/Auth/model text, native process restart or injected delivery failure are not
live identity/provider, real network partition or Personal Alpha acceptance.
