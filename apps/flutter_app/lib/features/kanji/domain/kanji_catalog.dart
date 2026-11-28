import 'dart:convert';

import '../../../shared/models/preview_level.dart';

/// Original public display metadata, not vetted stroke geometry or a grade.
final class KanjiCatalogEntry {
  KanjiCatalogEntry({
    required this.id,
    required this.level,
    required this.contentVersion,
    required this.character,
    required this.meaningVi,
    required List<String> onyomi,
    required List<String> kunyomi,
    required this.strokeCount,
    required this.radical,
    required this.hasStrokeReference,
  }) : onyomi = List.unmodifiable(onyomi),
       kunyomi = List.unmodifiable(kunyomi);

  final String id;
  final PreviewLevel level;
  final int contentVersion;
  final String character;
  final String meaningVi;
  final List<String> onyomi;
  final List<String> kunyomi;
  final int strokeCount;
  final String? radical;
  final bool hasStrokeReference;
}

abstract interface class KanjiCatalogRepository {
  Future<List<KanjiCatalogEntry>> load(PreviewLevel level);
}

List<KanjiCatalogEntry> decodeKanjiCatalog(String source, PreviewLevel level) {
  if (source.length > 8 * 1024 * 1024) {
    throw const FormatException('Oversized Kanji catalog');
  }
  final Object? rows = jsonDecode(source);
  if (rows is! List<Object?> || rows.length > 5000) {
    throw const FormatException('Expected a bounded Kanji list');
  }
  final entries = <KanjiCatalogEntry>[];
  final ids = <String>{};
  for (final row in rows) {
    if (row is! Map<String, dynamic>) {
      throw const FormatException('Invalid Kanji object');
    }
    final id = _text(row['id'], 36);
    if (!RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(id) ||
        !ids.add(id)) {
      throw const FormatException('Invalid or duplicate Kanji ID');
    }
    final rowLevel = switch (row['jlpt_level']) {
      'N5' => PreviewLevel.n5,
      'N4' => PreviewLevel.n4,
      _ => throw const FormatException('Unsupported Kanji level'),
    };
    final version = row['content_version'];
    final active = row['is_active'];
    final count = row['stroke_count'];
    final character = _text(row['character'], 2);
    if (version is! int ||
        version < 1 ||
        active is! bool ||
        count is! int ||
        count < 1 ||
        count > 64 ||
        character.runes.length != 1) {
      throw const FormatException('Invalid Kanji metadata');
    }
    final reference = row['stroke_data_ref'];
    final radical = row['radical'];
    if (reference != null) {
      _text(reference, 1000);
    }
    if (radical != null) {
      _text(radical, 20);
    }
    final entry = KanjiCatalogEntry(
      id: id,
      level: rowLevel,
      contentVersion: version,
      character: character,
      meaningVi: _text(row['meaning_vi'], 2000),
      onyomi: _readings(row['onyomi']),
      kunyomi: _readings(row['kunyomi']),
      strokeCount: count,
      radical: radical as String?,
      hasStrokeReference: reference != null,
    );
    if (active && rowLevel == level) {
      entries.add(entry);
    }
  }
  return List.unmodifiable(entries);
}

String _text(Object? value, int maxLength) {
  if (value is! String || value.trim().isEmpty || value.length > maxLength) {
    throw const FormatException('Invalid Kanji text');
  }
  return value;
}

List<String> _readings(Object? values) {
  if (values is! List<Object?> || values.length > 100) {
    throw const FormatException('Invalid Kanji readings');
  }
  final result = [for (final value in values) _text(value, 100)];
  if (result.toSet().length != result.length) {
    throw const FormatException('Duplicate Kanji reading');
  }
  return result;
}

List<KanjiCatalogEntry> searchKanjiCatalog(
  List<KanjiCatalogEntry> entries,
  String query,
) {
  final needle = _fold(query).trim();
  return List.unmodifiable([
    for (final entry in entries)
      if (needle.isEmpty ||
          [
            entry.character,
            entry.meaningVi,
            ...entry.onyomi,
            ...entry.kunyomi,
          ].any((value) => _fold(value).contains(needle)))
        entry,
  ]);
}

String _fold(String value) {
  var folded = value.toLowerCase().replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  for (final group in _vietnameseLetters.entries) {
    folded = folded.replaceAll(group.key, group.value);
  }
  return folded;
}

final _vietnameseLetters = <RegExp, String>{
  RegExp('[àáảãạăằắẳẵặâầấẩẫậ]'): 'a',
  RegExp('[èéẻẽẹêềếểễệ]'): 'e',
  RegExp('[ìíỉĩị]'): 'i',
  RegExp('[òóỏõọôồốổỗộơờớởỡợ]'): 'o',
  RegExp('[ùúủũụưừứửữự]'): 'u',
  RegExp('[ỳýỷỹỵ]'): 'y',
  RegExp('đ'): 'd',
};
