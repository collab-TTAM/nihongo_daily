# Opt-in Quiz/Review elapsed study — Issue #11 / #13

The vocabulary quiz can compose the existing account-scoped foreground timer
and durable completed-study service. This does not enable server availability:
current get_daily_plan SQL counts QUIZ_REVIEW as zero and returns BLOCKED.
Original local questions or an enabled client control cannot override that plan.
Trusted availability/version mapping and hosted learner acceptance remain open;
no SQL migration, snapshot reset, grants, Auth strategy or wire change is made.

## Explicit time, separate from quiz results

The timer requires the existing configured durable service and ready own profile.
Selected preview level must match the profile; quiz data must be settled, nonempty
and contain only original vocabulary targets/choices of that level with positive
versions. Loading, errors, empty/insufficient questions and wrong levels cannot
start. The actual quiz round must remain mounted/current and not be locked by a
captured quiz-history owner replacement. No timer is inferred from opening the
page, answering, scoring, completing a round or saving a local attempt.

Enter an explicit profile-local date or use the existing trusted today action,
then explicitly start. The unchanged shared recorder first reconciles pending
same-owner reports, loads the requested plan and requires this exact area to be
nonblocked/nonempty. It rechecks readiness after asynchronous preflight. A ready
SRS/vocabulary block cannot substitute for a blocked quiz area.

An explicit finish freezes ID/date/QUIZ_REVIEW/UTC interval, stages before RPC,
acknowledges durably and reloads authoritative progress. Existing duration,
monotonic/wall-clock, calendar, overlap, ownership and replay validation stays.
The event contains the same five study fields; no answers, score, attempt ID,
mastery or client-derived minutes are submitted. A partial quiz can report an
explicit valid self-reported interval; that proves no quiz completion or attention.
The complete result/review view can retain the same interval until explicit
finish. Local quiz attempt capture/save and its own owner guards are unchanged.
A guest round gaining a ready account can start new time explicitly; this never
retargets or saves its earlier guest answers as an account-owned quiz attempt.

## One owner/slot and round lifecycle

SRS, vocabulary, grammar, reading and quiz use one shared recorder. An uncertain
frozen report blocks all new starts, including failure before local staging.
Retry/recovery from another route retains its exact original area/date/ID/times;
no duplicate counting, automatic replay or new persistence owner is installed.

Restart/next batch explicitly interrupts only unfinished quiz time/preflight
before creating the new round. Level/source/loading loss removes the old host;
route exit/background/account loss also cancels unfinished timing. Other areas
and already accepted saves are not canceled by a quiz restart. Start and finish
callbacks capture owner/state/area and the exact mounted round; an old control
cannot finish its successor. Returning/reloading never starts automatically.

The shared panel remains mounted within the quiz host across history-owner loss
and logout/awaited app exit. Date text clears, disables and goes offstage without
retaining focus. Source/level/route replacement still disposes that host normally.
Late old-account save publication is fenced; a staged original-owner record can
remain pending for the existing exact recovery path. No tokens/log payloads,
plain-text fallback or learner URL/key input is added.

## Evidence and remaining work

Parent77e9cf4 / CI39938761913/latest attempt1 passed allfive jobs/every step,
747 full Flutter/five Chrome/Web/Windows/native/SQL/Edge checks, including allfive
reading callback regressions. These are component results, not new quiz checks.

Four new cases use actual disposable NativeStudySessionJournal files with TEST
ONLY Auth/RPC/clock/readiness/permissive plan: local/exact blocked/nonempty gate
and staged acknowledgment, failed-stage cross-area exclusion/exact retry,
uncertain committed event across close/reopen/manual replay, and late save after
owner replacement. Close/reopen is one process, not a new Windows crash proof.
The fresh official Dart3.9.2 archive checksum was verified. Identical current
production/core/fixtures/test bodies run in a disposable harness; only the
flutter_test import becomes package:test1.26.2. Strict targeted analysis and4/4
cases passed. This is not Flutter/provider/widget/platform execution.

Eleven authored widget cases use actual router/providers/quiz/core/service and
unchanged decoded N5/N4 source with TEST ONLY Auth/RPC/memory store/clock/plan:
public no credit, explicit partial-quiz staged interval, authoritative BLOCKED,
profile mismatch, restart/next-batch interruption and stale finish, pending
refresh, late preflight/route exit, frozen retry through SRS,320px/200-percent,
and logout/held save/date-editor retention. Old quiz/history/progress/owned-exit,
reading/SRS/native/SQL/CI tests remain unchanged. New cases require actual
exact-head Flutter CI; no local Flutter bootstrap-review bypass is attempted.

Format/local QA and final commit/tree/current-head CI observations are recorded
in PROJECT_STATUS and draft PR41/Issue11. Keep #11/#13 open and all14 hosted
Personal Alpha groups pending. Current server quiz availability/version mapping,
real signed-in learner validation, hosted attempt/sync/mastery and release gates
remain outstanding. Default app remains unconfigured; no fake Auth/save success,
canonical content/Pro branch, dependency/CI/provider/spend or production change.
