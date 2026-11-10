import '../domain/grammar_quiz_attempt.dart';
import '../domain/vocabulary_quiz_attempt.dart';

final _quizReportV2Uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _quizReportV2Instant = RegExp(
  r'^(20[0-9]{2}|2100)-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?Z$',
);

String _eventId(String value) {
  if (!_quizReportV2Uuid.hasMatch(value)) {
    throw const FormatException('Invalid quiz report event');
  }
  return value;
}

String _completedAt(DateTime value) {
  if (!value.isUtc || value.year < 2000 || value.year > 2100) {
    throw const FormatException('Invalid quiz report time');
  }
  final encoded = value.toIso8601String();
  if (!_quizReportV2Instant.hasMatch(encoded)) {
    throw const FormatException('Invalid quiz report time');
  }
  return encoded;
}

QuizReportV2Answer _answer({
  required String itemId,
  required int contentVersion,
  required String selectedId,
  required List<String> choices,
  required List<int>? choiceContentVersions,
}) {
  final copiedChoices = List<String>.of(choices);
  final copiedVersions = choiceContentVersions == null
      ? null
      : List<int>.of(choiceContentVersions);
  if (copiedVersions == null ||
      copiedChoices.length != 4 ||
      copiedVersions.length != 4 ||
      copiedChoices.toSet().length != 4 ||
      copiedChoices.any((choice) => !_quizReportV2Uuid.hasMatch(choice)) ||
      !_quizReportV2Uuid.hasMatch(itemId) ||
      !_quizReportV2Uuid.hasMatch(selectedId) ||
      !copiedChoices.contains(itemId) ||
      !copiedChoices.contains(selectedId) ||
      contentVersion < 1 ||
      contentVersion > 2147483647 ||
      copiedVersions.any((version) => version < 1 || version > 2147483647) ||
      copiedVersions[copiedChoices.indexOf(itemId)] != contentVersion) {
    throw const FormatException('Invalid quiz report choice provenance');
  }
  return QuizReportV2Answer._(
    itemId: itemId,
    contentVersion: contentVersion,
    selectedId: selectedId,
    choices: copiedChoices,
    choiceContentVersions: copiedVersions,
  );
}

Map<String, Object?> _strictObject(Object? value, Set<String> keys) {
  if (value is! Map<String, Object?> ||
      value.length != keys.length ||
      !value.keys.every(keys.contains)) {
    throw const FormatException('Invalid quiz report response');
  }
  return value;
}

/// Exact nd-quiz-report-2 answer projection. No owner, score, timer or credential.
final class QuizReportV2Answer {
  QuizReportV2Answer._({
    required this.itemId,
    required this.contentVersion,
    required this.selectedId,
    required List<String> choices,
    required List<int> choiceContentVersions,
  }) : choices = List.unmodifiable(choices),
       choiceContentVersions = List.unmodifiable(choiceContentVersions);

  final String itemId;
  final int contentVersion;
  final String selectedId;
  final List<String> choices;
  final List<int> choiceContentVersions;

  bool get isCorrect => selectedId == itemId;

  Map<String, Object?> toJson() => {
    'item_id': itemId,
    'content_version': contentVersion,
    'selected_id': selectedId,
    'choices': choices.toList(),
    'choice_content_versions': choiceContentVersions.toList(),
  };
}

/// Pure wire projection only. It never dispatches or authorizes a save.
final class QuizReportV2Request {
  QuizReportV2Request._({
    required this.clientEventId,
    required this.quizType,
    required this.practiceKind,
    required this.jlptLevel,
    required this.completedAt,
    required List<QuizReportV2Answer> answers,
  }) : answers = List.unmodifiable(answers) {
    if ((quizType != 'vocabulary_reading' &&
            quizType != 'grammar_meaning') ||
        (jlptLevel != 'N5' && jlptLevel != 'N4') ||
        (quizType == 'vocabulary_reading' && practiceKind != null) ||
        (quizType == 'grammar_meaning' &&
            practiceKind != 'primary' &&
            practiceKind != 'correction') ||
        answers.isEmpty ||
        answers.length > 10 ||
        answers.map((answer) => answer.itemId).toSet().length !=
            answers.length) {
      throw const FormatException('Invalid quiz report request');
    }
  }

  factory QuizReportV2Request.fromVocabularyAttempt(
    VocabularyQuizAttempt attempt,
  ) {
    if (attempt.formatVersion != 2) {
      throw const FormatException(
        'Legacy quiz attempt lacks displayed choice versions',
      );
    }
    return QuizReportV2Request._(
      clientEventId: _eventId(attempt.eventId),
      quizType: 'vocabulary_reading',
      practiceKind: null,
      jlptLevel: attempt.level.label,
      completedAt: _completedAt(attempt.completedAt),
      answers: [
        for (final answer in attempt.answers)
          _answer(
            itemId: answer.itemId,
            contentVersion: answer.contentVersion,
            selectedId: answer.selectedId,
            choices: answer.choices,
            choiceContentVersions: answer.choiceContentVersions,
          ),
      ],
    );
  }

  factory QuizReportV2Request.fromGrammarAttempt(GrammarQuizAttempt attempt) {
    if (attempt.formatVersion != 2) {
      throw const FormatException(
        'Legacy quiz attempt lacks displayed choice versions',
      );
    }
    return QuizReportV2Request._(
      clientEventId: _eventId(attempt.eventId),
      quizType: 'grammar_meaning',
      practiceKind: attempt.kind.name,
      jlptLevel: attempt.level.label,
      completedAt: _completedAt(attempt.completedAt),
      answers: [
        for (final answer in attempt.answers)
          _answer(
            itemId: answer.itemId,
            contentVersion: answer.contentVersion,
            selectedId: answer.selectedId,
            choices: answer.choices,
            choiceContentVersions: answer.choiceContentVersions,
          ),
      ],
    );
  }

  final String clientEventId;
  final String quizType;
  final String? practiceKind;
  final String jlptLevel;
  final String completedAt;
  final List<QuizReportV2Answer> answers;

  Map<String, Object?> toJson() => {
    'client_event_id': clientEventId,
    'quiz_type': quizType,
    'practice_kind': practiceKind,
    'jlpt_level': jlptLevel,
    'completed_at': completedAt,
    'answers': answers.map((answer) => answer.toJson()).toList(),
  };

  /// Correlates a response to this immutable request; it does not prove storage.
  QuizReportV2Response decodeResponse(Object? value) {
    final json = _strictObject(value, {
      'client_event_id',
      'quiz_type',
      'practice_kind',
      'jlpt_level',
      'completed_at',
      'answer_count',
      'correct_count',
    });
    final answerCount = json['answer_count'];
    final correctCount = json['correct_count'];
    final expectedCorrect = answers.where((answer) => answer.isCorrect).length;
    if (json['client_event_id'] != clientEventId ||
        json['quiz_type'] != quizType ||
        json['practice_kind'] != practiceKind ||
        json['jlpt_level'] != jlptLevel ||
        json['completed_at'] != completedAt ||
        answerCount is! int ||
        correctCount is! int ||
        answerCount != answers.length ||
        correctCount != expectedCorrect ||
        correctCount < 0 ||
        correctCount > answerCount) {
      throw const FormatException('Invalid quiz report response');
    }
    return QuizReportV2Response._(
      answerCount: answerCount,
      correctCount: correctCount,
    );
  }
}

final class QuizReportV2Response {
  const QuizReportV2Response._({
    required this.answerCount,
    required this.correctCount,
  });

  final int answerCount;
  final int correctCount;
}
