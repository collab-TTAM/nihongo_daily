import 'dart:convert';

import '../../../shared/models/preview_level.dart';
import 'grammar_quiz.dart';

final _grammarUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

String _identity(Object? value) {
  if (value is! String || !_grammarUuid.hasMatch(value)) {
    throw const FormatException('Invalid grammar attempt identity');
  }
  return value;
}

Map<String, Object?> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, Object?> ||
      value.length != keys.length ||
      !value.keys.every(keys.contains)) {
    throw const FormatException('Invalid grammar attempt record');
  }
  return value;
}

DateTime _completedTime(Object? value) {
  if (value is! String || value.length > 32) {
    throw const FormatException('Invalid grammar attempt time');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      !parsed.isUtc ||
      parsed.year < 2000 ||
      parsed.year > 2100 ||
      parsed.toIso8601String() != value) {
    throw const FormatException('Invalid grammar attempt time');
  }
  return parsed;
}

/// A structurally validated client report, never server or mastery evidence.
final class GrammarQuizAnswer {
  GrammarQuizAnswer._({
    required this.itemId,
    required this.contentVersion,
    required this.selectedId,
    required List<String> choices,
  }) : choices = List.unmodifiable(choices);

  factory GrammarQuizAnswer.fromJson(Object? value) {
    final json = _object(value, {
      'item_id',
      'content_version',
      'selected_id',
      'choices',
    });
    final itemId = _identity(json['item_id']);
    final selectedId = _identity(json['selected_id']);
    final version = json['content_version'];
    final rawChoices = json['choices'];
    if (version is! int ||
        version < 1 ||
        version > 2147483647 ||
        rawChoices is! List<Object?> ||
        rawChoices.length != 4) {
      throw const FormatException('Invalid grammar attempt answer');
    }
    final choices = rawChoices.map(_identity).toList();
    if (choices.toSet().length != 4 ||
        !choices.contains(itemId) ||
        !choices.contains(selectedId)) {
      throw const FormatException('Invalid grammar attempt choices');
    }
    return GrammarQuizAnswer._(
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

/// Caller classifies the completed practice; this is not server evidence.
enum GrammarQuizAttemptKind { primary, correction }

/// Pure local format v1. Not connected to a store, owner or save UI.
final class GrammarQuizAttempt {
  GrammarQuizAttempt._({
    required this.eventId,
    required this.kind,
    required this.level,
    required this.completedAt,
    required List<GrammarQuizAnswer> answers,
  }) : answers = List.unmodifiable(answers);

  factory GrammarQuizAttempt.capture({
    required String eventId,
    required DateTime completedAt,
    required GrammarQuizRound round,
    required GrammarQuizAttemptKind kind,
  }) {
    if (!round.isComplete ||
        round.questions.isEmpty ||
        round.answeredCount != round.questions.length ||
        !completedAt.isUtc) {
      throw const FormatException('Incomplete grammar attempt');
    }
    final level = round.questions.first.target.level;
    if (round.questions.any((q) => q.target.level != level)) {
      throw const FormatException('Mixed grammar attempt level');
    }
    final accepted = round.acceptedAnswers;
    return GrammarQuizAttempt.fromJson({
      'format_version': 1,
      'quiz_type': 'grammar_meaning',
      'practice_kind': kind.name,
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

  factory GrammarQuizAttempt.fromJson(Object? value) {
    final json = _object(value, {
      'format_version',
      'quiz_type',
      'practice_kind',
      'event_id',
      'level',
      'completed_at',
      'answers',
    });
    final version = json['format_version'];
    final rawAnswers = json['answers'];
    if (json['quiz_type'] != 'grammar_meaning' ||
        version is! int ||
        version != 1 ||
        rawAnswers is! List<Object?> ||
        rawAnswers.isEmpty ||
        rawAnswers.length > 10) {
      throw const FormatException('Invalid grammar attempt');
    }
    final kind = switch (json['practice_kind']) {
      'primary' => GrammarQuizAttemptKind.primary,
      'correction' => GrammarQuizAttemptKind.correction,
      _ => throw const FormatException('Invalid grammar practice kind'),
    };
    final level = switch (json['level']) {
      'N5' => PreviewLevel.n5,
      'N4' => PreviewLevel.n4,
      _ => throw const FormatException('Invalid grammar attempt level'),
    };
    final answers = rawAnswers.map(GrammarQuizAnswer.fromJson).toList();
    final targets = answers.map((answer) => answer.itemId).toSet();
    if (targets.length != answers.length) {
      throw const FormatException('Repeated grammar attempt target');
    }
    return GrammarQuizAttempt._(
      eventId: _identity(json['event_id']),
      kind: kind,
      level: level,
      completedAt: _completedTime(json['completed_at']),
      answers: answers,
    );
  }

  final String eventId;
  final GrammarQuizAttemptKind kind;
  final PreviewLevel level;
  final DateTime completedAt;
  final List<GrammarQuizAnswer> answers;
  int get score => answers.where((answer) => answer.isCorrect).length;

  Map<String, Object?> toJson() => {
    'format_version': 1,
    'quiz_type': 'grammar_meaning',
    'practice_kind': kind.name,
    'event_id': eventId,
    'level': level.label,
    'completed_at': completedAt.toIso8601String(),
    'answers': answers.map((answer) => answer.toJson()).toList(),
  };
}

bool sameGrammarQuizAttempt(
  GrammarQuizAttempt left,
  GrammarQuizAttempt right,
) => jsonEncode(left.toJson()) == jsonEncode(right.toJson());

/// Structural local key only, never authentication or write authorization.
String grammarHistoryUuid(Object? value) => _identity(value);

/// A trusted session repository must supply this owner, not a learner field.
final class OwnedGrammarQuizAttempt {
  OwnedGrammarQuizAttempt(String ownerId, this.attempt)
    : ownerId = _identity(ownerId);
  final String ownerId;
  final GrammarQuizAttempt attempt;
}
