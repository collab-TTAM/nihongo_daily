# PR #37 — two-session offline review conflict handoff

Run: `core-20261120T1415Z-pr37-two-session-conflict`
Branch: `automation/issue-22-atomic-review`
Base main: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`
Parent source HEAD: `696e3974f5d268a832449590546a2841011624dc`

## Change

The disposable local Supabase integration now submits two different immutable review events for the same vocabulary item concurrently through two independent GoTrue password sessions belonging to the same owner. The event instants are ordered. The newer event must always commit; the older event may commit first or must return the explicit `SYNC_CONFLICT` if the newer event acquired the owner lock first.

The test verifies:
- The response count follows the actual lock order and never regresses.
- Every accepted event has exactly one original receipt; a rejected stale event has no orphan receipt.
- The final item row uses the newer event instant and its review count equals the accepted events.
- Both sessions read the same server-authoritative row.
- A different owner cannot read either event receipt.

The QA case `offline-sync` remains `pending-integration`; its limitation now distinguishes this local concurrent-session baseline from physical two-device offline transfer/reconnect and hosted learner evidence.

## Paths

- `scripts/test_supabase_local.py`
- `qa/matrix.json`
- `docs/PROJECT_STATUS_HANDOFF_20261120T1415Z.md`

## Verification boundary

No local Supabase stack or Flutter SDK is available in the cloud authoring runtime. The new integration case has not been executed locally; exact-head GitHub Actions `supabase-integration` is the executable gate. The parent PR #37 exact-head run [44723290114](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44723290114) completed all six jobs/every step successfully, but it does not test this new case.

No migration, RLS/grant, Auth strategy/provider, default app activation, token handling, production/staging configuration, Pro-owned #14/#38/N4 path, or release state changed. This does not prove physical multi-device sync or hosted signed-JWT learner acceptance.

## Next

Inspect every latest-attempt job and required step on the new exact HEAD. Keep PR #37 Draft and #15/#20/#22/#18 open until hosted A/B, real device/offline recovery and complete Personal Alpha journey evidence are recorded.


## Follow-up review correction

The first source increment also changes the later same-owner review count before the existing cross-owner shared-event race. The follow-up therefore derives A's later expected count from `expected_device_count + 1` and timestamps the cross-owner event after the newer same-owner event. This preserves the existing owner-scoped race assertions without allowing an intentionally stale timestamp to turn that later case into a conflict. CI run [44754051266](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44754051266) targets the superseded pre-correction commit and is not acceptance evidence for the corrected script.
