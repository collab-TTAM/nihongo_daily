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
Storage read errors preserve the existing entry until an explicit cleanup/login. The account controller also retains its fixed sign-in error across queued no-session notifications; only an explicit retry or logout changes that error state.

Await `runtime.close()` before replacing the assembly. It revokes access, disposes
the account controller, drains interrupted Auth/credential operations, cancels
subscriptions and disposes only owned SDK/network resources. A fully saved
session is preserved for the next startup; interrupted Auth is cleaned. Supplied
HTTP clients and the supplied review store remain caller-owned. The required review store preserves uncertain events while rotation temporarily removes the old study runtime; this assembly never falls back to process-only review storage. The controller/provider's disposal alone does
not close this assembly. Neither close nor local logout promises all-device
revocation, OS-logoff/power-loss recovery or protection from same-OS-user processes.

## Reproduction and separate review

In `apps/flutter_app`, run `dart run tool/verify_session_lifecycle.dart` and
`flutter test`. Twenty-five pure cases cover empty/refresh startup, persistence
barriers, same-session rotation, account switches, older in-flight writes,
logout during write/restore/login, storage/read/clear/SDK errors and explicit
retry, revocation, owner exclusivity, stream closure and disposal. Fifteen pinned-SDK
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


## Caller-owned Supabase vault integration regressions — 2026-10-31

Two additional TEST ONLY cases are authored to exercise the actual pinned Supabase SDK and the
owned runtime's HTTP dispatch against the isolated in-memory OS-vault port:

- A credential-store write failure after Auth sign-in must keep the account
  unavailable, clear the uncertain secret, and issue no own-profile request.
  After the storage port recovers, only an explicit second login may persist
  the refresh token and proceed to the profile barrier.
- A delayed User A sign-in response delivered after explicit logout must not
  restore A, write A's refresh token, or dispatch A's profile. A subsequent
  explicit User B login must persist B's rotated refresh token and send B's
  captured bearer to the own-profile RPC.

These tests complement the existing pure lifecycle A/B and same-session
rotation fixtures, SDK timeout/late-startup response, and persist-before-profile
tests. They do not verify hosted JWT signatures, deployed RLS, actual Supabase
credentials, or a live learner. Default app startup remains the preview path;
no Auth strategy, provider, database, RLS, deployment or secret fallback changed.
Exact-head CI for this source increment is pending and is recorded in PR #37.


## Late refresh response after logout — 2026-10-31

A third pinned-SDK/owned-runtime HTTP regression now holds User A's refresh-token
rotation response, performs explicit local logout and vault clear, then releases
the old response. The test requires the refresh operation to fail safely, keeps
A's runtime unavailable, verifies no additional `ensure_profile` request or
stored A secret, and only then signs in User B. B must persist its own rotated
refresh secret and the profile request must carry B's captured bearer.

This closes a source-level gap between the earlier late-sign-in and late-startup
tests: a refresh response already in flight at logout must not resurrect the
same account's old session or race a subsequent account switch. The test uses
the pinned Supabase SDK with a TEST ONLY MockClient and in-memory vault backend;
it does not prove hosted JWT signatures, deployed RLS or live account isolation.
The existing storage-failure, write/clear ordering, generation guards and all
prior assertions remain unchanged. Fresh exact-head CI is required for this new
case; the preceding source head's successful CI is not carried forward.


## Credential clear failure blocks account replacement — 2026-10-31

A new pinned-Supabase-SDK/owned-runtime regression injects a failure while the
caller-owned credential backend clears User A's refresh token during logout.
The account must remain fenced, the old secret may remain physically present but
cannot authorize a runtime, and a User B sign-in attempt must not dispatch Auth
or profile requests while cleanup is still failing. After an explicit logout
retry successfully clears the credential, B can sign in, persist B's own rotated
secret and provision only B's profile with B's captured bearer.

This covers the full SDK/controller boundary for clear failure and retry; the
existing pure vault/lifecycle cases already cover clear ordering and retry at the
port level. The new case uses a TEST ONLY in-memory OS backend and pinned SDK
MockClient, not Windows Credential Manager failure injection or hosted Auth.
No plaintext fallback, auto-retry, default Auth activation or cross-account
cache exception is introduced. Exact-head CI must run the new test before it is
counted as verified.


## Windows OS-backed late refresh and account switch — 2026-11-01

The Windows runner's runtime-late-refresh phase extends the existing SDK/OS
bridge probe rather than relying only on the in-memory vault tests. It uses the
real production MethodChannel/Credential Manager and PersistentSupabaseRuntime
with a TEST ONLY HTTP handler:

