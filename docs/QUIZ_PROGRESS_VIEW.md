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
owner and selected level. Account/readiness/source/level replacement disposes the
old panel and clears its counters. Every await checks mounted state; repository
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
