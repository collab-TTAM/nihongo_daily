import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/quiz/application/quiz_report_v2_weak_points.dart';
import 'package:nihongo_daily/features/quiz/data/quiz_report_v2_adapter.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

String _id(int n) => 'a2000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
String _event(int n) =>
    'a3000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
CurriculumEntry _entry(
  int n,
  CurriculumKind kind, {
  PreviewLevel level = PreviewLevel.n5,
}) => CurriculumEntry(
  id: _id(n),
  kind: kind,
  level: level,
  contentVersion: 1,
  heading: kind == CurriculumKind.vocabulary ? '語$n' : '文法$n',
  caption: 'TEST ONLY',
  reading: kind == CurriculumKind.vocabulary ? 'ご$n' : null,
  meaningVi: 'Nghĩa $n',
  explanationVi: 'Giải thích $n',
  hasAudioReference: false,
  notes: const [],
  mistakes: const [],
  examples: const [],
);
List<CurriculumEntry> _source(
  CurriculumKind kind, {
  PreviewLevel level = PreviewLevel.n5,
  int base = 1,
}) => [for (var i = 0; i < 6; i++) _entry(base + i, kind, level: level)];
Map<String, Object?> _answer(
  CurriculumEntry target,
  List<CurriculumEntry> choices,
  bool correct, {
  bool reverse = false,
  int? targetVersion,
  int? distractorVersion,
}) {
  final shown = reverse ? choices.reversed.toList() : List.of(choices);
  final versions = shown.map((e) => e.contentVersion).toList();
  final targetIndex = shown.indexWhere((e) => e.id == target.id);
  if (targetVersion != null) versions[targetIndex] = targetVersion;
  if (distractorVersion != null) {
    versions[shown.indexWhere((e) => e.id != target.id)] = distractorVersion;
  }
  return {
    'item_id': target.id,
    'content_version': targetVersion ?? target.contentVersion,
    'selected_id': correct
        ? target.id
        : shown.firstWhere((e) => e.id != target.id).id,
    'choices': shown.map((e) => e.id).toList(),
    'choice_content_versions': versions,
  };
}

Map<String, Object?> _receipt(
  int n,
  String type,
  String level,
  String? kind,
  String received,
  String completed,
  List<Map<String, Object?>> answers,
) {
  final id = _event(n);
  final correct = answers.where((a) => a['item_id'] == a['selected_id']).length;
  return {
    'received_at': received,
    'request': {
      'client_event_id': id,
      'quiz_type': type,
      'practice_kind': kind,
      'jlpt_level': level,
      'completed_at': completed,
      'answers': answers,
    },
    'response': {
      'client_event_id': id,
      'quiz_type': type,
      'practice_kind': kind,
      'jlpt_level': level,
      'completed_at': completed,
      'answer_count': answers.length,
      'correct_count': correct,
    },
  };
}

QuizReportV2HistoryPage _page(
  List<Map<String, Object?>> items, {
  int limit = 20,
}) {
  final sorted = List<Map<String, Object?>>.of(items)
    ..sort(
      (a, b) =>
          (b['received_at'] as String).compareTo(a['received_at'] as String),
    );
  return QuizReportV2HistoryQuery(
    limit: limit,
  ).decodePage({'items': sorted, 'next_cursor': null});
}

