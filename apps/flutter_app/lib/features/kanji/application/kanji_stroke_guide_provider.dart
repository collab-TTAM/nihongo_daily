import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/bundled_kanji_stroke_guides.dart';
import '../domain/kanji_catalog.dart';
import '../domain/kanji_stroke_guide.dart';

final kanjiStrokeGuideRepositoryProvider = Provider<KanjiStrokeGuideRepository>(
  (ref) => BundledKanjiStrokeGuides(),
);
final kanjiStrokeGuideProvider = FutureProvider.autoDispose
    .family<KanjiStrokeGuide?, KanjiCatalogEntry>((ref, entry) {
      return ref.watch(kanjiStrokeGuideRepositoryProvider).load(entry);
    });
