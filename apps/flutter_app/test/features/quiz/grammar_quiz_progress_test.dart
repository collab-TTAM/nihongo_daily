// Synthetic client reports only; no hosted identity, mastery or study credit.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_progress.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import 'grammar_quiz_test.dart' show sample;

const owner = 'a1000000-0000-4000-8000-000000000001';
const other = 'a1000000-0000-4000-8000-000000000002';
String id(int n) => 'a2000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
List<CurriculumEntry> source({
  PreviewLevel level = PreviewLevel.n5,
  int version = 1,
}) => [
  for (var i = 0; i < 4; i++)
    sample(i, id: id(i), level: level, version: version),
];
GrammarQuizAttempt report({
  int event = 1,
  int minute = 1,
  bool correct = false,
  PreviewLevel level = PreviewLevel.n5,
  GrammarQuizAttemptKind kind = GrammarQuizAttemptKind.primary,
  List<GrammarQuizQuestion>? questions,
}) {
  final round = GrammarQuizRound(
    questions ?? buildGrammarQuiz(source(level: level), level),
  );
  for (final q in round.questions) {
    expect(
      round.answer(
        q.id,
        correct
            ? q.target.id
            : q.choices.firstWhere((c) => c.id != q.target.id).id,
      ),
      isTrue,
    );
    expect(round.advance(q.id), isTrue);
  }
  return GrammarQuizAttempt.capture(
    eventId: id(100 + event),
    completedAt: DateTime.utc(2026, 10, 30, 0, minute),
    round: round,
    kind: kind,
  );
}

GrammarQuizAttempt variant(
  GrammarQuizAttempt event,
  void Function(Map<String, Object?>) edit,
) {
  final json = jsonDecode(jsonEncode(event.toJson())) as Map<String, Object?>;
  edit(json);
  return GrammarQuizAttempt.fromJson(json);
}

GrammarQuizProgress derive(
  List<GrammarQuizAttempt> events, {
  GrammarQuizAttemptKind kind = GrammarQuizAttemptKind.primary,
  PreviewLevel level = PreviewLevel.n5,
  List<CurriculumEntry>? content,
}) => deriveGrammarQuizProgress(
  ownerId: owner,
  level: level,
  kind: kind,
  source: content ?? source(level: level),
  history: [for (final e in events) OwnedGrammarQuizAttempt(owner, e)],
);

