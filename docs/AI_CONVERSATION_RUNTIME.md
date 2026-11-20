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
pending fails safely unless the host explicitly installs the
[same-store correlated lookup-only binding](AI_CONVERSATION_RECOVERY_RUNTIME.md). Missing proceeds to acquire,
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


The private SQL prerequisites for lookup-only saved correlation/context and guarded
atomic reconciliation now exist in
[AI_CONVERSATION_RECONCILIATION.md](AI_CONVERSATION_RECONCILIATION.md). SQL binds
receipt/key/request/context but cannot authenticate an upstream result. No runtime
recovery flow is installed by this addition; pending remains unavailable.
All10 runtime native cases and allfive jobs/every step passed on exact014bee0 in
CI39805367641/latest attempt1. Future heads require their own complete checks.

The separate host-only [recovery driver](AI_CONVERSATION_RECOVERY_DRIVER.md) now
implements strict lookupRecovery/reconcile on the same owned PostgreSQL store.
AiDependencies and AiService are unchanged: no automatic/legacy recovery binding,
provider lookup or redispatch. Database correlation is not genuine upstream proof;
a trusted authenticated lookup-only verifier and explicit runtime guards remain
required. Allfive jobs/every step passed on parent9b9283f in CI39813007245/attempt1;
new driver native cases require their own source's CI.

Current optional recovery is documented in
[AI_CONVERSATION_RECOVERY_RUNTIME.md](AI_CONVERSATION_RECOVERY_RUNTIME.md). It never
uses legacy PendingRecovery, creates/renews a claim or calls generate. Explicit
same-store plus trusted authenticated lookup port is required; no real lookup
adapter/default is configured. Parent d8eeebc passed allfive jobs/every step and all18
native cases in CI39822068710/attempt1; new runtime native tests require own-head CI.
Structural correlation is not authenticated upstream or Personal Alpha proof.

The additive [standalone Deno compatibility gate](AI_DENO_COMPATIBILITY.md)
now runs the unchanged Node fixture suite on pinned Deno2.9.6, plus real loopback
HTTP/disconnect/deadline/permission tests and required CI pg execution on Deno.
Standalone CLI evidence does not establish Supabase Edge bundling/deployment/runtime
version or real Auth/provider provenance. Every existing Node/security gate remains.
Parent691a797 passed allfive jobs/every step in CI39831337442/latest attempt1; new
Deno gates/native42 require their own source's exact-head checks. Defaults stay
unconfigured, #31 open/#41 draft/all14 hosted learner release groups pending.


## Mutation lane final readiness fence — 2026-11-19

ConversationMutationLane now checks captured Auth identity again after the last
external readiness callback and checks permanent revocation before returning
currentness. Previously a callback returning true could replace the session or
revoke the lane after its only identity check, allowing a stale current hint.
This could expose CapturedConversationSession's retained original after a
same-owner refresh. The lane now uses a finally-released checking guard: nested
currentness probes return false; a nested submission during an external current
inspection receives AiTextRequestPending before any slot or dispatch is created.
Existing serialization, exact replay fingerprints, uncertainty and actual-wire
busy/drain rules remain unchanged. Retirement still discards in-memory slots
and never grants retry, clears durable receipt metadata or applies completion.

Six TEST ONLY regressions cover final-readiness same-owner refresh/account
replacement/revoke, nested inspection, nested submission from external inspection,
and retained session redaction after refresh. Each fails on the exact parent
source. Component evidence is not hosted Auth/RLS/provider proof; full current-
head CI/native gates and reviewed conditional application-release remain required.


## Captured-session readiness reentry propagation — 2026-11-19

The mutation lane owns a temporary `isCheckingAvailability` guard while it
calls the host-supplied readiness callback. That guard must also be visible to
its `CapturedConversationSession` consumer. Previously the lane could be in
that guard while the captured session's local guard was false. A controller
read reentered from the host callback then called `session.isCurrent`; the
lane correctly returned false to prevent nested currentness, but the session
mistook that temporary result for permanent revocation and discarded the
otherwise valid conversation. The view subsequently remained unavailable
instead of showing the still-pending operation.

