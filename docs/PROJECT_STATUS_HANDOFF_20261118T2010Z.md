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
