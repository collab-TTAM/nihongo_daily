# Owned persistent session lifecycle

`PersistentSupabaseRuntime` explicitly creates and exclusively owns a new pinned
Supabase SDK client, review binding, persistence access and account controller.
The caller supplies the trusted project URL/public key and matching credential
vault and an explicitly supplied DurableReviewStore, then awaits `start()` before installing `runtime.account` into the existing
account provider. A failed start returns a fixed safe error; caller must show a
restore failure and offer explicit login, which first cleans failed storage/SDK
state. Never put secrets in Riverpod state, journals, profile fields or logging.
No application startup configuration or default runtime activation is added.

The assembly validates endpoint, public-key shape and canonical vault target
before creating the client. Web is rejected because the pinned SDK broadcasts
Session objects across tabs; this component does not authorize browser token
storage/restore. The existing Windows vault is the implemented OS backend.
Other platforms still fail unavailable through that backend. Mock backends in
tests are not alternate production stores. No dependency/provider/Auth strategy,
production deployment, RLS, migration or frozen API contract changes occur.

## Readiness and ownership

`PersistentAccountAccess` is the account Auth port. `start()` reads only the
refresh secret and invokes SDK `setSession(secret)` without an access token,
requiring a server refresh. No session JSON/local access JWT is reconstructed.
The exact current rotated refresh secret must be successfully written before a
ReviewSession is exposed. The existing own-profile barrier then grants study
access. Secret strings remain private internal operational data; public phases
and account state contain no credentials. SDK logs are disabled before client
creation. Auth HTTP accepts only same-origin Auth/REST paths, disables redirects,
limits responses to 1MiB and bounds each full headers/body HTTP attempt to 15 seconds. The pinned SDK internally retries refresh transport/5xx failures under its existing retry policy, even with auto-refresh disabled; a full Auth operation can exceed 15 seconds. The persistence/controller layer adds no retry loop or timer.
Timeout/oversize/transport failures are fixed safe errors. A late timed-out
response cannot reach the SDK; the late response stream is cancelled.

The SDK and its mutation methods stay private. SDK automatic refresh is disabled;
`refresh()` is explicit and applies the same persistence barrier. No automatic
refresh timer is installed by default. The optional owned scheduler is described
in SESSION_REFRESH.md; it adds no failure retry loop. Without that opt-in, caller
must refresh before expiry;
expiry itself revokes review access and clears the persisted secret via the
binding event. Opt-in scheduling has fixture/source CI evidence; hosted expiry/rotation and
OS suspension acceptance remain separate. SDK rotation signals are observed independently of review lifecycle
signals because the review binding preserves identity on same-session refresh.

One active persistence owner is allowed per canonical project target in this
Dart isolate. Closing drains operations before releasing the owner slot. This
is not cross-process CAS/locking; caller must not run competing same-project
credential writers in multiple application instances. Credential Manager remains
OS-user scoped. Server verification is authoritative; decoded JWT hints are only
fail-closed client checks. No memory-zeroization claim is added for Dart strings.

## Logout, failure and shutdown

Logout revokes readiness before awaiting anything. SDK sign-out and credential
clear are both attempted even when one fails. Clear is ordered after any already
running write. Generation/session/secret guards prevent old queued writes or
responses from granting access. Logout/disposal during an Auth request keeps the
gate fenced and cleans again after that request settles, including SDK logout
failure followed by late sign-in success. Explicit retry is required after errors.

Every session rotation/account change revokes the old persistence gate until the
new secret is saved. No profile or study request is issued through the account
runtime before that barrier. Getter checks also reject a changed SDK identity or
secret before queued notifications are delivered. Failed writes fence access and
attempt credential clear. Clear failures remain visible as failed persistence;
later explicit login/logout must clean successfully before accepting a session.
Storage read errors preserve the existing entry until an explicit cleanup/login.

Await `runtime.close()` before replacing the assembly. It revokes access, disposes
the account controller, drains interrupted Auth/credential operations, cancels
subscriptions and disposes only owned SDK/network resources. A fully saved
session is preserved for the next startup; interrupted Auth is cleaned. Supplied
HTTP clients and the supplied review store remain caller-owned. The required review store preserves uncertain events while rotation temporarily removes the old study runtime; this assembly never falls back to process-only review storage. The controller/provider's disposal alone does
not close this assembly. Neither close nor local logout promises all-device
revocation, OS-logoff/power-loss recovery or protection from same-OS-user processes.