The lane now exposes a read-only checking hint. The captured session combines
its own and the lane's hints, redacts reentrant currentness without revoking,
and rejects a nested command as pending before it can create or dispatch work.
The controller regression asserts the hint is propagated, the nested view is
unavailable/redacted, and the outer accepted command remains loading and can
complete normally. This is a local reentrancy regression only; it does not
establish hosted provider, receipt, Auth, RLS or learner evidence.


## Inspect completion against the actual retained command — 2026-11-19

CapturedConversationSession.inspectRetainedCompletion(handle) is an explicit
synchronous read-only association. It accepts only an idle/current session with
an unresolved mutation and its real retained original. Completion.captureForAuth
requires the exact SAME borrowed Auth object as its reader, not only equal owner
or ReviewSession hints. Trusted host ports must still bind the fixed project and
correct authenticated original read; custom ports are not upgraded by this type.

Compare the completion's operation plus canonical typed original JSON to the
session's existing retained fingerprint. Every field/UUID spelling/code point/
whitespace remains exact. Pre/post captured readiness, actual lane busy/drain,
retained object/fingerprint and pending checks surround external getters. A
finally-released inspection guard redacts reentry and blocks nested commands.
A stale lease, different Auth port, changed command, in-flight/undrained operation
or session without unresolved input yields null. No HTTP/storage call is made.

The result is only the immutable receipt projection; it does not update the
conversation snapshot, change retryability, clear/reset a pending slot, grant
another event or prove transcript applicability/server reservation release.
No default UI calls it and no transcript/payload is persisted. Current-state
application validation and confirmed durable conditional release remain separate
required work, together with hosted Auth/RLS/provider/learner acceptance.


## Prospective transcript validation — 2026-11-19

previewRetainedCompletion(handle) first requires inspectRetainedCompletion's
same Auth/current lease/actual unresolved original/actual-I/O-drain association.
It then constructs an immutable PROSPECTIVE ConversationSessionSnapshot without
installing it. Recovered start requires notStarted/no accepted start and first
assistant sequence zero. Turn requires active/same session/nonempty transcript,
strictly advancing sequence and no case-insensitive message-ID reuse. Finish
requires active/same session and a typed summary; messages/session are preserved.
Invalid combinations yield null without changing the live transcript or pending.

Before returning, recheck completion/lane readiness, actual busy/pending, revocation
and identical retained-command/transcript objects. A finally-released guard
redacts nested preview calls; late readiness revoke cannot publish a candidate.
The preview is not an accepted application state or authority to clear/retry/send.
No default controller/UI consumes it, no optimistic success or payload persistence
is added, and recommendation references still cause no SRS/progress writes.
Production-host integration of confirmed conditional release and guarded session
application remains required; hosted Auth/RLS/provider/learner gates are open.


## Explicit lane completion reconciliation — 2026-11-19

`ConversationMutationLane.reconcileCompleted(completion, store: ownedStore)` is
an explicit trusted-host operation. The captured-session method below is an
explicit caller; no controller/UI/default binding is installed. The caller owns
the same project/account secure store and must first
validate its prospective conversation transcript; this lane layer does not know
conversation phase/sequence/message history. The opaque completion must come from
the exact same borrowed Auth object and current captured session/readiness lease.
Legacy metadata-only reads, UNKNOWN/PENDING/absent receipts and caller metadata
cannot construct that capability or stand in for the full retained command.

