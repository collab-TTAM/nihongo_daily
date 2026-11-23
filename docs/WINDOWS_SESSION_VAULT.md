# Windows refresh-secret vault

`createWindowsSessionCredentialVault(trustedProjectUrl)` explicitly assembles a
Dart facade and Windows method channel. The runner registers that channel and
unregisters it before destroying its Flutter engine. It is not called by the
default application or account factory. No token is written by the preview.

## Storage and trust boundary

The native helper uses `CredWriteW`, `CredReadW`, `CredDeleteW` and `CredFree` for
`CRED_TYPE_GENERIC`, with `CRED_PERSIST_LOCAL_MACHINE`. Targets use a fixed
application/version prefix followed by a canonical trusted HTTPS project origin.
The origin contains no account/password/query/fragment. Each project has a
single refresh-secret slot under the current Windows user's credential set.
The Credential Manager slot remains OS-user scoped, so other same-user software
can access generic credentials. The owned Nihongo Daily runtime additionally
acquires a per-project named-mutex lease before reading/restoring the slot. This
coordinates competing app instances in the same Windows logon session; it is
not a security boundary against arbitrary same-user processes, a multi-account
history store or a cross-device secret synchronization mechanism.

This component accepts an opaque, nonempty printable-ASCII value of at most
2048 bytes, below Windows' 2560-byte credential blob bound. This is a local
storage restriction, not a server credential-validity test or a guarantee of
future SDK token format. Only the refresh-secret argument is written, without
SDK Session JSON, access JWT, email, password, profile or study data. Callers
must never pass/log those objects. Stored values require server verification
and the own-profile readiness barrier before granting learner access.

Read returns null only for an absent entry. Storage/platform errors and corrupt
data fail safely; corrupt entries are not automatically deleted. Successful
clear is idempotent and limited to the exact namespaced target. Windows native
input bounds/namespace checks duplicate the Dart trust boundary. The method
channel accepts only read/clear with target, or write with target/token; unknown
fields/types fail, unknown methods are unimplemented. API/platform exceptions
do not include raw arguments, secrets, OS errors or response details.

Dart serializes operations across vault facades sharing the same canonical
target in one isolate. A failed operation does not poison the queue. Independent
project targets do not block each other. The Windows runtime also acquires a
native named mutex derived from a stable non-secret hash of the canonical target
before vault read/Auth restore; a competing app instance receives a fixed
unavailable result. The mutex is scoped to the current logon session and an
abandoned mutex is recoverable after process exit. This is an exclusive runtime
lease, not interprocess compare-and-swap or a transactional SDK token-rotation
protocol. Arbitrary same-user processes can still access Credential Manager.
Session assembly must own one writer, guard late results/account changes and
clear/revoke on logout.
The shared review journal, browser IndexedDB, preferences and logs are never
used as secret-storage fallbacks. Web/mobile/Linux/macOS explicitly fail
unavailable; their protected stores require separately tested adapters.

Native temporary credential buffers are wiped before release and returned
Credential Manager buffers are wiped before `CredFree`. Immutable Dart strings,
Flutter codec copies and caller-owned strings are not guaranteed zeroized.
Native errors return fixed platform text; Dart replaces platform exceptions
with typed safe errors. No secret is printed by production code or the probe.

## Native owner-lease acquisition failure

The caller reserves the project target in the Dart owner registry, then must
acquire the Windows native named-mutex lease before reading Credential Manager.
If acquisition returns false or the MethodChannel fails, startup fails closed:
no credential read/clear, Auth restore/password grant or own-profile request is
dispatched. The stored refresh secret is left untouched because this process
never acquired the native lease and cannot safely assume ownership of the slot.

Caller close still releases the local Dart reservation and owned SDK resources,
but does not call native `releaseOwner` for a lease it never acquired. After
the channel/contending process recovers, a new runtime can acquire the same
target and perform the normal server refresh -> rotated-secret write ->
own-profile readiness sequence. The TEST ONLY Windows MethodChannel regression
injects a native-style unavailable acquisition result and verifies this
recovery order. The standalone native probe separately covers real process-lease
contention and abandoned-mutex recovery; neither fixture is hosted learner Auth
proof.

## Caller close while the native vault read is pending

