# PR #41 Progress widget-test drain repair — 2026-11-18T02:07Z

## Exact source and observed CI

- Branch: `automation/issue-11-plan-sdk-integration`
- Parent HEAD: `8b6631f8cff95c89e3143dd755646a35fc877a3b`
- Base main: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`
- Exact-head Actions [44214526059](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44214526059), attempt 1, targets the parent above.
- Repo sanity, database, AI boundary and Windows completed successfully. Flutter pinned format and analyzer completed successfully; the full suite reported 1,861 passed and 2 failed. The two failures were `pumpAndSettle timed out` in `progress_overview_widget_test.dart`: the late keyset continuation case at the first page load and the server receipt retry case after its successful retry. Flutter lifecycle, Chrome, Web release and artifact steps were skipped after the test failure.

## Bounded test correction

Changed only `apps/flutter_app/test/features/progress/progress_overview_widget_test.dart`:

- Added a bounded helper that pumps until the expected UI finder appears, rather than requiring every indeterminate progress animation to settle.
- The late continuation test now waits for the first-page summary, asserts the initial loading label is gone, pumps one frame after account replacement, asserts the old summary and continuation spinner are hidden, then completes the held page and pumps the late response without allowing stale data to publish.
- The read-failure/retry test waits for the redacted error on the failed attempt and the summary on the retry, asserting the loading label is gone after each terminal state.
- No production widget behavior, server receipt parsing, cursor, account generation, weak-point logic, retry semantics, assertions about owner isolation or CI gates were removed or weakened.

## Verification and limits

- Cloud authoring runtime does not provide the repository's pinned Flutter/Dart SDK; local format/analyze/test/build were not run.
- The helper is bounded to 100 × 100 ms pumps and fails if the requested state never appears. The test also asserts that the loading label disappears, so a permanently loading UI is not accepted.
- New exact-head CI must verify pinned formatting, analyzer, all Flutter tests, native Windows, Chrome IndexedDB/browser checks, Web release, database/RLS and AI boundary.
- PR #37 remains separate/open/Draft at `7cc6218c8650f81399a7423ee9e417540be06182`; exact-head Actions [44188511253](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44188511253) completed all six jobs and every returned step successfully. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, protected staging restore/expiry and physical multi-device sync remain unverified.
- Pro-owned PR #38 / Issue #14 / N4 source and content scope was not edited. No staging dispatch/secrets, Auth/provider strategy, schema/RLS, default runtime, merge, deployment or release change.
- Next: inspect every latest-attempt job and step on the new exact PR #41 HEAD; fix only observed failures, or release a pending-only handoff without duplicate code.