Before any storage I/O, reserve the lane against reentry/concurrent submissions,
require the exact unresolved operation/event slot and byte-exact JSON original
fingerprint, ensure the actual timed-out wire has drained, and check store scope.
Hold the lane across `store.clearMatching`'s actual read/clear/confirmation read.
Its supplied guard rechecks completion and lane lease, store-open state, matching
pending key/slot identity and actual I/O drain at every storage boundary. After
confirmed absence, recheck all guards. Without callbacks/await between updates,
retire that exact mutation, replace only its slot with the immutable typed result
and release the pending key. Exact original replay then returns the cached result
without provider I/O; a different explicit event still traverses all normal lane
capacity/currentness/fingerprint rules. All old slots/count limits are retained.

Precondition mismatch returns false without touching storage. Once a conditional
clear is attempted, false/missing/mismatch/retirement or any storage exception
permanently retires the lane; errors remain fixed storage errors. This deliberately
prefers a fresh lifecycle/reconciliation over retrying an ambiguous clear. No
cached success or replacement event is authorized on that failed generation.
The actual clear may already have removed metadata when a late readiness check
fails; subsequent absence cannot be used as release/replay proof. The store still
owns its cleanup policy and actual queue drain; the lane never closes it.

This is not atomic session/transcript application, a cross-process transaction,
server receipt deletion/cancellation or hosted Auth/JWT/RLS/learner acceptance.
Store exclusion remains isolate-local, so trusted host process exclusion remains
mandatory. The captured-session method below keeps its own mutation guard
across the await, validates the unchanged original/transcript/current generation,
and installs the previously validated immutable projection before exposing a new
command. Production-host/default integration is still pending. No optimistic save, automatic dispatch, learner URL/key configuration,
payload persistence, SRS recommendation application or default activation is added.

Twenty-one TEST ONLY regressions cover all three operations' confirmed cache and
explicit next event, changed full originals sharing identical metadata, foreign
Auth/project, missing/mismatched metadata, three storage faults, concurrent calls,
refresh/account/revoke/reader retirement during held clear, actual timed-out wire
drain, signout during clear and final-readiness reentry. All159 component cases
pass in a fresh exact22-file Dart3.9.2 graph (only flutter_test→test1.26.2 import
adaptation; original fixtures), including old lane/session/reader/preview/store
cases. Focused analysis is clean with the curly-braces rule enabled. Full Flutter/
native/SDK host wiring and all14 hosted release groups remain separate gates.


## Explicit retained-completion application into a session — 2026-11-19

`CapturedConversationSession.applyRetainedCompletion(completion, store: ownedStore)`
joins the read-only preview to confirmed lane reconciliation. It is an explicit
trusted-host API, not a UI/controller/default binding. The caller borrows the
store owned by the same configured project/account runtime and excludes competing
processes. It never accepts learner-supplied endpoints/keys, reconstructs original
DTOs from metadata or treats missing/unknown receipts as dispatch authority.

Validate the immutable prospective transcript before any storage effect. Retain
the exact current snapshot/original/fingerprint and reserve the session mutation
guard across lane reconciliation and actual secure-store confirmation. While the
clear is held, the actual snapshot is unchanged, original/preview/inspection reads
are redacted, explicit retry does nothing and commands cannot dispatch. Nested or
concurrent application returns false without changing the outer operation.

After lane settlement, check completion and session currentness again, ensure the
lane is idle/resolved and snapshot/original/fingerprint identities are unchanged.
Only then update the operation's event marker, install the immutable candidate and
clear retained retry state without any intervening callback/await. Exact cached
start/turn/finish replay cannot append twice or roll back later progress. A
recovered finish remains terminal; model recommendations do not mutate SRS or
progress. Failure/retirement after confirmed deletion revokes the session instead
of publishing a stale candidate. Storage exceptions remain fixed errors and revoke
session state; false preconditions without lane retirement preserve prior pending.

This publication is atomic within the captured session's isolate/guard, not a
cross-process or durable payload transaction. Secure-store ownership/cleanup and
runtime close/logout remain caller-owned. No original command/transcript is newly
persisted; learner restart recovery is still memory-only. No UI/default activation or hosted Auth/JWT/RLS/provider/learner acceptance
is claimed. The explicit owned runtime action is described below.

