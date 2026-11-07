import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/preview_level.dart';
import '../../settings/application/preview_preferences.dart'
    show previewLevelProvider;
import '../data/bundled_reading_repository.dart';
import '../domain/reading_material.dart';
import '../domain/reading_repository.dart';

// The default is one fixed, read-only package asset. A trusted host may override
// it with a reviewed local source; no learner URL/path or network writer exists.
final readingRepositoryProvider = Provider<ReadingRepository?>(
  (ref) => BundledReadingRepository(),
);

final readingCatalogProvider = FutureProvider.autoDispose
    .family<List<ReadingPassage>, PreviewLevel>((ref, level) {
      final repository = ref.watch(readingRepositoryProvider);
      if (repository == null) {
        throw const ReadingLoadException(ReadingLoadFailure.unavailable);
      }
      return repository.load(level);
    });

// Selection is bound to the current source/level/catalog generation. Even an
// immediate refresh returning an identical list clears eligibility. It is public
// UI state, never account identity, completion or server-plan write authority.
final readingSelectedPassageProvider =
    StateProvider.autoDispose<ReadingPassage?>((ref) {
      final level = ref.watch(previewLevelProvider);
      final repository = ref.watch(readingRepositoryProvider);
      if (repository != null) {
        ref.watch(readingCatalogProvider(level));
      }
      return null;
    });
