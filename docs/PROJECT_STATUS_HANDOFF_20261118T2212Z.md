# PR #37 pinned Dart formatter diagnostic handoff

Run: `core-20261118T2208Z-pr37-pinned-dart-format-diagnostic`
Status: **RELEASED — diagnostic source persisted; exact-head CI required**

- Repository: `collab-TTAM/nihongo_daily`
- Branch: `automation/issue-22-atomic-review`
- Parent: `940064c3507b53f1e9f8bc7148b207a7b26c7020`
- Base: `main` at `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`
- Full parent tree: 345 entries, recursive response untruncated; no unrelated paths were omitted.

## Observed failure

Exact-head Actions [44398845531](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44398845531), attempt 1, targets `940064c3507b53f1e9f8bc7148b207a7b26c7020`. Five jobs completed successfully: repo-sanity, AI boundary, database, Windows and disposable local Supabase integration. Flutter failed at `dart format --output=none --set-exit-if-changed .`; its log says only `test/features/srs/windows_persistent_supabase_runtime_test.dart` would change. Flutter analyze, full tests and downstream Flutter/Web steps were skipped, not passed.

## Change in this checkpoint

Added a temporary read-only step to `.github/workflows/ci.yml` immediately before the unchanged strict formatter gate. It runs pinned `dart format --output=show` to a runner temp file and prints `diff -u`; it never edits the checkout. Also appended the exact observation and next action to `docs/PROJECT_STATUS.md`.

No product runtime, test assertion, Auth strategy/provider, API/schema/RLS, default preview, QA security gate, Pro-owned N4/content, hosted secret, staging dispatch, deployment or release changed.

## Verification limits

- Cloud authoring runtime does not have pinned Flutter/Dart SDK; local formatter/analyzer/test/build were not run.
- This diagnostic commit is not a passing test result. Exact-head GitHub Actions must show the diff and later all required jobs/steps must pass.
- Disposable local Supabase/TEST ONLY Windows bridge checks are not hosted signed-JWT learner A/B or physical multi-device evidence.

## Next action

1. Inspect every job and step on the new exact HEAD; capture the formatter diff from the Flutter job log.
2. Remove the temporary diagnostic step and apply only the exact pinned formatter output to the one TEST ONLY file.
3. Re-read the complete tree, use exact `base_tree_sha` and `update_ref(expected_sha, force=false)`, independently review the diff/tree/blob readbacks, and inspect all latest-attempt CI jobs/steps.
4. Keep PR #37 Draft; do not close #20/#22/#15 or claim Personal Alpha until hosted Auth/RLS, expiry/restart, multi-device and complete learner acceptance are observed.
