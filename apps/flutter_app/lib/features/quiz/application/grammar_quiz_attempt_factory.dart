import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/grammar_quiz.dart';
import '../domain/grammar_quiz_attempt.dart';

typedef GrammarQuizAttemptFactory =
    GrammarQuizAttempt Function(
      GrammarQuizRound round,
      GrammarQuizAttemptKind kind,
    );

final grammarQuizAttemptFactoryProvider = Provider<GrammarQuizAttemptFactory>(
  (ref) => captureGrammarQuizAttempt,
);

/// One identity per completed round; retries reuse the captured value.
GrammarQuizAttempt captureGrammarQuizAttempt(
  GrammarQuizRound round,
  GrammarQuizAttemptKind kind,
) {
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
  return GrammarQuizAttempt.capture(
    eventId: id,
    completedAt: DateTime.now().toUtc(),
    round: round,
    kind: kind,
  );
}
