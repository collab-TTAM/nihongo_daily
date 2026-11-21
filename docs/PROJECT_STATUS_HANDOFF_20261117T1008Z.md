# Core worker handoff — 2026-11-17T10:08Z

## Scope and source

- PR: [#41](https://github.com/collab-TTAM/nihongo_daily/pull/41), remains Draft.
- Branch: `automation/issue-11-plan-sdk-integration`.
- Parent / exact source HEAD: `2791a847d04cde74c02ed7e50d7965ddf2d03128`.
- Base main: `78a44faf09c03a8a214f10a2e0a0b5fa90a26f4c`.
- Run: `core-20261117T1008Z-pr41-progress-summary-null-safety-ci-repair`.
- PR #37 remains separate/open/Draft at `87ed02a8fbc1ec3efaba849bda32474c87f27620`; Pro-owned PR #38 / Issue #14 / N4 scope remains excluded.

## Observed parent CI

Exact-head [GitHub Actions run #44054927627](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44054927627), attempt 1, targets `2791a847d04cde74c02ed7e50d7965ddf2d03128` and completed FAILURE.

- `database`: SUCCESS; all 25 listed steps succeeded.
- `ai-boundary`: SUCCESS; all 20 listed steps succeeded.
- `repo-sanity`: SUCCESS; all 13 listed steps succeeded.
- `windows`: FAILURE in the TEST ONLY Dart-to-Windows bridge build because the progress screen accessed six fields on nullable `_ServerQuizPageSummary?`; the downstream native/release steps were SKIPPED.
- `flutter`: FAILURE only at strict Dart 3.35.4 formatting in `progress_overview_widget_test.dart`; analyzer, full Flutter tests, Chrome transactions and Web build were SKIPPED.
- The Windows compile diagnostics and formatter patch were read from the exact run's job logs. No skipped step is treated as a pass.

## Bounded repair

- `progress_overview_screen.dart`: make the existing derived invariant explicit by rendering the receipt breakdown only when both the page and its derived summary are non-null. No data fetch, write, page bound, owner fence or aggregation semantics changed.
- `progress_overview_widget_test.dart`: apply only the exact formatter layout emitted by CI to the existing mixed N5/N4 receipt test. All expectations and assertions are retained.
- Existing regression still asserts the explicit 20-row read, per-level/per-kind totals, no local history reads/writes, and no widget exception.
- The canonical `docs/PROJECT_STATUS.md` is too large for a safe full-file replacement through the connected file operation; this sidecar is the durable status record and does not reconstruct or truncate the canonical history.

## Verification required

- Cloud authoring runtime has no pinned Dart/Flutter SDK, so local format/analyze/test/build was not run or claimed.
- The new source commit must trigger exact-head Actions. Inspect every latest-attempt job and step on that exact SHA; require Flutter format/analyze/full tests, Chrome transactions, Web release, Windows native/release, database and AI checks to finish SUCCESS. Fix only observed diagnostics.
- Keep PR #41 Draft until acceptance and exact-head CI are complete.

## Remaining Personal Alpha gates

- PR #37 exact-head [run #44008302166](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44008302166) passed all six jobs and every returned step. This is component/CI evidence only: hosted signed-JWT learner A/B, deployed PostgREST/RLS, real learner expiry/restart and physical two-device offline/reconnect remain unverified and require protected non-production staging and dedicated test accounts.
- PR #41's server quiz history remains read-only/opt-in; the Edge function is undeployed. No hosted learner history, durable quiz-attempt/mastery/weak-point derivation, SRS mutation, study credit or cross-device proof is claimed.
- No Auth/provider strategy, schema/RLS, default save behavior, Pro-owned N4 content, production deployment, merge, issue closure or release change was made.

## Next action

Inspect all latest-attempt jobs/steps for the new exact PR #41 HEAD. If all pass, continue the next unblocked #13/#11 integration increment; otherwise fix only the observed failure.
