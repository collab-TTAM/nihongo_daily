import 'package:flutter/services.dart';

import '../../../shared/models/preview_level.dart';
import '../domain/kanji_catalog.dart';

final class BundledKanjiRepository implements KanjiCatalogRepository {
  BundledKanjiRepository({Future<String> Function(String)? read})
    : _read = read ?? rootBundle.loadString;

  final Future<String> Function(String) _read;

  @override
  Future<List<KanjiCatalogEntry>> load(PreviewLevel level) async {
    final path = switch (level) {
      PreviewLevel.n5 => 'assets/curriculum/n5/kanji.json',
      PreviewLevel.n4 => 'assets/curriculum/n4/kanji.json',
    };
    return decodeKanjiCatalog(await _read(path), level);
  }
}
