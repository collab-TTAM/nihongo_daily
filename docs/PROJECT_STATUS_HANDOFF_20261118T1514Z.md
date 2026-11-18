# Handoff — Windows hosted acceptance runner trust guard

Run: `core-20261118T1514Z-pr37-hosted-runner-guard`
Date: 2026-11-18 15:14 UTC
PR: [#37](https://github.com/collab-TTAM/nihongo_daily/pull/37)
Branch: `automation/issue-22-atomic-review`
Parent HEAD: `caef372ecdfa9ff91f909788579a416eaf4a5773`
Base main: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`

## Change

The manual hosted Supabase acceptance driver clears the current Windows user's exact project-scoped Credential Manager target before and after the process sequence. A runner label alone is not a sufficient trust boundary because a self-hosted machine can carry custom labels.

The PowerShell driver now checks `GITHUB_ACTIONS=true` and `RUNNER_ENVIRONMENT=github-hosted` before resolving the executable or invoking any cleanup phase. It fails with a fixed message and does not print environment values.

The offline `scripts/test_hosted_workflow.py` regression checks both conditions and their position before executable resolution and the first cleanup. The existing `auth-live` QA case now anchors this regression and includes it in its reproduction command. The hosted acceptance document explains the additional guard.

## Changed paths

- `apps/flutter_app/tool/verify_windows_hosted_runtime.ps1`
- `scripts/test_hosted_workflow.py`
- `docs/HOSTED_SUPABASE_ACCEPTANCE.md`
- `qa/matrix.json`
- `docs/PROJECT_STATUS.md`
- `docs/PROJECT_STATUS_HANDOFF_20261118T1514Z.md`

## Verification

- Parent CI [44292545976](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44292545976) on `caef372ecdfa9ff91f909788579a416eaf4a5773`: 6/6 jobs and every returned step SUCCESS. This does not verify the new guard.
- New exact-head CI must run `python3 scripts/test_hosted_workflow.py` in repo-sanity, plus the complete current Flutter/Windows/database/Supabase/AI jobs.
- Cloud authoring runtime has no pinned Flutter/Dart SDK or Windows PowerShell host. No local PowerShell, Flutter format/analyze/test/build or hosted staging run is claimed.
- No staging secrets were read or dispatched; no Auth strategy/provider, API/schema/RLS, production deletion, default runtime, Pro-owned N4 content, merge, deployment or release change.

## Next

Inspect all latest-attempt jobs and steps on the new exact HEAD. Keep PR #37 Draft and #20/#22/#15/#18 open until their full hosted learner acceptance is observed.
