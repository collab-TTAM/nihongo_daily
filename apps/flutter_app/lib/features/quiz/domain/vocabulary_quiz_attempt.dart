import 'dart:convert';

import '../../../shared/models/preview_level.dart';
import 'vocabulary_quiz.dart';

final _quizUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

String quizHistoryUuid(Object? value) {
  if (value is! String || !_quizUuid.hasMatch(value)) {
    throw const FormatException('Invalid quiz identity');
  }
  return value;
}

Map<String, Object?> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, Object?> ||
      value.length != keys.length ||
      !value.keys.every(keys.contains)) {
    throw const FormatException('Invalid quiz record');
  }
  return value;
}

DateTime _completedTime(Object? value) {
  if (value is! String || value.length > 32) {
    throw const FormatException('Invalid quiz time');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      !parsed.isUtc ||
      parsed.year < 2000 ||
      parsed.year > 2100 ||
      parsed.toIso8601String() != value) {
    throw const FormatException('Invalid quiz time');
  }
  return parsed;
}

/// A structurally validated client report, never server or mastery evidence.
final class VocabularyQuizAnswer {
  VocabularyQuizAnswer._({
    required this.itemId,
    required this.contentVersion,
    required this.selectedId,
    required List<String> choices,
  }) : choices = List.unmodifiable(choices);

  factory VocabularyQuizAnswer.fromJson(Object? value) {
    final json = _object(value, {
      'item_id',
      'content_version',
      'selected_id',
      'choices',
    });
    final itemId = quizHistoryUuid(json['item_id']);
    final selectedId = quizHistoryUuid(json['selected_id']);
    final version = json['content_version'];
    final rawChoices = json['choices'];
    if (version is! int ||
        version < 1 ||
        version > 2147483647 ||
        rawChoices is! List<Object?> ||
        rawChoices.length != 4) {
      throw const FormatException('Invalid quiz answer');
    }
    final choices = rawChoices.map(quizHistoryUuid).toList();
    if (choices.toSet().length != 4 ||
        !choices.contains(itemId) ||
        !choices.contains(selectedId)) {
      throw const FormatException('Invalid quiz choices');
    }
    return VocabularyQuizAnswer._(
      itemId: itemId,
      contentVersion: version,
      selectedId: selectedId,
      choices: choices,
    );
  }

  final String itemId;
  final int contentVersion;
  final String selectedId;
  final List<String> choices;
  bool get isCorrect => selectedId == itemId;

  Map<String, Object?> toJson() => {
    'item_id': itemId,
    'content_version': contentVersion,
    'selected_id': selectedId,
    'choices': choices.toList(),
  };
}

/// Local format v1. Owner identity is attached separately by a trusted caller.
final class VocabularyQuizAttempt {
  VocabularyQuizAttempt._({
    required this.eventId,
    required this.level,
    required this.completedAt,
    required List<VocabularyQuizAnswer> answers,
  }) : answers = List.unmodifiable(answers);

  factory VocabularyQuizAttempt.capture({
    required String eventId,
    required DateTime completedAt,
    required QuizRound round,
  }) {
    if (!round.isComplete ||
        round.questions.isEmpty ||
        round.answeredCount != round.questions.length ||
        !completedAt.isUtc) {
      throw const FormatException('Incomplete quiz attempt');
    }
    final level = round.questions.first.target.level;
    if (round.questions.any((q) => q.target.level != level)) {
      throw const FormatException('Mixed quiz level');
    }
    final accepted = round.acceptedAnswers;
    return VocabularyQuizAttempt.fromJson({
      'format_version': 1,
      'event_id': eventId,
      'level': level.label,
      'completed_at': completedAt.toIso8601String(),
      'answers': [
        for (final q in round.questions)
          {
            'item_id': q.target.id,
            'content_version': q.target.contentVersion,
            'selected_id': accepted[q.id],
            'choices': q.choices.map((choice) => choice.id).toList(),
          },
      ],
    });
  }

  factory VocabularyQuizAttempt.fromJson(Object? value) {
    final json = _object(value, {
      'format_version',
      'event_id',
      'level',
      'completed_at',
      'answers',
    });
    final version = json['format_version'];
    final rawAnswers = json['answers'];
    if (version is! int ||
        version != 1 ||
        rawAnswers is! List<Object?> ||
        rawAnswers.isEmpty ||
        rawAnswers.length > 10) {
      throw const FormatException('Invalid quiz attempt');
    }
    final level = switch (json['level']) {
      'N5' => PreviewLevel.n5,
      'N4' => PreviewLevel.n4,
      _ => throw const FormatException('Invalid quiz level'),
    };
    final answers = rawAnswers.map(VocabularyQuizAnswer.fromJson).toList();
    final targets = answers.map((answer) => answer.itemId).toSet();
    if (targets.length != answers.length) {
      throw const FormatException('Repeated quiz target');
    }
    return VocabularyQuizAttempt._(
      eventId: quizHistoryUuid(json['event_id']),
      level: level,
      completedAt: _completedTime(json['completed_at']),
      answers: answers,
    );
  }

  final String eventId;
  final PreviewLevel level;
  final DateTime completedAt;
  final List<VocabularyQuizAnswer> answers;
  int get score => answers.where((answer) => answer.isCorrect).length;

  Map<String, Object?> toJson() => {
    'format_version': 1,
    'event_id': eventId,
    'level': level.label,
    'completed_at': completedAt.toIso8601String(),
    'answers': answers.map((answer) => answer.toJson()).toList(),
  };
}

bool sameVocabularyQuizAttempt(
  VocabularyQuizAttempt left,
  VocabularyQuizAttempt right,
) => jsonEncode(left.toJson()) == jsonEncode(right.toJson());

/// Data only. A repository must capture and authorize the owner.
final class OwnedVocabularyQuizAttempt {
  OwnedVocabularyQuizAttempt(String ownerId, this.attempt)
    : ownerId = quizHistoryUuid(ownerId);
  final String ownerId;
  final VocabularyQuizAttempt attempt;
}