Twenty-eight TEST ONLY cases cover three-operation apply/replay/next-command rules,
changed original with identical metadata, transcript sequence/message-ID rejection,
foreign Auth/store, missing/mismatched metadata, three storage faults, held-clear
redaction/concurrency, refresh/account/revoke/reader retirement, signout, actual
wire drain for late success/error, and post-lane final-readiness revoke/reentry.
All187 component cases pass in a fresh exact23-file Dart3.9.2 graph with only
flutter_test→test1.26.2 import adaptation and original fixtures. Focused analysis
with the curly-braces rule is clean. Full Flutter/native/SDK host execution and
all14 hosted release groups remain separate verification gates.


## Owned runtime completion action — 2026-11-19

`PersistentSupabaseRuntime.applyRetainedConversationCompletion(completion)` is an
explicit opt-in host action, not a UI/default binding. It accepts no store, URL,
key or caller session. It borrows the same private store alias whose ownership
was already transferred to ReceiptAiRuntimeOwner by the constructor. Existing
project/open-store validation, persisted Auth/profile readiness and owner partition
checks remain; close/logout/refresh/terminal/draining guards and final generation/
account identities fence the operation. There is no second SDK/store owner or
change to cleanup order. Without receipt/conversation opt-in it returns false.

The AI owner selects its existing retained conversation and receipt reader; it
never creates/acquires a replacement capability during this action. The opaque
handle's `captureForReader` checks exact reader identity before invoking supplied
currentness getters. A sibling reader with the same Auth/session hint is rejected.
The existing owner creation/drain reservation now covers application/storage I/O,
blocks concurrent capability factories and causes close to await actual completion.
After application, recheck epoch/lease/session/reader and fence sibling capabilities
if the session retired. Unexpected operation failures expose only a fixed AI error.

Important remaining transport barrier: transcript application does NOT reset
ReceiptGuardedAiTransport._attempted or the current production dispatch claim.
The production transport still permits only one dispatch attempt per store. Exact
cached replay is local, but another mutation stays sync-conflict fenced even after
successful application/confirmed metadata deletion. A true host-action result means
transcript applied, NOT permission to send the next provider mutation. Do not enable
learner rollout or reset either claim from metadata absence/success alone. Next
implement separately reviewed conditional release tied to the exact owned dispatch
gate/full original/current lease/actual I/O drain and confirmed completed receipt.

Twelve new TEST ONLY owner cases cover all3operation owned application, exact-reader
provenance before foreign getters, absent retained reader/conversation, foreign
store, storage failure, concurrent acquisition/application, close actual storage
drain, refresh and readiness reentry. All199 component tests pass in a fresh exact
26-file Dart3.9.2 graph with only flutter_test→test1.26.2 adaptation/original fixtures;
focused analysis with curly-braces rule is clean. Four added pinned-SDK tests in
persistent_ai_text_runtime_test cover the real owned runtime/private SDK with
synthetic Auth/HTTP/OS ports: apply plus cached replay and STILL-BLOCKED next mutation,
close/preserved metadata, missing opt-in and fixed storage error. Those SDK tests,
full Flutter/native Windows execution are locally UNRUN and require exact-head CI.
No hosted JWT/RLS/provider/learner or physical OS failure proof is inferred.


## Verified gate release primitive — 2026-11-19

The captured session now retains an opaque single-use application proof only
after confirmed clear and atomic publication. `captureAppliedCompletion` borrows
that exact proof; it cannot be decoded, forged from metadata or created from a
boolean. Exact completion/store association, original applied snapshot, current
Auth/reader/session, actual idle/resolved state and final terminal flags fence
consumption. Revocation or later snapshot progress invalidates it. It adds no
payload persistence, SDK/store ownership or default action. Its toString is fixed.

