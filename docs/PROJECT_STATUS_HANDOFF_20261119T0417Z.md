# PR #41 downstream preview artifact verification handoff

- Run: `core-20261119T0417Z-pr41-downstream-preview-artifact-verification`
- Branch: `automation/issue-11-plan-sdk-integration`
- Parent: `0ef0e1d705c0100d1d7f1b9261842c212f40948b`
- Main: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`
- PR: https://github.com/collab-TTAM/nihongo_daily/pull/41

## Observed parent failure

CI [44454848765](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44454848765), attempt 1, targeted the parent exactly. Repository sanity, AI boundary and database passed. Flutter formatting, analysis, tests, Web build and upload passed. Windows build, native vault/process checks and upload passed. The only failures were the two `actions/download-artifact@v4` steps executed inside the same jobs that had just uploaded the Web and Windows artifacts. GitHub logs show each upload finalized; the run's completed artifact inventory later exposed `flutter-web-preview` and `flutter-windows-preview`. The subsequent byte/provenance steps were skipped.

## Source change

- `.github/workflows/ci.yml`: Flutter/Windows jobs now only build, package and upload. A downstream `preview-artifacts` job waits for repo-sanity, Flutter and Windows to finish, then downloads each artifact by stable name and runs the unchanged `scripts/package_preview.py --verify-ci` check.
- `qa/matrix.json` and `scripts/verify_qa.py`: add the sixth required CI job and its four critical steps.
- `qa/test_verify_qa.py`: update current evidence loops for six jobs while preserving explicit five-job historical snapshot validation; add a static regression against same-job artifact downloads.
- `docs/QA_SECURITY_MATRIX.md`, `docs/PROJECT_STATUS.md`: record the failure, correction, evidence boundary and next action.

## Verification boundary

No local Python, Flutter SDK, or Windows execution is claimed. The exact-head GitHub Actions run must execute the repo-sanity regression and all six jobs. A green producer build/upload alone is insufficient; both downstream artifact downloads and byte/provenance verifiers must succeed.

## Next action

Inspect the complete latest attempt for the resulting HEAD. If the downstream verifier passes for both bundles, record the exact run/head. If it fails, inspect that job's logs and correct only the observed issue. Keep PR #41 Draft; do not change staging secrets, Auth/provider strategy, schema/RLS, default runtime, Pro N4 content, or release gates.
