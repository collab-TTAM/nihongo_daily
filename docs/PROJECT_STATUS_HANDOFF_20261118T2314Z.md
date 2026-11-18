# PR #37 exact pinned Dart formatter repair handoff

Run: `core-20261118T2314Z-pr37-exact-dart-eof-repair`
Status: **RELEASED — source correction persisted; exact-head CI required**

- Repository: `collab-TTAM/nihongo_daily`
- Branch: `automation/issue-22-atomic-review`
- Parent / expected HEAD: `d8ab029ea79e66d03d34947b8325e71c87168e98`
- Base: `main` at `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`
- Parent recursive tree: 346 entries, 281 blobs / 65 trees, untruncated.

## Observed CI failure

Exact-head Actions [44409276678](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44409276678), attempt 1, targeted `d8ab029ea79e66d03d34947b8325e71c87168e98`. The diagnostic printed a one-line diff at EOF: the pinned Dart 3.35.4 formatter removes one extra blank line from `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`.

- repo-sanity: SUCCESS, all returned steps successful.
- ai-boundary: SUCCESS, all returned steps successful.
- database: SUCCESS, all returned steps successful.
- windows: SUCCESS, all returned steps successful.
- supabase-integration: SUCCESS, all returned steps successful.
- flutter: FAILURE at strict formatter. Analyze, full Flutter suite, lifecycle checks, browser/native wire checks and Web build were SKIPPED, not passed.

## Implemented correction

1. Removed exactly one terminal newline from the TEST ONLY Windows session lifecycle test, leaving the required single newline at EOF. No assertion or test logic changed.
2. Removed the temporary read-only formatter diagnostic from `.github/workflows/ci.yml`. The strict whole-package formatter, analyzer, full test suite and build gates are unchanged.
3. Appended the exact observed result and next action to `docs/PROJECT_STATUS.md`.

Changed paths:
- `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`
- `.github/workflows/ci.yml`
- `docs/PROJECT_STATUS.md`
- `docs/PROJECT_STATUS_HANDOFF_20261118T2314Z.md` (this file)

## Verification limits

- Cloud authoring runtime does not have the pinned Flutter/Dart SDK; no local format/analyze/test/build is claimed.
- The diagnostic is not a pass. The new exact-head CI must show formatter success and complete every required job/step.
- Windows bridge/local Supabase tests remain component evidence, not hosted signed-JWT learner A/B, deployed PostgREST/RLS or physical multi-device proof.
- No staging secrets were read or used; no protected hosted workflow was dispatched.

## Next action

Inspect the new exact-head Actions run, including every latest-attempt job and step. If formatter passes, continue through analyze, full Flutter tests, lifecycle/Windows/browser checks and Web build. Keep PR #37 Draft and #20/#22/#15 open until their complete acceptance; do not claim Personal Alpha from CI alone.
