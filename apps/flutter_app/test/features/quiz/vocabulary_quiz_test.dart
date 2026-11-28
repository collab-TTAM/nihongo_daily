import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';

const _expressions = [
  '私',
  '学生',
  '先生',
  '友達',
  '人',
  '水',
  '本',
  '今日',
  '明日',
  '毎日',
  '食べる',
  '飲む',
];
const _readings = [
  'わたし',
  'がくせい',
  'せんせい',
  'ともだち',
  'ひと',
  'みず',
  'ほん',
  'きょう',
  'あした',
  'まいにち',
  'たべる',
  'のむ',
];

List<VocabularyQuizEntry> _entries({
  int count = 6,
  String level = 'N5',
  List<String>? expressions,
  List<String>? readings,
  List<bool>? active,
}) {
  return List.generate(count, (index) {
    return VocabularyQuizEntry(
      id: 'source-$index',
      jlptLevel: level,
      contentVersion: 1,
      expression: expressions?[index] ??
          (index < _expressions.length ? _expressions[index] : '漢字$index'),
      reading: readings?[index] ??
          (index < _readings.length ? _readings[index] : 'よみ$index'),
      meaningVi: 'nghĩa $index',
      isActive: active?[index] ?? true,
    );
  });
}

void main() {
  const builder = VocabularyQuizBuilder();

  group('VocabularyQuizBuilder', () {
    test('builds four distinct original reading choices deterministically', () {
      final source = _entries();
      final first = builder.build(level: 'N5', entries: source);
      final repeated = builder.build(level: 'N5', entries: source);

      expect(first.status, VocabularyQuizBuildStatus.ready);
      expect(first.questions, hasLength(6));
      expect(
        first.questions.map((question) => question.questionId),
        repeated.questions.map((question) => question.questionId),
      );
      for (var index = 0; index < first.questions.length; index++) {
        final question = first.questions[index];
        final sameQuestion = repeated.questions[index];
        expect(question.options.map((option) => option.label).toSet(), hasLength(4));
        expect(
          question.options[question.correctOptionIndex].id,
          question.correctOptionId,
        );
        expect(
          question.options.map((option) => option.id).toList(),
          sameQuestion.options.map((option) => option.id).toList(),
        );
        expect(question.correctOptionIndex, index % 4);
        expect(question.reading, source[index].reading);
      }
    });

    test('keeps each explicit batch at ten questions in source order', () {
      final source = _entries(count: 12);
      final first = builder.build(level: 'N5', entries: source);
      final second = builder.build(
        level: 'N5',
        entries: source,
        batchIndex: 1,
      );
      final third = builder.build(
        level: 'N5',
        entries: source,
        batchIndex: 2,
      );

      expect(first.questions, hasLength(10));
      expect(first.hasNextBatch, isTrue);
      expect(second.questions, hasLength(2));
      expect(second.hasNextBatch, isFalse);
      expect(third.status, VocabularyQuizBuildStatus.empty);
      expect(third.questions, isEmpty);
      expect(
        first.questions.map((question) => question.sourceId).toSet().intersection(
          second.questions.map((question) => question.sourceId).toSet(),
        ),
        isEmpty,
      );
      expect(
        second.questions.map((question) => question.sourceId),
        ['source-10', 'source-11'],
      );
    });

    test('skips inactive and non-Kanji entries without fabricating prompts', () {
      final round = builder.build(
        level: 'N5',
        entries: _entries(
          count: 4,
          expressions: ['私', 'かな', '学生', '先生'],
          active: [true, true, false, true],
        ),
      );

      expect(round.status, VocabularyQuizBuildStatus.insufficientContent);
      expect(round.eligibleCount, 2);
      expect(round.questions, isEmpty);
    });

    test('skips duplicate expression headings and deduplicates reading labels', () {
      final round = builder.build(
        level: 'N5',
        entries: _entries(
          count: 6,
          expressions: ['私', '学生', '学生', '先生', '友達', '人'],
          readings: [
            'わたし',
            'がくせい',
            'せいと',
            'せんせい',
            'ともだち',
            'ともだち',
          ],
        ),
      );

      expect(round.status, VocabularyQuizBuildStatus.ready);
      expect(round.eligibleCount, 5);
      expect(round.questions.map((question) => question.expression), [
        '私',
        '学生',
        '先生',
        '友達',
        '人',
      ]);
      expect(
        round.questions.first.options.map((option) => option.label).toSet(),
        hasLength(4),
      );
      expect(
        round.questions.first.options.map((option) => option.label),
        isNot(contains('せいと')),
      );
    });

    test('returns an explicit insufficient-content state for fewer than four readings', () {
      final round = builder.build(
        level: 'N5',
        entries: _entries(
          count: 4,
          readings: ['わたし', 'がくせい', 'がくせい', 'せんせい'],
        ),
      );

      expect(round.status, VocabularyQuizBuildStatus.insufficientContent);
      expect(round.questions, isEmpty);
    });

    test('returns an empty state when no active Kanji prompt exists', () {
      final round = builder.build(
        level: 'N5',
        entries: _entries(
          count: 3,
          expressions: ['かな', 'あめ', 'みみ'],
        ),
      );

      expect(round.status, VocabularyQuizBuildStatus.empty);
      expect(round.eligibleCount, 0);
      expect(round.questions, isEmpty);
    });

    test('rejects mixed levels, duplicate IDs and malformed source rows', () {
      final mixed = [
        ..._entries(count: 4),
        const VocabularyQuizEntry(
          id: 'n4-row',
          jlptLevel: 'N4',
          contentVersion: 1,
          expression: '学校',
          reading: 'がっこう',
          meaningVi: 'trường học',
          isActive: true,
        ),
      ];
      expect(
        () => builder.build(level: 'N5', entries: mixed),
        throwsFormatException,
      );

      final source = _entries(count: 4);
      final duplicate = [
        ...source,
        VocabularyQuizEntry(
          id: source.first.id,
          jlptLevel: 'N5',
          contentVersion: 1,
          expression: '山',
          reading: 'やま',
          meaningVi: 'núi',
          isActive: true,
        ),
      ];
      expect(
        () => builder.build(level: 'N5', entries: duplicate),
        throwsFormatException,
      );

      expect(
        () => builder.build(
          level: 'N5',
          entries: [
            const VocabularyQuizEntry(
              id: ' ',
              jlptLevel: 'N5',
              contentVersion: 0,
              expression: '私',
              reading: ' ',
              meaningVi: '',
              isActive: true,
            ),
          ],
        ),
        throwsFormatException,
      );
    });

    test('bounds the source size and rejects invalid level or batch', () {
      expect(
        () => builder.build(level: 'N3', entries: const []),
        throwsFormatException,
      );
      expect(
        () => builder.build(level: 'N5', entries: _entries(count: 5001)),
        throwsFormatException,
      );
      expect(
        () => builder.build(level: 'N5', entries: _entries(), batchIndex: -1),
        throwsFormatException,
      );
    });
  });

  group('VocabularyQuizSession', () {
    test('accepts only the first valid answer for the current question', () {
      final round = builder.build(level: 'N5', entries: _entries(count: 4));
      final first = round.questions.first;
      var session = VocabularyQuizSession(round);

      expect(
        session.answer(questionId: 'stale-question', optionId: first.correctOptionId),
        same(session),
      );
      expect(
        session.answer(questionId: first.questionId, optionId: 'unknown-reading'),
        same(session),
      );
      session = session.answer(
        questionId: first.questionId,
        optionId: first.correctOptionId,
      );
      expect(session.correctCount, 1);
      expect(
        session.answer(
          questionId: first.questionId,
          optionId: first.options.firstWhere(
            (option) => option.id != first.correctOptionId,
          ).id,
        ),
        same(session),
      );
      expect(session.answers, hasLength(1));
    });

    test('cannot advance unanswered questions or apply a stale next action', () {
      final round = builder.build(level: 'N5', entries: _entries(count: 4));
      final first = round.questions[0];
      final second = round.questions[1];
      var session = VocabularyQuizSession(round);

      expect(session.next(first.questionId), same(session));
      session = session.answer(
        questionId: first.questionId,
        optionId: first.correctOptionId,
      );
      session = session.next(first.questionId);
      expect(session.currentQuestion?.questionId, second.questionId);
      expect(session.next(first.questionId), same(session));
      expect(session.currentQuestion?.questionId, second.questionId);
      expect(
        session.answer(
          questionId: first.questionId,
          optionId: second.correctOptionId,
        ),
        same(session),
      );
    });

    test('scores only accepted choices and retains original incorrect prompts', () {
      final round = builder.build(level: 'N5', entries: _entries(count: 4));
      final first = round.questions[0];
      final second = round.questions[1];
      var session = VocabularyQuizSession(round);

      session = session.answer(
        questionId: first.questionId,
        optionId: first.correctOptionId,
      );
      session = session.next(first.questionId);
      final wrong = second.options.firstWhere(
        (option) => option.id != second.correctOptionId,
      );
      session = session.answer(
        questionId: second.questionId,
        optionId: wrong.id,
      );
      session = session.next(second.questionId);
      for (final question in round.questions.skip(2)) {
        session = session.answer(
          questionId: question.questionId,
          optionId: question.correctOptionId,
        );
        session = session.next(question.questionId);
      }

      expect(session.isComplete, isTrue);
      expect(session.scoreLabel, '3/4');
      expect(session.correctCount, 3);
      expect(session.incorrectQuestions, hasLength(1));
      expect(session.incorrectQuestions.single.sourceId, second.sourceId);
      expect(session.incorrectQuestions.single.expression, second.expression);
      expect(session.incorrectQuestions.single.reading, second.reading);
    });

    test('restart resets only this in-memory round', () {
      final round = builder.build(level: 'N5', entries: _entries(count: 4));
      final question = round.questions.first;
      final answered = VocabularyQuizSession(round).answer(
        questionId: question.questionId,
        optionId: question.correctOptionId,
      );

      final restarted = answered.restart();
      expect(restarted.currentIndex, 0);
      expect(restarted.answers, isEmpty);
      expect(restarted.correctCount, 0);
      expect(restarted.scoreLabel, '0/4');
    });

    test('empty round has a zero-over-zero score without a percentage', () {
      final round = builder.build(
        level: 'N5',
        entries: _entries(
          count: 3,
          expressions: ['かな', 'あめ', 'みみ'],
        ),
      );
      final session = VocabularyQuizSession(round);

      expect(session.scoreLabel, '0/0');
      expect(session.correctCount, 0);
      expect(session.incorrectQuestions, isEmpty);
    });
  });
}