## Reproduction and separate review

In `apps/flutter_app`, run `dart run tool/verify_session_lifecycle.dart` and
`flutter test`. Twenty-two pure cases cover empty/refresh startup, persistence
barriers, same-session rotation, account switches, older in-flight writes,
logout during write/restore/login, storage/read/clear/SDK errors and explicit
retry, revocation, owner exclusivity, stream closure and disposal. Seven pinned-SDK
HTTP cases cover refresh-only startup/profile ordering, explicit rotation/logout,
late restore, rejected stored token recovery, log/scope checks, timeout and original pending-review retention across rotation/logout/relogin using actual disposable native disk.
Both SDK HTTP and OS storage here are TEST ONLY ports, not hosted login proof.

The existing actual Windows Credential Manager/process probe remains mandatory,
but it does not exercise this assembly's Dart-to-native bridge. Existing SQL/RLS,
profile races, Chrome, native disk, security, wire and release-build checks remain.
Current-source CI must pass; historical previous-source success is insufficient.
All 14 live Personal Alpha release groups remain pending. Keep PR #37 draft and
#20/#22/#15 open. Next: interactive Windows bridge/restart, hosted Auth learner
acceptance, caller startup/error UI and refresh scheduling.

Separate review checked persist-before-profile, no old credential fallback,
SDK ownership and log timing, exact project scope, callback-safe logout, clear
ordering, asynchronous late-result cleanup, failed-state retry and close draining.
Pinned SDK source inspected locally: supabase 2.16.5/gotrue 2.27.3 setSession,
refreshSession/session-version guards, signOut and callback/logging behavior.
Tests do not prove hosted JWT signatures, account/device isolation, real token
expiry/rotation windows, native interactive launch or production safety.


## Verified source evidence

