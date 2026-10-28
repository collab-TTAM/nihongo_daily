# Own-device quiz practice dashboard — Issue #13

The reviewed projection rules in QUIZ_ATTEMPTS.md remain unchanged. /progress
now reads configured local quiz history and current original vocabulary through
the existing typed repositories. Default preview has no account/history source
and offers the configured-account route without inventing results.

## Read and display

The learner explicitly loads/reloads statistics. No automatic read, retry, save,
study recorder, profile change, SRS mutation or server credit occurs. N5/N4
selection belongs only to this view; it does not retarget the account or public
preview preferences. It starts at N5 and is reset when leaving the route.

The existing owner-bound repository supplies validated immutable history. Current
public vocabulary loads first; history loads last so the repository's captured
session/readiness fence follows the public-content await. The projection derives
all counters in one step, rejecting mixed ownership or conflicting event replay
before producing results. Reload clears old counters and recommendations before
dispatch; content/history/projection failure shows a fixed safe error and manual
retry with no partial totals or raw paths/credentials.

Show unique selected-level saved rounds, original correct/answer totals and
current-source practiced-item count. These are client reports of quiz practice,
not time studied, attention or mastery. No mastery threshold is introduced.
Unknown/stale-version/changed-choice items can remain in historical totals but
cannot create a current recommendation. The latest wrong answer selects a
current item for review; a later correct answer clears it. Rank and ties use the
unchanged deterministic domain rules. Display at most20 original headings,
readings, Vietnamese meanings and repeated-error counts, with an explicit cap
notice. No owner/event IDs, filesystem paths or token text appear.

## Replacement and late work

State is keyed by the exact captured history repository, curriculum repository,
owner, selected level and a monotonically changing view-level revision. Account/
readiness/source/level replacement disposes the old panel and clears its counters.
Every load start and await checks mounted state AND the captured owner/history/
source/level/revision before further reads or publication; repository
history reads additionally enforce the original ready lifecycle before and after
storage. Late success/error or stale callbacks cannot publish into a new panel.
Loading is single-flight, and a disposed load callback is a no-op. Route return
starts empty and requires another explicit read. Accepted borrowed reads remain
tracked by the existing owner drain; this view does not open or close storage.

## Evidence and remaining acceptance

Exact parent c1f0b9b33ffa8040a565cc1c33efa755def3ad02, CI39716360716 latest
attempt2, completed allfive jobs/every required step successfully. Attempt1's
sole remaining failure was npm audit registry HTTP503; a single failed-jobs retry
resolved it without changing code/dependencies/security. Completed Flutter logs
prove674 tests, allnine save cases, five Chrome, Web/Windows builds and retained
native/SDK/process/wire/SQL gates. This validates the prior save integration.

Ten widget scenarios are authored for default preview, profile readiness and
explicit empty load, duplicate/repeated-error/later-correct behavior, safe reload
and content failure, same/other-owner late reads and duplicate/stale callbacks,
level change during held content, route-exit late failure and320px/200-percent
layout. Auth/profile/local storage are explicit TEST ONLY ports; original N5
content is read unchanged. Controllers/subscriptions are constructed inside each
widget body's FakeAsync zone. Existing domain/owner/disk/SDK tests remain.

Local QA inventory51/all29 Python regressions and whitespace checks passed;
new format/analyze/widget/platform execution requires exact-head Actions because
the local Flutter/Dart SDK is unavailable. Source review is not runtime proof.
All14 hosted release groups remain pending. Keep #13 open/#41 draft for hosted
ownership/sync, authoritative mastery rules and actual learner acceptance.


## Explicit focused practice

The current-source needs-review list now offers explicit focused practice through
the existing quiz panel; see FOCUSED_QUIZ_REVIEW.md for source/owner/level guards,
canonical full-source choices and verification limits. Statistics loading still
never saves. The learner separately completes and explicitly saves a new local
attempt, then reloads statistics to include it. Default account absence, projection
rules, no mastery/time credit and all hosted acceptance limits remain unchanged.


## Before-frame read fence — 2026-10-28

The previous mounted-only UI check could start public content from a retained load
callback after a level change, or start old private history when held public
content completed before the replacement frame. The repository still enforced
its own Auth readiness, but the view must also enforce its narrower captured
selection and source lifetime. _load now checks the existing isCurrent closure
before starting, after content/history awaits, in error publication and finally.
A level-change revision is captured in the panel key and closure: N5 -> N4 -> N5
before any frame cannot revive the original N5 panel or retained load callback.
No I/O is cancelled or storage ownership replaced; accepted reads retain existing
repository drain, and old abandoned panels publish neither totals nor errors.

Three widget regressions exercise retained load after selection but before frame,
held public content continuation before frame (zero old private history reads),
and level A-B-A without a frame. Each fresh panel must still support explicit
normal load with exact counters/selected level; all old widget bodies remain.
These are TEST ONLY Auth/profile/local ports; new Flutter cases/analyzer/format/
build are locally UNRUN (no SDK), require exact-head CI. Local QA46, inventory151
and whitespace passed. No new default/Auth/storage/retention/mastery/SRS/server
credit or Pro content change. #13 remains open and #41 draft; hosted gates pending.

## Captured selector callback — 2026-10-28 UTC

The view-level selector now checks mounted state before provider access/setState,
and requires the same captured history repository and curriculum source. A
retired callback cannot alter a replacement view before its frame or call
setState after disposal. This does not invalidate repeated selections within the
same current view: existing before-frame N5-N4-N5 revision/load guards remain.
No history read/write is triggered by selection, and no Auth/profile level or
study credit changes. Accepted borrowed work retains its existing owner/drain.

Two regression widgets retire the history repository before invoking the old
selector, or invoke it after route disposal. Both require zero content/history
reads, no exception, and a fresh explicit N5 load with exact counts. All original
widget bodies/assertions/cleanup remain. Parent aa7d7cd CI40761864119 attempt1
passed all5/every step and retained Windows markers. New2 widget/format/analyze/
build locally UNRUN (no Dart/Flutter SDK); QA46/inventory151/diffcheck pass
separately. Exact-head CI required. No hosted learner/mastery/release acceptance.


## Review original usage in place — 2026-10-28

Each displayed needs-review row can now expand to show its already captured
current curriculum entry's usage context and every original Japanese example,
kana reading and Vietnamese translation. Text is selectable; missing examples
have an explicit empty message and audio remains unavailable in this review view.
The heading/reading/meaning/error counts and existing focused-practice action are
unchanged. No synthetic example, alternate reading or new curriculum is authored.

Expansion uses only the immutable entry already accepted by the owner-bound
progress projection: no network/history/content read, save, recorder, score,
mastery/SRS/profile mutation or study credit. Existing twenty-row display cap and
current-version/choice matching still apply. Reload clears the projection and
removes expanded rows; redisplaying the same item starts collapsed. No PageStorage
key or persisted expansion is used. Owner/source/level/route replacement continues
to dispose the captured panel and its public context together.

Three added widget cases show exact original usage/examples and unchanged
read/write counters; reload to empty then back to the same recommendation without
restoring expansion; and320px/200-percent expanded text without layout exception.
All original widget bodies/assertions/cleanup remain unchanged. QA46/inventory151/
whitespace passed locally; new3 Flutter/format/analyze/build locally UNRUN(noSDK),
require exact-head CI. Parent e38f0bd CI40767557557/latestattempt1 all5/EVERYstep
SUCCESS/no skips. This is local practice assistance, not hosted mastery/learner
acceptance; #13 remains open/#41 draft/all14 hosted release groups pending.
