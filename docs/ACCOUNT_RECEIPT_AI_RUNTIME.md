# Profile-gated receipt runtime — Issue #17

AccountReceiptAiRuntime<T> is an explicit single-account/project source for text,
conversation and public scenarios. It owns ReceiptAiRuntimeOwner and its supplied
secure store. It borrows an existing AccountController<T> and a trusted accessor
for that account's ready runtime Auth. The host's transport factory must bind the
same owned SDK, trusted configured project, captured Auth and supplied store; the
component cannot inspect a generic transport's endpoint. The factory retains the
existing obligation to clean partial/orphan resources if construction fails.
No learner-editable origin/key, alternate Auth, SDK owner or persistence writer is
created. Construction is itself trusted opt-in; ordinary/staging app composition
is unchanged and never installs this source. No new UI or automatic request.

The existing account barrier remains authoritative: persistent Auth must first
save the rotated refresh secret, then ensure the exact own profile. The source
captures the exact ready-runtime object AND ReviewSession identity plus a fresh
AI generation. The store's fixed canonical owner must match that session; another
ready account cannot retarget the store. The trusted accessor must return the same
accepted session identity. Check account readiness again around that accessor;
synchronous reentry cannot publish a partially captured generation. Unknown
accessor errors permanently disable availability with no raw error exposure.

Every account transition synchronously invalidates the old AI lease; its existing
runtime drains actual receipt storage/transport work before constructing another.
Captured readiness closures recheck the live account objects at use/publication,
even before a stream hint arrives. Refresh, profile loss, logout, disposal and
A-B-A replacement cannot revive the old capability or send with replacement Auth.
Fresh acquisitions send nothing; all three source interfaces share one lease.
After actual drain the same account may acquire a fresh generation, but existing
pending metadata still blocks even the identical event. Metadata never supplies
an original command or authorizes replay, another event or provider redispatch.

Two terminal choices delegate to the existing receipt lifecycle:

- close revokes immediately, cancels the account subscription, waits actual work
  and preserves metadata before closing/releasing the store partition.
- clearForSignOut revokes immediately and cancels the subscription, waits actual
  work/owned transport cleanup, then confirms exact partition clear and releases
  ownership. This is LOCAL receipt cleanup. Host separately revokes/signs out its
  borrowed account/Auth and awaits BOTH before reporting successful logout.

Failure to drain/clear remains a fixed AiTextFailure(INTERNAL_ERROR), never local
logout success. Failed clear keeps ownership; close cannot bypass or retry it.
Only another explicit clearForSignOut retries. Failed owned transport cleanup
never clears/releases. Preserve-close cannot later clear a possibly handed-off
partition. This source does not close/dispose borrowed account, SDK, HTTP or
credential vault, and makes no remote session-revocation guarantee. Host must
await old cleanup before replacing project/source/store ownership. External same-
partition writers and competing processes remain excluded by the host; the store
claim is isolate-local, not cross-process CAS.

Fourteen new pure component cases compose actual PersistentAccountAccess,
SessionCredentialVault, AccountController, profile decoder, new source and existing
receipt owner/runtime/session/decorator/store. SDK, OS vault, profile and mutation
ports are explicitly TEST ONLY. They cover persisted startup then held own profile;
vault/profile/foreign-profile failure; fixed foreign partition; accessor reentry,
revocation during capture and foreign Auth; refresh and A-B-A during held write;
ignored late callback success/error before local clear; ambiguous persisted write,
failed clear/blocked replacement/explicit retry; and failed owned transport drain.
No new fixture is application data. Tests do not prove actual SDK/Windows-backed
startup, signed JWT/RLS, hosted provider or learner restoration. Earlier separate
SDK and actual Windows process evidence cannot establish the combined journey.

Parent0c98c72 CI40273658624/latestattempt1 passed all5 jobs/every required step,
1294 Flutter/five Chrome; all8 SDK receipt cases and BOTH retained timeout cases
explicitly passed. Thus the preceding disposable-harness timeout is not an
observed Flutter CI failure. New code needs its own exact-head full CI. Local
new/retained pure test and focused analysis evidence is in PROJECT_STATUS/PR41;
full graph lints6 reports four infos on unchanged Auth files (multiple underscores),
not new-source diagnostics. No old source/assertions/lints suppressed or changed.

Next bind this explicit source to the SAME caller-owned SDK plus Windows store
through a reviewed host lifecycle, and observe startup/profile/refresh/account/
shutdown across those real components. Authenticated lookup/verified conditional
release is required before enabling sequential conversation commands. No such
lookup endpoint or reset is invented here. Learner route remains memory-only;
one pending mutation/default AI unavailable/all14 hosted release groups pending.
No Auth strategy/provider/collection/spend/security/API/SQL/RLS/dependency/CI/
content/Pro/merge/release change or Personal Alpha acceptance.

## Same caller-owned Supabase factory

createSupabaseAccountReceiptAiRuntime<T> now binds the source to the supplied
actual Supabase client and existing captured HTTP transport. Before taking store
ownership, validate trusted URL/public key, SDK REST origin/key, store project
origin and timeout in(0,15seconds]. Failure is fixed VALIDATION_FAILURE; caller
still owns the untouched store. Per-lease factory checks accepted session/store
owner/readiness BEFORE constructing the inner transport. Its known mutation/read
interfaces and captured owner satisfy every receipt decorator constructor check;
no asynchronous orphan is created on a rejected decorator. Account source keeps
its original exact runtime/session/generation and actual drain barriers.

Successful factory transfers store ownership only, borrows SDK/account/supplied
HTTP, and allocates no transport/storage read/request until explicit acquisition
and command. Host still supplies the same account persistence/profile barrier,
keeps SDK alive through receipt drain and separately signs out Auth. No public SDK
or URL/key learner form/default activation is added. Existing Windows secure store
can be explicitly supplied, but its use is NOT yet observed with this factory.

Six new SDK cases in the existing transport suite cover held own-profile gating
then exact captured bearer/endpoint/key/body and persistence-before-send; project
and key mismatch before ownership; actual SDK A-B-A during held write with zero
HTTP/reopened-pending conflict; actual ignored AbortableRequest abort with late
success/error, separate host SDK logout, metadata retained until drain then exact
clear and borrowed HTTP left open. Every old SDK assertion/setup line retained.
Auth JWT/HTTP, own-profile response and receipt backend are TEST ONLY. The actual
SDK/binding/account/profile/source/transport/receipt chain executes, but NOT the
owned persistent startup/refresh-secret vault or Windows OS in one journey.
No hosted JWT/RLS/provider proof or authenticated receipt lookup/replay grant.

Parent4cee07d CI40279612687/attempt1 all5/every required step SUCCESS;1308Flutter/
fiveChrome/all14 account-source cases explicitly passed. New source requires its
own exact-head CI. Next combined owned persistence +same SDK +actual Windows store
host/process proof, and authenticated lookup/verified conditional release before
sequential conversation commands. All14 hosted gates remain pending/AI off.
