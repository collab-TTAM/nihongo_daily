import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../shared/models/preview_level.dart';
import '../domain/curriculum.dart';

final class BundledCurriculumRepository implements CurriculumRepository {
  BundledCurriculumRepository({Future<String> Function(String)? read})
    : _read = read ?? rootBundle.loadString;

  final Future<String> Function(String) _read;

  @override
  Future<List<CurriculumEntry>> load(
    CurriculumKind kind,
    PreviewLevel level,
  ) async {
    final directory = switch (level) {
      PreviewLevel.n5 => 'assets/curriculum/n5',
      PreviewLevel.n4 => 'assets/curriculum/n4',
    };
    // Each level has one fixed packaged source; never fall back to another level.
    final source = await _read('$directory/${kind.name}.json');
    return decodeCurriculum(source, kind, level);
  }
}

/// Display projection; authored exports retain their contract checks.
List<CurriculumEntry> decodeCurriculum(
  String source,
  CurriculumKind kind,
  PreviewLevel level,
) {
  if (source.length > 8 * 1024 * 1024) {
    throw const FormatException('Oversized curriculum');
  }
  final Object? rows = jsonDecode(source);
  if (rows is! List<Object?> || rows.length > 5000) {
    throw const FormatException('Expected a bounded curriculum list');
  }
  final entries = <CurriculumEntry>[];
  final ids = <String>{};
  for (final value in rows) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected curriculum object');
    }
    final id = _text(value, 'id');
    if (!RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(id) ||
        !ids.add(id)) {
      throw const FormatException('Invalid or duplicate curriculum ID');
    }
    final rowLevel = switch (value['jlpt_level']) {
      'N5' => PreviewLevel.n5,
      'N4' => PreviewLevel.n4,
      _ => throw const FormatException('Unsupported curriculum level'),
    };
    final version = value['content_version'];
    final active = value['is_active'];
    if (version is! int || version < 1 || active is! bool) {
      throw const FormatException('Invalid curriculum metadata');
    }
    final examples = value['examples'];
    if (examples is! List<Object?> || examples.length > 100) {
      throw const FormatException('Invalid curriculum examples');
    }
    final decodedExamples = <CurriculumExample>[];
    for (final example in examples) {
      if (example is! Map<String, dynamic>) {
        throw const FormatException('Invalid example');
      }
      decodedExamples.add(
        CurriculumExample(
          japanese: _text(example, 'sentence_ja'),
          reading: _text(example, 'reading_ja'),
          vietnamese: _text(example, 'translation_vi'),
        ),
      );
    }
    final vocabulary = kind == CurriculumKind.vocabulary;
    final audio = value['audio_ref'];
    if (audio != null && (audio is! String || audio.trim().isEmpty)) {
      throw const FormatException('Invalid audio reference');
    }
    final entry = CurriculumEntry(
      id: id,
      kind: kind,
      level: rowLevel,
      contentVersion: version,
      heading: _text(value, vocabulary ? 'expression' : 'pattern'),
      caption: _text(value, vocabulary ? 'part_of_speech' : 'title'),
      reading: vocabulary ? _text(value, 'reading') : null,
      meaningVi: _text(value, 'meaning_vi'),
      explanationVi: _text(
        value,
        vocabulary ? 'usage_context_vi' : 'explanation_vi',
      ),
      hasAudioReference: audio != null,
      notes: vocabulary ? const [] : _texts(value, 'usage_notes_vi'),
      mistakes: vocabulary ? const [] : _texts(value, 'common_mistakes'),
      examples: decodedExamples,
    );
    if (active && rowLevel == level) entries.add(entry);
  }
  return List.unmodifiable(entries);
}

String _text(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String || value.trim().isEmpty || value.length > 8000) {
    throw const FormatException('Invalid curriculum text');
  }
  return value;
}

List<String> _texts(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! List<Object?> || value.length > 100) {
    throw const FormatException('Invalid curriculum notes');
  }
  return [
    for (final text in value) _text({'text': text}, 'text'),
  ];
}
