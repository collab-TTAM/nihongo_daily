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
The owned adapter also reconciles the final SDK session synchronously after every
successful caller-owned sign-in, restore or refresh operation, before
`PersistentAccountAccess` settles its persistence barrier. This avoids
making startup readiness depend solely on when the SDK's asynchronous Auth
broadcast is delivered. The raw Auth stream remains necessary for out-of-band
refresh/logout events; queued events are still checked against the current
SDK lifecycle and cannot override a newer account.

The owned adapter therefore observes the raw Auth stream as a second listener,
but forwards an event only when it still matches the SDK's current user/session
lifecycle. A session-bearing SIGNED_OUT event is accepted only when its stable
user/session identity matches the SDK's current session; a delayed event for A
cannot revoke replacement B. A null-session SIGNED_OUT event has no identity,
so it is accepted only while the explicit local sign-out generation is still
current and the SDK itself has no current session. A newer sign-in, restore or
refresh invalidates an older pending null sign-out. This preserves a genuine
current-session sign-out while preventing delayed cleanup from deleting a
replacement refresh token. The pinned-SDK A-to-B regression covers the
predicate and the complete vault write/cleanup order.

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

If explicit logout arrives while startup is still awaiting the vault read, the generation is revoked immediately. Credential clear remains serialized behind that read; the saved value is never sent to Auth after it returns, and a replacement login remains blocked until the cancelled startup and clear have drained. The pinned-SDK/Windows-MethodChannel regression holds the read, attempts User B, then verifies clear -> B password grant -> B rotation write -> B own-profile. The held MethodChannel response is TEST ONLY; native Credential Manager behavior remains covered by the separate Windows process probe.

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
retry, revocation, owner exclusivity, stream closure and disposal. Pinned-SDK HTTP cases cover refresh-only startup/profile ordering, explicit rotation/logout,
late restore, rejected stored token recovery, log/scope checks, timeout and original pending-review retention across rotation/logout/relogin using actual disposable native disk.
Both SDK HTTP and OS storage here are TEST ONLY ports, not hosted login proof. The Windows MethodChannel suite also covers logout during a held vault read and blocks B until the stale read/clear drain; that held read is a mock channel response, not a native Credential Manager fault injection.

The new TEST ONLY `windows_persistent_supabase_runtime_test.dart` composes
the actual Dart Windows MethodChannel vault adapter with the pinned Supabase SDK.
It asserts saved-secret read, server refresh, rotated-secret write before
`ensure_profile`, logout before credential clear, fail-closed read/write errors,
and a late User A login followed by User B. The MethodChannel is mocked here:
this verifies assembly wiring, not the native Windows Credential Manager call.
The separate Windows child-process probe still verifies the actual OS store.
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

The caller-owned Auth HTTP boundary preserves typed, sanitized transport failures.
A response that exceeds the 1 MiB cap remains a non-retryable internal error;
request/body timeouts and HTTP client transport failures remain retryable network
unavailability. The pinned Supabase Auth SDK can wrap exceptions from its injected
HTTP client in an SDK `AuthException`, so the owned adapter cannot rely on a
direct `ReviewTransportFailure` catch alone.

The bounded client now keeps only the last typed Auth transport failure in a
private, ephemeral operation channel. `_OwnedSdkAccess` clears that channel at
the start of each serialized Auth operation and consumes it after the SDK call;
each new Auth request also clears an earlier attempt before recording its own
failure. If the SDK wraps a transport exception, the adapter returns the saved
safe category; unknown SDK errors still map to the fixed unauthorized result.
The channel stores no URL, response body, credential or raw exception and is
never logged. It does not change the SDK retry policy or add an application retry.

The pinned-SDK regressions exercise an oversized response and a timed-out refresh
whose late response is discarded. Both must fail startup before own-profile
dispatch while preserving the expected safe error classification. This remains
TEST ONLY MockClient/in-memory-vault coverage, not hosted Auth evidence; Auth
strategy/provider, default activation, credential storage, schema and RLS are
unchanged.


## Runtime close during startup refresh — 2026-11-02

A pinned-Supabase-SDK regression now closes the caller-owned runtime while its
startup refresh response is held. The close future must remain pending until the
late SDK operation settles and cleanup clears the uncertain refresh credential.
The test requires no own-profile dispatch, retains the same-project owner slot
until the drain finishes, then proves a replacement owner can start from an empty
vault. It also probes the injected HTTP client after close to verify that the
runtime disposes only its wrapper and never closes a caller-owned client.

