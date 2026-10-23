import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/preview_level.dart';
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
