import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vocabulary_quiz_repository.dart';
import '../domain/vocabulary_quiz.dart';

typedef VocabularyQuizRequest = ({String level, int batchIndex});

final vocabularyQuizRepositoryProvider = Provider<VocabularyQuizRepository>(
  (ref) => BundledVocabularyQuizRepository(),
);

final vocabularyQuizRoundProvider = FutureProvider.autoDispose
    .family<VocabularyQuizRound, VocabularyQuizRequest>((ref, request) async {
      final repository = ref.watch(vocabularyQuizRepositoryProvider);
      final entries = await repository.load(request.level);
      return const VocabularyQuizBuilder().build(
        level: request.level,
        entries: entries,
        batchIndex: request.batchIndex,
      );
    });