The optional full-original ConversationReceiptDispatch gate can consume that proof
only after its actual I/O drains, then compare the whole immutable command and
release only its own claim while permanently retiring itself. Legacy/current
production gates remain terminal because they do not capture originalCommand;
ReceiptGuardedAiTransport._attempted, owner action and default UI remain unchanged.
See CONVERSATION_RECEIPT_DISPATCH.md for the exact boundary. The next increment
must wire the same owned transport/gate and prove SDK/lifecycle behavior before
allowing further production commands. Normal HTTP success also needs its own
verified acknowledgement path; uncertain completion recovery is not that proof.

Twenty-five new TEST ONLY cases exercise the three operations, full-original
mismatch sharing metadata, single-use/foreign/legacy/wrong gates, lifecycle
retirement, held clear/actual wire drain, reentry and final-callback retirement.
All246 component cases pass in a fresh29-file Dart3.9.2 graph with only the
flutter_test to test1.26.2 import adaptation/original fixtures; focused analysis
is clean. Full Flutter/native/SDK checks require new exact-head Actions.


## Same-transport explicit proof consumption — 2026-11-19 12:52 UTC

ReceiptGuardedAiTransport now captures the full immutable command in its existing
dispatch gate. Its explicit releaseAppliedCompletion(application) reserves a
release guard before external getters, requires an attempted/current retained gate,
and delegates exact command/Auth/store/proof/actual-drain validation to that gate.
After successful own-claim release it rechecks the transport's captured session,
readiness and retirement/close/gate identity, then resets the attempted flag without
an intervening callback or await. The retired old gate cannot send again. Nested
release and invoke are fenced throughout; failure after gate release retires the
transport instead of reopening it. Close still drains actual work and owns only
the transferred inner transport, never the borrowed secure store.

Owner operations are now two explicit steps. `applyRetainedConversationCompletion`
keeps its original apply-only contract on the exact retained reader/flow/store,
including transports without an optional release capability. It confirms clear
and publishes the transcript but never consumes the application proof or changes
a transport claim. Successful application is not permission to dispatch.

`releaseAppliedConversationCompletion` is a separate host-only action, exposed by
AiTextRuntimeOwner, ReceiptAiRuntimeOwner, AccountReceiptAiRuntime and
PersistentSupabaseRuntime. It requires the same retained reader/flow/transport,
optional AppliedConversationCompletionReleasePort, exact unconsumed applied proof,
current lease/epoch and actual drain. It never applies/reads/clears on the caller's
behalf. Missing/foreign/stale proof, legacy port or held drain returns false; no
metadata absence/UNKNOWN/boolean implies authority. Production host borrows only
its existing private project/account store and uses the same readiness/generation/
close/logout/refresh/terminal/draining barriers for both operations. No new SDK or
store owner, learner flag, automatic retry or HTTP-success acknowledgement.

The new TEST ONLY owner regression drives a failed first start through the same
ReceiptGuardedAiTransport, reads the completed original receipt through that
transport's retained reader, rejects a foreign-reader completion, clears the exact
pending metadata, consumes the captured application proof, and then sends exactly
one next turn. Existing direct transport tests still cover held actual HTTP,
late success/error, A-to-B/session replacement, close and reentrant release.
These are injected component tests, not hosted learner proof. Pinned Flutter/Windows
CI must validate this exact head; all14 hosted release groups remain pending.


## Explicit apply/release contract repair — 2026-11-19

Exact-head CI44537668836 exposed nine failures after the earlier combined action:
legacy owners returned false before storage/drain work, while the owned SDK test
observed a next turn without a separate grant. The original apply method has
been restored without removing any of those assertions. The same-transport owner
regression now explicitly releases after apply, retaining its next-turn checks
and adding pre-apply/foreign-release rejection. Three new legacy-owner cases
require no release capability for apply, and no clear during attempted release.
Four new pinned-SDK tests cover explicit one-turn grant and stale proof after
close/logout/refresh; these SDK tests are locally UNRUN pending new exact-head CI.
The fresh33-file pure graph (only flutter_test to test1.26.2 import adaptation)
passes all283 component tests; focused analysis includes curly-braces and doc lint.
No component/native/unsigned JWT result is hosted learner/JWT/RLS/provider proof.


