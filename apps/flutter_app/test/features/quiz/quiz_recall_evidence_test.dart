// Synthetic local reports only; not trusted time or learner mastery proof.
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/domain/quiz_recall_evidence.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_progress.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import 'vocabulary_review_quiz_test.dart' show owner, entry, report;

void main() {
  final start = DateTime.utc(2026, 10, 1);
  test('recall counts three spaced correct reports with exact gap and cap', () {
    var evidence = const QuizRecallEvidence.empty();
    expect(QuizRecallEvidence.ruleVersion, 'nd-quiz-recall-1');
    expect(evidence.milestoneReached, isFalse);
    evidence = evidence.observe(correct: true, completedAt: start);
    final first = evidence;
    evidence = evidence.observe(correct: true, completedAt: start);
    evidence = evidence.observe(
      correct: true,
      completedAt: start.add(
        const Duration(hours: 24) - const Duration(microseconds: 1),
      ),
    );
    expect(evidence.countedCorrect, 1);
    expect(evidence.lastCountedAt, start);
    evidence = evidence.observe(
      correct: true,
      completedAt: start.add(const Duration(hours: 24)),
    );
    expect(evidence.countedCorrect, 2);
    evidence = evidence.observe(
      correct: true,
      completedAt: start.add(const Duration(hours: 48)),
    );
    expect(evidence.milestoneReached, isTrue);
    evidence = evidence.observe(
      correct: true,
      completedAt: start.add(const Duration(hours: 72)),
    );
    expect(evidence.countedCorrect, 3);
    expect(first.countedCorrect, 1); // Earlier snapshots remain immutable.
  });
  test(
    'wrong at any gap resets evidence including reached and tied instant',
    () {
      var evidence = const QuizRecallEvidence.empty();
      for (var day = 0; day < 3; day++) {
        evidence = evidence.observe(
          correct: true,
          completedAt: start.add(Duration(days: day)),
        );
      }
      evidence = evidence.observe(
        correct: false,
        completedAt: start.add(const Duration(days: 2)),
      );
      expect(evidence.countedCorrect, 0);
      expect(evidence.lastCountedAt, isNull);
      expect(evidence.milestoneReached, isFalse);
      evidence = evidence.observe(
        correct: true,
        completedAt: start.add(const Duration(days: 2)),
      );
      expect(evidence.countedCorrect, 1);
      evidence = evidence.observe(
        correct: false,
        completedAt: start.add(const Duration(days: 2, seconds: 1)),
      );
      expect(evidence.countedCorrect, 0);
    },
  );
  test(
    'recall rejects backwards and non UTC observations without mutation',
    () {
      final evidence = const QuizRecallEvidence.empty().observe(
        correct: true,
        completedAt: start,
      );
      for (final time in [
        start.subtract(const Duration(microseconds: 1)),
        DateTime(2026, 10, 1),
      ]) {
        expect(
          () => evidence.observe(correct: false, completedAt: time),
          throwsFormatException,
        );
      }
      expect(evidence.countedCorrect, 1);
      expect(evidence.lastObservedAt, start);
    },
  );
  for (final level in PreviewLevel.values) {
    test(
      '${level.name} recall projection retains owner dedup current identity and level fences',
      () {
        final source = [for (var i = 1; i <= 4; i++) entry(i, level)];
        final question = buildVocabularyQuiz(source, level).first;
        VocabularyQuizAttempt event(int id, int day, {bool correct = true}) {
          final json = report([question], id, correct: correct).toJson();
          json['completed_at'] = start
              .add(Duration(days: day))
              .toIso8601String();
          return VocabularyQuizAttempt.fromJson(json);
        }

        final a = event(1, 0), b = event(2, 1), c = event(3, 2);
        VocabularyQuizProgress derive(
          List<VocabularyQuizAttempt> events, {
          bool changed = false,
          PreviewLevel? selected,
        }) => deriveVocabularyQuizProgress(
          ownerId: owner,
          level: selected ?? level,
          source: selected != null
              ? [for (var i = 1; i <= 4; i++) entry(i, selected)]
              : changed
              ? [for (var i = 1; i <= 4; i++) entry(i, level, version: 2)]
              : source,
          history: [
            for (final e in events) OwnedVocabularyQuizAttempt(owner, e),
          ],
        );
        final p = derive([c, a, b, a, c]);
        expect(p.attemptCount, 3);
        expect(p.answerCount, 3);
        expect(p.practicedCurrentItemCount, 1);
        expect(p.recallMilestoneCurrentItemCount, 1);
        expect(p.items.single.recallEvidence.countedCorrect, 3);
        expect(p.needsReview, isEmpty);
        expect(derive([a, a, b]).recallMilestoneCurrentItemCount, 0);
        final wrong = derive([a, b, c, event(4, 2, correct: false)]);
        expect(wrong.recallMilestoneCurrentItemCount, 0);
        expect(wrong.needsReview, hasLength(1));
        expect(
          derive([a, b, c], changed: true).recallMilestoneCurrentItemCount,
          0,
        );
        final other = level == PreviewLevel.n5
            ? PreviewLevel.n4
            : PreviewLevel.n5;
        expect(
          derive([a, b, c], selected: other).recallMilestoneCurrentItemCount,
          0,
        );
        expect(
          () => deriveVocabularyQuizProgress(
            ownerId: owner,
            level: level,
            source: source,
            history: [
              OwnedVocabularyQuizAttempt(
                'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
                a,
              ),
            ],
          ),
          throwsFormatException,
        );
        final changed = a.toJson();
        changed['completed_at'] = start
            .add(const Duration(days: 8))
            .toIso8601String();
        expect(
          () => derive([a, VocabularyQuizAttempt.fromJson(changed)]),
          throwsA(isA<VocabularyQuizHistoryConflict>()),
        );
      },
    );
  }
}