After the Windows owner lease is acquired, startup may still be waiting for
Credential Manager to return the saved refresh secret. Caller close must revoke
readiness immediately but retain the native owner until that read settles. If
close wins before the SDK Auth restore is dispatched, it must not sign out or
clear the saved credential. Once the read drains, the owner lease can be
released; a fresh owner can then perform server refresh, persist the rotated
secret, and only afterward request the learner's own profile.

The Windows MethodChannel/runtime regression holds the native-style read,
starts caller close, and verifies there is no Auth token request, profile
request, vault clear, or owner release while the read is held. After releasing
the read it verifies that the saved secret remains intact and the lease is
released. A replacement runtime then restores the same secret and checks
refresh -> rotated-secret write -> own-profile ordering. This is a TEST ONLY
mocked MethodChannel lifecycle test, not actual hosted Auth or Credential
Manager execution; the separate Windows native probe remains the OS-backed
storage/lease evidence.

## Caller-owned startup publication gate

The configured host composes `PersistentAccountStartup` with
`AccountStartupController`. When a saved refresh secret exists, startup must
wait for the server refresh and the Windows vault's acknowledgement of the
rotated refresh secret. Only then may the account controller request the
captured user's own profile. The outer startup controller remains in
`loading` with `account == null` while either the vault write or profile
response is pending; it publishes the account only after both barriers settle.

The pinned-SDK Windows MethodChannel regression holds the rotation write and
own-profile response independently. It verifies refresh -> vault write ->
own-profile order, the captured User A Authorization header, no early account
publication, and final readiness for User A only. This is TEST ONLY synthetic
Auth HTTP plus a mocked MethodChannel; it proves caller/startup composition,
not hosted Auth, actual Credential Manager execution in this test, default app
activation or a learner UI journey.

## Reproduction and evidence limits

In `apps/flutter_app`:

```sh
dart run tool/verify_session_vault.dart
flutter test test/features/srs/session_credential_vault_test.dart
flutter test test/features/srs/windows_session_credential_vault_test.dart
flutter test test/features/srs/windows_persistent_supabase_runtime_test.dart --plain-name 'Windows startup publishes account only after restored rotation and own profile'
```

On a disposable Windows 2022/VS2022 CI host:

