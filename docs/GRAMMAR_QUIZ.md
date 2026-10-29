# Grammar quiz core — Issue #13

This is a pure process-local model, not a routed or persisted grammar quiz.
GrammarQuizQuestion and GrammarQuizRound are distinct types from vocabulary
questions/rounds, preventing accidental input to VocabularyQuizAttempt.capture.
No Auth, storage, study recorder, SRS or progress capability is imported.

## Reviewed selection and scoring rules

A future UI asks: Chọn nghĩa tiếng Việt theo bài gốc for target.heading (the
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
UI loading/error/empty states, actual curriculum integration, reviewed language
coverage, grammar-specific persistence and learner acceptance remain later work.
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
