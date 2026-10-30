import 'grammar_quiz.dart';
import 'grammar_quiz_progress.dart';
import 'grammar_quiz_attempt.dart';

/// Select primary-round review targets only, in the existing error priority.
/// Focused practice must be captured separately as correction; a correction
/// projection cannot become a primary-round recommendation source.
/// The full deck supplies canonical choices; filtering must never rebuild them
/// from the smaller set of incorrect items or substitute another source/version.
List<GrammarQuizQuestion> selectGrammarReviewQuestions(
  List<GrammarQuizQuestion> deck,
  GrammarQuizProgress progress,
) {
  if (progress.kind != GrammarQuizAttemptKind.primary || deck.length > 5000) {
    throw const FormatException('Invalid review deck');
  }
  final current = <String, GrammarQuizQuestion>{};
  for (final question in deck) {
    if (current.containsKey(question.id)) {
      throw const FormatException('Invalid review deck');
    }
    current[question.id] = question;
  }
  final selected = <GrammarQuizQuestion>[];
  for (final item in progress.needsReview) {
    final key =
        'grammar/${item.entry.level.name}/${item.entry.id}/${item.entry.contentVersion}';
    final question = current[key];
    if (question != null && identical(question.target, item.entry)) {
      selected.add(question);
    }
  }
  return List.unmodifiable(selected);
}
