# PR #37 — local Supabase SDK A→B→A late-profile handoff

Run: `core-20261120T1510Z-pr37-local-sdk-late-profile-switch`  
Branch: `automation/issue-22-atomic-review`  
Base main: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`  
Parent source HEAD: `cb9daebdd26d94f6f858d14cb97f7963e6e5d495`

## Change

Extended `apps/flutter_app/tool/verify_supabase_sdk_runtime.dart`, which is
already invoked by `scripts/test_supabase_local.py` inside the disposable
Supabase integration job.

The pinned Dart SDK now exercises this real local GoTrue/PostgREST sequence:

1. A signs in; the real `ensure_profile` response is held after the server
   returns it but before the response body reaches the SDK.
2. The test confirms A's refresh token was saved while profile readiness remains
   blocked, then logs A out and confirms the vault is cleared.
3. B signs in and reaches its own-profile readiness while A's old response is
   still held; B logs out.
4. A signs in again with the same Auth user UUID but a new session object and
   reaches readiness.
5. Only then is A1's old successful profile response released. The test requires
   the A2 profile/session/study runtime and refresh secret to remain unchanged,
   and requires the response not to have been cancelled.

This verifies the actual late-response fence through the pinned SDK and real
locally signed GoTrue sessions, rather than only a MockClient/unsigned-JWT
fixture. The existing due-queue, review RPC, journal reopen/replay and B
isolation sequence then continues.

## Paths

- `apps/flutter_app/tool/verify_supabase_sdk_runtime.dart`
- `docs/SUPABASE_REVIEW_BINDING.md`
- `docs/PROJECT_STATUS_HANDOFF_20261120T1510Z.md`

## Verification boundary

The cloud authoring runtime has no pinned Flutter/Dart SDK or local Supabase
stack, so local format/analyze/test/build were not run. Exact-head GitHub Actions
`supabase-integration` is the execution gate; its Python harness runs the pinned
Flutter SDK probe against a disposable local Supabase stack. This is not hosted
staging, physical two-device offline sync, or Personal Alpha learner evidence.
No hosted secrets were accessed.

No Auth strategy/provider, migration, RLS/grant, default app activation,
production/staging configuration, Pro-owned #14/#38/N4 content, deployment,
merge or release state changed.

## Next

Inspect every latest-attempt job and required step on the new exact HEAD. Fix only
observed diagnostics while preserving the real-session/late-response assertions.
Keep PR #37 Draft and #20/#22/#15/#18 open until hosted A/B, physical offline
recovery and the full Personal Alpha journey are evidenced.