```powershell
cmake -S tool/windows_session_vault -B build/session-vault-probe -G "Visual Studio 17 2022" -A x64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
cmake --build build/session-vault-probe --config Release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& ./build/session-vault-probe/Release/session_vault_probe.exe
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

Twelve pure cases cover canonical/invalid scopes, secret bounds, malformed read/
acknowledgment, safe failures, same-scope write-clear order, error recovery and
independent projects. Five channel cases use mock native messages: exact
arguments, redacted errors, unsupported platforms and missing channel. These
are not OS-storage execution. The separately built native probe shares the
production helper and uses actual Credential Manager with PID-qualified
`.invalid` TEST ONLY scopes. It tests write/read/replacement, child-write/exit/
parent-read, process-lease contention and abandoned-mutex recovery, project
isolation, invalid writes preserving the prior value,
maximum size, foreign namespace rejection, injected corrupt OS blob, recovery
and idempotent clear. Probe credentials are removed before a passing exit.
The probe is outside the packaged application release directory.

## Probe-only one-shot native fault injection

The standalone `session_vault_probe` CMake target alone defines
`NIHONGO_SESSION_VAULT_TEST_HOOKS`. The packaged Flutter Windows runner compiles
the same helper without that definition, so the test API and atomic fault state
are absent from the learner executable.

The probe injects one failure at a time at the native helper boundary:
- Read failure returns a fixed unavailable result before `CredReadW`; the next
  read must return the previously stored value.
- Write-before-commit returns unavailable without calling `CredWriteW`; the
  prior Credential Manager value must remain unchanged.
- Ambiguous write performs the real `CredWriteW` successfully, then returns
  unavailable once; a subsequent read must observe the newly committed value.
- Clear failure returns unavailable before `CredDeleteW`; the old value must
  remain readable, and an explicit second clear must succeed and read as absent.

All scopes are PID-qualified `.invalid` TEST ONLY targets and all values are
synthetic. These deterministic wrapper faults verify the caller-visible result
and retry ordering against actual Credential Manager state; they do not claim
that Windows itself spontaneously returned these errors, simulate power loss,
or prove hosted Auth/learner acceptance. No token or native error is printed.

CI requires the pure verifier and native Windows probe while retaining all old
jobs/steps. Compiling the runner validates the native bridge; mock Dart messages
plus a native helper probe are not an interactive Dart-to-Windows integration
or actual learner/login/JWT/OS-logoff/hardware-power-loss proof.

## Separate review and remaining work

Reviewed namespace/byte limits at both boundaries, typed errors without raw
details, absent/error distinction, clear/write ordering, native buffer cleanup,
channel lifetime and exact-target scope. No new dependency, Auth provider,
configuration, schema/RLS/RPC, deployment or production-history deletion.
Content lane #14 is untouched; shared QA/CI/docs belong to the coordinator.

The storage component is now wired through the explicitly caller-owned
PersistentSupabaseRuntime in the opt-in Windows staging owner. Startup refresh,
rotation persistence, own-profile readiness, logout fencing and late-result
generation guards have TEST ONLY SDK coverage. The separate Windows runner probe
also exercises a held User A refresh response after logout, then a fresh User B
login through the real Credential Manager/MethodChannel. It does not use hosted
HTTP or prove a real learner identity. Default preview still does not activate
Auth or the vault; all hosted Personal Alpha cases remain pending. Keep #37 draft
and #20/#22/#15 open.

Primary Microsoft documentation checked 2026-10-14:
- https://learn.microsoft.com/en-us/windows/win32/api/wincred/ns-wincred-credentialw
- https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credwritew
- https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credreadw
- https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-creddeletew

## Observed source evidence

Source `1dd109470369884f7f776888cfab91859f9efc1c` passed all five jobs in
[CI38558520796](https://github.com/collab-TTAM/nihongo_daily/actions/runs/38558520796).
Observed 283 Flutter tests (twelve pure vault/four mock platform cases added),
five Chrome tests, mandatory vault CLI, actual Windows credential/process probe,
retained security/native/wire/SQL-to-Dart checks and web/Windows release artifacts.
Native app bridge compiled; the separate probe used real credential APIs with
TEST ONLY values and cleaned its namespaces. Unmodified workflow/latest-attempt
jobs passed exact-head/all-critical-step QA verification. CLI lint and probe
narrowing were corrected without suppressing lint/compiler warnings or weakening
assertions. Child mode also rejects non-PID CI targets before any write. Results
are historical for later commits and do not establish hosted Auth/restoration,
interactive platform bridge execution, OS logoff/relogin or power-loss recovery.

## Dart/native cross-process bridge probe

The TEST ONLY `tool/windows_vault_bridge.dart` entrypoint runs in the production
Flutter Windows runner and calls the production Dart vault/MethodChannel/native
helper without mock platform messages. `tool/verify_windows_vault_bridge.ps1`
starts five separate processes: write, reopen/replace, observe replaced value,
clear, and observe absence. Each invocation has a GUID-qualified `.invalid`
project; only fixed synthetic values are accepted. Other-project reads must
remain absent. Each phase is bounded to 60 seconds; failed/timeout phases and
failed finally cleanup fail the job. No credential values or raw errors are logged.

CI builds this separate target, executes the probe, then rebuilds the normal
`lib/main.dart` entrypoint before uploading the learner preview. No new dependency
or default runtime activation. This narrows the method-channel evidence gap when
it passes, but does not invoke the Supabase runtime or establish hosted login,
SDK-to-OS restore, OS logoff/power-loss, concurrent writer safety or learner UI
acceptance. Existing pure/native/SQL/security gates stay mandatory.

Verified source `92250a67629c5fd2d73090c249075478847a59dd` passed all five jobs
in https://github.com/collab-TTAM/nihongo_daily/actions/runs/38584671877 .
The bridge build and actual cross-process execution both passed; Windows logs
contain the fixed cross-process success marker. The normal preview was rebuilt
afterward and both Windows/web artifacts passed upload. All retained pure/native/
SQL/Chrome/security gates passed; exact-head/every-required-step QA accepted raw
run/latest-attempt metadata. These results are historical for later commits.
No hosted Auth or SDK-to-OS restart acceptance is claimed.


## Windows OS-backed late-refresh/account-switch probe — 2026-11-01

The runtime-late-refresh phase in tool/windows_runtime_fixture.dart runs
inside the production Flutter Windows runner with the real MethodChannel and
Windows Credential Manager, the caller-owned PersistentSupabaseRuntime, and
the real native review-journal lease. It writes User A's synthetic refresh token
to the OS vault, holds the startup refresh response, logs out and confirms the
slot is empty before releasing A's old rotation response. The startup operation
must fail closed with no A profile request or restored secret. The same runtime
then signs in User B, checks that only B's own-profile request carries B's
captured bearer and that B's rotated refresh token is already readable from the
OS vault before profile readiness, then logs out and verifies the slot is empty.
The existing A-owned pending review remains in the journal and B's owner-scoped
view stays empty.

verify_windows_vault_bridge.ps1 runs this as a fresh process after the existing
login/restore/logout/rejected-token phases. Auth HTTP is a TEST ONLY MockClient
and the JWT is explicitly unsigned; only the Windows storage/channel/journal and
pinned SDK lifecycle are real. This is not hosted Auth, signed-JWT, deployed RLS,
two-device or learner acceptance. The normal preview remains unconfigured.

## Rejected stored-refresh recovery

The TEST ONLY Windows runtime suite also exercises a rejected stored refresh
through the pinned Supabase SDK and the Windows vault MethodChannel boundary.
The simulated server rejects the saved refresh value; no own-profile request or
study runtime is published. Explicit password login first runs owned cleanup.
If the vault clear fails, the old secret remains, the login is rejected and no
password grant/profile request is sent. A later explicit retry clears the old
slot before password Auth, then persists the new rotated refresh secret before
the captured user's own-profile request.

This is a mocked Auth HTTP response and mocked MethodChannel storage backend,
not hosted Auth/JWT evidence. The separate Windows CI process probe continues
to exercise the native Credential Manager API with TEST ONLY values.

## Caller close during a held Windows startup restore

The TEST ONLY `runtime-close-restore` phase runs in a fresh production Flutter Windows runner process. It writes a synthetic refresh value to the real Windows Credential Manager slot, starts the pinned Supabase SDK's refresh-only restore against a held MockClient response, then asks the caller-owned runtime to close before releasing that response. The fixture waits until the persistence owner is closed, releases the late response, and requires the startup operation to fail, no own-profile RPC/readiness to appear, the owned SDK cleanup to run, and the OS credential slot to be empty before close returns. A following fresh `runtime-signedout` process verifies that the slot remains absent across process boundaries.

This covers a close racing a pending startup restore in addition to the existing logout/account-switch and vault-write races. The Windows Credential Manager, MethodChannel, native journal lease and pinned SDK are real in the runner; Auth HTTP and JWT values remain synthetic TEST ONLY fixtures. It is not hosted Auth, signed-JWT, deployed RLS, OS logoff/power-loss or physical multi-device evidence. A fully persisted session still survives an ordinary clean close; an interrupted restore is deliberately cleaned before the owner is released.


## Windows process restore keeps study readiness closed while profile is held

The TEST ONLY `runtime-restore-profile-held` phase is a fresh Flutter runner
process after `runtime-login`. It first reads the synthetic refresh secret
written by the prior process from the real Windows Credential Manager, then
uses the pinned Supabase SDK's refresh-only startup path. The fixture's HTTP
handler returns a rotated secret and verifies that exact value is readable from
the OS vault before it accepts the own-profile request. That profile response
is then held while the process asserts that `readyRuntime` remains null and
the account is not ready. Only after releasing the profile response may the
account become ready. Clean caller close must preserve the confirmed rotated
secret for the next fresh process; the following `runtime-restore` phase
consumes that rotated value and rotates it again.

The PowerShell sequence launches every phase as a separate process with one
GUID-scoped `.invalid` target. The Windows Credential Manager, Dart
MethodChannel, native owner lease, pinned SDK and native journal are real in the
runner. Auth HTTP and JWTs are TEST ONLY MockClient/unsigned fixtures, and the
profile handler is a test double rather than deployed PostgREST. This adds
OS-backed process-boundary evidence for the persist-before-profile readiness
barrier; it is not hosted signed-JWT Auth, deployed RLS/PostgREST, a physical
learner login, OS logoff/power-loss or multi-device acceptance.


## Caller-owned runtime with native Credential Manager read-failure injection

The TEST ONLY bridge runner now exercises one end-to-end failure path through
the production C++ helper, registered MethodChannel,
`WindowsSessionCredentialVault`, `PersistentAccountAccess` and
`PersistentSupabaseRuntime`. A per-run GUID `.invalid` project target
contains a synthetic A refresh secret. The test-only helper returns
`unavailable` once before calling `CredReadW`; the Dart startup owner must
remain failed/unready without sending Auth or own-profile traffic, while the
stored A value remains intact.

After the one-shot fault is consumed, explicit B password login must clear the
exact-project slot before the grant, persist B's rotated refresh value before
the own-profile request, and leave A's journal records invisible to B. B logout
must clear the slot. The same harness then reconfigures the bridge runner with
`ND_SESSION_VAULT_TEST_HOOKS=OFF` and verifies the injection method is absent.
The CMake option defaults OFF and is enabled only in the CI fixture build;
staging and normal preview builds are performed after the OFF rebuild.

This is deterministic helper-boundary fault injection, not spontaneous Windows
Credential Manager failure, hosted signed-JWT Auth/PostgREST/RLS, OS logoff,
power loss or physical multi-device evidence. HTTP/Auth responses remain
TEST ONLY fixtures; no credential values or raw native errors are logged.


## Malformed stored refresh is rejected before Windows Auth dispatch

The TEST ONLY pinned-Supabase-SDK/Windows MethodChannel runtime suite returns a
malformed persisted refresh value (a string outside the vault's printable-token
contract). Startup must fail closed before any `/auth/v1/token` or own-profile
request; the value is never forwarded to Auth. While the caller still owns the
project vault, the existing explicit-login recovery path may be offered.

The regression then injects a failed exact-target clear. User B's password grant
and profile request must remain blocked, the corrupt value remains unchanged, and
the public error contains no stored value or platform details. After an explicit
retry succeeds, the corrupt slot is cleared before B's password grant; B's
rotated refresh secret is persisted before the captured B own-profile request/
readiness.

This is a TEST ONLY MethodChannel response and synthetic Auth HTTP/JWT fixture,
not a claim that the packaged app or hosted Auth was exercised. The separate
Windows native probe's corrupt-OS-blob case remains the Credential Manager
boundary evidence. No plaintext fallback or automatic cleanup retry is added.


## Caller-owned runtime fences an ambiguous native refresh rotation write

The TEST ONLY Windows runner now exercises a failure that previously existed
only in the standalone native vault probe. The pinned Supabase SDK first establishes a ready User A session and persists
its initial refresh token. The caller-owned runtime then performs an explicit
refresh. The test-only native hook allows the real `CredWriteW` to commit the
rotated value, then returns the fixed unavailable result to the MethodChannel
caller (`commit_then_fail`). A second one-shot hook makes the immediately
compensating `CredDeleteW` fail before the OS call.

The caller-owned `PersistentAccountAccess` must revoke A's readiness and
remain failed/unready: no second `ensure_profile` request for A is allowed,
and the test confirms the ambiguous rotated value is still in the actual
project-scoped Windows Credential Manager slot after the failed clear. A subsequent explicit B sign-in must first drain
SDK sign-out and retry the exact-slot clear; the password grant handler verifies
the slot is empty before it returns B's Auth response. B's newly rotated value
must be readable before the only own-profile request, which must carry B's
captured bearer/identity. B logout clears the slot, while A's pending journal
record remains invisible to B.

The fresh-process PowerShell bridge sequence invokes this phase and then opens
another process to verify the slot is signed out. The fault hooks are compiled
only into the TEST ONLY bridge runner; the existing script rebuilds the runner
with `ND_SESSION_VAULT_TEST_HOOKS=OFF` before staging/preview builds and verifies
that the injection method is absent.

This is real Windows Credential Manager + MethodChannel + pinned-SDK owner
composition with synthetic TEST ONLY Auth HTTP/JWT responses. It is not hosted
GoTrue/PostgREST, signed-JWT learner A/B, spontaneous OS failure, power-loss or
physical multi-device proof. The normal preview remains unconfigured and no
production Auth, schema/RLS or plaintext fallback is changed.


## Caller-owned runtime fences a native refresh write that fails before commit

The TEST ONLY Windows runner now exercises the complementary native failure
mode to the existing ambiguous commit-then-fail case. It establishes a ready
User A session and stores A's refresh token in the real project-scoped Windows
Credential Manager slot. The next explicit SDK refresh returns a rotated
refresh token, then a one-shot compile-time fault makes the native helper return
unavailable before calling `CredWriteW`.

The previous A token must remain in the OS slot at the native boundary, but the
caller-owned persistence layer must revoke A readiness and successfully issue
the compensating exact-target `CredDeleteW`. The fixture reads the real slot
after the refresh failure and requires it to be absent; no second A
`ensure_profile` request is allowed. Only after that cleanup may explicit
User B login proceed. The password-grant handler verifies the slot is empty
before Auth returns; B's rotated refresh token must be readable before B's
captured own-profile request. B logout clears the slot, A's pending journal
event remains invisible to B, and a separate fresh process confirms signed-out
startup with no Auth/profile traffic.

The existing commit-then-fail plus failed-clear regression remains unchanged.
The new PowerShell phase runs in its own process and the existing bridge script
still rebuilds with `ND_SESSION_VAULT_TEST_HOOKS=OFF` before the normal
preview/staging build and verifies that the injection method is absent.

This is actual Windows Credential Manager + MethodChannel + pinned-SDK owner
composition with synthetic TEST ONLY Auth HTTP/JWT responses and deterministic
pre-call fault injection. It is not a spontaneous Windows error, hosted
GoTrue/PostgREST, signed-JWT learner A/B, OS logoff/power-loss or physical
multi-device proof. No token or native error is logged, and the learner
executable does not contain the test hook.

## Native owner-lease contention across independent runner processes

The Windows CI bridge now starts `runtime-owner-hold` in one fresh Flutter
runner process. That process acquires the canonical project-scoped native
mutex, confirms the empty-vault startup is idle/unready with no Auth or profile
traffic, and publishes a bounded ready marker while retaining the lease.

A second independent runner process then starts `runtime-owner-contend` for the
same target. It installs a one-shot TEST ONLY native read failure before calling
`PersistentSupabaseRuntime.start()`. The start must fail closed at native owner
acquisition, before `CredReadW`, Auth or own-profile dispatch. A second direct
native lease acquisition must also be rejected. The still-pending read fault is
consumed only by a subsequent explicit vault read, proving the contender did
not reach storage. After the first process receives its release marker and
closes normally, a third fresh process runs `runtime-owner-reacquire` and must
acquire/release the same target successfully.

This is actual Windows named-mutex and Flutter MethodChannel process-boundary
evidence for cooperating Nihongo Daily runtimes in one Windows logon session.
It uses an empty project slot, TEST ONLY public configuration and no Auth/JWT
or learner data. It does not coordinate separate Windows logon sessions or
arbitrary same-user software, and does not replace hosted signed-JWT learner
acceptance or OS logoff/power-loss testing. The compile-time fault hook remains
limited to the CI bridge build and is disabled before staging/preview rebuilds.

## Caller close while a Windows refresh-token rotation write is pending

The TEST ONLY pinned-SDK/Windows MethodChannel regression starts with a saved
User A refresh secret, restores it through the owned SDK, and waits until the
rotated secret is confirmed in the vault and the own profile is ready. It then
holds a second refresh rotation at the native-vault write acknowledgement and
starts caller close while that write is pending.

Close must revoke profile/study readiness immediately but must not clear the
slot or release the Windows owner lease while the write is still unresolved.
After the write is released, the in-flight refresh is treated as interrupted:
the owned SDK performs local sign-out, the exact project slot is cleared, and
only then may the native owner lease be released. A replacement runtime must
observe an empty slot and issue neither another refresh nor an own-profile
request.

This is a TEST ONLY MockClient/MethodChannel lifecycle regression. It proves
ordering and close-drain behavior at the Dart Windows adapter boundary; it does
not simulate a spontaneous delayed `CredWriteW` OS failure or prove hosted
GoTrue/PostgREST, signed-JWT learner A/B, OS logoff/power loss, or physical
multi-device sync. The separate Windows native process probes remain the
Credential Manager/owner-lease evidence.



## Caller-owned runtime retries an actual native logout clear failure

The TEST ONLY Windows bridge now injects a one-shot `CredDeleteW` failure
before the native delete call while User A is signed in through the pinned
Supabase SDK and caller-owned runtime. The first explicit logout must revoke
A's profile/study readiness but leave A's previous refresh secret in the real
project-scoped Credential Manager slot. The account remains in its fixed
sign-out error state; a User B password attempt is ignored and cannot issue
Auth or own-profile traffic.

A second, explicit logout call consumes the already-failed cleanup obligation.
It must successfully sign out and clear the exact A project slot before the
account returns to signed-out. Only then may B authenticate. The fixture checks
that B's rotated refresh secret is readable before B's captured own-profile
request, A's pending journal record remains invisible to B, and B logout clears
the slot. The PowerShell harness starts a separate fresh runner afterward and
requires signed-out startup with no Auth/profile requests.

This phase uses the production Windows MethodChannel and Credential Manager
helper with deterministic compile-time TEST ONLY fault injection. It verifies
caller-owned logout ordering against actual OS credential state; it does not
claim a spontaneous Windows API failure, hosted signed-JWT learner A/B,
deployed PostgREST/RLS, OS logoff/power loss or physical multi-device sync.
The fault hook remains absent from the normal learner executable because the
bridge is rebuilt with `ND_SESSION_VAULT_TEST_HOOKS=OFF` before preview/staging
builds.


## Caller-owned runtime fences an ambiguous native logout clear

The TEST ONLY Windows bridge also exercises the opposite side of a failed
`CredDeleteW` result: the operating system deletes User A's exact credential,
but the native helper reports an unavailable result after the API returns
success. A subsequent native read must observe an empty slot, while the owned
persistence state remains failed and A's study readiness remains revoked.

A User B password attempt is still blocked even though the OS value is absent;
slot absence alone is not an acknowledgement from the failed clear operation.
A second explicit logout retries the same retained owner and idempotent clear.
Only after that retry succeeds may B authenticate. The runner then checks that
B's rotated refresh secret is stored before B own-profile, A's pending journal
remains isolated, B logout clears the slot, and a separate fresh process starts
signed out.

The native hook is compile-time TEST ONLY and is accepted only by the
`.invalid` bridge target. It is removed by rebuilding with
`ND_SESSION_VAULT_TEST_HOOKS=OFF` before staging/preview builds. This is
deterministic post-commit acknowledgement-loss injection against actual
Windows Credential Manager, not a spontaneous Windows failure, hosted
signed-JWT learner A/B, deployed PostgREST/RLS, OS logoff/power-loss or physical
multi-device evidence.


## Late User A own-profile response against the actual Windows vault

The Windows runtime bridge now adds a fresh-process phase that combines the
pinned Supabase SDK, production MethodChannel, real Credential Manager and the
disk-backed native review journal. User A signs in; the runner confirms A's
rotated refresh token is present in the OS vault before the captured
`ensure_profile` request, then holds that response without publishing a ready
study runtime.

While A's response is held, explicit logout must revoke A readiness and clear
the exact project credential. User B then signs in through the same caller-owned
runtime; the runner verifies B's rotated secret is present before B's own-profile
request and confirms B has no access to A's pending journal event.

Only after B is ready does the fixture return A's previously captured profile
response and Authorization identity. B's profile, session, ready runtime and
stored refresh token must remain unchanged. B then logs out, and a separate
fresh runner confirms the project slot is signed out.

This is actual Windows Credential Manager/journal and process-runner evidence
with TEST ONLY synthetic Auth HTTP/JWT and deterministic response ordering. It
is not hosted GoTrue/PostgREST, signed-JWT A/B, deployed RLS, OS logoff/power
loss or physical multi-device learner acceptance. Native test hooks remain
compile-time-only and are disabled before the normal staging/preview build.


## Native refresh-write failure while User A profile is held

The TEST ONLY Windows bridge now combines the two previously separate cases:
a held User A `ensure_profile` response and an actual native Credential Manager
refresh-write failure. A signs in through the pinned Supabase SDK; the real
rotated refresh secret is stored before A's own-profile request is captured and
held. A same-session refresh then commits a new value through `CredWriteW` but
the deterministic one-shot hook reports an unavailable result. The first
compensating `CredDeleteW` is also forced to fail before deletion.

The runtime must revoke A's readiness, issue no second A profile request, and
retain the exact project owner while the OS slot still contains the uncertain
rotated value. Explicit replacement login for B retries cleanup before its
password grant. B's rotated refresh secret must be visible before B's own-profile
request; B's profile/session/runtime and A/B journal isolation are then checked.
Only after B is fully ready does the runner release A's captured response. It
must not replace B's accepted profile generation, session, runtime or stored
refresh secret. B logout clears the slot and a separate fresh process confirms
signed-out startup.

This is actual Windows Credential Manager + MethodChannel + pinned-SDK
composition with deterministic compile-time TEST ONLY fault injection and
synthetic Auth HTTP/JWT responses. It is not a spontaneous OS failure, hosted
GoTrue/PostgREST, signed-JWT learner A/B, deployed RLS, OS logoff/power-loss or
physical multi-device proof. The hook is disabled before the normal
staging/preview rebuild; no token or native error is logged.


## Native same-owner session-generation fence

A new Windows runner phase authenticates one verified owner as A1, holds A1's
`ensure_profile` response after the refresh secret is committed to Credential
Manager, then logs out and clears the exact project slot. The same owner signs
in as A2 with a different Auth `session_id`; the new rotated secret is visible
before A2's own-profile request. A1's captured response is released after A2 is
ready and must not replace A2's profile, captured session, ready runtime or
stored refresh secret. The same-owner native journal entry remains intact.

The phase uses the production Windows MethodChannel and real Credential Manager
in the TEST ONLY bridge runner, with synthetic Auth HTTP/JWT and deterministic
response ordering. It is not hosted GoTrue/PostgREST, signed-JWT learner
acceptance, deployed RLS, OS logoff/power-loss or physical multi-device proof.


## Same-owner late refresh response after logout

The Windows bridge adds a second same-owner generation regression focused on
Auth refresh rather than profile loading. A1 first establishes a ready session
and stores its rotated refresh secret in the real Credential Manager. The
fixture then holds A1's refresh response after the server-side mock has produced
a different rotated value.

Logout must revoke study readiness and clear the exact project slot before
that held response is released. It remains pending until the captured SDK
operation drains and compensating sign-out/clear completes. The fixture then
authenticates A2 with the same verified user ID but a different Auth
`session_id`; only A2's refresh secret may be stored before A2 own-profile
readiness. It checks distinct A1/A2 bearer values, the final A2 session/runtime,
an empty slot after A2 logout, and a fresh signed-out process.

This uses the production Windows MethodChannel, actual Credential Manager and
native journal with TEST ONLY synthetic Auth HTTP/JWT responses. It is local
Windows component evidence for late-response cleanup and same-owner session
generation ordering, not hosted signed-JWT learner A/B, deployed PostgREST/RLS,
OS logoff/power-loss or physical multi-device sync.


## Unreadable SDK snapshot during a queued rotation

The persistence owner validates the exact captured ReviewSession identity and
refresh token both before and after the vault write. A normal generation/session
mismatch means the queued write is stale and is ignored. If either SDK snapshot
getter throws, the runtime cannot prove which identity owns the just-written
secret: it revokes readiness, marks cleanup required and fails closed. Explicit
replacement login must sign out and clear the exact project slot before sending
the new password grant. Caller close must drain sign-out and clear before
releasing the native owner lease. The raw SDK exception and token are never
surfaced.

Two TEST ONLY lifecycle regressions inject an out-of-band session event and
make the session or refresh-token getter throw only during post-write
validation. One verifies close clears the committed secret before owner
release; the other verifies User A cleanup completes before User B password
Auth and rotation persistence. These tests exercise the shared persistence
owner with an in-memory SDK/vault, not hosted Auth or actual Windows Credential
Manager. The existing Windows CI bridge and native process probes remain
separate component evidence.


## Hosted password-login token persistence proof

The manual Windows hosted fixture now captures the exact refresh token returned
by password grants as well as refresh grants. For User A, revoked-token recovery
and User B, it reads the project-scoped Credential Manager slot immediately
before `ensure_profile` and requires exact equality with the successful
password response. The refresh-restore phase additionally requires the returned
token to differ from the submitted refresh token. Only fixed phase labels are
recorded; token values stay in the fixture's short-lived in-memory proof and are
never logged or persisted by the probe.

The isolated proof helper has TEST ONLY regressions for password mismatch,
one-shot consumption, grant confusion, failed/malformed responses, oversized
values and unchanged refresh tokens. These checks improve the protected manual
probe but are not a hosted run. The `supabase-staging` environment and its
approved non-production secrets/accounts are still required before dispatch.
