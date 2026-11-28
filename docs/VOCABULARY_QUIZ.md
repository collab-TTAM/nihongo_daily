# Vocabulary reading quiz — bounded domain increment

## Scope

This increment implements only a deterministic, in-memory vocabulary-reading quiz domain for a single selected JLPT level. It is a prerequisite for the learner-facing quiz route, not a complete Issue #13 delivery.

- A prompt uses the canonical reading stored on an active original vocabulary row whose expression contains Kanji.
- All four options are distinct trimmed readings drawn from the same selected level. No distractor, alternative reading, translation or curriculum row is fabricated.
- The first original expression heading wins; duplicate headings are skipped. Repeated reading labels are deduplicated for the option pool.
- The source is bounded to 5,000 rows; a round is bounded to ten questions. batchIndex explicitly selects the next batch and preserves source order.
- Correct option slots rotate deterministically. Question identity binds the level, original row ID and content version.
- Fewer than four distinct readings returns insufficientContent; no eligible prompt or an out-of-range explicit batch returns empty.
- The session accepts only the first valid option for the current question. Stale question IDs, unknown options, repeated taps and stale next actions are no-ops. An unanswered question cannot be skipped.
- The local result is an integer correct/total; incorrect questions retain their original source details for review. Restart resets only the in-memory round.

## Deliberate limits

This domain does not persist quiz attempts, update user-owned counters, derive mastery or weak points, mutate SRS, set MASTERED, create a study session, award plan minutes, or write progress. It has no Auth or network dependency. Leaving/reloading the route discards the result.

The increment is N5-ready against the current original seed. N4 remains unavailable until the separate Pro-owned content lane is reviewed and integrated; N5 is never substituted for N4. The existing N5 seed has not yet received independent teacher/native-speaker review, so using its canonical reading field does not claim linguistic approval or complete JLPT coverage.

## Verification

From apps/flutter_app:

    flutter test test/features/quiz/vocabulary_quiz_test.dart

Full pinned-SDK format/analyze/test and Web/Windows CI is still required on the exact PR head. quiz-progress remains a pending Personal Alpha integration case until durable user-owned attempts, mastery/weak-point rules, UI and progress evidence exist.
