# Core handoff — bounded Auth HTTP cancellation regression

**Run:** `core-20261118T0712Z-pr37-bound-http-cancel-test`  
**Branch:** `automation/issue-22-atomic-review`  
**Parent:** `6bda5663bfb9653bd76913fa544ce8d6b5cfcd83`  
**Base main:** `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`

## Observed failure

Exact-head Actions [44243011392](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44243011392), attempt 1, targeted the parent commit. Repository sanity, database/RLS, AI boundary, Windows and disposable Supabase integration all succeeded (13, 12, 12, 18 and 13 steps). Flutter format/analyze succeeded; the complete suite reported 447 passing / 1 failing. The only failure was the two-second outer timeout in `SDK body deadline returns while response cancellation acknowledgement is stalled`. Downstream Flutter steps were skipped.

## Correction

The failing test timed out the whole `PersistentSupabaseRuntime.start()`, not one HTTP request. The pinned Supabase SDK retries transport failures, so a complete Auth operation can outlast one request deadline (as already documented). The test now exercises the exact bounded transport directly through a narrowly scoped `@visibleForTesting` factory. It verifies one Auth request maps its body deadline to retryable `NETWORK_UNAVAILABLE` while the delayed `onCancel` acknowledgement remains pending, then injects an acknowledgement error to verify cleanup handling. The separate pinned-SDK runtime test still covers late-response rejection and the no-own-profile barrier.

## Paths

- `apps/flutter_app/lib/features/auth/application/persistent_supabase_runtime.dart`
- `apps/flutter_app/test/features/srs/persistent_supabase_runtime_test.dart`
- `docs/PERSISTENT_SESSION_LIFECYCLE.md`
- `qa/matrix.json`
- `docs/PROJECT_STATUS.md`
- This handoff file

No production Auth behavior, SDK/provider strategy, schema/RLS, default activation, hosted staging dispatch/secrets, or Pro-owned N4 scope changed.

## Verification limits and next action

The cloud authoring runtime has no pinned Flutter/Dart SDK; no local formatter/analyzer/test/build was run. Require exact-head CI for formatter, analyzer, full Flutter suite, Chrome/Web, Windows, database, disposable Supabase and AI-boundary checks. Hosted signed-JWT learner A/B, deployed PostgREST/RLS, real Windows learner restart/expiry and physical two-device sync remain unverified. Keep PR #37 Draft and #20/#22/#15 open. Inspect every latest-attempt job and step before any further code change; do not treat a skipped downstream step as passing.
