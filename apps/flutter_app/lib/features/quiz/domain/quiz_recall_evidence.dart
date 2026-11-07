/// Transparent local-report milestone, not certified mastery or SRS state.
/// Callers must first enforce owner, event deduplication and current content.
final class QuizRecallEvidence {
  const QuizRecallEvidence.empty()
    : countedCorrect = 0,
      lastCountedAt = null,
      lastObservedAt = null;

  const QuizRecallEvidence._(
    this.countedCorrect,
    this.lastCountedAt,
    this.lastObservedAt,
  );

  static const ruleVersion = 'nd-quiz-recall-1';
  static const requiredCorrect = 3;
  static const minimumGap = Duration(hours: 24);
  final int countedCorrect;
  final DateTime? lastCountedAt;
  final DateTime? lastObservedAt;
  bool get milestoneReached => countedCorrect == requiredCorrect;

  QuizRecallEvidence observe({
    required bool correct,
    required DateTime completedAt,
  }) {
    final previous = lastObservedAt;
    if (!completedAt.isUtc ||
        (previous != null && completedAt.isBefore(previous))) {
      throw const FormatException('Invalid quiz recall observation time');
    }
    if (!correct) return QuizRecallEvidence._(0, null, completedAt);
    final countedAt = lastCountedAt;
    if (countedAt != null && completedAt.difference(countedAt) < minimumGap) {
      return QuizRecallEvidence._(countedCorrect, countedAt, completedAt);
    }
    return QuizRecallEvidence._(
      countedCorrect < requiredCorrect ? countedCorrect + 1 : requiredCorrect,
      completedAt,
      completedAt,
    );
  }
}
