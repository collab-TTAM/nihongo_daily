

### PR #41 transport close during Auth listener cleanup — 2026-11-12T22:07Z

- Run `core-20261112T2207Z-pr41-close-during-auth-cleanup`; branch `automation/issue-11-plan-sdk-integration`; parent/expected HEAD `b34eed01bcc6478033ef165328b46e9cc9c7f937`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added TEST ONLY regression `close drains lookup while Auth listener cancellation is pending` in `apps/flutter_app/test/features/quiz/quiz_report_v2_transport_test.dart`. A valid replay-only lookup response is held at Auth listener cancellation; caller close must deny new dispatch, remain pending until cleanup drains, then reject the old receipt as fixed `NETWORK_UNAVAILABLE`. The same original request is not submitted again.
- Updated `docs/QUIZ_REPORT_API.md` and QA anchor `quiz-report-v2-captured-http-transport`. No production transport/Auth/provider, public route/grant, schema/RLS, default save, local-history release, mastery/study credit, Pro N4 or deployment change.
- Cloud authoring runtime has no pinned Flutter/Dart SDK; local format/analyze/test/build are not claimed. Exact-head Actions is the required verification. Hosted learner A/B, deployed PostgREST/RLS, remote receipt, mastery and multi-device proof remain outstanding.
- Next: inspect every latest-attempt job/step on the new exact HEAD; repair only observed failures, or hand off if checks are pending. PR #41 remains Draft and Issue #13 remains open.
