# Opt-in reading elapsed sessions — Issue #34 / #11

Reading can use the same captured-owner completed-study recorder as SRS,
vocabulary and grammar. This is gated composition, not a deployed availability
change. Current SQL get_daily_plan still gives LISTENING_READING zero resources
and BLOCKED status. A local source or enabled client button cannot override that
plan; preflight refuses to begin, and server submission keeps all existing rules.
Reviewed reading material, server-side availability/version mapping and hosted
learner evidence remain required before enabling real reading time. No migration,
plan snapshot reset, RLS/grant, wire contract or default source changes here.

## Selection and account readiness

The reading repository remains public/read-only with null default. A separate
selection provider is bound to its source, preview level and catalog generation.
Source/level/reload changes clear selection even if an immediate load returns
an identical list. Opening/restarting a round explicitly selects its immutable
passage; returning to the list clears it. Source-scoped callbacks cannot select
an old collection after source/level replacement.

Start requires that selected passage be an identical member of the settled
nonempty catalog, all entries have the selected level/positive version, and the
ready own profile matches that level. Loading, errors, no selected passage,
empty/wrong-level data and source replacement cannot start. The shared recorder
rechecks readiness after asynchronous pending-report/plan preflight and requires
the requested LISTENING_READING block to be nonblocked and nonempty. A ready
vocabulary/SRS block cannot substitute. No account, timer start, report or credit
is inferred from opening/answering a passage.

## Explicit report and lifecycle

The existing area-aware panel stays mounted at the reading page root. Its date
EditableText is cleared/disabled/offstage after account loss while retained
through awaited exit. No SDK/vault/journal owner or second recorder is created.
A valid explicit profile-local date and explicit start/finish use the unchanged
monotonic interval/60..90000-second/wall-clock guards. Finished reports freeze the
original ID/date/area/UTC times, stage before dispatch, durably acknowledge and
then load fresh progress through the existing captured service.

Changing/restarting a passage, back-to-list, level/source/reload loss, leaving the
route or backgrounding cancels unfinished timing/preflight without a report.
Opening/restarting explicitly interrupts the reading area only; an old reading
host cannot cancel a different activity. Reading finish callbacks additionally
capture the exact running state so a retained callback cannot finish a later
restarted reading interval. No automatic resume is installed.

A frozen uncertain report survives route navigation in the one shared slot,
including failure before local staging. It blocks new starts in every activity.
Existing manual retry/recovery from reading or SRS keeps the original reading
event without retargeting its area. Accepted saves retain existing drain/owner
semantics; account replacement fences late publication while a staged original
owner record can remain pending. This is self-reported reading time, not attention,
comprehension, passage completion, saved answers, mastery or SRS progress.

The UI explicitly says the timer is for reading only. Audio remains unavailable
and its control disabled; no listening player, synthetic completion, recording,
permission, retention, provider configuration or extra paid operation is added.

## Verification

Five new core cases use TEST ONLY Auth/RPC/clock/readiness and an actual disposable
NativeStudySessionJournal. They cover local readiness and exact blocked/nonempty
server area, failed-stage frozen exclusion/exact retry, uncertain committed event
across journal close/reopen and immutable manual replay, held canceled preflight/
new-area isolation, and late save after account replacement. Close/reopen runs in
one process; it is not a new Windows crash/restart or hosted JWT test. The permissive
fixture plan is explicitly TEST ONLY, not current production SQL availability.

Twelve widget cases use actual router/providers/selection/shared panel/core/service
with simulated Auth/RPC/memory-store/clock and TEST ONLY passage/plan. They cover
public no-dispatch, selected-profile readiness/staged interval/ack, BLOCKED refusal,
level mismatch, held reload, back/restart cancellation, late preflight after route
exit, frozen reading retry through SRS, retained old finish versus new interval,
320px/200% controls and logout/held save/date-editor retention. All15 prior reading
widget cases and existing study/Auth/native/SQL/CI tests remain unchanged.

Observed local core testing uses identical current production source and allfive
new test bodies in a disposable Dart3.9.2 harness; only flutter_test import becomes
package:test1.26.2. Strict targeted analysis and5/5 cases passed. This is actual
native-file logic evidence, not Flutter/provider/widget/platform execution. Full
new-head Flutter/analyze/tests/Chrome/Web/Windows remain exact-head CI gates.
Local formatting/QA/source preservation results are recorded in PROJECT_STATUS.
No Flutter bootstrap metadata-review workaround is attempted.

Next: inspect every latest-attempt current-head required job/step and fix genuine
failures without weakening checks. Then separately review original/licensed reading
content and server availability mapping before activation; no existing plan is
silently unblocked. Audio and all14 hosted Personal Alpha gates remain pending.
