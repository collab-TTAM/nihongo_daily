import '../domain/vocabulary_quiz_attempt.dart';

/// Local isolation keys are not authentication. A ready-session repository
/// must capture the owner and fence every await before exposing this port.
abstract interface class VocabularyQuizAttemptStore {
  Future<List<OwnedVocabularyQuizAttempt>> list(String ownerId);
  Future<OwnedVocabularyQuizAttempt> append(
    String ownerId,
    VocabularyQuizAttempt attempt,
  );
}

final class VocabularyQuizStorageFailure implements Exception {
  const VocabularyQuizStorageFailure();

  @override
  String toString() => 'Không thể đọc hoặc lưu lịch sử quiz.';
}
