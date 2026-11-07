import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/vocabulary_quiz.dart';
import '../domain/vocabulary_quiz_attempt.dart';

typedef QuizAttemptFactory = VocabularyQuizAttempt Function(QuizRound);

final quizAttemptFactoryProvider = Provider<QuizAttemptFactory>(
  (ref) => captureQuizAttempt,
);

/// One identity per completed round; retries reuse the captured value.
VocabularyQuizAttempt captureQuizAttempt(QuizRound round) {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final id = [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20),
  ].join('-');
  return VocabularyQuizAttempt.capture(
    eventId: id,
    completedAt: DateTime.now().toUtc(),
    round: round,
  );
}
