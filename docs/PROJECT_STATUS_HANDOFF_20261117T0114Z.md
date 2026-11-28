# Project status handoff — 2026-11-17T02:14Z

## PR #37 — pinned Dart formatter correction (source repair committed)

- Branch: `automation/issue-22-atomic-review`
- Parent / expected HEAD: `ba9fe73d2b836652d29acf2ff876224aa30b8280`
- Base: `main` at `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`
- Run marker: `core-20261117T0214Z-pr37-apply-pinned-formatter` was ACTIVE before source publication and is now RELEASED in the PR #37 conversation.

### Observed exact-head failure

GitHub Actions [43994336960](https://github.com/collab-TTAM/nihongo_daily/actions/runs/43994336960), attempt 1, ran on exact HEAD `ba9fe73d2b836652d29acf2ff876224aa30b8280`. Five jobs (`repo-sanity`, `ai-boundary`, `database`, `windows`, `supabase-integration`) completed SUCCESS and every returned step succeeded. Flutter failed only at strict `dart format --output=none --set-exit-if-changed .`; the pinned Dart 3.35.4 preview identified exactly two formatting hunks in `tool/windows_runtime_fixture.dart`. Flutter analyze, full tests, Chrome/browser checks and Web build were skipped after format failure, not passes.

### Correction committed

Applied only:
- remove one redundant blank line before `_EmptyReviewStore`;
- collapse the `reject(String userId, String eventId, ReviewFailure rejection)` override signature to the exact pinned formatter layout.

Removed the temporary read-only preview step from `.github/workflows/ci.yml`; the strict formatter gate remains unchanged. No assertions or runtime semantics changed.

### Boundaries and verification

No production Auth/provider, vault behavior, API/schema/RLS, default runtime, hosted staging/secrets, deployment, or Pro-owned #14/#38/N4 content changed. The cloud authoring runtime lacks the pinned Flutter/Dart SDK, so local format/analyze/tests/build were not run. The corrected source has a new exact-head CI run pending; do not claim verification until all required jobs and steps complete successfully.

### Next

Inspect the complete latest-attempt jobs/steps on the corrected exact HEAD. Keep PR #37 Draft and #20/#22/#15 open until hosted signed-JWT A/B, deployed PostgREST/RLS, actual learner restart/expiry and physical multi-device offline/reconnect acceptance are recorded.
