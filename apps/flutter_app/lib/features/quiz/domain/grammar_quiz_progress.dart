import '../../../shared/models/preview_level.dart';
import '../../curriculum/domain/curriculum.dart';
import 'grammar_quiz.dart';
import 'grammar_quiz_attempt.dart';

final class GrammarQuizProgressConflict implements Exception {
  const GrammarQuizProgressConflict();
}

final class GrammarQuizItemProgress {
  const GrammarQuizItemProgress({
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

final class GrammarQuizProgress {
  GrammarQuizProgress._({
    required this.kind,
    required this.attemptCount,
    required this.answerCount,
    required this.correctCount,
    required this.eligibleCurrentItemCount,
    required List<GrammarQuizItemProgress> items,
    required List<GrammarQuizItemProgress> needsReview,
  }) : items = List.unmodifiable(items),
       needsReview = List.unmodifiable(needsReview);
  final GrammarQuizAttemptKind kind;
  final int attemptCount;
  final int answerCount;
  final int correctCount;

  /// Targets with a canonical question, not full JLPT curriculum coverage.
  final int eligibleCurrentItemCount;
  final List<GrammarQuizItemProgress> items;
  final List<GrammarQuizItemProgress> needsReview;
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

/// Pure projection of reports already read by an owner-bound repository.
/// Explicit kind prevents correction practice from changing primary evidence.
/// This function does not authenticate identity, confer mastery or study credit.
GrammarQuizProgress deriveGrammarQuizProgress({
  required String ownerId,
  required PreviewLevel level,
  required GrammarQuizAttemptKind kind,
  required List<CurriculumEntry> source,
  required List<OwnedGrammarQuizAttempt> history,
}) {
  grammarHistoryUuid(ownerId);
  if (history.length > 10000 ||
      history.any((record) => record.ownerId != ownerId)) {
    throw const FormatException('Invalid owner quiz history');
  }
  final unique = <String, GrammarQuizAttempt>{};
  for (final record in history) {
    final event = record.attempt;
    final existing = unique[event.eventId];
    if (existing != null && !sameGrammarQuizAttempt(existing, event)) {
      throw const GrammarQuizProgressConflict();
    }
    unique[event.eventId] = event;
  }
  final events = unique.values
      .where((event) => event.level == level && event.kind == kind)
      .toList();
  events.sort((a, b) {
    final time = a.completedAt.compareTo(b.completedAt);
    return time == 0 ? a.eventId.compareTo(b.eventId) : time;
  });
  final questions = buildGrammarQuiz(source, level);
  final current = {for (final q in questions) q.target.id: q};
  final progress = <String, GrammarQuizItemProgress>{};
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
      progress[answer.itemId] = GrammarQuizItemProgress(
        entry: question.target,
        answerCount: (previous?.answerCount ?? 0) + 1,
        incorrectCount:
            (previous?.incorrectCount ?? 0) + (answer.isCorrect ? 0 : 1),
        lastAnswerCorrect: answer.isCorrect,
        lastCompletedAt: event.completedAt,
      );
    }
  }
  final items = <GrammarQuizItemProgress>[];
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
  return GrammarQuizProgress._(
    kind: kind,
    attemptCount: events.length,
    answerCount: answerCount,
    correctCount: correctCount,
    eligibleCurrentItemCount: questions.length,
    items: items,
    needsReview: needsReview,
  );
}
