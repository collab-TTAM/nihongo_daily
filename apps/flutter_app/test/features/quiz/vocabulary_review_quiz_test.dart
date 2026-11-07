// TEST ONLY synthetic vocabulary. Selection uses the actual builder/projection.
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_progress.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_review_quiz.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

const owner = 'a1000000-0000-4000-8000-000000000001';
CurriculumEntry entry(int i, PreviewLevel level, {int version = 1}) =>
    CurriculumEntry(
      id: 'a2000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
      kind: CurriculumKind.vocabulary,
      level: level,
      contentVersion: version,
      heading: '語$i',
      caption: 'TEST ONLY',
      reading: 'ご$i',
      meaningVi: 'Từ $i',
      explanationVi: 'TEST ONLY',
      hasAudioReference: false,
      notes: const [],
      mistakes: const [],
      examples: const [],
    );
VocabularyQuizAttempt report(
  List<QuizQuestion> questions,
  int id, {
  bool correct = false,
}) {
  final round = QuizRound(questions);
  for (final q in questions) {
    round.answer(
      q.id,
      correct
          ? q.target.id
          : q.choices.firstWhere((c) => c.id != q.target.id).id,
    );
    round.advance(q.id);
  }
  return VocabularyQuizAttempt.capture(
    eventId: 'a3000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
    completedAt: DateTime.utc(2026, 10, 23, 0, id),
    round: round,
  );
}

VocabularyQuizProgress progress(
  List<CurriculumEntry> source,
  List<VocabularyQuizAttempt> events,
) => deriveVocabularyQuizProgress(
  ownerId: owner,
  level: source.first.level,
  source: source,
  history: [for (final e in events) OwnedVocabularyQuizAttempt(owner, e)],
);

void main() {
  for (final level in PreviewLevel.values) {
    test(
      '${level.name} focused selection retains existing error priority and canonical choices',
      () {
        final source = List.generate(12, (i) => entry(i + 1, level));
        final deck = buildVocabularyQuiz(source, level);
        final p = progress(source, [
          report([deck[0]], 1),
          report([deck[2]], 2),
          report([deck[2]], 3),
        ]);
        final focused = selectVocabularyReviewQuestions(deck, p);
        expect(focused, [same(deck[2]), same(deck[0])]);
        expect(focused.first.choices, same(deck[2].choices));
        expect(focused.first.choices, hasLength(4));
        expect(
          focused.first.choices.any(
            (c) => !focused.any((q) => q.target.id == c.id),
          ),
          isTrue,
        );
        expect(() => focused.clear(), throwsUnsupportedError);
        expect(p.needsReview, hasLength(2));
        expect(p.answerCount, 3);
      },
    );
  }

  test(
    'saved focused correction clears only its current-source review targets',
    () {
      final source = List.generate(12, (i) => entry(i + 1, PreviewLevel.n5));
      final deck = buildVocabularyQuiz(source, PreviewLevel.n5);
      final events = [
        report([deck[0], deck[1]], 1),
      ];
      final focused = selectVocabularyReviewQuestions(
        deck,
        progress(source, events),
      );
      final correction = report([focused.first], 2, correct: true);
      final after = progress(source, [...events, correction, correction]);
      expect(after.attemptCount, 2);
      expect(after.correctCount, 1);
      expect(selectVocabularyReviewQuestions(deck, after), [same(deck[1])]);
    },
  );

  test(
    'equal-version copies and replacement versions cannot retarget old progress',
    () {
      final source = List.generate(4, (i) => entry(i + 1, PreviewLevel.n5));
      final deck = buildVocabularyQuiz(source, PreviewLevel.n5);
      final p = progress(source, [
        report([deck.first], 1),
      ]);
      final copies = List.generate(4, (i) => entry(i + 1, PreviewLevel.n5));
      final newer = List.generate(
        4,
        (i) => entry(i + 1, PreviewLevel.n5, version: 2),
      );
      expect(
        selectVocabularyReviewQuestions(
          buildVocabularyQuiz(copies, PreviewLevel.n5),
          p,
        ),
        isEmpty,
      );
      expect(
        selectVocabularyReviewQuestions(
          buildVocabularyQuiz(newer, PreviewLevel.n5),
          p,
        ),
        isEmpty,
      );
      expect(selectVocabularyReviewQuestions(deck, p), [same(deck.first)]);
    },
  );

  test(
    'empty correct-only and foreign-level decks never invent review questions',
    () {
      final source = List.generate(4, (i) => entry(i + 1, PreviewLevel.n5));
      final deck = buildVocabularyQuiz(source, PreviewLevel.n5);
      final empty = progress(source, []);
      expect(selectVocabularyReviewQuestions(deck, empty), isEmpty);
      expect(
        selectVocabularyReviewQuestions(
          deck,
          progress(source, [
            report([deck.first], 1, correct: true),
          ]),
        ),
        isEmpty,
      );
      final wrong = progress(source, [
        report([deck.first], 1),
      ]);
      final foreign = List.generate(4, (i) => entry(i + 1, PreviewLevel.n4));
      expect(
        selectVocabularyReviewQuestions(
          buildVocabularyQuiz(foreign, PreviewLevel.n4),
          wrong,
        ),
        isEmpty,
      );
      expect(selectVocabularyReviewQuestions([], wrong), isEmpty);
    },
  );

  test(
    'ambiguous or oversized review deck fails before selecting a target',
    () {
      final source = List.generate(4, (i) => entry(i + 1, PreviewLevel.n5));
      final deck = buildVocabularyQuiz(source, PreviewLevel.n5);
      final p = progress(source, [
        report([deck.first], 1),
      ]);
      expect(
        () => selectVocabularyReviewQuestions([deck.first, deck.first], p),
        throwsFormatException,
      );
      expect(
        () => selectVocabularyReviewQuestions(List.filled(5001, deck.first), p),
        throwsFormatException,
      );
    },
  );
}
