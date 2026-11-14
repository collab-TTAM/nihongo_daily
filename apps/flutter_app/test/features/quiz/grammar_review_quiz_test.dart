// TEST ONLY synthetic grammar. Selection uses the actual builder/projection.
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_progress.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_review_quiz.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

const owner = 'a1000000-0000-4000-8000-000000000001';
CurriculumEntry entry(int i, PreviewLevel level, {int version = 1}) =>
    CurriculumEntry(
      id: 'a2000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
      kind: CurriculumKind.grammar,
      level: level,
      contentVersion: version,
      heading: 'TEST ONLY pattern $i',
      caption: 'TEST ONLY',
      reading: null,
      meaningVi: 'TEST ONLY meaning $i',
      explanationVi: 'TEST ONLY',
      hasAudioReference: false,
      notes: const [],
      mistakes: const [],
      examples: const [],
    );
GrammarQuizAttempt report(
  List<GrammarQuizQuestion> questions,
  int id, {
  bool correct = false,
  GrammarQuizAttemptKind kind = GrammarQuizAttemptKind.primary,
}) {
  final round = GrammarQuizRound(questions);
  for (final q in questions) {
    round.answer(
      q.id,
      correct
          ? q.target.id
          : q.choices.firstWhere((c) => c.id != q.target.id).id,
    );
    round.advance(q.id);
  }
  return GrammarQuizAttempt.capture(
    eventId: 'a3000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
    completedAt: DateTime.utc(2026, 10, 23, 0, id),
    round: round,
    kind: kind,
  );
}

GrammarQuizProgress progress(
  List<CurriculumEntry> source,
  List<GrammarQuizAttempt> events, {
  GrammarQuizAttemptKind kind = GrammarQuizAttemptKind.primary,
}) => deriveGrammarQuizProgress(
  ownerId: owner,
  kind: kind,
  level: source.first.level,
  source: source,
  history: [for (final e in events) OwnedGrammarQuizAttempt(owner, e)],
);

void main() {
  for (final level in PreviewLevel.values) {
    test(
      '${level.name} focused selection retains existing error priority and canonical choices',
      () {
        final source = List.generate(12, (i) => entry(i + 1, level));
        final deck = buildGrammarQuiz(source, level);
        final p = progress(source, [
          report([deck[0]], 1),
          report([deck[2]], 2),
          report([deck[2]], 3),
        ]);
        final focused = selectGrammarReviewQuestions(deck, p);
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

  test('focused correction never clears primary recommendations or scores', () {
    final source = List.generate(12, (i) => entry(i + 1, PreviewLevel.n5));
    final deck = buildGrammarQuiz(source, PreviewLevel.n5);
    final initial = report([deck[0], deck[1]], 1);
    final focused = selectGrammarReviewQuestions(
      deck,
      progress(source, [initial]),
    );
    final correction = report(
      [focused.first],
      2,
      correct: true,
      kind: GrammarQuizAttemptKind.correction,
    );
    final after = progress(source, [initial, correction, correction]);
    expect(after.attemptCount, 1);
    expect(after.answerCount, 2);
    expect(after.correctCount, 0);
    expect(selectGrammarReviewQuestions(deck, after), [
      same(deck[0]),
      same(deck[1]),
    ]);
    final corrected = progress(source, [
      initial,
      correction,
      correction,
    ], kind: GrammarQuizAttemptKind.correction);
    expect(corrected.attemptCount, 1);
    expect(corrected.correctCount, 1);
    expect(
      () => selectGrammarReviewQuestions(deck, corrected),
      throwsFormatException,
    );
  });

  test(
    'equal-version copies and replacement versions cannot retarget old progress',
    () {
      final source = List.generate(4, (i) => entry(i + 1, PreviewLevel.n5));
      final deck = buildGrammarQuiz(source, PreviewLevel.n5);
      final p = progress(source, [
        report([deck.first], 1),
      ]);
      final copies = List.generate(4, (i) => entry(i + 1, PreviewLevel.n5));
      final newer = List.generate(
        4,
        (i) => entry(i + 1, PreviewLevel.n5, version: 2),
      );
      expect(
        selectGrammarReviewQuestions(
          buildGrammarQuiz(copies, PreviewLevel.n5),
          p,
        ),
        isEmpty,
      );
      expect(
        selectGrammarReviewQuestions(
          buildGrammarQuiz(newer, PreviewLevel.n5),
          p,
        ),
        isEmpty,
      );
      expect(selectGrammarReviewQuestions(deck, p), [same(deck.first)]);
    },
  );

  test(
    'empty correct-only and foreign-level decks never invent review questions',
    () {
      final source = List.generate(4, (i) => entry(i + 1, PreviewLevel.n5));
      final deck = buildGrammarQuiz(source, PreviewLevel.n5);
      final empty = progress(source, []);
      expect(selectGrammarReviewQuestions(deck, empty), isEmpty);
      expect(
        selectGrammarReviewQuestions(
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
        selectGrammarReviewQuestions(
          buildGrammarQuiz(foreign, PreviewLevel.n4),
          wrong,
        ),
        isEmpty,
      );
      expect(selectGrammarReviewQuestions([], wrong), isEmpty);
    },
  );

  test(
    'ambiguous or oversized review deck fails before selecting a target',
    () {
      final source = List.generate(4, (i) => entry(i + 1, PreviewLevel.n5));
      final deck = buildGrammarQuiz(source, PreviewLevel.n5);
      final p = progress(source, [
        report([deck.first], 1),
      ]);
      expect(
        () => selectGrammarReviewQuestions([deck.first, deck.first], p),
        throwsFormatException,
      );
      expect(
        () => selectGrammarReviewQuestions(List.filled(5001, deck.first), p),
        throwsFormatException,
      );
    },
  );
  test(
    'focused grammar selection retains all targets beyond display and batch caps',
    () {
      final source = List.generate(24, (i) => entry(i + 1, PreviewLevel.n5));
      final deck = buildGrammarQuiz(source, PreviewLevel.n5);
      final events = [
        for (var offset = 0; offset < 24; offset += 8)
          report(deck.skip(offset).take(8).toList(), offset ~/ 8 + 1),
      ];
      final p = progress(source, events);
      final selected = selectGrammarReviewQuestions(deck, p);
      expect(selected, hasLength(24));
      expect(
        selected.map((q) => q.target.id).toSet(),
        deck.map((q) => q.target.id).toSet(),
      );
      expect(
        selected.every((q) => deck.any((original) => identical(q, original))),
        isTrue,
      );
      expect(
        selected.map((q) => q.target.id).toList(),
        p.needsReview.map((item) => item.entry.id).toList(),
      );
    },
  );
  test(
    'correction-only empty projection is rejected before focused practice',
    () {
      final source = List.generate(4, (i) => entry(i + 1, PreviewLevel.n5));
      final p = progress(source, [], kind: GrammarQuizAttemptKind.correction);
      expect(() => selectGrammarReviewQuestions([], p), throwsFormatException);
    },
  );
}
