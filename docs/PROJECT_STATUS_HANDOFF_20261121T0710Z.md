# Project Status Handoff — 2026-11-21 07:10 UTC

## Source and branch

- Repository: `collab-TTAM/nihongo_daily`
- Main observed at `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`.
- Core branch: `automation/issue-11-plan-sdk-integration`; parent before this increment `75566157806d8303816e2fa90bba79c158d09a1e`.
- PR #41 remains Draft. PR #37 remains Draft; exact-head CI `44849012716` passed all six jobs and all returned steps.
- PR #41 parent exact-head CI `44875192672` passed all six jobs and all returned steps. This is parent evidence, not the new commit's CI.

## Delivered increment

The completed-study recovery API returns one captured-owner snapshot containing pending and terminally rejected events. The recovery screen displays rejected events as immutable, read-only history with fixed Vietnamese explanations. It never offers a resend control for a rejected event. A newly persisted definitive rejection refreshes the snapshot immediately. Acknowledged records remain hidden; no local history is deleted, compacted or rewritten.

Changed paths:
- `apps/flutter_app/lib/features/daily_plan/data/durable_study_session_repository.dart`
- `apps/flutter_app/lib/features/daily_plan/presentation/study_recovery_screen.dart`
- `apps/flutter_app/test/features/daily_plan/study_recovery_widget_test.dart`
- `docs/DURABLE_STUDY_SESSIONS.md`
- `docs/OWNED_STUDY_RECOVERY.md`
- `qa/matrix.json`
- `docs/PROJECT_STATUS_HANDOFF_20261121T0710Z.md` (this handoff)

The new widget regression checks restored terminal history, exclusion of acknowledged records, no resend action for rejected events, immediate movement after a newly persisted definitive rejection, and redaction of private text. QA inventory increases from 186 to 187 cases.

## Verification boundary

The cloud authoring runtime has no Flutter/Dart SDK. New formatter, analyzer, widget tests, native process checks, and Web/Windows builds are not claimed locally; the commit triggers exact-head GitHub Actions. Existing exact-head parent CI results above are not substituted for new-head results. QA JSON structure and formatting were validated during authoring; repo-sanity remains the authoritative matrix/anchor check.

The historical `docs/PROJECT_STATUS.md` blob on this branch is 1,310,541 bytes and the available GitHub file reader returned no content for it. It is preserved byte-for-byte; this bounded handoff records the current iteration rather than risking truncation.

## Remaining gates

No hosted signed-JWT learner A/B, deployed RLS/PostgREST, physical Windows restart acceptance, iPhone/Web cross-device synchronization, browser eviction recovery, retention/compaction approval, AI/Voice live acceptance, or complete learner journey is claimed. Default preview remains unconfigured. Pro-owned PR #38/N4 and shared content/manifests/content tests were not changed.

## Next action

Inspect every latest-attempt job and required step on the new exact commit. Fix only observed failures. Then continue the remaining hosted/offline and study/quiz integration gaps without changing Auth strategy, RLS, retention, production data, or Pro-owned content.
