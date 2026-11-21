import 'vocabulary_quiz.dart';
import 'vocabulary_quiz_progress.dart';

/// Focus on current-source review targets in the existing deterministic priority.
/// The full deck supplies canonical choices; filtering must never rebuild them
/// from the smaller set of incorrect items or substitute another source/version.
List<QuizQuestion> selectVocabularyReviewQuestions(
  List<QuizQuestion> deck,
  VocabularyQuizProgress progress,
) {
  if (deck.length > 5000) {
    throw const FormatException('Invalid review deck');
  }
  final current = <String, QuizQuestion>{};
  for (final question in deck) {
    if (current.containsKey(question.id)) {
      throw const FormatException('Invalid review deck');
    }
    current[question.id] = question;
  }
  final selected = <QuizQuestion>[];
  for (final item in progress.needsReview) {
    final key =
        '${item.entry.level.name}/${item.entry.id}/${item.entry.contentVersion}';
    final question = current[key];
    if (question != null && identical(question.target, item.entry)) {
      selected.add(question);
    }
  }
  return List.unmodifiable(selected);
}
