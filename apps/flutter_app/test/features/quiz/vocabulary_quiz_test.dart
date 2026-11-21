import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/curriculum/data/bundled_curriculum_repository.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

// TEST ONLY metadata variants; original assets are not modified.
CurriculumEntry quizVariant(
  CurriculumEntry entry, {
  String? id,
  String? heading,
  String? reading,
  int? version,
  CurriculumKind? kind,
}) => CurriculumEntry(
  id: id ?? entry.id,
  kind: kind ?? entry.kind,
  level: entry.level,
  contentVersion: version ?? entry.contentVersion,
  heading: heading ?? entry.heading,
  caption: entry.caption,
  reading: reading ?? entry.reading,
  meaningVi: entry.meaningVi,
  explanationVi: entry.explanationVi,
  hasAudioReference: entry.hasAudioReference,
  notes: entry.notes,
  mistakes: entry.mistakes,
  examples: entry.examples,
);

void main() {
  final originals = <PreviewLevel, List<CurriculumEntry>>{};
  setUpAll(() async {
    for (final level in PreviewLevel.values) {
      final file = File('../../data/${level.name}/vocabulary.json');
      originals[level] = decodeCurriculum(
        await file.readAsString(),
        CurriculumKind.vocabulary,
        level,
      );
    }
  });

  for (final level in PreviewLevel.values) {
    test('${level.name} actual canonical choices', () {
      final source = originals[level]!;
      expect(source.length, level == PreviewLevel.n5 ? 24 : 366);
      final questions = buildVocabularyQuiz(source, level);
      expect(questions.length, greaterThanOrEqualTo(10));
      final again = buildVocabularyQuiz(source, level);
      expect(again.map((q) => q.id), questions.map((q) => q.id));
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        expect(q.choices, hasLength(4));
        expect(q.choices[i % 4], same(q.target));
        expect(q.choices.map((e) => e.reading!.trim()).toSet(), hasLength(4));
        expect(q.choices.every((e) => source.contains(e)), isTrue);
        expect(q.choices.every((e) => e.level == level), isTrue);
        expect(() => q.choices.clear(), throwsUnsupportedError);
        expect(again[i].choices.map((e) => e.id), q.choices.map((e) => e.id));
      }
      expect(() => questions.clear(), throwsUnsupportedError);
    });
  }

  test('duplicate first answer and stale next', () {
    final deck = buildVocabularyQuiz(
      originals[PreviewLevel.n5]!,
      PreviewLevel.n5,
    );
    final round = QuizRound(deck.take(2).toList());
    final first = round.current!;
    expect(round.advance(first.id), isFalse);
    expect(round.answer('foreign', first.target.id), isFalse);
    expect(round.answer(first.id, 'foreign'), isFalse);
    expect(round.answeredCount, 0);
    expect(round.answer(first.id, first.target.id), isTrue);
    expect(round.answer(first.id, first.choices.last.id), isFalse);
    expect(round.answeredCount, 1);
    expect(round.score, 1);
    expect(round.advance(first.id), isTrue);
    expect(round.advance(first.id), isFalse);
    expect(round.answer(first.id, first.target.id), isFalse);
    expect(round.current, same(deck[1]));
    expect(round.answeredCount, 1);
  });

  test('wrong answers stay local and unique', () {
    final deck = buildVocabularyQuiz(
      originals[PreviewLevel.n5]!,
      PreviewLevel.n5,
    );
    final questions = deck.take(3).toList();
    final round = QuizRound(questions);
    for (final q in questions) {
      final wrong = q.choices.firstWhere((e) => e.id != q.target.id);
      expect(round.answer(q.id, wrong.id), isTrue);
      expect(round.answer(q.id, q.target.id), isFalse);
      expect(round.advance(q.id), isTrue);
    }
    expect(round.isComplete, isTrue);
    expect(round.score, 0);
    expect(round.answeredCount, 3);
    expect(round.incorrect, questions.map((q) => q.target));
    expect(() => round.incorrect.clear(), throwsUnsupportedError);
    expect(round.answer(questions.last.id, questions.last.target.id), isFalse);
    final restarted = QuizRound(questions);
    expect(restarted.score, 0);
    expect(restarted.answeredCount, 0);
    expect(restarted.incorrect, isEmpty);
    expect(round.incorrect, hasLength(3));
  });

  test('empty and insufficient reading pool', () {
    final source = originals[PreviewLevel.n5]!;
    expect(buildVocabularyQuiz([], PreviewLevel.n5), isEmpty);
    final short = buildVocabularyQuiz(source.take(3).toList(), PreviewLevel.n5);
    expect(short, isEmpty);
    final empty = QuizRound([]);
    expect(empty.isComplete, isTrue);
    expect(empty.score, 0);
    expect(empty.incorrect, isEmpty);
    expect(empty.answer('missing', 'missing'), isFalse);
    expect(empty.advance('missing'), isFalse);
  });

  test('duplicate prompts and reading labels', () {
    final source = originals[PreviewLevel.n5]!;
    final duplicatePrompt = quizVariant(
      source.first,
      id: source[1].id,
      reading: source[1].reading,
    );
    final input = [source.first, duplicatePrompt, ...source.skip(2)];
    final questions = buildVocabularyQuiz(input, PreviewLevel.n5);
    expect(
      questions.any((q) => q.target.heading == source.first.heading),
      isFalse,
    );
    final duplicateReading = [
      source.first,
      quizVariant(source[1], reading: source.first.reading),
      ...source.skip(2),
    ];
    for (final q in buildVocabularyQuiz(duplicateReading, PreviewLevel.n5)) {
      expect(q.choices.map((e) => e.reading!.trim()).toSet(), hasLength(4));
    }
  });

  test('invalid source fails closed', () {
    final source = originals[PreviewLevel.n5]!;
    for (final input in <List<CurriculumEntry>>[
      [source.first, source.first],
      originals[PreviewLevel.n4]!,
      [quizVariant(source.first, id: '')],
      [quizVariant(source.first, heading: '')],
      [quizVariant(source.first, reading: '')],
      [quizVariant(source.first, version: 0)],
      [quizVariant(source.first, kind: CurriculumKind.grammar)],
      [quizVariant(source.first, reading: 'x' * 129)],
      List.filled(5001, source.first),
    ]) {
      expect(
        () => buildVocabularyQuiz(input, PreviewLevel.n5),
        throwsFormatException,
      );
    }
  });

  test('round bounds and disjoint batches', () {
    final deck = buildVocabularyQuiz(
      originals[PreviewLevel.n5]!,
      PreviewLevel.n5,
    );
    expect(() => QuizRound(deck.take(11).toList()), throwsFormatException);
    expect(() => QuizRound([deck.first, deck.first]), throwsFormatException);
    final first = QuizRound(deck.take(10).toList());
    final next = QuizRound(deck.skip(10).take(10).toList());
    final ids = first.questions.map((q) => q.id).toSet();
    expect(next.questions.every((q) => !ids.contains(q.id)), isTrue);
    expect(() => first.questions.clear(), throwsUnsupportedError);
  });
}
