// Synthetic question coverage, not language coverage, mastery or hosted proof.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_progress.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import 'vocabulary_review_quiz_test.dart' show owner, entry, report;

List<CurriculumEntry> source(
  PreviewLevel level, {
  int count = 4,
  int version = 1,
}) => [for (var i = 1; i <= count; i++) entry(i, level, version: version)];
VocabularyQuizProgress derive(
  List<CurriculumEntry> content,
  List<VocabularyQuizAttempt> events, {
  PreviewLevel level = PreviewLevel.n5,
}) => deriveVocabularyQuizProgress(
  ownerId: owner,
  level: level,
  source: content,
  history: [for (final e in events) OwnedVocabularyQuizAttempt(owner, e)],
);

void main() {
  test(
    'vocabulary coverage uses full eligible deck beyond a ten question batch',
    () {
      for (final level in PreviewLevel.values) {
        final p = derive(source(level, count: 12), [], level: level);
        expect(p.eligibleCurrentItemCount, 12);
        expect(p.unpracticedCurrentItemCount, 12);
        expect(p.latestCorrectCurrentItemCount, 0);
        for (final content in [<CurriculumEntry>[], source(level, count: 3)]) {
          final empty = derive(content, [], level: level);
          expect(empty.eligibleCurrentItemCount, 0);
          expect(empty.unpracticedCurrentItemCount, 0);
          expect(empty.latestCorrectCurrentItemCount, 0);
        }
      }
    },
  );
  test(
    'vocabulary coverage partitions distinct targets after replay and transitions',
    () {
      final content = source(PreviewLevel.n5);
      final q = buildVocabularyQuiz(content, PreviewLevel.n5);
      final a = report([q[0]], 1, correct: true);
      final b = report([q[1]], 2);
      final p = derive(content, [a, b, a]);
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
      final corrected = derive(content, [
        a,
        b,
        report([q[1]], 3, correct: true),
      ]);
      expect(corrected.latestCorrectCurrentItemCount, 2);
      expect(corrected.unpracticedCurrentItemCount, 2);
      expect(corrected.needsReview, isEmpty);
      final wrong = derive(content, [
        a,
        b,
        report([q[0]], 4),
      ]);
      expect(wrong.latestCorrectCurrentItemCount, 0);
      expect(wrong.unpracticedCurrentItemCount, 2);
      expect(wrong.needsReview, hasLength(2));
    },
  );
  test(
    'vocabulary coverage leaves obsolete version or choices historical only',
    () {
      final content = source(PreviewLevel.n5);
      final event = report(
        buildVocabularyQuiz(content, PreviewLevel.n5),
        1,
        correct: true,
      );
      final json =
          jsonDecode(jsonEncode(event.toJson())) as Map<String, Object?>;
      for (final raw in json['answers'] as List) {
        final row = raw as Map<String, Object?>;
        row['choices'] = (row['choices'] as List).reversed.toList();
      }
      for (final p in [
        derive(source(PreviewLevel.n5, version: 2), [event]),
        derive(content, [VocabularyQuizAttempt.fromJson(json)]),
      ]) {
        expect(p.eligibleCurrentItemCount, 4);
        expect(p.unpracticedCurrentItemCount, 4);
        expect(p.latestCorrectCurrentItemCount, 0);
        expect(p.practicedCurrentItemCount, 0);
        expect(p.correctCount, 4);
      }
    },
  );
  test('vocabulary coverage never consumes another level reports', () {
    final n4 = source(PreviewLevel.n4);
    final event = report(
      buildVocabularyQuiz(n4, PreviewLevel.n4),
      1,
      correct: true,
    );
    final n5 = derive(source(PreviewLevel.n5), [event]);
    expect(n5.unpracticedCurrentItemCount, 4);
    expect(n5.latestCorrectCurrentItemCount, 0);
    expect(n5.answerCount, 0);
    final p4 = derive(n4, [event], level: PreviewLevel.n4);
    expect(p4.unpracticedCurrentItemCount, 0);
    expect(p4.latestCorrectCurrentItemCount, 4);
  });
}