## SDK test timeline correction — 2026-11-19

Exact-head CI44548573216 passed format/analyze and2047 Flutter tests; its sole
failure was the explicit SDK next-turn case. Frozen standalone response examples
reuse assistant ID2222 and sequence0 for both start and turn. They validate shape,
not multi-message chronology. The production transcript guard correctly revoked
that attempted duplicate/non-increasing response after real TEST ONLY SDK HTTP.

The SDK test now deep-copies its turn response into a local TEST ONLY timeline
helper with distinct valid assistant UUID3333 and sequence2. Shared frozen
fixtures/content stay byte-identical. Every positive SDK assertion (exact endpoint,
bearer/body, one next turn, secure metadata, consumed proof/later finish fence)
is unchanged; only the test response source changes. Two additive SDK cases
separately repeat the assistant ID or sequence0 and require syncConflict, revoked
session, preserved turn metadata, no new session/release and no additional HTTP.
No production guard/timeout/interface/default was changed.

Local Dart3.9.2 verification passes283 retained component tests plus4 scratch
checks using the byte-extracted actual SDK response helper and actual captured
session (old standalone fails, valid timeline succeeds, duplicate ID/old sequence
fail, original fixtures unchanged). This is not execution of the SDK test file.
Focused analysis/formatter/QA pass; new exact-head Flutter/SDK/native CI remains
required. All14 hosted release groups remain pending.


## Held secure-clear SDK acceptance — 2026-11-19

Exact-head CI44559405494/latestattempt1 passed all6jobs/all127steps, including
2050 Flutter tests, the corrected explicit SDK next-turn case and independent
duplicate-ID/stale-sequence rejection, plus owned/browser/native/preview gates.
Windows persistent-vault/same SDK/profile/receipt and conditional-clear markers
were observed. These remain TEST ONLY SDK/Auth/HTTP/native component results;
all14 hosted learner release groups remain pending.

The SDK test backend now exposes an optional held-clear barrier/entry signal.
Its default clear still executes without awaiting a new barrier; repeated clears
signal entry only once. Five additional SDK cases exercise application while the
same private store's clear is held: release/commands cannot overlap, prior metadata
and transcript remain, only confirmed success allows explicit release, and failure
maps to fixed internalError with metadata retained/no grant. During held clear,
close/logout must await actual work, refresh must prevent capability replacement,
and late application must return false/revoke rather than publish or release.
The logout case then logs B in only after A's clear drains and proves A's handle
cannot release/create B's AI partition; B's refresh secret remains intact.

Every held operation is released in finally before awaiting observers/teardown.
No production guard, timeout, SDK/store owner or default learner behavior changed.
The5 new full SDK cases are locally UNRUN. Local286-test Dart verification includes
283 retained components plus3 actual-store cases using the byte-extracted backend
(normal held clear, guard loss and clear failure); this is not SDK/hosted proof.
New exact-head Flutter/native CI is required before reporting those cases passed.


## Normal-success acknowledgement prerequisite — 2026-11-19

