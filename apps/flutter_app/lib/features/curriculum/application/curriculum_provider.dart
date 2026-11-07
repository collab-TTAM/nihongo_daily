import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/preview_preferences.dart';
import '../data/bundled_curriculum_repository.dart';
import '../domain/curriculum.dart';

final curriculumRepositoryProvider = Provider<CurriculumRepository>(
  (ref) => BundledCurriculumRepository(),
);

final curriculumProvider = FutureProvider.autoDispose
    .family<List<CurriculumEntry>, CurriculumKind>((ref, kind) {
      final level = ref.watch(previewLevelProvider);
      return ref.watch(curriculumRepositoryProvider).load(kind, level);
    });
