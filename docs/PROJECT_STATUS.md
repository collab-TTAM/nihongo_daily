

## N5 reading catalog count regression — 2026-11-22T01:12Z

- Run `core-20261122T0110Z-pr41-reading-catalog-count-tests`; branch `automation/issue-11-plan-sdk-integration`; parent `0222e9d0f17ffe50471c9e46a18e051ae88e9559`; base main `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`.
- Exact-head Actions [44965187142](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44965187142), attempt 1, completed with repo-sanity, database, AI boundary and Windows SUCCESS; Flutter FAILED after format and analyze passed. The full Flutter suite reported 2,132 passed / 2 failed; preview-artifacts and downstream Flutter steps were skipped, not passed.
- Failure 1: `bundled_reading_repository_test.dart` still expected five N5 IDs and 15 questions, while the fixed bundled catalog contains six passages including `n5-sunday-meal-01` and 18 questions. Failure 2: `reading_widget_test.dart` expected the stale label “5 bài đọc · Chọn để mở”, while the screen correctly derives the count from the six loaded passages.
- Corrected only these two feature tests: assert the sixth stable ID, 18 total questions, the visible sixth card and the six-passage label. No reading content, production UI/domain logic, N4/Pro-owned files, manifest, Auth, API/schema/RLS or CI gate changed.
- The cloud authoring runtime has no pinned Flutter/Dart SDK; no local Flutter format/analyze/test/build was run. The new exact-head CI must rerun the full suite and all downstream jobs.
- Next: inspect every latest-attempt job and step on the new exact HEAD; fix only observed diagnostics. Keep PR #41 Draft and #34/#11/#18 open pending independent content review, audio availability, trusted study-session integration, hosted learner evidence and Personal Alpha acceptance.


## N5 reading commute passage — 2026-11-22T02:16Z

- Run core-20261122T0212Z-pr41-n5-reading-commute-passage; branch automation/issue-11-plan-sdk-integration; parent 57dd2c34d5e12003727467a8df8c946352526712; base main 61604bc21da64a0dd94dbb97ba3c4b1d035430a6.
- Added original draft passage n5-bus-commute-01 (バスで会社へ行きます) with Vietnamese translation, kana reading and three deterministic source-grounded questions. Bundled N5 reading now has 7 passages / 21 questions. The source note still says teacher/native-speaker review is outstanding; audio remains unavailable and this passage cannot grant listening availability, study credit, mastery or SRS progress.
- Changed exactly: apps/flutter_app/assets/reading/catalog.json, apps/flutter_app/test/features/reading/bundled_reading_n5_expansion_test.dart, docs/READING_MATERIAL.md, docs/PROJECT_STATUS.md. The regression asserts the seventh passage, updates the total and includes its three-question round in the deterministic answer test.
- Full source tree audit before write: 1025 entries (900 blobs, 125 trees), recursive result untruncated; Pro-owned N4/shared paths were present and preserved. No data/n4, data/manifest.json, data/README.md, shared content test or N4 documentation change.
- JSON/identity/choice-key structural preflight passed in the cloud authoring step. The authoring runtime has no pinned Flutter/Dart SDK, so Dart format/analyze/Flutter tests/Web/Windows builds were not run locally. Exact-head GitHub Actions must verify the new regression and all retained gates; no new-head CI pass is claimed.
- PR #41 remains Draft; #34/#11/#18 remain open. Hosted learner, reviewed reading content, vetted audio and Personal Alpha release evidence remain separate gates.