This is TEST ONLY pinned SDK + MockClient + in-memory vault evidence. It does not
prove hosted Auth/JWT/RLS, OS Credential Manager failure injection, OS logoff or
power-loss behavior. No default Auth activation, URL/key input, Auth strategy,
provider, schema, RLS or production configuration changes.

## Refresh rotation vault-write failure — 2026-11-02

A pinned-Supabase-SDK/owned-runtime regression now holds the credential-vault
write after an explicit refresh returns a rotated token, then injects a storage
failure. While the write is pending, the prior persisted secret remains but the
study/profile gate is closed. After failure, the uncertain secret is cleared,
the account remains fenced, the fixed needs-login notice is published, and no
second own-profile request is dispatched.

After the storage port recovers, only an explicit login can persist a fresh
rotated secret. The test holds the own-profile response and verifies that the
secret is already saved while readiness remains closed; readiness opens only
after the matching profile response arrives.

This is TEST ONLY pinned SDK + MockClient + in-memory vault evidence. It does
not prove Windows Credential Manager failure injection, hosted signed-JWT
learner A/B, deployed RLS, OS logoff or power-loss behavior. No default Auth
activation, plaintext fallback, Auth strategy/provider, schema, RLS or
production configuration changes.


## Failed refresh rotation and failed vault cleanup — 2026-11-02

A pinned-Supabase-SDK/owned-runtime regression now combines two consecutive
credential-storage failures. User A's explicit refresh returns a rotated secret,
but the vault write fails; the compensating clear also fails, leaving the prior
secret physically present. The runtime must revoke its accepted session, keep
profile/study readiness closed, publish only the fixed needs-login notice, and
send no additional own-profile request.

An explicit User B login is then attempted while cleanup still fails. It must
retry the clear before dispatching another Auth token request; B cannot inherit
A's retained secret or open a profile. After the vault becomes available, a
second explicit login clears the uncertain A slot, persists B's rotated secret,
and only then waits for B's own-profile response before readiness opens.

This is TEST ONLY pinned SDK + MockClient + in-memory vault evidence. It does not
inject failures into Windows Credential Manager or prove hosted signed-JWT
learner A/B, deployed RLS, OS logoff or power-loss behavior. No plaintext
fallback, automatic retry, default Auth activation, Auth strategy/provider,
schema, RLS or production configuration changes.


## Coalesced SDK sign-out cleanup — 2026-11-02

The owned binding and raw Supabase Auth observer can both report the same
signed-out transition. A delayed duplicate null-session notification must not
enqueue another credential clear after an explicit cleanup has already begun.
PersistentAccountAccess now marks that cleanup before calling SDK sign-out
and coalesces further null-session events until a new non-null session is
observed. This preserves the required serialized order: failed rotation
compensation, failed cross-account cleanup, successful explicit cleanup, then
User B's rotated-secret write. The final stored secret and own-profile bearer
remain bound to B.

The regression remains TEST ONLY pinned SDK + MockClient + in-memory vault
evidence; it is not hosted signed-JWT learner A/B or Windows Credential Manager
failure injection. No automatic retry, plaintext fallback, default Auth
activation, Auth strategy/provider, schema, RLS or production configuration
changes.


## Ignore stale sign-out events after account replacement — 2026-11-02

The prior persistence-level clear coalescing fence was insufficient by itself:
the pinned Supabase SDK can deliver a queued `SIGNED_OUT`/null-session event
for User A after a replacement User B session is already current. The binding
previously revoked its session unconditionally for every such event. The
persistence observer then saw no current session and could enqueue a fourth
vault clear over B's newly rotated refresh token.

`SupabaseReviewBinding` now checks the current SDK session before applying a
signed-out/null event. A current session must pass the full existing session
hint validation. If the event has no session or its stable user + JWT
`session_id` differs from that current lifecycle, the event is stale and is
ignored. An event matching the current lifecycle, or any signed-out event when
the SDK has no current session, still revokes normally. The event comparison
uses only lifecycle identity; it does not persist, expose or log tokens.

The pinned-SDK/MockClient/in-memory-vault regression continues to require the
exact three cleanup attempts, B's rotated refresh secret, B's captured profile
bearer and B-only readiness. This is TEST ONLY SDK evidence, not hosted
signed-JWT learner A/B or native Windows Credential Manager failure injection.
No Auth strategy/provider, default activation, plaintext fallback, schema,
RLS, production configuration or Pro-owned N4 content changed.


