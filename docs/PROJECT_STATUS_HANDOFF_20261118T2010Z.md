# PR #37 handoff — caller close during pending Windows refresh rotation write

- Run: `core-20261118T2010Z-pr37-close-during-vault-write`
- Branch: `automation/issue-22-atomic-review`
- Parent HEAD: `80c520ca17b1f33c1274b33061ab3df695577f25`
- Base main: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`

## Delivered

Added TEST ONLY pinned-Supabase-SDK/Windows MethodChannel regression:
`Windows caller close drains a pending rotation write before clearing and releasing owner`.

The test restores User A and confirms the first rotated refresh secret before
profile readiness. It then holds a second refresh-token vault write, starts
caller close, and verifies close cannot clear the pending slot or release the
native owner before the write settles. After the write commits, close must
perform local sign-out, clear the exact project slot, then release the owner.
A replacement runtime must see an empty slot and issue no extra refresh or
own-profile request.

Changed paths:
- `apps/flutter_app/test/features/srs/windows_persistent_supabase_runtime_test.dart`
- `docs/WINDOWS_SESSION_VAULT.md`
- `qa/matrix.json` (one anchor/scope/limitation update in the existing case)
- this handoff sidecar

## Verification and limits

- Full parent recursive tree: 344 entries, untruncated; base tree
  `aaa857f928d2894e6868d6be0ef4d49f0d774d52`.
- Cloud authoring runtime has no pinned Flutter/Dart SDK; local
  `dart format`, `flutter analyze`, Flutter tests and native Windows build
  were not run. Exact-head GitHub Actions is required.
- The regression is TEST ONLY MockClient/MethodChannel evidence. It does not
  prove delayed native `CredWriteW` OS failure, hosted GoTrue/PostgREST,
  signed-JWT learner A/B, deployed RLS, OS logoff/power loss, or physical
  multi-device sync. No staging secrets were read or dispatched.
- No production Auth/provider strategy, API/schema/RLS, default activation,
  migration, Pro-owned #14/#38/N4 content, deployment, merge or release change.

## Next

Inspect every latest-attempt job and required step for the exact new PR HEAD.
Keep PR #37 Draft and #20/#22/#15/#18 open until hosted learner and release
acceptance is actually observed.


## Follow-up exact-head CI observation — 2026-11-18T20:21Z

- Exact-head Actions [44389051027](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44389051027), attempt 1, targeted `cedcdfaeafbf011977f7715d7de0154a6c29b510`.
- Repo-sanity, database and AI boundary succeeded. Flutter failed strict Dart 3.35.4 formatting in `windows_persistent_supabase_runtime_test.dart`; Flutter analyze, complete suite, lifecycle/vault/profile/browser/native/Web checks were skipped. Windows and disposable Supabase jobs remained in progress at observation.
- The next commit adds a temporary read-only pinned formatter diff diagnostic for that one file. Do not count this run as a complete CI pass or as test evidence for the new regression.


## Exact-head formatter diagnosis and correction — 2026-11-18T21:07Z

- Parent PR #37 HEAD `4eb71799425857c5b58a60e5e85d183fbf004a8e`; exact-head Actions [44389540839](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44389540839), attempt 1, completed with Flutter strict format failure only. The read-only diagnostic emitted five expression-wrapping corrections in the new TEST ONLY close-during-vault-write case and one formatter-required blank line at EOF.
- Applied exactly those pinned Dart 3.35.4 formatter changes; no test assertion, timing, production behavior or CI gate changed. Removed the temporary diagnostic step from `.github/workflows/ci.yml`; strict format/analyze/test/build and all other jobs remain enabled.
- Exact corrected-head Actions is now required. The cloud authoring runtime lacks pinned Flutter/Dart SDK and Windows OS, so local Flutter/native checks were not run.
- Next: inspect every latest-attempt job and step on the corrected exact HEAD. Do not count the parent formatter failure's skipped Flutter checks as passes. PR #37 stays Draft; hosted learner and Personal Alpha acceptance remain pending.
