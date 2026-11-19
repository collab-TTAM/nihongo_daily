# Nihongo Daily — core worker handoff

## 2026-11-19T11:05Z — hosted server-revoked refresh restoration recovery

- Run: `core-20261119T1105Z-pr37-revoked-refresh-restore-recovery`
- PR: [#37](https://github.com/collab-TTAM/nihongo_daily/pull/37)
- Branch: `automation/issue-22-atomic-review`
- Parent HEAD: `84ac78a6134f9a12fce3f6dd400b17dae2876d64`
- Base main: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`
- Base tree: `b779d781e14a987b63b269c9c525012f0fec3bc3` (350 entries; recursive response untruncated)

### Change

The protected, manual-only Windows staging runner now adds two fresh-process phases:

- `prepare-revoked-a`: sign A in, capture the refresh token directly from the exact Credential Manager slot, local-logout A to revoke it, verify the slot is empty, then re-seed that same revoked value for this TEST ONLY recovery scenario and close.
- `restore-revoked-a`: a new process attempts startup restore. Real GoTrue must reject the revoked refresh token; the owned runtime stays failed/unready and must not request `ensure_profile`. Explicit password login must see an empty vault before Auth and a persisted replacement refresh token before own-profile, then local-logout and clear.

A TEST ONLY HTTP observer records fixed route/grant labels only. It checks the actual OS vault at the password/profile boundaries and never records bodies, account credentials or tokens.

### Changed paths

- `apps/flutter_app/tool/windows_hosted_runtime_fixture.dart`
- `apps/flutter_app/tool/verify_windows_hosted_runtime.ps1`
- `scripts/test_hosted_supabase_probe.py`
- `docs/HOSTED_SUPABASE_ACCEPTANCE.md`
- `qa/matrix.json`
- `docs/PROJECT_STATUS.md`
- This handoff file

### Verification and limits

- Parent exact-head CI [44504582637](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44504582637) passed all six jobs and every returned step on `84ac78a6134f9a12fce3f6dd400b17dae2876d64`; it does not verify this new head.
- No local Flutter/Dart SDK or Windows OS is available in the cloud authoring runtime. Exact-head CI is required for format/analyze/test/build and static hosted-workflow regressions.
- No hosted workflow was dispatched and no staging secrets were read. The new live scenario remains pending until the protected `supabase-staging` environment and two disposable accounts are configured and approved.
- A server-revoked refresh token is not a cryptographically expired JWT or proof of provider expiry windows. No production Auth/provider, schema/RLS, default runtime, Pro N4, deployment, merge or release changed.

### Next action

Inspect every latest-attempt job/step for the new exact HEAD. Fix only observed failures. Dispatch hosted acceptance only after the protected non-production prerequisites are approved; keep #20/#22/#15/#18 and PR #37 Draft until their complete acceptance evidence exists.


## Exact-head test correction — 2026-11-19T11:18Z

- The first new-head run [44513418991](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44513418991) reported one error in the new static test: `HostedWorkflowSafetyTests` has no `windows_driver` attribute. The other 34 tests in that invocation passed. Repo-sanity therefore failed and downstream Windows, Supabase integration and Flutter jobs were skipped; AI-boundary and database passed.
- Corrected the regression to load the PowerShell driver from the repository path within the test itself. No test assertion or security/workflow gate was removed.
- Corrected source parent: `2db39c2cea0e39df49cf2761c87af5b58ffb5923`; base tree: `1676e3784b90570221732f4f02964cd5a7bd2dbd`; next exact-head CI is required. No local Dart/Flutter or native Windows run is claimed.
