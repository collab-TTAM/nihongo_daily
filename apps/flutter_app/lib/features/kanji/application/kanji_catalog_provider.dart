import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/preview_level.dart';
import '../data/bundled_kanji_repository.dart';
import '../domain/kanji_catalog.dart';

final kanjiCatalogRepositoryProvider = Provider<KanjiCatalogRepository>(
  (ref) => BundledKanjiRepository(),
);

final kanjiCatalogProvider = FutureProvider.autoDispose
    .family<List<KanjiCatalogEntry>, PreviewLevel>((ref, level) {
      return ref.watch(kanjiCatalogRepositoryProvider).load(level);
    });
