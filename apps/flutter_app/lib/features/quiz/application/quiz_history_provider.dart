import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/account_controller.dart';
import '../../auth/application/account_provider.dart';
import '../data/vocabulary_quiz_history_repository.dart';

/// Only configured owned startup supplies this borrowed capability.
final quizHistorySourceProvider = Provider<VocabularyQuizHistorySource?>(
  (ref) => null,
);

final quizHistoryRepositoryProvider = Provider<VocabularyQuizHistoryRepository?>(
  (ref) {
    final account = ref.watch(accountStateProvider);
    final runtime = ref.watch(accountRuntimeProvider);
    final source = ref.watch(quizHistorySourceProvider);
    if (account.phase != AccountPhase.ready ||
        account.profile == null ||
        runtime?.readyRuntime == null ||
        source == null) {
      return null;
    }
    try {
      return source.createVocabularyQuizHistoryRepository();
    } on Object {
      return null;
    }
  },
);