## Fence transient registry invalidation during an SDK lifecycle transition — 2026-11-02

The review registry can emit a lifecycle notification when its previous
captured connection is revoked. During a user switch or refresh, the SDK may
already hold a valid replacement session while the corresponding Auth event is
still queued for the binding. That temporary mismatch is not a signed-out
credential state. Forwarding it unconditionally to persistence can schedule an
extra vault clear before the new session's own Auth event is processed.

The owned SDK adapter now forwards a registry notification to the persistence
barrier only when the SDK has no current session, the current SDK session is
invalid/expired, or its exact user/session lifecycle, access token and expiry
match the binding's current hint. A valid-but-not-yet-bound SDK session
suppresses the transient notification; the raw Auth observer still processes
the matching queued event and persists its refresh-token rotation before
own-profile readiness. A genuine logout or expired/invalid SDK session still
reaches the persistence barrier and clears the credential in the existing
serialized order.

The existing pinned-SDK regression retains the exact three cleanup attempts,
operation order, B refresh secret, B profile bearer and B-only readiness. No
test expectation was weakened. This remains TEST ONLY SDK/MockClient/in-memory
vault evidence, not hosted signed-JWT learner A/B or Windows Credential Manager
failure injection.


## Deliver owned lifecycle notifications synchronously — 2026-11-02

The owned SDK adapter delivers its private Auth/registry change stream
synchronously. These notifications describe SDK state at emission time; an
asynchronous second queue could replay a transient null from User A after User
B's sign-in has settled and clear B's newly persisted refresh token.

During an owned restore, sign-in or refresh, the persistence barrier ignores
reentrant lifecycle callbacks while its Auth operation is in flight. The
operation's settle phase then samples the SDK's final current session and drains
serialized credential writes before publishing readiness. Outside an owned
Auth operation, a real signed-out or invalid/expired lifecycle notification is
still handled immediately and its clear remains serialized behind any write.
The synchronous callback performs no SDK mutation or network request.

The A-to-B pinned-SDK regression now checks the exact three cleanup attempts,
the complete vault operation order, B's rotated refresh secret, B's captured
profile bearer, B-only readiness and the absence of a late fourth clear after
profile readiness. This remains TEST ONLY SDK/MockClient/in-memory-vault
evidence, not hosted signed-JWT learner A/B or Windows Credential Manager
failure injection.


## Owned Auth operation generation fence

Supabase Auth may deliver a queued `SIGNED_OUT` event with a null session after
its originating sign-out call has returned. A null event carries no user or
session identity, so sampling only the SDK's state at callback time is not enough
to prove that the event still belongs to the current account lifecycle.

The owned binding advances an operation generation before password
sign-in, refresh-token restore and explicit refresh. An explicit local sign-out
records its generation. A null-session SIGNED_OUT event is accepted only while
that pending sign-out generation still matches and the SDK has no current
session; beginning a newer Auth operation invalidates the older null event.
A session-bearing SIGNED_OUT event is checked separately against the SDK's
current stable user/session identity, so a current-session sign-out is accepted
while a previous-session A event cannot revoke replacement B. Explicit logout
remains accepted in its own generation, while registry expiry/invalid-session
handling and failed Auth operations remain fail-closed through their existing
paths.

This is a local event-ordering guard, not JWT signature verification, hosted Auth
proof, or permission for another caller to mutate the exclusively owned SDK.


## Caller close while startup vault read is pending — 2026-11-04

The caller-owned runtime can be closed while its initial OS credential read is
still pending. Closing revokes the accepted-session generation immediately and
waits for the owned persistence operation to settle. If the vault read returns
after close began, the captured generation/closed guard must reject the saved
secret before any Supabase Auth refresh or own-profile RPC. The cancelled
startup then clears the exact project vault slot before the caller-owned close
completes.

The pinned-Supabase-SDK regression holds the TEST ONLY in-memory vault read,
starts caller close, confirms the saved secret is not cleared before the read
settles, then releases the late read. It requires no Auth token request, no
profile RPC, a single ordered read-then-clear, and a closed persistence phase.

This is a TEST ONLY SDK/MockClient/in-memory-vault lifecycle check. It does not
inject a stalled native Windows Credential Manager call or prove hosted
signed-JWT learner restoration, deployed RLS, OS logoff, or power-loss behavior.
No production Auth/session/vault implementation, default activation, plaintext
fallback, strategy/provider, schema/RLS, or Pro-owned N4 content changes.