void main() {
  test('empty page produces no weak points', () {
    expect(
      deriveQuizReportV2WeakPoints(page: _page([]), currentContent: const {}),
      isEmpty,
    );
  });
  test(
    'latest wrong answer, repeated errors and grammar kinds stay separate',
    () {
      final vocab = _source(CurriculumKind.vocabulary);
      final grammar = _source(CurriculumKind.grammar, base: 101);
      final vq = buildVocabularyQuiz(vocab, PreviewLevel.n5);
      final gq = buildGrammarQuiz(grammar, PreviewLevel.n5);
      final page = _page([
        _receipt(
          1,
          'vocabulary_reading',
          'N5',
          null,
          '2026-11-17T10:00:01.000000Z',
          '2026-11-17T09:00:00Z',
          [_answer(vq[0].target, vq[0].choices, false)],
        ),
        _receipt(
          2,
          'vocabulary_reading',
          'N5',
          null,
          '2026-11-17T10:00:02.000000Z',
          '2026-11-17T09:02:00Z',
          [_answer(vq[0].target, vq[0].choices, false)],
        ),
        _receipt(
          3,
          'vocabulary_reading',
          'N5',
          null,
          '2026-11-17T10:00:03.000000Z',
          '2026-11-17T09:00:00Z',
          [_answer(vq[1].target, vq[1].choices, false)],
        ),
        _receipt(
          4,
          'vocabulary_reading',
          'N5',
          null,
          '2026-11-17T10:00:04.000000Z',
          '2026-11-17T09:05:00Z',
          [_answer(vq[1].target, vq[1].choices, true)],
        ),
        _receipt(
          5,
          'grammar_meaning',
          'N5',
          'primary',
          '2026-11-17T10:00:05.000000Z',
          '2026-11-17T09:00:00Z',
          [_answer(gq[0].target, gq[0].choices, false)],
        ),
        _receipt(
          6,
          'grammar_meaning',
          'N5',
          'correction',
          '2026-11-17T10:00:06.000000Z',
          '2026-11-17T09:06:00Z',
          [_answer(gq[0].target, gq[0].choices, true)],
        ),
      ]);
      final result = deriveQuizReportV2WeakPoints(
        page: page,
        currentContent: {
          quizReportV2ContentKey('vocabulary_reading', 'N5'): vocab,
          quizReportV2ContentKey('grammar_meaning', 'N5'): grammar,
        },
      );
      expect(result, hasLength(2));
      expect(result.first.entry, same(vocab.first));
      expect(result.first.incorrectCount, 2);
      expect(result.last.entry, same(grammar.first));
      expect(result.last.practiceKind, 'primary');
      expect(result.any((p) => p.entry.id == vocab[1].id), isFalse);
      expect(result.any((p) => p.practiceKind == 'correction'), isFalse);
    },
  );
  test(
    'stale target, reordered choices and changed choice versions are excluded',
    () {
      final source = _source(CurriculumKind.vocabulary);
      final q = buildVocabularyQuiz(source, PreviewLevel.n5);
      final page = _page([
        _receipt(
          11,
          'vocabulary_reading',
          'N5',
          null,
          '2026-11-17T10:00:03.000000Z',
          '2026-11-17T09:00:03Z',
          [_answer(q[0].target, q[0].choices, false, targetVersion: 2)],
        ),
        _receipt(
          12,
          'vocabulary_reading',
          'N5',
          null,
          '2026-11-17T10:00:02.000000Z',
          '2026-11-17T09:00:02Z',
          [_answer(q[1].target, q[1].choices, false, reverse: true)],
        ),
        _receipt(
          13,
          'vocabulary_reading',
          'N5',
          null,
          '2026-11-17T10:00:01.000000Z',
          '2026-11-17T09:00:01Z',
          [_answer(q[2].target, q[2].choices, false, distractorVersion: 2)],
        ),
      ]);
      expect(
        deriveQuizReportV2WeakPoints(
          page: page,
          currentContent: {
            quizReportV2ContentKey('vocabulary_reading', 'N5'): source,
          },
        ),
        isEmpty,
      );
    },
  );
  test('contradictory outcomes at the same completion instant are omitted', () {
    final source = _source(CurriculumKind.vocabulary);
    final q = buildVocabularyQuiz(source, PreviewLevel.n5).first;
    final page = _page([
      _receipt(
        21,
        'vocabulary_reading',
        'N5',
        null,
        '2026-11-17T10:00:01.000000Z',
        '2026-11-17T09:00:00Z',
        [_answer(q.target, q.choices, false)],
      ),
      _receipt(
        22,
        'vocabulary_reading',
        'N5',
        null,
        '2026-11-17T10:00:02.000000Z',
        '2026-11-17T09:00:00Z',
        [_answer(q.target, q.choices, true)],
      ),
    ]);
    expect(
      deriveQuizReportV2WeakPoints(
        page: page,
        currentContent: {
          quizReportV2ContentKey('vocabulary_reading', 'N5'): source,
        },
      ),
      isEmpty,
    );
  });
  test('missing content snapshot fails closed and N5/N4 remain separate', () {
    final n5 = _source(CurriculumKind.vocabulary);
    final n4 = _source(
      CurriculumKind.vocabulary,
      level: PreviewLevel.n4,
      base: 201,
    );
    final q5 = buildVocabularyQuiz(n5, PreviewLevel.n5).first;
    final q4 = buildVocabularyQuiz(n4, PreviewLevel.n4).first;
    final page = _page([
      _receipt(
        31,
        'vocabulary_reading',
        'N5',
        null,
        '2026-11-17T10:00:01.000000Z',
        '2026-11-17T09:00:00Z',
        [_answer(q5.target, q5.choices, false)],
      ),
      _receipt(
        32,
        'vocabulary_reading',
        'N4',
        null,
        '2026-11-17T10:00:02.000000Z',
        '2026-11-17T09:00:01Z',
        [_answer(q4.target, q4.choices, false)],
      ),
    ]);
    expect(
      () => deriveQuizReportV2WeakPoints(page: page, currentContent: const {}),
      throwsFormatException,
    );
    final result = deriveQuizReportV2WeakPoints(
      page: page,
      currentContent: {
        quizReportV2ContentKey('vocabulary_reading', 'N5'): n5,
        quizReportV2ContentKey('vocabulary_reading', 'N4'): n4,
      },
    );
    expect(result.map((p) => p.jlptLevel).toSet(), {'N5', 'N4'});
  });
  test('keyset page merge rejects duplicates and order regressions', () {
    final source = _source(CurriculumKind.vocabulary);
    final question = buildVocabularyQuiz(source, PreviewLevel.n5).first;
    final correctAnswer = _answer(question.target, question.choices, true);
    final newer = _page([
      _receipt(
        51,
        'vocabulary_reading',
        'N5',
        null,
        '2026-11-17T10:00:02.000000Z',
        '2026-11-17T09:00:02Z',
        [correctAnswer],
      ),
    ]);
    final older = _page([
      _receipt(
        52,
        'vocabulary_reading',
        'N5',
        null,
        '2026-11-17T10:00:01.000000Z',
        '2026-11-17T09:00:01Z',
        [correctAnswer],
      ),
    ]);
    expect(
      mergeQuizReportV2HistoryPages([
        newer,
        older,
      ]).map((entry) => entry.request.clientEventId),
      [_event(51), _event(52)],
    );
    expect(
      () => mergeQuizReportV2HistoryPages([newer, newer]),
      throwsFormatException,
    );
    expect(
      () => mergeQuizReportV2HistoryPages([older, newer]),
      throwsFormatException,
    );
  });

  test('weak points reconcile the latest answer across separate pages', () {
    final source = _source(CurriculumKind.vocabulary);
    final question = buildVocabularyQuiz(source, PreviewLevel.n5).first;
    final pages = [
      _page([
        _receipt(
          61,
          'vocabulary_reading',
          'N5',
          null,
          '2026-11-17T10:00:02.000000Z',
          '2026-11-17T09:59:00Z',
          [_answer(question.target, question.choices, false)],
        ),
      ]),
      _page([
        _receipt(
          62,
          'vocabulary_reading',
          'N5',
          null,
          '2026-11-17T10:00:01.000000Z',
          '2026-11-17T10:00:00Z',
          [_answer(question.target, question.choices, true)],
        ),
      ]),
    ];
    final entries = mergeQuizReportV2HistoryPages(pages);
    expect(
      deriveQuizReportV2WeakPointsFromEntries(
        entries: entries,
        currentContent: {
          quizReportV2ContentKey('vocabulary_reading', 'N5'): source,
        },
      ),
      isEmpty,
    );
  });

  test('overview receipt aggregation is capped at one hundred items', () {
    final source = _source(CurriculumKind.vocabulary);
    final question = buildVocabularyQuiz(source, PreviewLevel.n5).first;
    final correctAnswer = _answer(question.target, question.choices, true);
    final receipts = [
      for (var index = 1; index <= 100; index++)
        _receipt(
          index,
          'vocabulary_reading',
          'N5',
          null,
          '2026-11-17T10:${(index ~/ 60).toString().padLeft(2, '0')}:${(index % 60).toString().padLeft(2, '0')}.000000Z',
          '2026-11-17T09:00:00Z',
          [correctAnswer],
        ),
    ];
    final firstPage = _page(receipts, limit: 100);
    final extraPage = _page([
      _receipt(
        101,
        'vocabulary_reading',
        'N5',
        null,
        '2026-11-17T09:59:59.000000Z',
        '2026-11-17T09:00:00Z',
        [correctAnswer],
      ),
    ], limit: 1);
    expect(
      () => mergeQuizReportV2HistoryPages([firstPage, extraPage]),
      throwsFormatException,
    );
  });
}