ConversationMutationLane now offers read-only inspectAcceptedCompletion against
its existing successful mutation cache and exact original-bound completed receipt.
It conservatively compares full command and full typed result, rejects pending/
busy/stale/foreign/mismatched states and excludes receipt-reconciled cache slots.
It sends nothing and performs no store read/clear or claim/proof transition.
CapturedConversationSession.inspectPublishedCompletion now composes that check
with the exact already-published snapshot and session event markers (see
CAPTURED_CONVERSATION_SESSION.md). Old start/turn results after later progress,
reconciled replay and lane success rejected by transcript validation cannot match.
This synchronous inspection returns the same immutable view, performs no I/O and
mints no proof. Normal-success acknowledgement is now a separate explicit host
action: the mutation lane rechecks the exact original and typed accepted result,
then conditionally clears and confirms the same project/owner receipt. The session
revalidates the same immutable snapshot and captured reader/session after that
storage effect before minting a single-use application proof. AiTextRuntimeOwner
consumes the proof on the same retained transport; the ReceiptAiRuntimeOwner and
AccountReceiptAiRuntime expose the action without wiring it into the default UI.
A failed attempted clear or failed proof consumption retires the lease; metadata
absence, raw HTTP success, replay or a read-only snapshot never grants release.
Existing uncertain recovery application/release remains a separate path. Do not
enable provider/default activation or infer hosted evidence from these components.


## Normal-success receipt acknowledgement — 2026-11-20

The normal-success path now has a distinct explicit host operation. It requires
an accepted, non-reconciled lane slot; full original fingerprint and full typed
receipt result equality; no pending/held mutation; the exact open project/owner
store; and the already-published session event/message/summary snapshot. The
lane conditionally clears the matching reference and confirms absence through a
second read. A missing/mismatched reference or ambiguous attempted clear does
not grant acknowledgement and retires the lane.

The session reserves across storage I/O, captures the pre-clear immutable view,
then rechecks the same completion command/receipt, reader, captured Auth session,
current generation, exact snapshot identity, idle lane and open store after the
clear. Only then does it mint the existing private single-use application proof.
The runtime owner keeps the same lease/reader/session/transport reserved while it
consumes that proof through the exact dispatch gate. If consumption fails after
clear, the owner invalidates the lease rather than retrying or permitting another
mutation. The accepted slot remains cached so exact same-event replay is local and
does not redispatch; a new event is possible only after proof consumption.

TEST ONLY coverage exercises all three operations, stale snapshots, A-B-A during
a held clear, ambiguous clear failure, same-owner proof consumption, local replay
and the next turn through both receipt owner and account wrapper. This is not
hosted learner/provider/voice/native durability evidence. No default UI, automatic
HTTP acknowledgement, Auth strategy/provider, API/schema/RLS, spend or deployment
was changed; default AI remains off and #17 remains Draft pending human/live gates.


## Owned persistent SDK host forwarding — 2026-11-20

PersistentSupabaseRuntime now exposes explicit
acknowledgePublishedConversationCompletion(completion). It borrows the SAME
private owned receipt store and existing AiTextRuntimeOwner; callers cannot supply
a store, project, Auth hint or replacement lease. A private exhaustive action enum
shares the existing apply/release pre/post guards: configured conversation owner,
store/owner presence, ready runtime and exact Auth/generation, close/logout/refresh,
terminal and actual-drain barriers. Existing uncertain apply/release semantics stay
separate. The new method delegates normal-success clear AND proof consumption to
the existing owner, then checks the same captured host generation after await.
No automatic acknowledgement, new SDK/storage owner, learner/default binding,
provider activation or durable payload storage is introduced.

Six new TEST ONLY pinned SDK/HTTP cases require normal accepted start plus an
authenticated original-bound receipt lookup, same snapshot/store/lease, local replay
without redispatch and one subsequent turn only after acknowledgement. Held clear
excludes reentry/commands and preserves the prior metadata/view; success or fixed
clear failure is checked. Close/logout must await actual clear, refresh must fence
replacement capabilities, and late completion cannot grant acknowledgement. Logout
then B login must preserve B's secret and reject A's old handle without AI HTTP.
All held futures drain in finally. The backend first-write entry signal is now
idempotent; subsequent writes still execute. Local component verification excludes
these six SDK cases; exact-head Flutter CI must execute them. Native OS/hosted
learner/JWT/RLS/provider and all14 release groups remain separate acceptance gates.
