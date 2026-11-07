import '../domain/grammar_quiz_attempt.dart';

/// Local isolation keys are not authentication. A ready-session repository
/// must capture the owner and fence every await before exposing this port.
abstract interface class GrammarQuizAttemptStore {
  Future<List<OwnedGrammarQuizAttempt>> list(String ownerId);
  Future<OwnedGrammarQuizAttempt> append(
    String ownerId,
    GrammarQuizAttempt attempt,
  );
}

final class GrammarQuizStorageFailure implements Exception {
  const GrammarQuizStorageFailure();

  @override
  String toString() => 'Không thể đọc hoặc lưu lịch sử quiz ngữ pháp.';
}

final class GrammarQuizHistoryConflict implements Exception {
  const GrammarQuizHistoryConflict();

  @override
  String toString() => 'Kết quả quiz ngữ pháp không khớp bản đã lưu.';
}