void main() {
  test('empty grammar history has no invented progress', () {
    final p = derive([]);
    expect(p.attemptCount, 0);
    expect(p.answerCount, 0);
    expect(p.correctCount, 0);
    expect(p.items, isEmpty);
    expect(p.needsReview, isEmpty);
    expect(p.kind, GrammarQuizAttemptKind.primary);
  });
  test('unique reports count first answers and original current entries', () {
    final content = source();
    final p = derive([report()], content: content);
    expect(p.attemptCount, 1);
    expect(p.answerCount, 4);
    expect(p.correctCount, 0);
    expect(p.practicedCurrentItemCount, 4);
    expect(p.needsReview, hasLength(4));
    expect(p.items.first.entry, same(content.first));
    expect(
      p.items.every((i) => i.answerCount == 1 && i.incorrectCount == 1),
      isTrue,
    );
  });
  test('exact replay cannot inflate grammar counters', () {
    final a = report();
    final copy = GrammarQuizAttempt.fromJson(
      jsonDecode(jsonEncode(a.toJson())),
    );
    final p = derive([a, a, copy]);
    expect(p.attemptCount, 1);
    expect(p.answerCount, 4);
    expect(p.items.first.incorrectCount, 1);
  });
  test('conflicting event fails before kind and level selection', () {
    final a = report();
    for (final b in [
      report(correct: true),
      report(kind: GrammarQuizAttemptKind.correction),
      report(level: PreviewLevel.n4),
      report(minute: 2),
    ]) {
      expect(
        () => derive(
          [a, b],
          kind: GrammarQuizAttemptKind.correction,
          level: PreviewLevel.n4,
        ),
        throwsA(isA<GrammarQuizProgressConflict>()),
      );
    }
  });
  test('foreign owner fails before excluded kind or level can hide it', () {
    expect(
      () => deriveGrammarQuizProgress(
        ownerId: owner,
        level: PreviewLevel.n5,
        kind: GrammarQuizAttemptKind.primary,
        source: source(),
        history: [
          OwnedGrammarQuizAttempt(
            other,
            report(
              level: PreviewLevel.n4,
              kind: GrammarQuizAttemptKind.correction,
            ),
          ),
        ],
      ),
      throwsFormatException,
    );
    expect(
      () => deriveGrammarQuizProgress(
        ownerId: 'learner-input',
        level: PreviewLevel.n5,
        kind: GrammarQuizAttemptKind.primary,
        source: source(),
        history: [],
      ),
      throwsFormatException,
    );
  });
  test('correction success never changes primary scores or weak points', () {
    final events = [
      report(),
      report(
        event: 2,
        minute: 2,
        correct: true,
        kind: GrammarQuizAttemptKind.correction,
      ),
    ];
    final primary = derive(events);
    final correction = derive(events, kind: GrammarQuizAttemptKind.correction);
    expect(primary.attemptCount, 1);
    expect(primary.correctCount, 0);
    expect(primary.needsReview, hasLength(4));
    expect(correction.kind, GrammarQuizAttemptKind.correction);
    expect(correction.attemptCount, 1);
    expect(correction.correctCount, 4);
    expect(correction.needsReview, isEmpty);
  });
  test('selected level totals remain separate', () {
    final events = [
      report(),
      report(event: 2, correct: true, level: PreviewLevel.n4),
    ];
    expect(derive(events).correctCount, 0);
    expect(derive(events).answerCount, 4);
    expect(derive(events, level: PreviewLevel.n4).correctCount, 4);
  });
  test('repeated wrong then correct clears only current needs review', () {
    final p = derive([
      report(event: 3, minute: 3, correct: true),
      report(event: 2, minute: 2),
      report(),
    ]);
    expect(p.attemptCount, 3);
    expect(p.answerCount, 12);
    expect(p.correctCount, 4);
    expect(p.needsReview, isEmpty);
    expect(p.items.first.incorrectCount, 2);
    expect(p.items.first.lastAnswerCorrect, isTrue);
  });
  test('later wrong restores review and retains earlier counts', () {
    final p = derive([report(correct: true), report(event: 2, minute: 2)]);
    expect(p.needsReview, hasLength(4));
    expect(p.items.first.answerCount, 2);
    expect(p.items.first.incorrectCount, 1);
    expect(p.items.first.lastAnswerCorrect, isFalse);
  });
  test(
    'equal timestamp latest event ID is deterministic regardless input order',
    () {
      final a = report();
      final b = report(event: 2, correct: true);
      for (final events in [
        [a, b],
        [b, a],
      ]) {
        final p = derive(events);
        expect(p.needsReview, isEmpty);
        expect(p.correctCount, 4);
        expect(p.items.first.answerCount, 2);
      }
    },
  );
  test(
    'stale version stays historical and cannot recommend current source',
    () {
      final p = derive([report()], content: source(version: 2));
      expect(p.answerCount, 4);
      expect(p.attemptCount, 1);
      expect(p.items, isEmpty);
      expect(p.needsReview, isEmpty);
    },
  );
  test('unknown source retains only historical totals', () {
    final p = derive([report()], content: []);
    expect(p.answerCount, 4);
    expect(p.practicedCurrentItemCount, 0);
    expect(p.needsReview, isEmpty);
  });
  test('changed ordered choices cannot create a current recommendation', () {
    final changed = variant(report(), (json) {
      for (final raw in json['answers'] as List) {
        final row = raw as Map<String, Object?>;
        row['choices'] = (row['choices'] as List).reversed.toList();
      }
    });
    final p = derive([changed]);
    expect(p.answerCount, 4);
    expect(p.items, isEmpty);
  });
  test('review rank uses repeated errors then recency then original ID', () {
    final q = buildGrammarQuiz(source(), PreviewLevel.n5);
    final p = derive([
      report(questions: [q[2]], event: 1),
      report(questions: [q[2]], event: 2, minute: 2),
      report(questions: [q[1]], event: 3, minute: 3),
      report(questions: [q[0]], event: 4, minute: 3),
    ]);
    expect(p.needsReview.map((i) => i.entry.id), [id(2), id(0), id(1)]);
    expect(p.items.map((i) => i.entry.id), [id(0), id(1), id(2)]);
  });
  test('invalid current content rejects even with empty history', () {
    for (final invalid in [
      [...source(), source().first],
      source(level: PreviewLevel.n4),
      [sample(0, kind: CurriculumKind.vocabulary)],
    ]) {
      expect(() => derive([], content: invalid), throwsFormatException);
    }
  });
  test('history bound applies before deduplication', () {
    final event = report();
    expect(derive(List.filled(10000, event)).attemptCount, 1);
    expect(() => derive(List.filled(10001, event)), throwsFormatException);
  });
  test('results are immutable and independent of caller list mutation', () {
    final events = [report()];
    final content = source();
    final p = derive(events, content: content);
    events.clear();
    content.clear();
    expect(p.answerCount, 4);
    expect(p.items, hasLength(4));
    expect(() => p.items.clear(), throwsUnsupportedError);
    expect(() => p.needsReview.clear(), throwsUnsupportedError);
  });
  // Current-deck coverage buckets are practice evidence, never mastery.
  test('grammar coverage counts eligible targets with no matching reports', () {
    final p = derive([]);
    expect(p.eligibleCurrentItemCount, 4);
    expect(p.unpracticedCurrentItemCount, 4);
    expect(p.latestCorrectCurrentItemCount, 0);
    for (final content in [<CurriculumEntry>[], source().take(3).toList()]) {
      final empty = derive([], content: content);
      expect(empty.eligibleCurrentItemCount, 0);
      expect(empty.unpracticedCurrentItemCount, 0);
      expect(empty.latestCorrectCurrentItemCount, 0);
    }
  });

  test(
    'grammar coverage buckets partition distinct matched targets after replay',
    () {
      final q = buildGrammarQuiz(source(), PreviewLevel.n5);
      final a = report(questions: [q[0]], correct: true);
      final b = report(questions: [q[1]], event: 2, minute: 2);
      final p = derive([a, b, a]);
      expect(p.eligibleCurrentItemCount, 4);
      expect(p.practicedCurrentItemCount, 2);
      expect(p.unpracticedCurrentItemCount, 2);
      expect(p.latestCorrectCurrentItemCount, 1);
      expect(p.needsReview, hasLength(1));
      expect(p.answerCount, 2);
      expect(
        p.unpracticedCurrentItemCount +
            p.latestCorrectCurrentItemCount +
            p.needsReview.length,
        p.eligibleCurrentItemCount,
      );
      final corrected = derive([
        a,
        b,
        report(questions: [q[1]], event: 3, minute: 3, correct: true),
      ]);
      expect(corrected.unpracticedCurrentItemCount, 2);
      expect(corrected.latestCorrectCurrentItemCount, 2);
      expect(corrected.needsReview, isEmpty);
      final wrongAgain = derive([
        a,
        b,
        report(questions: [q[0]], event: 4, minute: 4),
      ]);
      expect(wrongAgain.latestCorrectCurrentItemCount, 0);
      expect(wrongAgain.unpracticedCurrentItemCount, 2);
      expect(wrongAgain.needsReview, hasLength(2));
    },
  );

  test(
    'grammar coverage excludes obsolete version and ordered-choice evidence',
    () {
      final stale = derive([
        report(correct: true),
      ], content: source(version: 2));
      final changed = derive([
        variant(report(correct: true), (json) {
          for (final raw in json['answers'] as List) {
            final row = raw as Map<String, Object?>;
            row['choices'] = (row['choices'] as List).reversed.toList();
          }
        }),
      ]);
      for (final p in [stale, changed]) {
        expect(p.eligibleCurrentItemCount, 4);
        expect(p.unpracticedCurrentItemCount, 4);
        expect(p.latestCorrectCurrentItemCount, 0);
        expect(p.practicedCurrentItemCount, 0);
        expect(p.correctCount, 4); // Historical score remains independent.
      }
    },
  );

  test(
    'grammar coverage keeps primary correction and level evidence separate',
    () {
      final events = [
        report(correct: true, kind: GrammarQuizAttemptKind.correction),
        report(event: 2, level: PreviewLevel.n4, correct: true),
      ];
      final primary = derive(events);
      expect(primary.unpracticedCurrentItemCount, 4);
      expect(primary.latestCorrectCurrentItemCount, 0);
      final correction = derive(
        events,
        kind: GrammarQuizAttemptKind.correction,
      );
      expect(correction.unpracticedCurrentItemCount, 0);
      expect(correction.latestCorrectCurrentItemCount, 4);
      expect(
        primary.eligibleCurrentItemCount,
        correction.eligibleCurrentItemCount,
      );
    },
  );
  // End current-deck coverage regressions.
}