Source `021c36bf7a5572dcc0111161d093a0fc7b3377f8` passed all five jobs in
[CI38575156585](https://github.com/collab-TTAM/nihongo_daily/actions/runs/38575156585).
Observed Flutter format/analyze without issues, 312 tests including 22 pure
lifecycle/seven pinned-SDK HTTP cases, five real Chrome cases, the mandatory
lifecycle verifier, retained wire/native/same-run SQL gates and web/Windows builds.
The Windows credential API/process probe and all four file/process verifiers
passed. Exact-head/all-critical-step QA accepted unmodified run/latest-attempt
metadata. All 233 local source blobs matched GitHub; N4 PR #38 stayed separate.

Review corrections preserved every gate/assertion: inherited-stream @override,
operation ownership through late cleanup, cancellation during failed-state retry,
private SDK mutation port, Japanese JSON fixture encoding and required review
store to preserve uncertain events when rotation replaces the study runtime.
The SDK timeout test's observed ~12-second completion led to checking its refresh
retry implementation: bounds apply per HTTP attempt, not a 15-second whole-Auth
promise. No retry-policy/provider/security change or claim of no SDK retries.

Local evidence: 22 pure lifecycle and ten retained account cases, source analysis/
format, 49 Python contract and 17 QA tests. Full SDK/Flutter/Chrome/build/native SQL
and Windows evidence came from CI, not local execution. Auth/OS lifecycle ports
are still TEST ONLY; the seventh SDK case uses actual disposable review files.
No hosted login/JWT signatures or interactive Dart-to-Credential-Manager startup
restoration evidence. Default runtime remains null and explicit refresh scheduling
is still caller work. All 14 live release groups remain pending; keep #37 draft.
Source evidence is historical for subsequent documentation/source commits.

## Actual Windows runtime restart probe

The separate TEST ONLY Flutter runner now invokes `PersistentSupabaseRuntime`
with the real production Windows vault/MethodChannel/Credential Manager and
NativeReviewJournal. Five additional fresh-process phases cover explicit login,
refresh-only restore of the previous secret with rotation, restore/logout with
synchronous fencing, signed-out restart without any Auth/profile dispatch, and
401 stored-token rejection followed by explicit login/logout recovery.
The fixture profile handler reads the actual OS vault before returning: profile
dispatch must follow saving the exact rotated secret. Runtime close must preserve
a fully saved secret. Each phase retains the same original uncertain review in
the real journal; unexpected endpoints (including submit_review) fail the probe.

`tool/windows_runtime_fixture.dart` contains fixed synthetic credentials, unsigned
JWTs and actual pinned SDK with mock HTTP; no hosted request or live credential
is accepted. GUID-qualified `.invalid` scope and per-run temp journal are cleaned
by the bounded PowerShell finally phase. The normal learner entrypoint is rebuilt
before artifact upload. These checks narrow SDK-to-OS process-restart evidence
only when observed passing. They do not establish hosted JWT/Auth, two-client
identity isolation, OS-logoff/power-loss, concurrent process writers or actual
learner UI. No default activation, provider, dependency or contract changes.

Verified source `e39d6fee1ac554f8e9802294b09ef54d5ed17b63` passed all five jobs
in https://github.com/collab-TTAM/nihongo_daily/actions/runs/38590916038 .
Observed 312 Flutter tests, five actual Chrome tests, analysis/format, all ten
Dart vault/runtime process phases with real Credential Manager/journal, native
credential/process probe, retained SQL/native/wire/security gates and normal
web/Windows preview builds/uploads. Windows logs explicitly confirm both bridge
and persistent SDK runtime cross-process success. Raw run/latest-attempt metadata
passed exact-source-head/every-required-step QA. Auth HTTP and JWT signatures
remain simulated; this is sequential OS-backed process restoration, not hosted
identity/device/logoff/power-loss proof. One fixture lint block and one retained
SDK test's fixed event-turn readiness heuristic were corrected without changing
production logic or original ready/non-null expectations. Source evidence is
historical for later documentation commits; next startup/error UI and explicit
refresh scheduling, then configured hosted learner acceptance.

## Shared production SDK persistence port

The unchanged private SDK persistence adapter is extracted as internal host
component SupabaseRefreshableAccountAccess. PersistentSupabaseRuntime still
constructs the same port around its private SDK/binding and closes it in the same
order, after persistence/AI drains and before binding/SDK disposal. No caller-facing
runtime SDK handle or automatic activation is added. The component owns only its
two lifecycle subscriptions; host must supply matching binding/client, retain sole
Auth mutation ownership, disable SDK logs/auto-refresh and keep refresh secrets
out of UI/state/logging. Its secret getter belongs only to persistence machinery.

The Windows combined receipt probe now uses this SAME production port instead of
a TEST ONLY duplicate. Auth/JWT/profile/HTTP remain simulated; production runtime
and native component checks still do not prove a deployed learner journey. Actual
same-session SDK refresh signal, safe restore/refresh failures and borrowed SDK
lifetime have focused SDK regressions; full old owned-runtime/Windows checks remain
mandatory exact-head CI. No Auth strategy/provider/storage policy change.

## Optional owned conversation receipt store

PersistentSupabaseRuntime now optionally accepts conversationReceiptStore. The
trusted host must explicitly enable conversation, supply the same project origin,
an OPEN fixed-account secure store, and keep exclusive ownership. Invalid scope/
mode fails before SDK construction or store ownership transfer. A successful
constructor owns this store. Default/staging builders supply none and are unchanged.
No learner URL/key form, fake Auth/save success or extra SDK/token writer.

The existing ONE AI owner is backed by ReceiptAiRuntimeOwner in this opt-in mode;
text/conversation/scenarios still share the same generation/transport/drain. The
store's owner must match the exact accepted Auth hint before inner SDK transport
allocation. Existing persisted-refresh/own-profile readiness gates still apply.
The decorator writes metadata before mutation dispatch; existing pending metadata
blocks even identical events. No metadata-derived replay or later-command grant.

Account logout revokes the account gate first, then starts BOTH receipt retirement/
clear and existing persistence SDK logout/refresh-vault cleanup. Both attempts are
observed even if one fails. Receipt clear waits actual storage/HTTP and owned
transport drain; logout succeeds only after both operations. Receipt failure maps
to the existing fixed account signOutError, retains partition ownership and needs
an explicit account logout retry. Use account.signOut, not direct manipulation of
runtime.persistence/SDK. Sign-in/readiness/refresh logic is otherwise unchanged.

Runtime close retires the same AI owner, drains actual work, preserves receipt
metadata/releases the partition, then follows existing SDK disposal ordering.
Failed receipt cleanup blocks SDK teardown success; close cannot bypass/retry a
failed explicit clear. Host must observe failures. No remote logout guarantee or
server receipt deletion is inferred. A failed overall close remains failed.

This fixed-partition receipt source is terminal after explicit logout. Auth/SRS
can sign in again, but AI remains unavailable until host closes/replaces the owned
runtime with a fresh explicit receipt store/lifecycle. It never retargets the old
partition to B or clears ambiguous state to manufacture new command permission.
One pending mutation still requires authenticated lookup/verified conditional
release before sequential conversation can be enabled for learners.

Eight new actual owned-runtime/SDK tests are authored for startup rotation/profile,
persistence-before-HTTP/preserve-close, held ignored-abort logout late success/error,
failed clear/claim/explicit retry, refresh during held receipt write, post-logout
other-account source retirement, and foreign project pre-ownership rejection.
Auth/JWT/vault/profile/AI HTTP/receipt backend are TEST ONLY; full Flutter/native
execution needs exact-head CI. This is an opt-in production assembly change, not
installed startup configuration, native combined-host proof or hosted learner
acceptance. All14 release gates/default AI unavailable remain.

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

## Owned receipt storage failure regressions

Source94e0343 CI40314676148/latestattempt1 now passed all5 jobs and every required
step without skips. Windows121544248148 explicitly printed the OWNED production
runtime/vault/receipt restore/preserve/reopen/no-redispatch/held-logout marker.
That verifies the previous native host probe with TEST ONLY Auth/HTTP, not hosted
identity/provider or live learner acceptance.

Six additional tests now exercise the actual PersistentSupabaseRuntime/private
SDK/production receipt chain using controllable TEST ONLY receipt storage. Four
cases inject read failure, corrupt stored data, failure before write, and an
ambiguous write that saves metadata then throws. All require fixed non-retryable
INTERNAL_ERROR without private details, failed-store state and ZERO AI HTTP.
Auth remains separately valid. Repairing the storage port and refreshing Auth
cannot renew the attempted command; fresh generation still conflicts without
reading/overwriting/clearing the original metadata. Only explicit account logout
clears receipt plus refresh vault; no plaintext fallback or replay grant.

Two more cases hold an actual receipt write through account logout, then release
either success or an error AFTER saving metadata. Logout revokes readiness and
clears Auth immediately, but must stay pending with the receipt partition claimed
and no clear/AI HTTP until storage really settles. The late result is consumed as
UNAUTHORIZED; confirmed metadata clear follows write, then logout is signedOut,
store closed and borrowed HTTP remains open. Every held write is released and
logout awaited in finally. Existing failed-clear/explicit retry tests remain.

The new six are authored locally UNRUN; formatting/QA checks do not replace new
exact-head Flutter analysis/test/build evidence. No OS fault injection or hosted
JWT/provider/RLS proof. Native host tests and all old assertions stay required;
production code/defaults/CI/Auth strategy/security/Pro content are unchanged.
Next remaining account-change/failure journeys and authenticated receipt lookup/
verified conditional release. One pending mutation/learner memory-only/default
AI unavailable/all14 hosted gates remain.

## Held receipt write and account A-B-A

Sourceb4d4e68 CI40321214507/latestattempt1 passed all5 jobs/every required step,
with all6 storage-failure cases explicitly observed in Flutter121567036723 and
retained OWNED native Windows marker121566412769. New regressions below require
their own exact-head CI; none are claimed locally executed.

Two additional tests hold A's receipt write through logout, releasing either
success or an ambiguous failure AFTER metadata was saved. While logout drains,
trying B's login must produce ZERO additional SDK token requests: account/profile
and AI readiness stay fenced, Auth vault empty, no receipt clear or AI HTTP.
Only after actual write drains and both cleanup paths finish may B log in.
B's own profile and persisted refresh secret become ready, while the fixed A
receipt source remains terminal. The original A capability stays unauthorized.
After B logout and A login again, new A Auth/profile/refresh are ready but neither
text nor conversation AI revives. Both journals remain empty, metadata stays absent
and the released A receipt partition can be reopened read-only without a record.
No stale transport dispatch, transcript leak, retarget or new-event permission.
Held writes/results/logout are awaited in finally; all old assertions retained.

Actual private SDK and production owned runtime/account/store lifecycle are used;
Auth/JWT/vault/profile/receipt backend/HTTP are TEST ONLY. No hosted user A/B,
native fault injection, two-device or default activation proof. Host must still
close/replace a terminal AI runtime to start a new explicit store lifetime, and
needs authenticated receipt lookup/verified conditional release before enabling
sequential conversation. All14 hosted gates/learner memory-only limit remain.
