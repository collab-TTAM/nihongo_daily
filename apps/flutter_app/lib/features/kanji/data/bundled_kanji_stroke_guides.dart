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
    final path = switch (entry.level) {
      PreviewLevel.n5 => 'assets/kanji_references/n5.json',
      PreviewLevel.n4 => 'assets/kanji_references/n4.json',
    };
    final guides = decodeKanjiStrokeGuides(
      await _read(path),
      level: entry.level,
    );
    for (final guide in guides) {
      if (guide.matches(entry)) {
        return guide;
      }
    }
    return null;
  }
}
