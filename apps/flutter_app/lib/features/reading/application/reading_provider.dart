import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/preview_level.dart';
import '../../settings/application/preview_preferences.dart'
    show previewLevelProvider;
import '../domain/reading_material.dart';
import '../domain/reading_repository.dart';

// The host may inject a reviewed trusted local source. No demo lesson, arbitrary
// learner URL, account capability or default network service is installed.
final readingRepositoryProvider = Provider<ReadingRepository?>((ref) => null);

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
