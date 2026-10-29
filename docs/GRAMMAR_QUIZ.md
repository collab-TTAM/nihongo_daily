# Grammar quiz core — Issue #13

The grammar quiz now has an explicit process-local route at /quiz/grammar,
linked from /quiz. It does not persist grammar attempts.
GrammarQuizQuestion and GrammarQuizRound are distinct types from vocabulary
questions/rounds, preventing accidental input to VocabularyQuizAttempt.capture.
No Auth, storage, study recorder, SRS or progress capability is imported.

## Accepted-answer review — 2026-10-29 UTC

Completed rounds now show the accepted choice meaning, original target meaning
and original target explanation for each incorrect answer, in question order.
The display reads the completed round's immutable accepted-answer snapshot and
exact question choices. No invented explanation or additional curriculum request.
Correct answers are omitted. Focused correction summaries use only that subset's
answers while the original score remains frozen; restart removes the old summary.
Existing first-answer, round/source/level lifecycle guards remain unchanged.

Two synthetic widget cases exercise normal and320px/200% layouts, selected vs
correct meanings, distinct target explanations, omission of correct questions,
subset isolation, frozen original score, full restart and a single source read.
Existing tests/assertions remain untouched. Local format/QA and exact-head CI are
recorded in PR41; Flutter/analyze/native builds locally unavailable. This remains
process-local feedback, not grammar persistence/mastery or hosted learner proof.


## Focused correction round — 2026-10-29

After a completed original round containing errors, Luyện riêng câu sai starts a
separate round from exactly its incorrect original question objects, in original
order. Choices, source versions, explanations and examples are reused unchanged;
no new curriculum read or generated material. It retains first-answer scoring and
source/level/provider/generation guards. The original integer score stays visible
as Bộ gốc and cannot be raised by correction answers. This is practice feedback,
not repeated-error persistence, mastery or server study credit.

Làm lại câu sai resets only the correction subset. Làm lại bộ gốc explicitly
starts the entire original batch with empty answers and removes the frozen score.
Bộ câu hỏi tiếp theo always advances by the original batch length, even after
reviewing only one or two mistakes; no original questions repeat or disappear.
Perfect primary rounds and correction rounds offer no nested review action.
Every transition constructs a fresh round identity, so captured original/focused
answer/advance/review/restart/batch callbacks cannot revive through an ABA cycle.
Reload, level/source change and route exit discard both scopes as before.

Four synthetic widget cases cover8/10 original +2/2 correction, preserved score,
exact subset order/one source read, duplicate/stale actions, subset restart,
original restart/perfect round, original10-row next-batch offset, reload/level/
disposal and320px200% actual controls. All original fixture bytes/assertions/
timeouts/cleanup are retained. Parent504e157 CI40880006535/latestattempt1 all5/
EVERYstep SUCCESS and native persistent SDK marker observed; TEST ONLY component,
not hosted learner proof. Fresh Dart3.9.2 archive SHA256 verified/strict format
clean (unresolved Flutter lint include warning); QA55/inventory154/whitespace
checked separately. New4/full Flutter/analyze/build locally UNRUN(noFlutter),
require new exact-head Actions. No storage/Auth/SRS/vocabulary history/content/
Pro/default/retention policy change; all14 hosted release groups remain pending.


## Local screen and source integration — 2026-10-29

The fixed curriculum repository grammar/selected-level read feeds an autoDispose
provider and the existing bounded core. Vietnamese loading, safe redacted error,
manual reload and insufficient-content states do not invent data. Each visible
round has at most10 questions; next batch and restart are explicit. Feedback and
incorrect review retain original meaning/explanation; score is integer correct/
round total. No grammar data enters vocabulary history or progress/save paths.

Every action checks the exact provider snapshot, repository, level and screen
generation. Manual listeners retire level/source callbacks before the next frame,
including ABA. Provider invalidation immediately retires old actions; a keyed new
panel discards answers on reload/source/level replacement. Round identity fences
old answer/advance/restart/batch closures even for identical question IDs. Route
exit disposes the panel; no stale callback may trigger a read or answer.

