# Nihongo Daily — core worker handoff

## 2026-11-19T09:08Z — actual Windows logout clear failure and retry

- Run: `core-20261119T0908Z-pr37-native-logout-clear-failure`
- PR: [#37](https://github.com/collab-TTAM/nihongo_daily/pull/37)
- Branch: `automation/issue-22-atomic-review`
- Pre-write parent: `7dee9c05d5b9cf1ddf470c03ea22f3fc6c6d1e86`
- Base main: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`
- Source increment: [`bb6c567`](https://github.com/collab-TTAM/nihongo_daily/commit/bb6c56712a09ee42a833c8862cc7a40318cf1071) plus the focused fixture correction [`7dee9c0`](https://github.com/collab-TTAM/nihongo_daily/commit/7dee9c05d5b9cf1ddf470c03ea22f3fc6c6d1e86).

### Change

Added `runtime-native-logout-clear-failure` to the TEST ONLY Windows bridge. It starts the actual caller-owned `PersistentSupabaseRuntime`, signs in User A through the pinned Supabase SDK, stores A's refresh token in the real project-scoped Windows Credential Manager, and injects a one-shot native clear failure before `CredDeleteW`.

The phase requires the first explicit logout to revoke A's study/profile readiness while retaining A's old OS credential. A subsequent B sign-in attempt must not dispatch Auth or own-profile. A second explicit logout retries the same owner and exact-target clear. Only after the slot is absent can B authenticate; B's rotated refresh secret must be readable before B's captured own-profile request. A's pending journal event remains isolated from B. B logout and a separate fresh runner must both observe signed-out state.

### Changed paths

- `apps/flutter_app/tool/windows_runtime_fixture.dart`
- `apps/flutter_app/tool/verify_windows_vault_bridge.ps1`
- `docs/WINDOWS_SESSION_VAULT.md`
- `docs/PERSISTENT_SESSION_LIFECYCLE.md`
- `qa/matrix.json` (two exact anchors on the existing lifecycle case)
- `docs/PROJECT_STATUS.md`
- This handoff file

### Review and verification

- Initial source parent `cfceae7885738dd64a524acd9f84719d64f2879e`; exact base tree `b19b62a115a8d258afc81442df4a94a41993ee5f`; recursive tree was complete (348 entries, 283 blobs, 65 trees). The source tree update used `base_tree_sha`; the branch update compared expected parent and `force=false`.
- Source diff review confirmed five intended blobs changed; no paths were added/deleted and no modes/types changed. Every unchanged blob SHA was preserved. The follow-up fixture correction changed only `windows_runtime_fixture.dart` and was separately compared/reviewed against its exact parent.
- Static checks in the cloud authoring script: QA JSON parsed; phase allowlist, native MethodChannel fault operation, PowerShell invocation and QA anchors matched. No pinned Dart/Flutter SDK or Windows OS is available here, so local format/analyze/Flutter tests/native probe/build were not run.
- Exact final-head GitHub Actions is the required execution gate. Do not claim this new phase or any final-head test/build pass until every latest-attempt job and step is observed successful on that exact SHA; skipped/pending/failed jobs are not passes.

### Limits and next action

- Auth HTTP/JWT in the Windows fixture remain TEST ONLY synthetic responses. The fault hook is compile-time TEST ONLY and the PowerShell harness rebuilds with `ND_SESSION_VAULT_TEST_HOOKS=OFF` before normal preview/staging builds.
- No spontaneous OS failure, hosted signed-JWT learner A/B, deployed PostgREST/RLS, OS logoff/power loss or physical multi-device evidence is claimed.
- No production Auth/provider strategy, API/schema/RLS/migration, default runtime activation, learner-supplied URL/key, staging dispatch/secrets, Pro-owned #14/#38/N4, merge, deployment or release changed.
- Keep PR #37 Draft and #20/#22/#15/#18 open. Next: inspect exact final-head Actions jobs/steps and repair only observed failures; hosted acceptance still depends on the protected non-production Supabase environment and explicit owner-controlled staging prerequisites.
