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

## Windows same-SDK/profile process probe

The mandatory existing Windows bridge now adds four new runner processes:
receipt-sdk-write/reopen/clear/absent, with receipt-sdk-cleanup attempted in the
outer finally even after any earlier cleanup fails. Each invocation uses the
validated unique bridge GUID origin suffixed -sdk-receipt.invalid and one fixed
synthetic account/event. No learner target or service connection is accepted.

The new TEST ONLY fixture composes actual Supabase client/binding/AccountController,
held own-profile readiness, same-SDK receipt factory, actual captured HTTP transport
and Windows facade/MethodChannel/Credential Manager. Auth HTTP/JWT/profile and AI
HTTP are synthetic. This does not run persistent refresh-token startup or verify
hosted identity/provider/RLS. Existing persistent runtime and all older probes
remain required and unchanged; separate evidence is not a combined journey.

Write checks the slot initially absent/profile blocks acquisition. At actual HTTP
send verify original body/fixed endpoint/captured bearer/key/no redirects and read
back the real native receipt already present. Hold an HTTP response that ignores
abort. Preserve-close must signal actual abort, revoke session, retain native
metadata and exclusive store claim, leave SDK/client borrowed and remain pending.
Release late error; it must be consumed as unauthorized before close completes.
New process reopen sees the exact metadata; same-event start conflicts with ZERO
HTTP and close preserves. Clear process confirms exact local deletion without SDK
logout, then separately logs out Auth. Fourth process confirms absence/no HTTP.
Every held callback is finally released; early send failure is observed instead
of hanging only on port entry. Fixed errors and no token/metadata logs.

These new process phases are authored, locally UNRUN (no Windows/Flutter here).
Exact-head Windows CI must observe the explicit same-SDK/profile receipt marker;
no build/OS pass is claimed before that. Still no cross-process CAS, replay grant,
authenticated lookup, pending release or default activation. Next combined owned
persistent startup/refresh vault and these components, plus real hosted gates.

## Combined persistent-vault Windows phases

Separate receipt-persist-write/reopen/clear/absent/cleanup phases now extend the
same mandatory probe without replacing any original receipt-sdk phase. They use
a different GUID-derived -persistent-receipt.invalid origin. The first process
seeds a fixed TEST ONLY refresh secret into actual Windows Credential Manager.
Actual PersistentAccountAccess.start reads it and calls actual SDK setSession;
Auth HTTP must see exactly one refresh_token grant with the original secret.
Each fresh process returns a different fixed synthetic rotated secret. Verify the
rotated secret in actual native vault before profile publication and after
persistence close; the next process must present that exact saved secret.

The profile account uses actual PersistentAccountAccess as Auth, and the receipt
source uses that SAME SDK via the existing factory. The existing held own-profile,
persisted-before-HTTP, actual ignored-abort drain/claim/preserve and fresh-process
pending block assertions still execute. Local receipt clear leaves the SDK logged
in; separate account.signOut must then clear SDK AND actual Auth vault. The fourth
process checks both real vault partitions absent; finally cleanup attempts both
partitions even after a receipt failure. No enumeration/foreign learner target.

A TEST ONLY RefreshableAccountAccess adapter wraps the actual SDK/binding and dual
Auth/binding lifecycle streams. This is a fixture ownership adapter, not the
private production PersistentSupabaseRuntime port or installed application host.
Auth endpoint/JWT/rotation/profile/AI HTTP remain synthetic. The new combined
process phases require exact-head CI: no local Windows/Flutter/PowerShell
execution or hosted identity/rotation/learner restoration claim. Default app and
all14 hosted gates remain unchanged. Next production-host ownership/integration,
storage failure/account-change journeys and authenticated receipt reconciliation;
unknown metadata never grants provider redispatch or a new command.

### CI đã quan sát và sửa analyzer — 2026-10-26