1. Persist User A's synthetic refresh secret in the real OS vault and hold the
   startup refresh response before the SDK can complete restoration.
2. Explicitly log out, require the credential slot to be empty and keep profile
   readiness unavailable.
3. Release A's late rotated response; the restore must fail closed, leave no
   secret and issue no own-profile request.
4. Sign in User B on the same owned runtime; require exactly one profile request,
   B's captured bearer, B's rotated secret already persisted before profile
   readiness, and no A-owned pending review visible through B's journal scope.
5. Log out B and require the OS credential slot to be empty.

This proves the Windows OS storage bridge participates in the caller-owned SDK
generation/session guards for this deterministic fixture sequence. The HTTP
server, Auth identities and unsigned JWT are TEST ONLY; it does not prove hosted
JWT signatures, deployed PostgREST/RLS, real learner accounts, OS logoff or
hardware power-loss behavior. Storage write/clear failure injection remains in
the isolated backend tests, not a fabricated Credential Manager failure.


## Startup vault read failure and explicit recovery — 2026-11-01

A new pinned-SDK/owned-runtime regression starts with an existing stored refresh
secret while the credential backend reports a read failure. Startup must fail
closed without calling the Auth token endpoint or `ensure_profile`; the existing
stored value is not treated as a usable session. After the backend recovers, only
an explicit login may proceed. The test records method names only and requires
the order `read -> clear -> write`: failed-state cleanup clears the old slot
before authentication, and the new rotated refresh secret is written before the
own-profile barrier can publish study readiness.

This is a TEST ONLY in-memory credential backend with the pinned Supabase SDK and
MockClient HTTP, not a Windows Credential Manager failure injection or hosted
Auth test. It adds no plaintext fallback, automatic retry, default Auth
activation, Auth strategy/provider, schema/RLS or deployment change. The Windows
OS-backed bridge still verifies successful read/write/clear and late refresh
account switching; live hosted identity remains a separate #20 gate.


## Corrupt stored refresh value and explicit recovery — 2026-11-01

A pinned-Supabase-SDK/owned-runtime regression now supplies a malformed stored
refresh value from the TEST ONLY credential backend. Startup must fail closed at
the vault decoder, preserve the corrupt entry for explicit cleanup, and issue no
Auth token refresh or own-profile request. Only an explicit login may clean the
entry and proceed; the method sequence is `read -> clear -> write`, and the new
rotated refresh secret must be persisted before the own-profile barrier opens.

The fixture uses an invalid control-character value, the actual pinned SDK,
MockClient HTTP and an in-memory vault port. It is not a Windows Credential
Manager failure injection or hosted Auth/JWT/RLS evidence. It adds no plaintext
fallback, automatic retry, default Auth activation, Auth strategy/provider,
schema/RLS or deployment change.


## Corrupt-vault cleanup failure remains fenced — 2026-11-01

The pinned-Supabase-SDK regression now combines malformed startup storage with
an explicit cleanup failure. Startup rejects the corrupt refresh value before
Auth/profile dispatch. A subsequent explicit sign-in attempts cleanup first;
when the vault clear fails, the account stays unavailable, the corrupt value
remains untrusted, and no Auth token or own-profile request is sent. After an
explicit logout retry clears the slot, a new explicit sign-in is allowed and
must persist its rotated refresh secret before profile readiness.

This is TEST ONLY MockClient/in-memory-backend coverage. It does not simulate a
Windows Credential Manager failure or establish hosted Auth/JWT/RLS evidence.
No production fallback, automatic retry, default Auth activation, Auth
strategy/provider, migration, schema or RLS behavior is changed.


## Bounded Auth response failures — 2026-11-01

The caller-owned Auth HTTP boundary preserves typed, sanitized transport failures
instead of converting every failure into a retryable network error. A response
that exceeds the 1 MiB cap remains a non-retryable internal error; request/body
timeouts and HTTP client transport failures are reported as retryable network
unavailability. The pinned SDK adapter and persistent account owner rethrow only
the already-safe `ReviewTransportFailure` type; unknown SDK exceptions continue
to collapse to the generic unauthorized result.

The regression uses a TEST ONLY stored refresh token and an oversized mock Auth
response. It requires startup to fail closed, retain the untrusted stored value
for explicit recovery, and make no own-profile request. The timeout regression
also asserts the safe retryable network classification and late-response discard.
This is not hosted Auth evidence and does not change Auth strategy/provider,
default activation, credential storage, schema or RLS.
