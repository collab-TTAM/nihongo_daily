# Nihongo Daily — core worker handoff

## 2026-11-19T08:10Z — native Windows CredWriteW fail-before-commit regression

- Run: `core-20261119T0810Z-pr37-credwritew-rotation-failure`
- PR: [#37](https://github.com/collab-TTAM/nihongo_daily/pull/37)
- Branch: `automation/issue-22-atomic-review`
- Parent / pre-write HEAD: `a4d48b21ad3dc29b1edc5d9ac476baba18ebc593`
- Base `main`: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`
- Worker scope: sole core writer; previous ACTIVE marker at 06:08Z had its last heartbeat at 06:32Z and was older than 90 minutes at resume. PR #41's latest worker checkpoint was RELEASED at 07:55Z. Pro-owned PR #38 / Issue #14 / N4 was excluded.

### Change

Added a new TEST ONLY Windows runtime process phase, `runtime-native-rotation-write-fail-before`, alongside (not replacing) the existing commit-then-fail/failed-clear phase.

The new phase:
1. Starts the caller-owned runtime with an empty project vault.
2. Signs in User A and confirms A's initial refresh token is in the actual Windows Credential Manager before A own-profile.
3. Injects the compile-time TEST ONLY native `write/fail_before` hook, then performs a pinned Supabase SDK refresh rotation.
4. Requires A readiness to be revoked, no second A own-profile request, and a successful compensating exact-project clear that leaves the OS slot absent. The native helper returns before calling `CredWriteW`; the old A value is therefore not silently replaced.
5. Allows explicit User B login only after cleanup; verifies the password grant sees an empty slot, B's rotated token is stored before B own-profile, and A's pending journal event is invisible to B.
6. Logs B out and starts a separate fresh runner process to verify signed-out startup with no Auth/profile traffic.

The existing ambiguous commit-then-fail and failed-clear regression remains intact. The PowerShell bridge executes the new phase and fresh-process check. The existing script rebuilds with `ND_SESSION_VAULT_TEST_HOOKS=OFF` and verifies that the test injection method is absent before normal preview/staging build.

### Changed paths

- `apps/flutter_app/tool/windows_runtime_fixture.dart`
- `apps/flutter_app/tool/verify_windows_vault_bridge.ps1`
- `docs/WINDOWS_SESSION_VAULT.md`
- `qa/matrix.json` — existing `persistent-session-lifecycle` case only; two exact new anchors
- `docs/PROJECT_STATUS.md`
- `docs/PROJECT_STATUS_HANDOFF_20261119T0810Z.md` (this file)

### Verification and limits

- Pre-write read: branch and PR both at `a4d48b21ad3dc29b1edc5d9ac476baba18ebc593`; recursive tree contained 347 entries and was not truncated. Every modified file's fetched blob SHA matched the tree.
- Local Dart/Flutter/Windows commands were not run: this cloud authoring runtime has no pinned Flutter/Dart SDK or Windows OS.
- Exact-head GitHub Actions is required to run formatter, analyzer, full Flutter suite, Windows build, the new actual Windows process phase, native bridge hook-off verification, and every retained database/Supabase/AI/repository gate. No new-head CI pass is claimed before observation.
- This uses deterministic compile-time TEST ONLY fault injection with synthetic Auth HTTP/JWT responses. It is not a spontaneous OS failure, hosted signed-JWT learner A/B, deployed PostgREST/RLS, OS logoff/power-loss or physical multi-device proof.
- No production Auth/provider strategy, API/schema/RLS, default runtime activation, staging dispatch/secrets, Pro-owned N4, merge, deployment or release change.

### Next action

Inspect the exact-head Actions run and every latest-attempt job/step. Fix only observed diagnostics. Keep PR #37 Draft and #20/#22/#15/#18 open until hosted and integrated learner acceptance is evidenced.
