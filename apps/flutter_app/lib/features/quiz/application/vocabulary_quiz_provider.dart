import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/preview_level.dart';
import '../../curriculum/application/curriculum_provider.dart';
import '../../curriculum/domain/curriculum.dart';
import '../domain/vocabulary_quiz.dart';

final vocabularyQuizProvider = FutureProvider.autoDispose
    .family<List<QuizQuestion>, PreviewLevel>((ref, level) async {
      final repository = ref.watch(curriculumRepositoryProvider);
      final entries = await repository.load(CurriculumKind.vocabulary, level);
      return buildVocabularyQuiz(entries, level);
    });
