# Core worker handoff — 2026-11-17T07:09Z

## Scope and source

- PR: [#41](https://github.com/collab-TTAM/nihongo_daily/pull/41), still Draft.
- Branch: `automation/issue-11-plan-sdk-integration`.
- Parent / exact source HEAD: `7d22e0cf436c3956d8e6cf27edcb591e6381205b`.
- Base main: `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Run: `core-20261117T0709Z-pr41-apply-exact-dart-format-and-docs-correction`.
- Pro-owned PR #38 / Issue #14 / N4 content scope was not read for editing and remains untouched.

## Observed parent CI

Exact-head [GitHub Actions run #44029709620](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44029709620), attempt 1, targets `7d22e0cf436c3956d8e6cf27edcb591e6381205b` and completed FAILURE.

- `database`: SUCCESS; every listed step SUCCESS.
- `repo-sanity`: SUCCESS; every listed step SUCCESS.
- `ai-boundary`: SUCCESS; every listed step SUCCESS.
- `windows`: SUCCESS; every listed step SUCCESS, including configured TEST ONLY bridge and release build.
- `flutter`: FAILURE only at `dart format --output=none --set-exit-if-changed .`.
- Flutter log showed `progress_overview_widget_test.dart` as the sole formatter-changed file and emitted one exact hunk: collapse the multiline `_mount(tester, harness, source, serverHistoryReader: reader)` invocation to one line. Analyzer, full Flutter tests, Chrome transaction checks and Web release build were SKIPPED, not passes.

## Change made

- Applied only that formatter-emitted whitespace/line-wrap hunk in `apps/flutter_app/test/features/progress/progress_overview_widget_test.dart`.
- No test, expectation, assertion, runtime behavior, fixture or CI gate was changed.
- Re-read `docs/QUIZ_REPORT_API.md`: the previously reviewed comma-splice correction is already present on this branch (authenticated history endpoint paragraph, lines 962–993), so no redundant second edit was made.
- The canonical `docs/PROJECT_STATUS.md` is oversized for a safe full-file replacement through this connector; this sidecar is the durable checkpoint and does not truncate/reconstruct that file.

## Post-change verification required

No CI has yet run on the new commit. The cloud authoring runtime has no pinned Flutter/Dart SDK, so no local format/analyze/test/build pass is claimed. The next worker must inspect the complete latest-attempt jobs and steps for the exact new HEAD. If the strict formatter passes, require analyzer, full Flutter suite, Chrome transactional checks, Web build, Windows, database and AI jobs to finish successfully before further feature work.

## Remaining Personal Alpha gates

- PR #37 remains separate at `87ed02a8fbc1ec3efaba849bda32474c87f27620`; [run #44008302166](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44008302166) completed SUCCESS across all six jobs. This is component/CI evidence only.
- Hosted signed-JWT learner A/B, deployed PostgREST/RLS, learner restart/expiry and physical multi-device offline/reconnect acceptance remain unverified and require the protected non-production staging environment and dedicated test accounts.
- PR #41's server quiz history remains read-only/opt-in. The Edge function is undeployed; no hosted learner history, mastery/weak-point, SRS mutation or study-credit claim is made.
- No Auth/provider strategy, schema/RLS, default save behavior, production deployment, merge, issue closure or release change was made.

## Previous handoff closure

Exact-head CI for the formatter correction passed on 2026-11-17 at
`f2c57b7ecffacd4da3be616eeba2122fa764636d`: all five published jobs and every
returned step succeeded. The next #13 progress increment is recorded below.


## Progress overview N5/N4 breakdown — 2026-11-17T08:16Z

- Run `core-20261117T0816Z-pr41-progress-level-breakdown`; branch `automation/issue-11-plan-sdk-integration`; parent HEAD `f2c57b7ecffacd4da3be616eeba2122fa764636d`; base main `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Added per-level N5/N4 attempt and correct/answer totals for local vocabulary, grammar-primary and grammar-correction history on `/overview`. Existing aggregate totals, manual load, one read per configured repository, read-only behavior and account-generation fences remain.
- Extended the existing mixed-history widget regression with N4 vocabulary and both grammar kinds; added QA anchors and clarified `docs/PROGRESS_OVERVIEW.md`. No Auth, storage, server request, mastery, SRS, study-minute credit, Pro content, schema/RLS or default activation change.
- Source changes are committed in the enclosing PR #41 checkpoint. Cloud authoring runtime has no pinned Flutter/Dart SDK; no local format/analyze/test/build result is claimed. Exact-head CI must verify format, analyzer, full Flutter tests, Chrome, Web and Windows.
- PR #37 remains open/Draft at `87ed02a8fbc1ec3efaba849bda32474c87f27620`; exact-head run [44008302166](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44008302166) passed all six jobs/every step. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, learner restart/expiry and physical multi-device acceptance remain protected-staging blockers. Pro-owned PR #38 / Issue #14 / N4 scope remains excluded.
- Next: inspect all latest-attempt jobs/steps for the exact new PR #41 HEAD; fix only observed failures, then continue the next unblocked #13 learner-history/progress increment. Keep PR #41 Draft and hosted release gates open.
