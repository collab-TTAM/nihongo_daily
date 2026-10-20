import 'package:flutter/services.dart';
import '../../../shared/models/preview_level.dart';
import '../domain/kanji_catalog.dart';
import '../domain/kanji_stroke_guide.dart';

final class BundledKanjiStrokeGuides implements KanjiStrokeGuideRepository {
  BundledKanjiStrokeGuides({Future<String> Function(String)? read})
    : _read = read ?? rootBundle.loadString;
  final Future<String> Function(String) _read;
  @override
  Future<KanjiStrokeGuide?> load(KanjiCatalogEntry entry) async {
    if (entry.level != PreviewLevel.n5) {
      return null;
    }
    final guides = decodeKanjiStrokeGuides(
      await _read('assets/kanji_references/n5.json'),
    );
    for (final guide in guides) {
      if (guide.kanjiId == entry.id &&
          guide.character == entry.character &&
          guide.contentVersion == entry.contentVersion &&
          guide.strokes.length == entry.strokeCount) {
        return guide;
      }
    }
    return null;
  }
}
