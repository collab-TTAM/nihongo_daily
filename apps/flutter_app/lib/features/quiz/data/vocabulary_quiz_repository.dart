import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/vocabulary_quiz.dart';

abstract interface class VocabularyQuizRepository {
  Future<List<VocabularyQuizEntry>> load(String level);
}

final class QuizContentUnavailable implements Exception {
  const QuizContentUnavailable(this.level);

  final String level;
}

final class BundledVocabularyQuizRepository
    implements VocabularyQuizRepository {
  BundledVocabularyQuizRepository({
    Future<String> Function(String assetPath)? read,
  }) : _read = read ?? rootBundle.loadString;

  final Future<String> Function(String assetPath) _read;

  @override
  Future<List<VocabularyQuizEntry>> load(String level) async {
    if (level == 'N4') throw QuizContentUnavailable(level);
    if (level != 'N5') {
      throw const FormatException('Unsupported quiz level');
    }

    final source = await _read('assets/curriculum/n5/vocabulary.json');
    return decodeVocabularyQuizEntries(source, expectedLevel: level);
  }
}

List<VocabularyQuizEntry> decodeVocabularyQuizEntries(
  String source, {
  required String expectedLevel,
}) {
  if (source.length > 8 * 1024 * 1024) {
    throw const FormatException('Oversized vocabulary source');
  }
  if (expectedLevel != 'N5' && expectedLevel != 'N4') {
    throw const FormatException('Unsupported quiz level');
  }

  final decoded = jsonDecode(source);
  if (decoded is! List<Object?> ||
      decoded.length > VocabularyQuizBuilder.maxSourceEntries) {
    throw const FormatException('Expected a bounded vocabulary list');
  }

  final ids = <String>{};
  final entries = <VocabularyQuizEntry>[];
  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  for (final value in decoded) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected vocabulary object');
    }
    final id = _requiredText(value, 'id');
    if (!uuid.hasMatch(id) || !ids.add(id)) {
      throw const FormatException('Invalid or duplicate vocabulary ID');
    }

    final level = _requiredText(value, 'jlpt_level');
    final version = value['content_version'];
    final active = value['is_active'];
    if (level != expectedLevel ||
        version is! int ||
        version < 1 ||
        active is! bool) {
      throw const FormatException('Invalid vocabulary metadata');
    }

    entries.add(
      VocabularyQuizEntry(
        id: id,
        jlptLevel: level,
        contentVersion: version,
        expression: _requiredText(value, 'expression'),
        reading: _requiredText(value, 'reading'),
        meaningVi: _requiredText(value, 'meaning_vi'),
        isActive: active,
      ),
    );
  }

  return List.unmodifiable(entries);
}

String _requiredText(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String || value.trim().isEmpty || value.length > 8000) {
    throw FormatException('Invalid vocabulary field: $key');
  }
  return value;
}
