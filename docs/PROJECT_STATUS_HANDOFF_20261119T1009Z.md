# Nihongo Daily — core worker handoff

## 2026-11-19T10:09Z — actual Windows ambiguous logout clear acknowledgement

- Run: `core-20261119T1009Z-pr37-native-clear-commit-ambiguity`
- PR: [#37](https://github.com/collab-TTAM/nihongo_daily/pull/37)
- Branch: `automation/issue-22-atomic-review`
- Parent HEAD: `775cbfea719e40b787cd0089643ae0227eeacc12`
- Base main: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`
- Base tree: `165d0c1105e2e8055e3112c6ee2219711d8d2df9` (349 entries, 284 blobs, 65 trees; recursive response untruncated)

### Change

Added a compile-time TEST ONLY `CredDeleteW` commit-then-fail path. The native helper calls the real Windows API; when deletion succeeds, the one-shot hook reports `unavailable` after the OS credential has already been removed.

The caller-owned Supabase runtime must not treat a subsequent empty-slot read as proof that the failed clear was acknowledged. It stays in its fixed sign-out error/failed persistence state, keeps the project owner, and blocks B Auth/profile. A second explicit logout retries the exact-target clear and is the only operation that restores the signed-out/login-allowed state. The phase then checks B refresh-token write-before-own-profile, A journal isolation, B logout, and a separate fresh process signed out.

### Changed paths

- `apps/flutter_app/windows/runner/session_credential_vault.cpp`
- `apps/flutter_app/windows/runner/session_vault_channel.cpp`
- `apps/flutter_app/tool/windows_runtime_fixture.dart`
- `apps/flutter_app/tool/verify_windows_vault_bridge.ps1`
- `docs/WINDOWS_SESSION_VAULT.md`
- `docs/PERSISTENT_SESSION_LIFECYCLE.md`
- `qa/matrix.json`
- `docs/PROJECT_STATUS.md`
- This handoff file

### Review and verification

- The existing native hook enum already included `commit_then_fail`; the channel previously accepted it only for writes. The new mapping allows the same fault only for write/clear, never read.
- The clear helper captures the Win32 error before any subsequent call, treats `ERROR_NOT_FOUND` as idempotent success, and injects the ambiguous failure only after `CredDeleteW` itself succeeded.
- The fixture runs both clear fail-before and clear commit-then-fail. In the latter case it asserts the actual Credential Manager slot is already empty while the caller remains failed and blocks B until explicit retry.
- Parent exact-head CI [44496085748](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44496085748) completed SUCCESS on parent `775cbfea719e40b787cd0089643ae0227eeacc12`: six jobs and every returned step succeeded. This does not verify the new phase.
- Cloud authoring runtime has no pinned Flutter/Dart SDK or Windows OS; no local format/analyze/Flutter test/native build is claimed. New exact-head GitHub Actions must run the added phase and all retained jobs/steps.

### Limits and next action

- The fault hook is compile-time TEST ONLY and restricted to `.invalid` bridge targets. The PowerShell runner rebuilds with `ND_SESSION_VAULT_TEST_HOOKS=OFF` before staging/preview builds.
- Auth HTTP/JWT remain synthetic TEST ONLY. This is deterministic native fault injection against actual Windows Credential Manager, not a spontaneous OS failure, hosted signed-JWT learner A/B, deployed PostgREST/RLS, OS logoff/power-loss or physical multi-device proof.
- No production Auth/provider strategy, API/schema/RLS, default runtime, staging dispatch/secrets, Pro-owned #14/#38/N4, merge, deployment or release changed. Keep PR #37 Draft and #20/#22/#15/#18 open.
- Next: inspect every latest-attempt job/step on the new exact HEAD; fix only observed diagnostics. Hosted learner acceptance remains dependent on the protected non-production Supabase environment and owner-approved staging evidence.
