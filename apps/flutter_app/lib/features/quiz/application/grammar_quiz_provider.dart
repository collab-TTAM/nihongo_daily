import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/preview_level.dart';
import '../../curriculum/application/curriculum_provider.dart';
import '../../curriculum/domain/curriculum.dart';
import '../domain/grammar_quiz.dart';

final grammarQuizProvider = FutureProvider.autoDispose
    .family<List<GrammarQuizQuestion>, PreviewLevel>((ref, level) async {
      final repository = ref.watch(curriculumRepositoryProvider);
      final entries = await repository.load(CurriculumKind.grammar, level);
      return buildGrammarQuiz(entries, level);
    });