## Late credential write and account replacement

The pinned-Supabase-SDK + Windows MethodChannel suite also holds User A's
refresh-secret write after the SDK has returned a session. Logout is issued
while that write is pending. The test verifies that the persistence generation
is revoked immediately, no own-profile request is made for A, and the queued
vault clear cannot overtake the unresolved write. After the write is released,
cleanup clears A's late value before a new B login is accepted. B's rotated
secret must be stored before B's own-profile request, whose bearer and returned
profile must both belong to B.

This is TEST ONLY SDK/HTTP/MethodChannel evidence; the channel is mocked in this
test. The separate Windows Credential Manager/process and runner probes remain
the evidence for native storage/bridge behavior. This does not establish hosted
signed-JWT learner A/B acceptance or deployed RLS.


## Caller close while logout vault clear is pending — 2026-11-06

The caller-owned runtime may be closed while an explicit logout has already
revoked study readiness but its serialized credential-vault clear is still
pending. Close must remain pending until that logout cleanup settles; it must
not dispose the exclusively owned Supabase SDK while the vault operation is
unresolved. The test also verifies that the caller-supplied HTTP client remains
usable after the owned runtime closes.

The pinned-Supabase-SDK regression first establishes a TEST ONLY User A session
and persists its rotated refresh secret. It then holds the in-memory vault
clear, starts logout, and calls runtime close. The expected state is immediately
closed/fenced with no own-profile readiness, while the old secret remains
present only until the held clear is released. Close must not complete early.
After release, logout and close settle, the vault is empty, no extra profile
request occurred, and the borrowed HTTP client still serves its caller-owned
probe.

This is TEST ONLY MockClient/in-memory-vault lifecycle evidence. It does not
inject a delayed native Windows Credential Manager operation and does not prove
hosted signed-JWT learner Auth, deployed RLS, OS logoff, power-loss or physical
multi-device behavior. No production Auth/provider/schema/RLS/default activation
or Pro-owned N4 content changes.


## Late User A write followed by a failed logout clear — 2026-11-06

The pinned-SDK Windows MethodChannel regression holds User A's refresh-secret
write after password Auth has returned a session, then starts explicit logout.
The vault clear must remain queued behind the unresolved write. After the write
is released, the first clear is deliberately failed: study/profile readiness
must remain revoked, the uncertain User A value may remain in the test vault,
and a User B sign-in must produce no Auth or profile request.

Only an explicit successful cleanup retry may clear the old value and reopen
login. The test then signs in User B and requires B's rotated refresh secret to
be persisted before ensure_profile; the only profile/bearer observed belongs
to B. This covers the combined late-write + failed-clear ordering, not merely
the two failure cases in isolation.

This is TEST ONLY pinned-SDK/MockClient/MethodChannel evidence with in-memory
storage. The separate Windows Credential Manager/process probes remain the
native component evidence; neither establishes a hosted learner A/B flow,
deployed RLS/PostgREST, or delayed native Credential Manager failure injection.


## Caller close after a failed logout clear — 2026-11-07

A failed credential clear is not a successful shutdown. The persistence owner
now records when sign-out, a rotation-write compensation, or an unsolicited
null-session clear leaves cleanup uncertain. `close()` retries SDK sign-out
and vault clear before releasing the project owner. If the retry also fails,
close returns a fixed safe storage error, keeps the owner slot, and can be
called again after storage recovers. A fully saved session with no interrupted
or failed cleanup is still preserved for the next startup.

The pure lifecycle regression holds the cleanup failure through the first close,
asserts that a competing owner cannot be constructed, then restores storage and
requires a second close to clear the secret before releasing ownership. The
pinned-SDK Windows MethodChannel regression exercises the same behavior through
the production Windows vault adapter and caller-owned runtime, including a
failed close, rejected replacement owner and successful close retry.

These are TEST ONLY in-memory/MethodChannel failure injections. They do not
simulate a native Credential Manager failure or establish hosted Auth. The
native Windows process probes and hosted staging acceptance remain separate.


## Empty-vault first-login ordering

An owned account access start with an empty credential vault must settle to an
idle, signed-out state and immediately allow one explicit password sign-in. The
operation slot is reserved before asynchronous Auth/vault work is scheduled, so
an immediately completing read cannot leave a completed operation marked busy.
The first authenticated session is still hidden until its rotated refresh token
has been durably written and the verified user's own profile is ready. This does
not enable automatic login, plaintext fallback, token logging or a default Auth
assembly.


