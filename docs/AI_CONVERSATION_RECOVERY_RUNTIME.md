# Opt-in correlated conversation recovery — Issue #31

`CorrelatedConversationRecovery` and optional `AiDependencies.conversationRecovery`
provide bounded lookup-only orchestration for an existing atomic pending mutation.
They do not configure an upstream provider, authenticate its transport, install an
endpoint or change the default application. Without an explicit trusted binding,
AiService retains fail-closed pending behavior. Legacy PendingRecovery is never used
by the coherent conversation lane. Normal missing→acquire→generate behavior remains
unchanged; recovery never creates or renews a claim, dispatches or borrows a token.

## Explicit binding and proof boundary

The host must provide the SAME object as `AiDependencies.conversations` in the
recovery binding's store, plus an `AuthenticatedConversationLookup`. The store
implements both coherent conversation and private recovery ports. AiService captures
store/lookup before asynchronous receipt I/O and rejects a different recovery store.
Provider dependencies, verified Supabase identity and distributed quota remain
required; no input can select an owner, database, provider URL, key or recovery mode.

`lookupExisting` is a server-only trusted contract: authenticate upstream transport
and verify genuine existing-result provenance before returning metadata. It must
never generate, reissue or invent metadata from a learner/model echo. It accepts
frozen original key/request/saved context/existing idempotencyKey, not the dispatch
token or internal receipt ID. Null means absent/unknown and stays pending forever
unless later lookup finds the original result; it does not authorize redispatch.

A successful lookup returns a bounded JSON string with exactly seven fields:
user_id, operation, client_event_id, idempotency_key, request, context, response.
The first four are original canonical association metadata, request/context are the
original immutable values, response is the original structured result. A real
adapter must prove that association from authenticated upstream evidence, not merely
copy the input fields around arbitrary text. No such transport adapter is configured
or implemented here. TypeScript types, structural equality, SQL role and synthetic
fixtures do NOT establish upstream authenticity or hosted learner proof. Provider
selection, credentials/spend/live integration remain #17/applicable human gates.

## Recovery order and guards

After verified Auth/quota, existing completed receipt returns its original result.
Existing pending (including a losing acquire) may enter recovery only with explicit
same-store binding. The coordinator captures/freeze-validates canonical owner/op/event
and full original request, then runs the existing private recovery lookup. Missing or
legacy pending cannot fabricate context or become a new dispatch. Completion racing
this read returns original schema-checked replay without any upstream lookup.

For atomic pending, exact saved receipt UUID/owner/op/event/key and strict original
context are cloned/frozen before upstream I/O. Require bounded fields/transcript/
server IDs/slots/typed refs; never rebuild context from newer content. Then inspect
only the existing upstream result with the captured original stable key. Parse once
at <=2MiB UTF-8, require exactly the seven fields, exact owner/op/event/full key and
semantic JSON equality of the whole original request/context (including supplied
UUID casing and array order). Unknown/extra/mismatched/malformed metadata stays
unavailable without reconciliation, renewal or fallback.

Use the same pure validator as normal PostgreSQL completion/reconciliation for the
unchanged response schema,1MiB UTF-8 bound, reserved session/message/sequence, null
audio and complete typed-ref membership. SQL/context/correlation/JSON helpers moved
unchanged into internal pure conversation_validation.ts; no Node pg import is added
to the service's validation path. All existing policy tests are retained.

Supply only captured key/request/receipt correlation/context/validated output to the
owned store's reconcile and await confirmed COMMIT before final success. SQL remains
authoritative for owner, source/session, original request/context, receipt locking,
original-worker races, response/schema and public state+receipt+release rollback.
A racing original completion yields original replay for identical output or
SYNC_CONFLICT for changed output. Unknown COMMIT delivery returns failure; a fresh
request can read original completion without upstream work. No automatic retry.

The coordinator has its own monotonic10s deadline (constructor1–15000ms) plus the
service's original overall deadline/parent disconnect. Each awaited port races an
owned abort signal and checks the deadline after settlement; synchronous timer
starvation cannot authorize a later phase. Late/uncooperative DB/upstream/reconcile
responses cannot advance after abort. Finally remove timers/parent listeners and
abort only the private signal; pg driver closes its owned connection once. Unknown
upstream exceptions and bad outputs become safe PROVIDER_UNAVAILABLE; controlled
store errors remain safe existing codes. No token/context/credential/raw exception
logging, transaction held over upstream I/O or live-success fallback is introduced.

## Observed evidence and remaining gates

Local pinned Node24: formatter, strict TypeScript and168 tests passed (152 retained,
16 new, zero failures/skips/cancellations), production audit0 findings. Fixtures
exercise allthree operations, absent/legacy/completed/corrupted DB values, explicit
same-store binding/late host replacement, all seven metadata fields, original casing/
semantic object order, strict output IDs/refs/UTF-8 bounds, captured snapshots,
COMMIT delivery/uncertainty, cancellation/independent deadlines/late responses and
A/B/A isolation. These are port fixtures, not authentic upstream or durable SQL.

Ten additional native PostgreSQL17 runtime cases are authored/typechecked in the
retained required command (28 total with18 earlier cases). Real pg + quota + original
SQL cover start→turn→finish/replay after closure/profile change/source retirement;
actual reconciliation COMMIT lost delivery/fresh original replay; acquire COMMIT
loss with no provider result staying pending across retries; cancelled late upstream
with no reconciliation; observed lock-wait cancellation/no late persistence; identical
and changed-result races against original token worker; A/B/A same-event result
misassociation denial; source retirement during lookup and actual COMMIT delivery
before runtime success. Fixed disposable database only. No local PostgreSQL binary;
new native execution requires this source's exact-head CI. Auth/generated lookup/
plaintext/delivery faults are TEST ONLY and not a real upstream/partition proof.

Parentd8eeebc6a616a7f347e9c0358f3baaeece356bb5 passed allfive jobs/every step in
[CI39822068710](https://github.com/collab-TTAM/nihongo_daily/actions/runs/39822068710),
latest attempt1. Completed database log verifies all18 original native cases passed,
including eight recovery-driver cases (no failure/skip/cancel). This resolves its old
pending checkpoint; a new head needs its own allfive latest-attempt jobs/native28.
Then implement/verify an approved real authenticated lookup adapter and hosted
TLS/CA/JWT/PostgREST/Edge/Deno/provider evidence; keep unconfigured defaults and #31
open/#41 draft. All14 Personal Alpha learner release groups remain pending. No
provider strategy/Auth/wire/migration/RLS/dependency/workflow/deploy/release change.
