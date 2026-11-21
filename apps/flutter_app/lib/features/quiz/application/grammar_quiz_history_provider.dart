import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/account_controller.dart';
import '../../auth/application/account_provider.dart';
import '../data/grammar_quiz_history_repository.dart';

/// Only configured owned startup supplies this borrowed capability.
final grammarQuizHistorySourceProvider = Provider<GrammarQuizHistorySource?>(
  (ref) => null,
);

final grammarQuizHistoryRepositoryProvider =
    Provider<GrammarQuizHistoryRepository?>((ref) {
      final account = ref.watch(accountStateProvider);
      final runtime = ref.watch(accountRuntimeProvider);
      final source = ref.watch(grammarQuizHistorySourceProvider);
      if (account.phase != AccountPhase.ready ||
          account.profile == null ||
          runtime?.readyRuntime == null ||
          source == null) {
        return null;
      }
      try {
        return source.createGrammarQuizHistoryRepository();
      } on Object {
        return null;
      }
    });