Eight synthetic widget cases cover real route/link/provider/core, wrong/correct/
duplicate answers, ten-question scoring/review/restart/next batch with one source
read, safe errors/retry/empty, pending old-level success/error, level ABA/reload/
disposal, repository replacement before a frame and320px/200% actual buttons.
No corpus files/tests or Pro scope modified. Parent465b17a CI40872072420/latest
attempt1 all5/EVERYstep succeeded; all10 core cases and native persistent SDK
marker observed. New widgets/analyze/platform builds locally UNRUN(no Flutter);
Dart3.9.2 archive SHA256 verified/format clean, with unresolved Flutter lint include
warning. QA55/inventory154/whitespace checked separately; new exact-head Actions
required. Default AI off/all14 hosted groups pending; not hosted learner proof.


## Original usage and examples after answering — 2026-10-29

After a valid current answer, a collapsed Cách dùng và ví dụ theo bài gốc panel
shows the target's original usage notes, common mistakes and every Japanese /
reading / Vietnamese example. Wrong answers still show the correct target's
material, not the selected distractor. Empty note/mistake sections are omitted;
missing examples explicitly say Bài gốc chưa có ví dụ. No examples are generated.
The existing explanation remains visible without opening the panel.

The panel is keyed to the exact question identity and exists only after answering.
Advancing/reloading removes it; the next answered question starts collapsed.
Existing source/level/generation/round guards remain unchanged. Expanding/collapsing
uses the loaded immutable entry and performs no extra repository read or write.
It does not change scoring, vocabulary persistence, study time or mastery.

Three synthetic widget cases cover hidden-before-answer/collapsed state, wrong/
correct target material including two complete example triples, next-question
reset, empty sections/reload and actual title/next taps at320px/200% text. Every
original test fixture byte is retained after removing the new helper/cases.
Parentfa5da1a CI40876848905/latestattempt1 all5/EVERYstep succeeded, including
all8 prior grammar widgets and Windows persistent SDK/profile/receipt rotation.
New3 widgets/format/analyze/build locally UNRUN(no SDK); QA55/inventory154/diffcheck
are separate checks. No content/Pro/Auth/API/RLS/retention/default policy change;
all14 hosted learner release groups remain pending and PR41 stays draft.

## Reviewed selection and scoring rules

The UI asks: Chọn nghĩa tiếng Việt theo bài gốc for target.heading (the
existing grammar pattern). Choice labels are original meaningVi values. This is
source association, not proof that other grammar patterns are semantically wrong
or that original explanations are complete. Linguistic review remains required.
No new text, examples or distractors are generated or added to content exports.

Validate the entire selected-level grammar source before filtering: at most5000
entries, unique nonblank IDs up to128 code units, positive content versions,
nonblank patterns up to256 and nonblank meanings up to2048. Fixed format errors
contain no source text. Bounds are local quiz limits, not shared wire changes.
Skip all repeated trimmed patterns; distinct trimmed meanings form the option
pool. Fewer than four eligible meanings returns an empty list. Original order,
first representative per meaning and a rotating correct slot give deterministic
four-choice questions without mutating source entries. Target/options remain
original immutable entries; outer/option lists are immutable snapshots.

Question identity includes grammar, level, original ID and version. A round has
at most10 unique targets from one level. Accept only the first valid answer for
the exact current question and one of its choices. Cannot advance unanswered or
with an earlier question ID. Each accepted matching target ID scores1, other
valid choices0. Incorrect entries and exported answer maps are immutable snapshots.
An empty round is complete with score0, not a percentage or mastered state.
A new round starts empty. Callers must still replace rounds on source/route change.

No grammar results are passed to vocabulary history/progress. No minutes, server
credit, mastery threshold, account cache or saved-success behavior is introduced.
Reviewed language coverage, grammar-specific persistence and learner acceptance
remain later work.
This increment does not complete issue13 or any Personal Alpha release gate.

## Verification

From apps/flutter_app:

```bash
flutter test test/features/quiz/grammar_quiz_test.dart
```

Ten synthetic core cases cover deterministic original choices/slots, insufficient
meaning diversity, duplicate patterns, invalid hidden inputs/limits, repeated
meaning targets, immutable lists/maps, first-answer/stale-advance behavior,
level/version identity, round bounds/empty state and ten-question scoring.
These tests do not modify or validate Pro's N4 content or certify language quality.
Local Dart/Flutter SDK unavailable: new tests/format/analyze/build UNRUN; require
new exact-head Actions. QA55/inventory153/diffcheck are separate checks. Parent
CI40868376520 exacte9f6adc/latestattempt1 all5/EVERYstep succeeded, including actual
restored-history journey and Windows persistent SDK/protected original-mismatch
markers; parent success is not new grammar or hosted learner proof.
