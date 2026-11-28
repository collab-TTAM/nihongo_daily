# N5 vocabulary reading quiz

## Learner route

The `/quiz` route now presents a deterministic vocabulary-reading round using the canonical N5 export packaged with the Flutter app.

- The bundled N5 asset is a byte-for-byte copy of `data/n5/vocabulary.json`; repo-sanity CI checks parity so app packaging cannot silently drift from the authored source.
- The learner chooses N5 or N4 explicitly. N4 currently returns a visible unavailable state; the app never substitutes N5 when N4 is selected. N4 remains owned by the separate Pro content lane until reviewed and integrated.
- Loading, safe error, manual retry, empty and insufficient-content states are explicit.
- A question asks for the canonical reading of an active Kanji-containing expression. All four choices are distinct readings from the same selected source.
- The first valid answer wins. Vietnamese feedback shows the original reading and meaning; incorrect source entries are listed for local review.
- Rounds are deterministic, preserve source order, and contain at most ten questions. The next batch is explicit.

## Deliberate limits

This is an in-memory learner-facing increment only. It does not persist quiz attempts, update user-owned counters, derive mastery or weak points, mutate SRS, set MASTERED, create a study session, award plan minutes, or write progress. Leaving/reloading the route discards the local result.

The current main branch has only the original N5 seed. N4 stays unavailable until the Pro-owned content lane is reviewed and integrated; no N5 fallback is allowed. The N5 seed has not received independent teacher/native-speaker review, so the UI does not claim linguistic approval or complete JLPT coverage. Missing audio remains outside this quiz.

## Verification

From `apps/flutter_app`:

    flutter test test/features/quiz/vocabulary_quiz_repository_test.dart
    flutter test test/features/quiz/vocabulary_quiz_screen_test.dart

The full pinned-SDK formatter, analyzer, Flutter suite, Web and Windows release builds are required on the exact PR head. `quiz-progress` remains a pending Personal Alpha gate until durable user-owned attempts, reviewed mastery/weak-point rules and integrated progress evidence exist.
