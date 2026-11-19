# PR #41 captured-session readiness reentry handoff

Run: `core-20261119T0010Z-pr41-lane-readiness-reentry-guard`
Status: **RELEASED — source and regression persisted; exact-head CI required**

- Repository: `collab-TTAM/nihongo_daily`
- Branch: `automation/issue-11-plan-sdk-integration`
- Parent / expected HEAD: `5308c8ead50a6b3b5473ee5a9f64afb16d3b15b4`
- Base main: `61604bc21da64a0dd94dbb97ba3c4b1d035430a6`
- Parent tree: `abaf7015ff89667eb4d933b8fc557bbd9f47b0b7`, 1009 entries / 884 blobs / 125 trees, recursive result untruncated.

## Preflight and observed failure

PR #37 was re-read first. Its exact-head Actions [44419367037](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44419367037) targets `a4d48b21ad3dc29b1edc5d9ac476baba18ebc593`; all six jobs and every returned step completed SUCCESS. This remains component/CI evidence, not hosted learner A/B or deployed PostgREST/RLS proof.

PR #41's previous worker released at 2026-11-18T23:56Z. Exact-head Actions [44424875485](https://github.com/collab-TTAM/nihongo_daily/actions/runs/44424875485) targets parent `5308c8ead50a6b3b5473ee5a9f64afb16d3b15b4`. Repo-sanity, AI boundary, database and Windows succeeded. Flutter formatter/analyzer succeeded, but full Flutter tests failed one case: `duplicate taps port and readiness reentry cannot create another command` expected `AiConversationPhase.loading`, observed `AiConversationPhase.unavailable`. All Flutter downstream steps were skipped after the failure.

## Root cause and correction

The mutation lane's temporary `_checking` fence was not visible to its captured session. During a host readiness callback, a reentrant controller read could call `CapturedConversationSession.isCurrent`; the lane returned false to reject nested inspection, but the session interpreted that transient result as permanent revocation.

The correction:

1. Expose a read-only `ConversationMutationLane.isCheckingAvailability` hint.
2. Propagate the lane hint through `CapturedConversationSession.isCheckingAvailability` and `isBusy`.
3. Make nested `isCurrent` return false without revoking while the lane is checking.
4. Reject nested session commands with `AiTextRequestPending` before dispatch.
5. Strengthen the existing controller regression to assert the propagated guard, redacted nested state and continued outer loading state.

Changed paths:
- `apps/flutter_app/lib/features/ai/data/conversation_mutation_lane.dart`
- `apps/flutter_app/lib/features/ai/data/captured_conversation_session.dart`
- `apps/flutter_app/test/features/ai/ai_conversation_controller_test.dart`
- `docs/AI_CONVERSATION_RUNTIME.md`
- `docs/PROJECT_STATUS.md`
- `docs/PROJECT_STATUS_HANDOFF_20261119T0010Z.md` (this file)

## Verification limits

- Cloud authoring runtime has no pinned Flutter/Dart SDK. No local format/analyze/test/build is claimed.
- Parent CI failure logs were read; new exact-head CI must pass format, analyze, full Flutter tests and all downstream jobs/steps. No skipped step counts as a pass.
- No hosted provider/Auth, signed-JWT learner, PostgREST/RLS, voice/audio, physical multi-device or Personal Alpha evidence is claimed.
- No staging secrets/workflow dispatch, Auth/provider strategy, schema/RLS, default app activation, Pro-owned #14/#38/N4, deployment, merge or release changed.

## Next action

Inspect every latest-attempt job and every returned step for the new exact HEAD. Fix only observed diagnostics, preserving the regression and all existing gates. Keep PR #41 Draft and #17 open.
