# Configured vocabulary/grammar elapsed sessions — Issue #11/#12

Default /vocabulary and /grammar remain public packaged-content browsers. No
network operation, start, report, credit or mastery is inferred from opening,
searching or navigating an item. Configured Windows with a ready own profile
and the existing captured durable service can explicitly report elapsed study.

## Learner flow and readiness

The reader and SRS panels use the same StudySessionTimerPanel/provider/controller,
never one recorder per route. Enter a valid explicit profile-local YYYY-MM-DD or
choose the existing server/profile today-fill action. Filling the date does not
start or save. Start requires settled nonempty curriculum data of the selected
kind/level, positive original content versions and profile.level equal to that
preview level. Loading, errors (including stale retained successful data), empty
content, no-match search and level mismatch disable start. Preview level never
changes the authenticated profile. Readiness is checked again after preflight.

Start first checks same-owner pending local reports, then loads the requested
day's authoritative plan and requires the matching vocabulary/grammar block to
be nonblocked/nonempty. Another ready area cannot substitute. Only then does
foreground monotonic timing begin. Finish explicitly freezes the existing UUID,
date, area and UTC interval, stages before dispatch, acknowledges durably and
loads fresh progress through the unchanged service. The existing one-minute to
25-hour duration, wall-clock discrepancy, server calendar/overlap/credit rules
remain. Time is a self-report, not attention, item completion or mastery.

## Lifecycle and frozen reports

Level changes, unavailable/reloading content, no-match search, route departure,
backgrounding and owner loss cancel unfinished timing/preflight without a new
report. Ordinary matching-content search, details and previous/next can continue
the same interval. Returning or reloading never restarts automatically. Scoped
interruption and generation checks prevent old routes/late preflight from
canceling a newer area's interval. Accepted saves retain existing drain ownership.

One frozen report blocks every area's new start, including when local staging
failed and disk recovery is empty. Any of these three panels shows its original
area/date/UTC interval and offers explicit exact retry/manual recovery. Retrying
from another route never retargets its event. Unknown results remain uncertain;
confirmed acknowledgment plus failed fresh-plan reload stays confirmed with a
separate message and no invented progress. Owner replacement clears projections
and fences late results; staged records retain existing owner isolation.

Date EditableText remains mounted through logout and awaited OS exit, while
cleared, disabled, offstage and excluded from focus. The existing router, SDK,
store leases and shutdown drain are retained. No Auth/storage owner, journal or
RPC format, endpoint, dependency, migration, RLS or background retry is added.

## Verification and limits

Parent e674e60b3bf388b3ccd8d9899fe1e993588807c3 / CI39376257044 is verified all five
jobs/every required step successful: 506 Flutter tests, five Chrome tests,
SDK/native/process/SQL/Web/Windows, including the shared-provider failed-stage
regression. Those are parent results, not execution of the new reader widgets.

Seventeen new widget cases are authored for both public/configured readers,
explicit date/save/ack, profile-level mismatch, loading/error/empty/wrong-level,
refresh retaining old data, pending-before-plan/matching blocked area, failed-stage
cross-route retry/ambiguous commit, search/level/route/background cancellation,
late preflight, logout/late save, 320px/200-percent confirmed reload failure and
actual owned-host exit retention. They use original decoded exports with TEST
ONLY Auth/RPC/storage/clock; owned exit additionally loads the actual bundled N4
provider. Taps use visible hit targets. Existing SRS/reader/owned tests remain.

The native frozen-slot fixture now also asserts immutable pendingEvent identity
and clearing after acknowledgment. Direct pinned Dart formatting/pure targeted
analysis, all 27 native verifier scenarios plus actual abrupt-child/process-lease/
reopen checks, QA inventory49/17 regressions and whitespace passed locally.
Full new Flutter/provider/widget/SDK/platform results require exact-head Actions;
local Flutter metadata-endpoint automatic-review rejection is not retried or
bypassed. No local full Flutter pass or hosted learner/OS/device proof is claimed.

Keep #41 draft, #11/#12 open and all14 hosted acceptance groups pending. Remaining
activities, hosted validation, browser study persistence, full sync, real Kanji
grading and live AI/voice remain outstanding. Main and source drafts/content
stay unchanged; no merge, deployment, release or schedule change.


## Reader test corrections — 2026-10-20

Exact e1915c04 CI39392930477 Flutter format/analyze passed; full tests reported
520 passed/3 failed. All14 other new reader cases passed, including failed-stage
cross-route retry, lifecycle/late preflight, logout, narrow/large-text confirmed
reload failure and bundled owned-host exit. Downstream Flutter/browser/Web steps
were skipped, not successful. Database/repo-sanity/AI were successful at review;
Windows was still running. This is not a complete verified-head result.

Both configured save cases compared separate DailyPlanDate objects, whose strict
model deliberately has no value-equality override. Compare event.date.value to
the exact expected YYYY-MM-DD instead. Keep acknowledgment, area,61-second
interval, one event ID/write, two plan reads and no SRS queue assertions.

The retained-data refresh case already observed loading=true, readiness=false
and recorder=canceled; its start-button lookup ran before the scheduled panel
frame. Render that single frame while the reload future is still held, then
assert one disabled start plus no elapsed/frozen report. Do not settle the active
loading spinner or complete reload to make the readiness assertion pass. All
17 cases/original checks remain; no production/lint/CI/timeout change.

Pinned local format1/0changes, QA inventory49/all17 regressions, whitespace and
separate exact diff review passed. Full corrected Flutter execution requires
fresh exact-head CI; prior metadata-endpoint automatic-review rejection remains
and no local Flutter CLI retry/bypass is attempted. Next inspect that CI before
new product work; pending-only means handoff without duplicate changes/long
polling. All14 hosted gates remain pending; keep #11/#12 open/#41 draft.
