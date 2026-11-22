

## N5 reading catalog count regression — 2026-11-22T01:12Z

- Run `core-20261122T0110Z-pr41-reading-catalog-count-tests`; branch `automation/issue-11-plan-sdk-integration`; parent `0222e9d0f17ffe50471c9e46a18e051ae88e9559`; base main `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`.
- Exact-head Actions [44965187142](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44965187142), attempt 1, completed with repo-sanity, database, AI boundary and Windows SUCCESS; Flutter FAILED after format and analyze passed. The full Flutter suite reported 2,132 passed / 2 failed; preview-artifacts and downstream Flutter steps were skipped, not passed.
- Failure 1: `bundled_reading_repository_test.dart` still expected five N5 IDs and 15 questions, while the fixed bundled catalog contains six passages including `n5-sunday-meal-01` and 18 questions. Failure 2: `reading_widget_test.dart` expected the stale label “5 bài đọc · Chọn để mở”, while the screen correctly derives the count from the six loaded passages.
- Corrected only these two feature tests: assert the sixth stable ID, 18 total questions, the visible sixth card and the six-passage label. No reading content, production UI/domain logic, N4/Pro-owned files, manifest, Auth, API/schema/RLS or CI gate changed.
- The cloud authoring runtime has no pinned Flutter/Dart SDK; no local Flutter format/analyze/test/build was run. The new exact-head CI must rerun the full suite and all downstream jobs.
- Next: inspect every latest-attempt job and step on the new exact HEAD; fix only observed diagnostics. Keep PR #41 Draft and #34/#11/#18 open pending independent content review, audio availability, trusted study-session integration, hosted learner evidence and Personal Alpha acceptance.
