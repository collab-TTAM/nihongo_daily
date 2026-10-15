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
This is an OS-user credential facility, not application/process isolation; other
processes running as that user may access generic credentials. It is not a
multi-account history store or a cross-device secret synchronization mechanism.

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
project targets do not block each other. This is not interprocess compare-and-
swap or a transactional SDK token-rotation protocol. Session assembly must own
one writer, guard late results/account changes and clear/revoke on logout.
The shared review journal, browser IndexedDB, preferences and logs are never
used as secret-storage fallbacks. Web/mobile/Linux/macOS explicitly fail
unavailable; their protected stores require separately tested adapters.

Native temporary credential buffers are wiped before release and returned
Credential Manager buffers are wiped before `CredFree`. Immutable Dart strings,
Flutter codec copies and caller-owned strings are not guaranteed zeroized.
Native errors return fixed platform text; Dart replaces platform exceptions
with typed safe errors. No secret is printed by production code or the probe.

## Reproduction and evidence limits

In `apps/flutter_app`:

```sh
dart run tool/verify_session_vault.dart
flutter test test/features/srs/session_credential_vault_test.dart
flutter test test/features/srs/windows_session_credential_vault_test.dart
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
independent projects. Four channel cases use mock native messages: exact
arguments, redacted errors, unsupported platforms and missing channel. These
are not OS-storage execution. The separately built native probe shares the
production helper and uses actual Credential Manager with PID-qualified
`.invalid` TEST ONLY scopes. It tests write/read/replacement, child-write/exit/
parent-read, project isolation, invalid writes preserving the prior value,
maximum size, foreign namespace rejection, injected corrupt OS blob, recovery
and idempotent clear. Probe credentials are removed before a passing exit.
The probe is outside the packaged application release directory.

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

This complete storage component is not yet wired to Supabase session refresh,
token rotation, sign-in/logout persistence or startup restore. That next assembly
must preserve profile readiness, captured SDK identity, immediate logout fencing
and late-result rejection, and prove error handling before any automatic restore
is enabled. All 14 live Personal Alpha cases remain pending; keep #37 draft and
#20/#22/#15 open. Default account runtime remains null.

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
