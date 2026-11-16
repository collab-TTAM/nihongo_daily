import 'dart:convert';
import '../../../shared/models/preview_level.dart';
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

bool _validQuizReportInstant(String value, {bool requireMicroseconds = false}) {
  if (!_quizReportV2Instant.hasMatch(value) ||
      (requireMicroseconds &&
          !RegExp(
            r'^(20[0-9]{2}|2100)-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{6}Z$',
          ).hasMatch(value))) {
    return false;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) return false;
  final fraction =
      RegExp(r'\.([0-9]{1,6})Z$').firstMatch(value)?.group(1) ?? '';
  final microseconds = fraction.isEmpty
      ? 0
      : int.parse(fraction.padRight(6, '0'));
  return parsed.year == int.parse(value.substring(0, 4)) &&
      parsed.month == int.parse(value.substring(5, 7)) &&
      parsed.day == int.parse(value.substring(8, 10)) &&
      parsed.hour == int.parse(value.substring(11, 13)) &&
      parsed.minute == int.parse(value.substring(14, 16)) &&
      parsed.second == int.parse(value.substring(17, 19)) &&
      parsed.millisecond == microseconds ~/ 1000 &&
      parsed.microsecond == microseconds % 1000;
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
  static const int maxRawBodyBytes = 16 * 1024;

  QuizReportV2Request._({
    required this.clientEventId,
    required this.quizType,
    required this.practiceKind,
    required this.jlptLevel,
    required this.completedAt,
    required List<QuizReportV2Answer> answers,
  }) : answers = List.unmodifiable(answers) {
    if ((quizType != 'vocabulary_reading' && quizType != 'grammar_meaning') ||
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

  factory QuizReportV2Request.fromJson(Object? value) {
    final json = _strictObject(value, {
      'client_event_id',
      'quiz_type',
      'practice_kind',
      'jlpt_level',
      'completed_at',
      'answers',
    });
    final eventId = json['client_event_id'];
    final quizType = json['quiz_type'];
    final practiceKind = json['practice_kind'];
    final decodedPracticeKind = practiceKind is String ? practiceKind : null;
    final jlptLevel = json['jlpt_level'];
    final completedAt = json['completed_at'];
    final rawAnswers = json['answers'];
    if (eventId is! String ||
        quizType is! String ||
        (practiceKind != null && decodedPracticeKind == null) ||
        jlptLevel is! String ||
        completedAt is! String ||
        !_validQuizReportInstant(completedAt) ||
        rawAnswers is! List ||
        rawAnswers.isEmpty ||
        rawAnswers.length > 10) {
      throw const FormatException('Invalid quiz report history request');
    }
    final answers = <QuizReportV2Answer>[];
    for (final rawAnswer in rawAnswers) {
      final answer = _strictObject(rawAnswer, {
        'item_id',
        'content_version',
        'selected_id',
        'choices',
        'choice_content_versions',
      });
      final itemId = answer['item_id'];
      final contentVersion = answer['content_version'];
      final selectedId = answer['selected_id'];
      final choices = answer['choices'];
      final versions = answer['choice_content_versions'];
      if (itemId is! String ||
          contentVersion is! int ||
          selectedId is! String ||
          choices is! List ||
          choices.any((choice) => choice is! String) ||
          versions is! List ||
          versions.any((version) => version is! int)) {
        throw const FormatException('Invalid quiz report history answer');
      }
      answers.add(
        _answer(
          itemId: itemId,
          contentVersion: contentVersion,
          selectedId: selectedId,
          choices: choices.cast<String>(),
          choiceContentVersions: versions.cast<int>(),
        ),
      );
    }
    return QuizReportV2Request._(
      clientEventId: _eventId(eventId),
      quizType: quizType,
      practiceKind: decodedPracticeKind,
      jlptLevel: jlptLevel,
      completedAt: completedAt,
      answers: answers,
    );
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

  /// Encodes a fresh immutable UTF-8 body for the strict v2 ingress.
  ///
  /// This is a wire projection only; it does not dispatch or authorize a save.
  List<int> encodeRawBody() {
    final bytes = utf8.encode(jsonEncode(toJson()));
    if (bytes.length > maxRawBodyBytes) {
      throw const FormatException('Invalid quiz report request size');
    }
    return List<int>.unmodifiable(bytes);
  }

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

  /// Decodes only the replay-only lookup union against this original request.
  /// A miss remains unresolved; it is never permission to submit again.
  QuizReportV2LookupResult decodeLookupResponse(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Invalid quiz report lookup response');
    }
    final status = value['status'];
    if (status == 'unresolved') {
      final json = _strictObject(value, {'status', 'client_event_id'});
      if (json['client_event_id'] != clientEventId) {
        throw const FormatException('Invalid quiz report lookup response');
      }
      return QuizReportV2LookupResult._(clientEventId: clientEventId);
    }
    if (status == 'found') {
      final json = _strictObject(value, {'status', 'response'});
      return QuizReportV2LookupResult._(
        clientEventId: clientEventId,
        response: decodeResponse(json['response']),
      );
    }
    throw const FormatException('Invalid quiz report lookup response');
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

/// A correlated receipt result. A missing receipt is explicitly unresolved,
/// not a negative acknowledgement and not a retry instruction.
final class QuizReportV2LookupResult {
  const QuizReportV2LookupResult._({
    required this.clientEventId,
    this.response,
  });

  final String clientEventId;
  final QuizReportV2Response? response;

  bool get hasReceipt => response != null;
  bool get isUnresolved => response == null;
}


/// Cursor for the server's immutable, owner-scoped receipt history.
final class QuizReportV2HistoryCursor {
  const QuizReportV2HistoryCursor({
    required this.receivedAt,
    required this.clientEventId,
  });

  final String receivedAt;
  final String clientEventId;

  Map<String, Object?> toJson() => {
    'received_at': receivedAt,
    'client_event_id': clientEventId,
  };
}

final class QuizReportV2HistoryEntry {
  const QuizReportV2HistoryEntry({
    required this.receivedAt,
    required this.request,
    required this.response,
  });

  final String receivedAt;
  final QuizReportV2Request request;
  final QuizReportV2Response response;
}

final class QuizReportV2HistoryPage {
  QuizReportV2HistoryPage._({
    required List<QuizReportV2HistoryEntry> items,
    required this.nextCursor,
  }) : items = List.unmodifiable(items);

  final List<QuizReportV2HistoryEntry> items;
  final QuizReportV2HistoryCursor? nextCursor;
}

QuizReportV2HistoryCursor? _decodeQuizReportV2HistoryCursor(Object? value) {
  if (value == null) return null;
  final json = _strictObject(value, {'received_at', 'client_event_id'});
  final receivedAt = json['received_at'];
  final eventId = json['client_event_id'];
  if (receivedAt is! String ||
      !_validQuizReportInstant(receivedAt, requireMicroseconds: true) ||
      eventId is! String ||
      !_quizReportV2Uuid.hasMatch(eventId) ||
      eventId != eventId.toLowerCase()) {
    throw const FormatException('Invalid quiz report history cursor');
  }
  return QuizReportV2HistoryCursor(
    receivedAt: receivedAt,
    clientEventId: eventId,
  );
}

int _compareQuizReportV2HistoryKey(
  String leftReceivedAt,
  String leftEventId,
  String rightReceivedAt,
  String rightEventId,
) {
  final time = leftReceivedAt.compareTo(rightReceivedAt);
  return time == 0 ? leftEventId.compareTo(rightEventId) : time;
}

/// Fixed read-only filters; the owner, project, table and query are never inputs.
final class QuizReportV2HistoryQuery {
  QuizReportV2HistoryQuery({
    this.jlptLevel,
    this.quizType,
    this.limit = 20,
    this.cursor,
  }) {
    if ((jlptLevel != null && jlptLevel != 'N5' && jlptLevel != 'N4') ||
        (quizType != null &&
            quizType != 'vocabulary_reading' &&
            quizType != 'grammar_meaning') ||
        limit < 1 ||
        limit > 100 ||
        (cursor != null &&
            (!_validQuizReportInstant(
                  cursor.receivedAt,
                  requireMicroseconds: true,
                ) ||
                !_quizReportV2Uuid.hasMatch(cursor.clientEventId) ||
                cursor.clientEventId != cursor.clientEventId.toLowerCase()))) {
      throw const FormatException('Invalid quiz report history filter');
    }
  }

  static const int maxRawBodyBytes = 16 * 1024;

  final String? jlptLevel;
  final String? quizType;
  final int limit;
  final QuizReportV2HistoryCursor? cursor;

  Map<String, Object?> toJson() => {
    'jlpt_level': jlptLevel,
    'quiz_type': quizType,
    'limit': limit,
    'cursor': cursor?.toJson(),
  };

  List<int> encodeRawBody() {
    final bytes = utf8.encode(jsonEncode(toJson()));
    if (bytes.isEmpty || bytes.length > maxRawBodyBytes) {
      throw const FormatException('Invalid quiz report history request size');
    }
    return List<int>.unmodifiable(bytes);
  }

  QuizReportV2HistoryPage decodePage(Object? value) {
    final json = _strictObject(value, {'items', 'next_cursor'});
    final rawItems = json['items'];
    if (rawItems is! List || rawItems.length > limit) {
      throw const FormatException('Invalid quiz report history page');
    }

    final items = <QuizReportV2HistoryEntry>[];
    final seen = <String>{};
    for (final rawItem in rawItems) {
      final item = _strictObject(rawItem, {
        'received_at',
        'request',
        'response',
      });
      final receivedAt = item['received_at'];
      if (receivedAt is! String ||
          !_validQuizReportInstant(receivedAt, requireMicroseconds: true)) {
        throw const FormatException('Invalid quiz report history timestamp');
      }
      final request = QuizReportV2Request.fromJson(item['request']);
      if ((jlptLevel != null && request.jlptLevel != jlptLevel) ||
          (quizType != null && request.quizType != quizType) ||
          !seen.add(request.clientEventId)) {
        throw const FormatException('Invalid quiz report history identity');
      }
      if (cursor != null &&
          _compareQuizReportV2HistoryKey(
                receivedAt,
                request.clientEventId,
                cursor.receivedAt,
                cursor.clientEventId,
              ) >=
              0) {
        throw const FormatException('Invalid quiz report history cursor page');
      }
      if (items.isNotEmpty) {
        final previous = items.last;
        if (_compareQuizReportV2HistoryKey(
              previous.receivedAt,
              previous.request.clientEventId,
              receivedAt,
              request.clientEventId,
            ) <=
            0) {
          throw const FormatException('Unordered quiz report history page');
        }
      }
      items.add(
        QuizReportV2HistoryEntry(
          receivedAt: receivedAt,
          request: request,
          response: request.decodeResponse(item['response']),
        ),
      );
    }

    final nextCursor = _decodeQuizReportV2HistoryCursor(json['next_cursor']);
    if (nextCursor != null) {
      if (items.length != limit || items.isEmpty) {
        throw const FormatException('Invalid quiz report history continuation');
      }
      final last = items.last;
      if (nextCursor.receivedAt != last.receivedAt ||
          nextCursor.clientEventId != last.request.clientEventId) {
        throw const FormatException('Invalid quiz report history continuation');
      }
    }
    return QuizReportV2HistoryPage._(
      items: items,
      nextCursor: nextCursor,
    );
  }
}
