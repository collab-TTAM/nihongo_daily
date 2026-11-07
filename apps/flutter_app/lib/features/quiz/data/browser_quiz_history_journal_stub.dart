import '../domain/grammar_quiz_attempt.dart';
import '../domain/vocabulary_quiz_attempt.dart';
import 'grammar_quiz_attempt_store.dart';
import 'vocabulary_quiz_attempt_store.dart';

final class BrowserVocabularyQuizJournal implements VocabularyQuizAttemptStore {
  @override
  Future<List<OwnedVocabularyQuizAttempt>> list(String ownerId) =>
      Future<List<OwnedVocabularyQuizAttempt>>.error(
        const VocabularyQuizStorageFailure(),
      );

  @override
  Future<OwnedVocabularyQuizAttempt> append(
    String ownerId,
    VocabularyQuizAttempt attempt,
  ) => Future<OwnedVocabularyQuizAttempt>.error(
    const VocabularyQuizStorageFailure(),
  );

  Future<void> close() async {}
}

final class BrowserGrammarQuizJournal implements GrammarQuizAttemptStore {
  @override
  Future<List<OwnedGrammarQuizAttempt>> list(String ownerId) =>
      Future<List<OwnedGrammarQuizAttempt>>.error(
        const GrammarQuizStorageFailure(),
      );

  @override
  Future<OwnedGrammarQuizAttempt> append(
    String ownerId,
    GrammarQuizAttempt attempt,
  ) => Future<OwnedGrammarQuizAttempt>.error(const GrammarQuizStorageFailure());

  Future<void> close() async {}
}

Future<BrowserVocabularyQuizJournal> openBrowserVocabularyQuizJournal({
  String databaseName = 'nd-vocabulary-quiz-history-v1',
}) => Future<BrowserVocabularyQuizJournal>.error(
  const VocabularyQuizStorageFailure(),
);

Future<BrowserGrammarQuizJournal> openBrowserGrammarQuizJournal({
  String databaseName = 'nd-grammar-quiz-history-v1',
}) =>
    Future<BrowserGrammarQuizJournal>.error(const GrammarQuizStorageFailure());
