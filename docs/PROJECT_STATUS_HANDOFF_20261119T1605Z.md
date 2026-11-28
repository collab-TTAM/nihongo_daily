# PR #37 handoff — local PostgREST due-queue sync

Run: `core-20261119T1605Z-pr37-local-postgrest-queue-sync`  
State: RELEASED  
Branch: `automation/issue-22-atomic-review`  
Source commit: `a5a423a4c724e33f0952afa1f136944d8aa9cc7c`  
Base main: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`

## Delivered

- Added a second deterministic vocabulary record only to `supabase/tests/local_integration_seed.sql`; it is TEST ONLY and is not a canonical curriculum export.
- Extended `scripts/test_supabase_local.py` so the disposable local GoTrue/PostgREST stack creates a due event through the actual `submit_review` RPC and reads the actual `get_review_queue` RPC from two independent User A sessions and User B.
- A's sessions must see the same typed N5 due item; B and A's N4 queue must be empty. The test validates server time/due ordering, limit behavior, invalid-limit and forged-owner errors, expired JWT rejection, and read-only queue behavior by comparing review-event and scheduling projections before/after.
- The event is two hours old, so the normal ten-minute NEW-card GOOD interval is due without direct privileged SQL updates.
- Updated `docs/REVIEW_QUEUE.md`, `supabase/README.md` and the existing `local-two-session-sync` QA anchor. No production code, migration, RLS, Auth provider, frozen API or Pro-owned N4 path changed.

## Review and verification

- Separate source diff review: exactly five intended paths; no other source path changed.
- Full recursive tree: 351 entries / 286 blobs / 65 trees, untruncated. Exactly five blobs changed; 281 untouched blobs and every path/mode/type were preserved. `create_tree` used exact parent `base_tree_sha`; the one-parent commit was published with `update_ref(expected_sha, force=false)` and branch readback matched.
- No local Docker/Python environment was used to claim execution; the new integration runs in CI's disposable local Supabase stack.
- Exact-head Actions result is pending inspection on the final status commit. Do not claim pass for queued, skipped, missing or pending jobs.

## Next action

Inspect the latest-attempt workflow for the final PR #37 HEAD and all jobs/steps, especially `supabase-integration` and its new `get_review_queue` assertions. If a test fails, repair only the observed failure and preserve all existing RLS/auth/replay assertions. Keep #15/#20/#22/#18 open; local two-session evidence does not replace hosted signed-JWT learner A/B, physical-device offline/reconnect/restart or Personal Alpha smoke.