## Cancellation latch across deferred Auth dispatch — 2026-11-07

`_runTracked` reserves the caller-owned operation slot synchronously and resets the cancellation latch before publishing that slot. A concurrent logout/close can then set the latch even if the runner is still queued as a microtask. `_run` must never clear that latch on entry: the original Auth operation remains cancelled, and its finalizer drains SDK sign-out plus credential clear after any late SDK response. This is a one-shot cancellation/cleanup path, not an automatic Auth retry. The deterministic lifecycle fixtures retain late-login, failed-logout and login-during-late-cleanup coverage; the failed-close retry fixture performs only one initial login.


## Caller-owned runtime close and restore — 2026-11-07

A pinned-Supabase-SDK regression closes a fully authenticated caller-owned
runtime, verifies that its confirmed refresh secret is preserved, then constructs
a fresh SDK/runtime against the same trusted project vault. Startup must send
only the saved refresh secret to the server, accept the server's rotated secret,
and persist that rotation before dispatching the new own-profile request. The
profile response is held to prove that the recreated runtime remains unavailable
to study until its matching own profile completes.

This is TEST ONLY pinned SDK + MockClient + in-memory vault evidence with the
caller-owned disposable journal retained across runtime reconstruction. It
verifies a new SDK/runtime owner in one test process; it is not a forced process
restart, native Credential Manager restoration, hosted signed-JWT learner A/B,
deployed RLS/PostgREST, OS logoff, power-loss or physical multi-device proof.
No default Auth activation, plaintext fallback, token logging, Auth strategy,
provider, schema/RLS, production configuration or Pro-owned N4 content changes.


## Windows refresh rotation write failure

The pinned Supabase SDK + Windows MethodChannel regression first establishes
User A through password Auth and persists A's refresh secret. An explicit
refresh then receives a rotated secret while the Windows vault write is
deliberately failed. The runtime must revoke A's session/profile readiness,
attempt to clear the uncertain credential, and issue no additional own-profile
request. A subsequent explicit User B login must run SDK sign-out and vault
cleanup before the password grant, persist B's rotated secret, and only then
request B's own profile.

This combines a post-login rotation failure with the account-switch boundary.
It is TEST ONLY MockClient/MethodChannel failure injection using the production
Dart Windows vault adapter; it does not inject a native Credential Manager
failure or prove hosted learner A/B, deployed RLS/PostgREST, or physical
multi-device behavior.


## Refresh completion across an account switch

The scheduler allows only one refresh attempt at a time. If account A's refresh is already in flight when the caller publishes account B, an update does not start an overlapping request. When A's attempt settles, the scheduler re-reads the caller-owned current lease and schedules B using B's identity and expiry. A canceled A timer callback that was already queued may re-arm the current B timer, but its captured A lease cannot dispatch a refresh. The scheduler does not authorize or persist a session: `PersistentAccountAccess` remains responsible for SDK session/generation checks and the vault write-before-readiness barrier. This deterministic timer regression is not hosted Auth or OS-suspension evidence.


## Caller close after a corrupt stored refresh value — 2026-11-08

A successful credential read whose value fails the vault's bounded token
validation is a known corrupt slot, not a transient storage outage. Startup
still fails closed and never sends that value to Supabase. It now marks cleanup
as required so a caller that closes before an explicit login cannot release the
exclusive project owner while the unusable value remains in Credential Manager.
Close performs the existing ordered SDK sign-out and exact-project vault clear;
if clear fails, close returns the fixed safe storage error and retains ownership
for a later close retry. A transient read-unavailable error is deliberately
different: it does not mark the saved value for deletion, so a temporary OS
outage does not destroy a potentially valid session.

The pinned-SDK/MockClient regression starts with a corrupt in-memory vault
value, verifies no Auth refresh or own-profile request, fails the first close
clear, checks that the secret and exclusive owner remain, then restores storage
and requires a second close to clear the slot before releasing ownership.

This is TEST ONLY in-memory vault/MockClient evidence. It does not inject a
native Windows Credential Manager failure or prove hosted signed-JWT learner
A/B, deployed RLS/PostgREST, OS logoff, power-loss, or physical multi-device
behavior. No Auth strategy/provider, default activation, plaintext fallback,
token logging, schema/RLS, production configuration, or Pro-owned N4 content
changes.
