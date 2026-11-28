import 'dart:convert';

import '../../../shared/models/preview_level.dart';

/// Local import format only. No endpoint, audio, owner or learning-write authority.
final class ReadingChoice {
  ReadingChoice._(this.id, this.japanese, this.reading, this.vietnamese);
  final String id;
  final String japanese;
  final String reading;
  final String vietnamese;
}

final class ReadingQuestion {
  ReadingQuestion._(
    this.id,
    this.japanese,
    this.reading,
    this.vietnamese,
    List<ReadingChoice> choices,
    this.correctChoiceId,
    this.explanationVi,
  ) : choices = List.unmodifiable(choices);
  final String id;
  final String japanese;
  final String reading;
  final String vietnamese;
  final List<ReadingChoice> choices;
  final String correctChoiceId;
  final String explanationVi;
}

final class ReadingPassage {
  ReadingPassage._(
    this.id,
    this.level,
    this.contentVersion,
    this.titleJa,
    this.titleVi,
    this.japanese,
    this.reading,
    this.vietnamese,
    this.sourceNoteVi,
    List<ReadingQuestion> questions,
  ) : questions = List.unmodifiable(questions);
  final String id;
  final PreviewLevel level;
  final int contentVersion;
  final String titleJa;
  final String titleVi;
  final String japanese;
  final String reading;
  final String vietnamese;
  // Attribution metadata is not proof of licensing or linguistic review.
  final String sourceNoteVi;
  final List<ReadingQuestion> questions;
  String get snapshotKey => '${level.name}/$id/$contentVersion';
}

Never _invalid() => throw const FormatException('Invalid reading material');

Map<String, Object?> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, Object?> ||
      value.length != keys.length ||
      !value.keys.every(keys.contains)) {
    _invalid();
  }
  return value;
}

List<Object?> _list(Object? value, int minimum, int maximum) {
  if (value is! List<Object?> ||
      value.length < minimum ||
      value.length > maximum) {
    _invalid();
  }
  return value;
}

String _text(Object? value, int maximum) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > maximum ||
      RegExp(
        r'[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]',
      ).hasMatch(value)) {
    _invalid();
  }
  return value;
}

String _id(Object? value) {
  final text = _text(value, 64);
  if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(text)) _invalid();
  return text;
}

/// Validate the whole catalog before filtering; malformed other-level entries
/// cannot be hidden. Bounds apply before decoding and to every nested collection.
List<ReadingPassage> decodeReadingMaterial(String source, PreviewLevel level) {
  const maximumBytes = 262144;
  try {
    if (source.length > maximumBytes ||
        utf8.encode(source).length > maximumBytes) {
      _invalid();
    }
    final catalog = _object(jsonDecode(source), {'schema_version', 'passages'});
    if (catalog['schema_version'] is! int || catalog['schema_version'] != 1) {
      _invalid();
    }
    final ids = <String>{};
    final passages = <ReadingPassage>[];
    for (final raw in _list(catalog['passages'], 0, 50)) {
      final row = _object(raw, {
        'id',
        'jlpt_level',
        'content_version',
        'title_ja',
        'title_vi',
        'text_ja',
        'reading_ja',
        'translation_vi',
        'source_note_vi',
        'questions',
      });
      final id = _id(row['id']);
      if (!ids.add(id)) _invalid();
      final entryLevel = switch (row['jlpt_level']) {
        'N5' => PreviewLevel.n5,
        'N4' => PreviewLevel.n4,
        _ => _invalid(),
      };
      final version = row['content_version'];
      if (version is! int || version < 1 || version > 2147483647) _invalid();
      final questionIds = <String>{};
      final questions = <ReadingQuestion>[];
      for (final rawQuestion in _list(row['questions'], 1, 10)) {
        final question = _object(rawQuestion, {
          'id',
          'prompt_ja',
          'reading_ja',
          'prompt_vi',
          'choices',
          'correct_choice_id',
          'explanation_vi',
        });
        final questionId = _id(question['id']);
        if (!questionIds.add(questionId)) _invalid();
        final choiceIds = <String>{};
        final labels = <String>{};
        final choices = <ReadingChoice>[];
        for (final rawChoice in _list(question['choices'], 2, 4)) {
          final choice = _object(rawChoice, {
            'id',
            'text_ja',
            'reading_ja',
            'text_vi',
          });
          final choiceId = _id(choice['id']);
          final label = _text(choice['text_ja'], 512);
          if (!choiceIds.add(choiceId) || !labels.add(label.trim())) _invalid();
          choices.add(
            ReadingChoice._(
              choiceId,
              label,
              _text(choice['reading_ja'], 512),
              _text(choice['text_vi'], 512),
            ),
          );
        }
        final correct = _id(question['correct_choice_id']);
        if (!choiceIds.contains(correct)) _invalid();
        questions.add(
          ReadingQuestion._(
            questionId,
            _text(question['prompt_ja'], 512),
            _text(question['reading_ja'], 512),
            _text(question['prompt_vi'], 512),
            choices,
            correct,
            _text(question['explanation_vi'], 2048),
          ),
        );
      }
      final passage = ReadingPassage._(
        id,
        entryLevel,
        version,
        _text(row['title_ja'], 256),
        _text(row['title_vi'], 256),
        _text(row['text_ja'], 8192),
        _text(row['reading_ja'], 8192),
        _text(row['translation_vi'], 8192),
        _text(row['source_note_vi'], 1024),
        questions,
      );
      if (entryLevel == level) passages.add(passage);
    }
    return List.unmodifiable(passages);
  } on FormatException {
    // jsonDecode's exception can contain raw source; expose one fixed error.
    _invalid();
  }
}

/// First valid answer wins, bound to one immutable content snapshot. Process-local
/// practice only: completion/score never grants study minutes, mastery or sync.
final class ReadingRound {
  ReadingRound(this.passage);
  final ReadingPassage passage;
  final _answers = <String, String>{};
  Map<String, String> get acceptedAnswers => Map.unmodifiable(_answers);
  bool get isComplete => _answers.length == passage.questions.length;
  int get correctCount => passage.questions
      .where((q) => _answers[q.id] == q.correctChoiceId)
      .length;

  bool answer(String snapshotKey, String questionId, String choiceId) {
    if (snapshotKey != passage.snapshotKey ||
        _answers.containsKey(questionId)) {
      return false;
    }
    for (final question in passage.questions) {
      if (question.id == questionId &&
          question.choices.any((choice) => choice.id == choiceId)) {
        _answers[questionId] = choiceId;
        return true;
      }
    }
    return false;
  }
}
