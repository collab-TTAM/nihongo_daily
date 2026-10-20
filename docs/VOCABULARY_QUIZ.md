# Public original-vocabulary quiz — Issue #13

## Reviewed rules and delivery boundary

The bounded rules were recorded/reviewed in #13 before code. /quiz replaces
its unavailable placeholder with a reading-choice exercise from unchanged
original vocabulary, independently of Auth/SRS/plan/storage. This is usable public
practice, not hosted attempt persistence, mastery or a progress dashboard.

1. A fixed selected N5/N4 level chooses the existing fixed vocabulary repository.
   Reject foreign level/kind, duplicate ID, invalid version, blank/oversized
   ID/expression/reading and more than5000 rows. Preserve original entry objects.
2. Ask “Chọn cách đọc theo bài gốc” for a Kanji-containing expression.
   Repeated expression headings are excluded; four distinct trimmed canonical
   readings come from eligible words in that same level. No invented distractor
   text, translation or complete alternate-reading/linguistic-approval claim.
   Fewer than four distinct readings produces explicit insufficient content.
3. Original question order and distractor selection are deterministic. Correct
   slot rotates; no random seed, personalization or external provider. Each
   round is at most10 questions; explicit next batch does not wrap.
4. Question identity binds level/original ID/content version. A current question
   accepts only its first valid displayed choice. Unknown/stale IDs or repeated
   actions do nothing. Next requires an answer; stale next cannot skip a question.
5. A matching canonical choice contributes1; other accepted choices0. Show the
   integer correct/round-total only. Original incorrect entries support local
   review feedback. Empty round yields0 without a percentage or fabricated result.
6. Restart/next uses a fresh local round. Mounted/current-round guards fence
   stale UI actions after source/route/batch replacement. Loading/error/refresh
   removes the old panel; late old-level results cannot enter the new level.
   Preview level selection never changes an authenticated profile.
7. Mastery remains unavailable. Score is not studied/mastered/attention; never
   write MASTERED, attempts, plan/SRS/profile/counters, timer/recorder or server
   credit. No network service or storage is introduced. #13 remains open for
   reviewed durable user-owned events, repeated-error history and progress.

Independent pre-code review considered duplicate prompt/reading ambiguity,
first-answer dedup, wrong/late next, empty source, invalid source and stale level.
The original source still needs linguistic review. Read-only JavaScript inventory
of the pinned original exports found24 eligible N5 prompts from24 rows and364
N4 prompts from366 rows, with362 distinct N4 readings. Two N4 expressions without
Kanji are intentionally not prompts. This inventory is not Dart execution,
learning acceptance or complete JLPT coverage.

## UI and state

N5/N4 selector, explicit choices, source feedback with Vietnamese meaning/context,
disabled answered choices, explicit next/result/restart/next batch and incorrect
word review. Full-width buttons and scrolling support narrow/large text. Loading,
safe redacted source error/manual retry and insufficient-content states are
separate. Result and answers live only in the route panel; reload/exit/source or
level replacement discards them. No new EditableText or SDK/runtime owner.

## Verification

Parent0c7644e CI39422900350 completed allfive jobs/every required step successfully:
587 Flutter/five actual Chrome, retained SQL/SDK/native/process/Web/Windows builds
and artifacts. Both-level trace refresh and320px/200-percent corrections passed.
This is historical parent evidence, not execution of the new quiz.

New tests are authored for both original levels and canonical immutable choices,
determinism/rotating slots, duplicate prompts/readings, foreign/invalid source,
empty/short source, first-answer/stale next dedup, wrong answers/local reset,
round bounds/disjoint batches. UI cases cover actual original data, correct/
incorrect feedback/results/restart, stale next/batch/choice callbacks, source
refresh/route/level/late result boundaries, redacted error/retry/insufficient data,
both-level320px/200-percent strict hit tests and actual bundled owned exit.

The execution environment is unavailable in this run. No local Dart/Flutter,
format/analyze, Python QA, browser/render or build check was executed. Existing
Actions must verify the new exact head; workflow/dependencies/lints unchanged.
Prior Flutter metadata automatic-review rejection was not retried/bypassed.
Separate source/rule/identity/bounds/callback review completed via pinned GitHub
files. QA inventory adds one automated-baseline anchor; all14 hosted acceptance
groups stay pending. Removing /quiz from the placeholder map replaces that old
unavailable behavior with dedicated real-route tests; other placeholders stay.

Keep #41 draft/#13 open/default preview. No main/source/Pro/canonical curriculum/
Auth/API/schema/RLS/storage/provider/spend/merge/deployment/release/schedule change.