CI [40292719170](https://github.com/collab-TTAM/nihongo_daily/actions/runs/40292719170)
tại source `932929221df326dae025904b94cd4aa3425f0803`, latest attempt 1, đã chạy
đạt toàn bộ Windows job `121471411984`, bao gồm marker chính xác
`Windows persistent vault/same SDK/profile/receipt rotation preserve/reopen/no-redispatch/logout passed (TEST ONLY Auth/HTTP)`.
Database, ai-boundary và repo-sanity cũng đạt. Tuy nhiên Flutter analyzer dừng ở
lint thiếu block `if` tại `windows_sdk_receipt_fixture.dart:148:5`; các bước Flutter
test/build phía sau bị skip. Tổng CI chưa đạt.

Bản sửa chỉ thêm `{ }` cho phép đổi tên phase có điều kiện; mọi assertion,
deadline, cleanup và security gate giữ nguyên. Source mới cần CI riêng; không
có full Flutter/Dart/Windows SDK để xác minh local. Bằng chứng probe trên không
thay thế production host, hosted learner Auth/RLS/provider hoặc acceptance của
14 nhóm release; learner recovery và quyền gửi lệnh tiếp không thay đổi.

## Shared production persistence adapter

The combined Windows probe now uses SupabaseRefreshableAccountAccess, extracted
from the original production PersistentSupabaseRuntime adapter, replacing only the
duplicate TEST ONLY ownership adapter. Production runtime imports the same shared
class. Exact original methods, dual binding+SDK rotation signals, fixed errors,
subscription close order and borrowed SDK/binding ownership remain; only class/
private-field names and unused wildcard spelling change. SDK/binding fields are
private and no learner configuration or token-state surface is added.

All native probe assertions, process phases and original SDK assertions remain.
Three direct SDK cases cover same-session refresh notification even while the
binding hint identity is stable, closed subscription with borrowed SDK still usable,
and safe restore/refresh error redaction with no accepted hint/refresh token.
New exact-head CI must re-run the combined Windows marker and existing owned
persistent runtime/account/late-response suites. This removes a fixture-port gap;
it does not install the receipt source in the production startup host or prove
hosted Auth/JWT/RLS/provider/learner flows. All14 release gates remain pending.

## Existing owned runtime integration

PersistentSupabaseRuntime can now receive an explicit conversationReceiptStore;
see PERSISTENT_SESSION_LIFECYCLE.md for validation, fixed-account ownership,
shared ONE AI owner, logout join/failed-clear retry and preserve-close ordering.
It reuses the existing private SDK/production persistence adapter and account
profile barrier. No second AI lane or default factory is installed. The optional
source retires permanently on logout; a host must close/replace it before another
receipt lifetime. Auth/SRS re-login alone cannot retarget/renew that AI capability.
Eight owned-runtime/SDK cases require new exact-head Flutter/Windows CI. Hosted
identity/provider, default learner activation and authenticated reconciliation
are still missing; metadata never grants replay or a new event.

## Windows owned production-runtime receipt probe

The existing mandatory Windows bridge now also runs receipt-owned-write/reopen/
logout/held-logout/absent as fresh runner/engine/isolate processes. These phases
construct the actual PersistentSupabaseRuntime with its PRIVATE SDK, production
refresh adapter, real Windows refresh vault, NativeReviewJournal and optional
Windows receipt store. No parallel component assembly or duplicate SDK adapter.
The bridge GUID derives two separate .invalid project origins and temporary
journal directories; only synthetic fixed account/event/secrets are accepted.

First write seeds a TEST ONLY native refresh secret. Startup must send exactly
one refresh grant with the saved secret, save its rotated replacement to actual
Credential Manager BEFORE ensure_profile dispatch, and block AI acquisition while
the profile HTTP response is held. After own-profile readiness, captured AI HTTP
checks exact original request/endpoint/key/bearer/no redirects and reads back the
real receipt already stored. Preserve-close aborts synchronously but must wait
for an HTTP response that deliberately ignores abort. Before release, readiness
is fenced, metadata and exclusive partition ownership remain. Release a late
private error: consume it as unauthorized, finish close, preserve both native
refresh and receipt records and leave borrowed HTTP open until fixture cleanup.

Second process restores the exact first rotated secret, persists the next rotation
and rejects the original event with SYNC_CONFLICT and ZERO AI HTTP. Close preserves
both records. Third process restores that new secret, rotates again and logs out
through runtime.account.signOut; successful logout must clear BOTH native stores.
A separate unique project exercises logout DURING actual held HTTP: Auth vault
clears while receipt remains owned/present and logout stays pending; only actual
late-response drain permits receipt deletion and signedOut. Fifth process checks
both project partitions absent and starts the actual runtime with ZERO Auth,
profile or AI dispatch. Native SRS journal remains empty throughout.

Every held response is finally released and cleanup failures fail CI. The outer
PowerShell finally attempts the new receipt-owned-cleanup even if earlier cleanup
fails; it clears both exact synthetic namespaces and both unique directories,
without enumeration or foreign targets. Existing 60-second process bounds, all
older phases/assertions and the normal learner rebuild remain required.

Parent source388588f CI40307092083/latestattempt1 is observed SUCCESS in all5
jobs/every required step/no skips. Flutter log121519501294 explicitly confirms all8
owned-runtime cases; Windows121518849339 confirms the prior combined component
marker. This new native owned-host journey is AUTHORED locally UNRUN; new exact-
head CI must print the OWNED production runtime/vault/receipt marker. Local Dart
format/QA inventory/regressions are distinct from Flutter/native execution.
Auth endpoint/JWT/rotation/profile/AI HTTP remain TEST ONLY. No hosted identity,
provider, learner activation, cross-process CAS, hardware-loss or reconciliation
proof. One pending mutation/default AI unavailable/all14 release gates remain;
next storage-failure/account-change cases and authenticated lookup/verified
conditional release before sequential conversation commands.
