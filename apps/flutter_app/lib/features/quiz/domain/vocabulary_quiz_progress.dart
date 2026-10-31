import '../../../shared/models/preview_level.dart';
import '../../curriculum/domain/curriculum.dart';
import 'vocabulary_quiz.dart';
import 'vocabulary_quiz_attempt.dart';

final class VocabularyQuizHistoryConflict implements Exception {
  const VocabularyQuizHistoryConflict();
}

final class VocabularyQuizItemProgress {
  const VocabularyQuizItemProgress({
    required this.entry,
    required this.answerCount,
    required this.incorrectCount,
    required this.lastAnswerCorrect,
    required this.lastCompletedAt,
  });
  final CurriculumEntry entry;
  final int answerCount;
  final int incorrectCount;
  final bool lastAnswerCorrect;
  final DateTime lastCompletedAt;
}

final class VocabularyQuizProgress {
  VocabularyQuizProgress._({
    required this.attemptCount,
    required this.answerCount,
    required this.correctCount,
    required this.eligibleCurrentItemCount,
    required List<VocabularyQuizItemProgress> items,
    required List<VocabularyQuizItemProgress> needsReview,
  }) : items = List.unmodifiable(items),
       needsReview = List.unmodifiable(needsReview);
  final int attemptCount;
  final int answerCount;
  final int correctCount;

  /// Canonical question targets, not full JLPT curriculum coverage.
  final int eligibleCurrentItemCount;
  final List<VocabularyQuizItemProgress> items;
  final List<VocabularyQuizItemProgress> needsReview;
  int get practicedCurrentItemCount => items.length;
  int get unpracticedCurrentItemCount =>
      eligibleCurrentItemCount - practicedCurrentItemCount;
  int get latestCorrectCurrentItemCount =>
      practicedCurrentItemCount - needsReview.length;
}

bool _sameChoices(List<String> left, List<CurriculumEntry> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i].id) return false;
  }
  return true;
}

/// Owner-bound client reports only; no mastery or study credit.
VocabularyQuizProgress deriveVocabularyQuizProgress({
  required String ownerId,
  required PreviewLevel level,
  required List<CurriculumEntry> source,
  required List<OwnedVocabularyQuizAttempt> history,
}) {
  quizHistoryUuid(ownerId);
  if (history.length > 10000 ||
      history.any((record) => record.ownerId != ownerId)) {
    throw const FormatException('Invalid owner quiz history');
  }
  final unique = <String, VocabularyQuizAttempt>{};
  for (final record in history) {
    final event = record.attempt;
    final existing = unique[event.eventId];
    if (existing != null && !sameVocabularyQuizAttempt(existing, event)) {
      throw const VocabularyQuizHistoryConflict();
    }
    unique[event.eventId] = event;
  }
  final events = unique.values.where((event) => event.level == level).toList();
  events.sort((a, b) {
    final time = a.completedAt.compareTo(b.completedAt);
    return time == 0 ? a.eventId.compareTo(b.eventId) : time;
  });
  final questions = buildVocabularyQuiz(source, level);
  final current = {for (final q in questions) q.target.id: q};
  final progress = <String, VocabularyQuizItemProgress>{};
  var answerCount = 0;
  var correctCount = 0;
  for (final event in events) {
    for (final answer in event.answers) {
      answerCount++;
      if (answer.isCorrect) correctCount++;
      final question = current[answer.itemId];
      if (question == null ||
          question.target.contentVersion != answer.contentVersion ||
          !_sameChoices(answer.choices, question.choices)) {
        continue;
      }
      final previous = progress[answer.itemId];
      progress[answer.itemId] = VocabularyQuizItemProgress(
        entry: question.target,
        answerCount: (previous?.answerCount ?? 0) + 1,
        incorrectCount:
            (previous?.incorrectCount ?? 0) + (answer.isCorrect ? 0 : 1),
        lastAnswerCorrect: answer.isCorrect,
        lastCompletedAt: event.completedAt,
      );
    }
  }
  final items = <VocabularyQuizItemProgress>[];
  for (final question in questions) {
    final item = progress[question.target.id];
    if (item != null) items.add(item);
  }
  final needsReview = items.where((item) => !item.lastAnswerCorrect).toList();
  needsReview.sort((a, b) {
    final errors = b.incorrectCount.compareTo(a.incorrectCount);
    if (errors != 0) return errors;
    final time = b.lastCompletedAt.compareTo(a.lastCompletedAt);
    return time == 0 ? a.entry.id.compareTo(b.entry.id) : time;
  });
  return VocabularyQuizProgress._(
    attemptCount: events.length,
    answerCount: answerCount,
    correctCount: correctCount,
    eligibleCurrentItemCount: questions.length,
    items: items,
    needsReview: needsReview,
  );
}
