# Core development handoff — Progress A→B→A late failure

- Date: 2026-11-20 UTC.
- PR: [#41](https://github.com/collab-TTAM/nihongo_daily/pull/41).
- Branch: `automation/issue-11-plan-sdk-integration`.
- Parent HEAD: `505b4028657e9c9a6b83fa12708bf3c4181b9675`; base main: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`.
- Scope: TEST ONLY regression for a delayed server quiz page-two failure after A→B→A account replacement.
- Changed paths: `apps/flutter_app/test/features/progress/progress_overview_widget_test.dart`, `docs/QUIZ_PROGRESS_VIEW.md`, `qa/matrix.json`, and this dated handoff. The oversized historical `docs/PROJECT_STATUS.md` (1,299,055 bytes) is preserved unchanged; this focused handoff is the current status supplement.
- Behavior covered: keep page two pending for A; switch to B and back to A with the same owner UUID; load a fresh page one for the new A; then release the old page-two request as a TEST ONLY failure. The fresh summary and normal load-more action must remain, with no stale pagination error/retry label or raw diagnostic text.
- Parent exact-head CI [44727646458](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44727646458) was re-read before this change and completed all six jobs with every returned step successful. This is parent evidence only, not execution of the new regression.
- No local Flutter/Dart SDK in the cloud authoring runtime; no local format/analyze/test/build claim. New exact-head CI must verify formatter, analyzer, the new widget, full Flutter suite and retained platform jobs.
- No production source, Auth/provider, API/schema/RLS, default runtime, Pro-owned #14/#38/N4 content, migration, paid provider, deployment, merge or release changes.
- Next: inspect every latest-attempt job and step for the new exact HEAD; fix only observed diagnostics. Keep PR #41 Draft and Issue #13 open; hosted learner, deployed RLS, mastery and multi-device acceptance remain outstanding.
