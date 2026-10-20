# Foreground SRS session recorder — Issue #11 / PR #41

Configured owned Windows now exposes an optional elapsed-study panel on /srs.
Default preview has no enabled recorder or fabricated progress. The existing
review results remain separate: a duration report does not prove attention,
recall, mastery or a completed curriculum. The public RPC's reviewed policy is
authenticated self-reported elapsed time (STUDY_SESSION_API.md).

## Explicit learner flow

A ready current-account SRS card, no unresolved review and selected SRS level
matching the current profile are required to start. The learner enters a real
YYYY-MM-DD under the displayed profile timezone. No device timezone guess or
new timezone dependency selects a day. Automatic profile-local today remains
outstanding. Starting explicitly checks current-owner pending completed reports
first: any pending report blocks the new interval and offers /study-recovery,
without a plan read or submit. Otherwise load the authoritative plan and require
an available nonempty SRS block, then recheck current card/lease before timing.
Missing/malformed/offline plan or failed local read never starts a timer.

The stopwatch starts after preflight and records one continuous interval.
**Kết thúc và lưu buổi học** freezes one UUIDv4, original plan date, SRS area and
UTC interval, then uses the existing durable service. No owner, derived minutes,
score, arbitrary RPC, credentials or editable timestamps enter the report.
The server retains all own-identity/day/availability/duration/overlap/deduplication
and authoritative progress rules; no client progress overwrite is added.

Only intervals60..90000 seconds are created. Elapsed time uses a monotonic clock;
end is start UTC plus that elapsed interval. A wall-clock discrepancy over five
seconds or invalid/rolled ticks cancels without credit. This is a conservative
clock-consistency check, not server-time synchronization or activity proof.
Cross-profile-midnight reports are not split/retargeted; the server rejects any
interval outside its frozen plan day. Fractional-minute credit remains server
policy. Short/invalid/canceled intervals explicitly say they were not saved.

## Pending reports, errors and visibility

The existing service flushes the exact event before the fixed submit RPC.
Storage/ambiguous transport failures cannot display confirmation. One frozen
report remains in its non-auto-disposed account-scoped recorder; an explicit
**Thử lại cùng buổi học** uses identical fields/ID and blocks a replacement
interval. Navigation preserves a frozen uncertain report in memory; staged ones
also survive restart in the journal. If staging itself failed, the frozen report
is only in memory: the UI asks to retry it before leaving the application.
Account/ready-service replacement clears this transient state; no claim of
crash durability is made before staging succeeds.

A validated acknowledgment plus durable marker is confirmed even if the fresh
plan reload fails. The UI distinguishes that state and never displays old
receipt totals as current progress. A definitive rejection retains its terminal
code in the journal, shows a safe failure and permits a new explicit preflight;
no automatic retry occurs. Checking/recovery/saving disables duplicate actions.
A frozen report reconciled from /study-recovery can be explicitly retried in the
recorder too: the acknowledged marker causes only a fresh read, not a new submit.

## Foreground lifetime and existing ownership

Navigation, non-resumed lifecycle state, queue reload/recovery/failure and account
loss cancel an unfinished timer/preflight with no report or write. Re-entry starts
a fresh interval only on explicit action. The visible periodic tick redraws a
label; it never dispatches or credits time. SRS level changes are disabled while
preflight/timing/save runs, and new starts require the profile level. A last-card
completion can still be explicitly finished. No pause/resume/background accrual
or automatic save is installed. OS kill/power loss of unfinished timing loses
that unsaved interval; the UI explains finish is needed to save.

Once finish has accepted a durable submission, route loss/disposal does not
cancel that immutable operation. The existing runtime operation drain holds SDK
and both journals through completion; account replacement fences publication.
The panel keeps its keyed EditableText mounted/disabled/hidden/unfocusable and
clears its text on account/runtime revocation, preserving awaited OS-exit
observer ownership. No Auth/token writer/refresh/close policy is replaced.

## Authored evidence and limits

Eight pure recorder scenarios use a fake Auth/RPC/clock with actual disposable
NativeStudySessionJournal: current-card/read/short/minute boundaries, pending/
blocked/storage preflight, wall/tick/max-duration failure, failed stage/uncertain
commit/duplicate/exact retry, confirmed reload failure, foreground/account loss,
late preflight/disposal after accepted save and durable definitive rejection.
They run as Flutter cases and in the existing native completed-study verifier
on Linux/Windows, alongside all seven prior recovery/process-lease scenarios.
The workflow and every prior step/assertion are unchanged.

Nine widget cases use memory ports and clocks (no real I/O under fake time):
preview gating, explicit date/card/start/short interval, profile-level mismatch,
save/duplicate controls/fresh totals, pending recovery navigation, stage/network
uncertainty and immutable retry across navigation, background/route cancellation,
retained cleared field with late old-owner save, and320px/200-percent text with
confirmed-but-reload-failed. All preexisting widgets/SDK tests remain.

Local pinned Dart formatting/source+test analysis, the expanded real-disk/process
verifier, QA inventory49/17 regressions and whitespace passed. Flutter CLI is
blocked locally by automatic metadata-endpoint review, so full new-source widget/
SDK/browser/platform execution requires exact-head CI. Parent b28684c CI39363924790
was verified allfive jobs/every required step success,444 Flutter/five Chrome
and all nine recovery widgets. Historical success does not verify this increment.

Other activity timers, automatic profile-local day, browser study persistence,
active-interval crash recovery/clock synchronization and all14 hosted JWT/A-B/
restart/two-device acceptance groups remain outstanding. Keep #11 open/#41 draft;
no source draft/main merge, deployment, schema/RLS/Auth strategy/provider,
dependency, Pro/reader content, spend or schedule change.


## Retry viewport regression — 2026-10-20

Source575716dd CI39365344329 passed repo-sanity, database, AI and Windows,
including the expanded15-scenario native/process verifier. Flutter format/analyze
passed; full tests460 passed/1 failed. All8 recorder scenarios, the8 other timer
widgets and prior SDK/recovery tests passed. The remaining navigation/retry
widget tapped its retry button at y556 while the bottom navigation received the
pointer. The report was therefore never staged, and the subsequent list.single
assertion failed. Flutter's real hit-test warning identifies the missed tap.
Downstream Flutter/browser/Web checks were skipped, not passing.

The fixture now scrolls to and settles each retry target, explicitly asserts it
is hit-testable, then performs a normal tap. Both retries use this helper, and
exact1/2 dispatch counts are additionally checked before the original immutable
interval/unique receipt assertions. All9 cases and original assertions remain;
no warning suppression, direct callback invocation, production behavior, test
viewport enlargement or CI/lint/security change. Local pinned formatting/QA/
whitespace and separate diff review passed; current-head widget execution requires
independent CI. Local Flutter CLI remains blocked by prior metadata-endpoint
approval review; no retry/bypass is attempted by this correction.
