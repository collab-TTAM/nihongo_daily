import 'dart:convert';
import 'kanji_catalog.dart';

const kanjiGuideVersion = 'kanjivg-70a0b7ae-n5-1';
const kanjiGuideCommit = '70a0b7ae0c18ceb5cb358274b029cce0234a43bc';

final class GuidePoint {
  const GuidePoint(this.x, this.y);
  final double x;
  final double y;
}

final class KanjiStrokeGuide {
  KanjiStrokeGuide({
    required this.kanjiId,
    required this.character,
    required this.contentVersion,
    required List<List<GuidePoint>> strokes,
  }) : strokes = List.unmodifiable(
         strokes.map((stroke) => List<GuidePoint>.unmodifiable(stroke)),
       );
  final String kanjiId;
  final String character;
  final int contentVersion;
  final List<List<GuidePoint>> strokes;
}

abstract interface class KanjiStrokeGuideRepository {
  Future<KanjiStrokeGuide?> load(KanjiCatalogEntry entry);
}

/// Display-only normalized geometry, never an attempt, real score or progress.
List<KanjiStrokeGuide> decodeKanjiStrokeGuides(String source) {
  if (source.length > 1024 * 1024) {
    throw const FormatException('Guide size');
  }
  final root = _object(jsonDecode(source));
  if (root['format_version'] != 1 ||
      root['reference_version'] != kanjiGuideVersion ||
      root['source_commit'] != kanjiGuideCommit ||
      root['license'] != 'CC-BY-SA-3.0' ||
      root['source_url'] != 'https://github.com/KanjiVG/kanjivg' ||
      root['license_url'] !=
          'https://creativecommons.org/licenses/by-sa/3.0/') {
    throw const FormatException('Unknown guide provenance');
  }
  for (final key in ['author', 'copyright', 'changes']) {
    _text(root[key], 2000);
  }
  final rows = root['entries'];
  if (rows is! List<Object?> || rows.length != 8) {
    throw const FormatException('Guide coverage');
  }
  final ids = <String>{};
  final result = <KanjiStrokeGuide>[];
  for (final value in rows) {
    final row = _object(value);
    final id = _text(row['kanji_id'], 36);
    final character = _text(row['character'], 2);
    final version = row['content_version'];
    final count = row['stroke_count'];
    final hash = row['source_sha256'];
    if (!RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(id) ||
        !ids.add(id) ||
        character.runes.length != 1 ||
        version is! int ||
        version < 1 ||
        count is! int ||
        count < 1 ||
        count > 64 ||
        hash is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ||
        row['source_file'] !=
            '${character.runes.single.toRadixString(16).padLeft(5, '0')}.svg') {
      throw const FormatException('Guide identity');
    }
    final rawStrokes = row['strokes'];
    if (rawStrokes is! List<Object?> || rawStrokes.length != count) {
      throw const FormatException('Guide stroke count');
    }
    final strokes = <List<GuidePoint>>[];
    for (final raw in rawStrokes) {
      if (raw is! List<Object?> || raw.length < 2 || raw.length > 4096) {
        throw const FormatException('Guide point count');
      }
      final points = <GuidePoint>[];
      for (final point in raw) {
        if (point is! List<Object?> || point.length != 2) {
          throw const FormatException('Guide point');
        }
        points.add(GuidePoint(_coordinate(point[0]), _coordinate(point[1])));
      }
      if (!points.any((p) => p.x != points.first.x || p.y != points.first.y)) {
        throw const FormatException('Degenerate guide stroke');
      }
      strokes.add(points);
    }
    result.add(
      KanjiStrokeGuide(
        kanjiId: id,
        character: character,
        contentVersion: version,
        strokes: strokes,
      ),
    );
  }
  return List.unmodifiable(result);
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Guide object');
  }
  return value;
}

String _text(Object? value, int bound) {
  if (value is! String || value.trim().isEmpty || value.length > bound) {
    throw const FormatException('Guide text');
  }
  return value;
}

double _coordinate(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > 1) {
    throw const FormatException('Guide coordinate');
  }
  return value.toDouble();
}
