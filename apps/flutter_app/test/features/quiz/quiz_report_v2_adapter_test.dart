import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/data/quiz_report_v2_adapter.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';

String _id(int value) =>
    'a2000000-0000-4000-8000-${value.toString().padLeft(12, "0")}';
String _event(int value) =>
    'a3000000-0000-4000-8000-${value.toString().padLeft(12, "0")}';

Map<String, Object?> _answer(
  int start, {
  int selectedOffset = 0,
  int targetVersion = 1,
  List<int>? versions,
  bool legacy = false,
}) => {
  'item_id': _id(start),
  'content_version': targetVersion,
  'selected_id': _id(start + selectedOffset),
  'choices': [_id(start), _id(start + 1), _id(start + 2), _id(start + 3)],
  if (!legacy) 'choice_content_versions': versions ?? [targetVersion, 1, 2, 1],
};

VocabularyQuizAttempt _vocabulary({int formatVersion = 2}) =>
    VocabularyQuizAttempt.fromJson({
      'format_version': formatVersion,
      'event_id': _event(1),
      'level': 'N4',
      'completed_at': '2026-11-10T05:00:00.123456Z',
      'answers': [
        _answer(
          1,
          targetVersion: 2,
          versions: [2, 1, 2, 1],
          selectedOffset: 0,
          legacy: formatVersion == 1,
        ),
        _answer(
          5,
          versions: [1, 3, 1, 2],
          selectedOffset: 1,
          legacy: formatVersion == 1,
        ),
      ],
    });

GrammarQuizAttempt _grammar({int formatVersion = 2, String kind = 'primary'}) =>
    GrammarQuizAttempt.fromJson({
      'format_version': formatVersion,
      'quiz_type': 'grammar_meaning',
      'practice_kind': kind,
      'event_id': _event(2),
      'level': 'N5',
      'completed_at': '2026-11-10T05:00:00.123456Z',
      'answers': [
        _answer(
          11,
          targetVersion: 3,
          versions: [3, 1, 2, 1],
          selectedOffset: 2,
          legacy: formatVersion == 1,
        ),
      ],
    });

Map<String, Object?> _response(QuizReportV2Request request) => {
  'client_event_id': request.clientEventId,
  'quiz_type': request.quizType,
  'practice_kind': request.practiceKind,
  'jlpt_level': request.jlptLevel,
  'completed_at': request.completedAt,
  'answer_count': request.answers.length,
  'correct_count': request.answers.where((answer) => answer.isCorrect).length,
};

void main() {
  test('maps vocabulary v2 attempts without owner or derived fields', () {
    final attempt = _vocabulary();
    final request = QuizReportV2Request.fromVocabularyAttempt(attempt);
    final json = request.toJson();

    expect(json.keys.toSet(), {
      'client_event_id',
      'quiz_type',
      'practice_kind',
      'jlpt_level',
      'completed_at',
      'answers',
    });
    expect(json['client_event_id'], attempt.eventId);
    expect(json['quiz_type'], 'vocabulary_reading');
    expect(json['practice_kind'], isNull);
    expect(json['jlpt_level'], 'N4');
    expect(json['completed_at'], '2026-11-10T05:00:00.123456Z');
    expect(json['answers'], [
      {
        'item_id': _id(1),
        'content_version': 2,
        'selected_id': _id(1),
        'choices': [_id(1), _id(2), _id(3), _id(4)],
        'choice_content_versions': [2, 1, 2, 1],
      },
      {
        'item_id': _id(5),
        'content_version': 1,
        'selected_id': _id(6),
        'choices': [_id(5), _id(6), _id(7), _id(8)],
        'choice_content_versions': [1, 3, 1, 2],
      },
    ]);
    expect(json.keys, isNot(contains('owner_id')));
    expect(json.keys, isNot(contains('score')));
    expect(json.keys, isNot(contains('duration_ms')));
    expect(request.answers, hasLength(2));
  });

  test(
    'maps grammar primary and correction attempts with captured choice versions',
    () {
      for (final kind in ['primary', 'correction']) {
        final attempt = _grammar(kind: kind);
        final request = QuizReportV2Request.fromGrammarAttempt(attempt);
        expect(request.quizType, 'grammar_meaning');
        expect(request.practiceKind, kind);
        expect(request.answers.single.choiceContentVersions, [3, 1, 2, 1]);
        expect(request.toJson()['practice_kind'], kind);
        expect(request.answers.single.choices, [
          _id(11),
          _id(12),
          _id(13),
          _id(14),
        ]);
      }
    },
  );

  test('rejects legacy v1 attempts without displayed choice versions', () {
    expect(
      () => QuizReportV2Request.fromVocabularyAttempt(
        _vocabulary(formatVersion: 1),
      ),
      throwsFormatException,
    );
    expect(
      () => QuizReportV2Request.fromGrammarAttempt(_grammar(formatVersion: 1)),
      throwsFormatException,
    );
  });

  test('correlates response identity and counts to the captured request', () {
    final request = QuizReportV2Request.fromVocabularyAttempt(_vocabulary());
    final response = request.decodeResponse(_response(request));
    expect(response.answerCount, 2);
    expect(response.correctCount, 1);
  });

  test('rejects response identity, shape and count mismatches', () {
    final request = QuizReportV2Request.fromGrammarAttempt(_grammar());
    final changedEvent = _response(request)..['client_event_id'] = _event(9);
    expect(() => request.decodeResponse(changedEvent), throwsFormatException);

    final changedKind = _response(request)..['practice_kind'] = 'correction';
    expect(() => request.decodeResponse(changedKind), throwsFormatException);

    final changedCounts = _response(request)..['correct_count'] = 1;
    expect(() => request.decodeResponse(changedCounts), throwsFormatException);

    final extraField = _response(request)..['owner_id'] = _id(99);
    expect(() => request.decodeResponse(extraField), throwsFormatException);

    final missingField = _response(request)..remove('completed_at');
    expect(() => request.decodeResponse(missingField), throwsFormatException);
  });

  test(
    'keeps request and answer snapshots immutable while returning fresh JSON',
    () {
      final request = QuizReportV2Request.fromVocabularyAttempt(_vocabulary());
      expect(() => request.answers.clear(), throwsUnsupportedError);
      expect(
        () => request.answers.first.choices.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => request.answers.first.choiceContentVersions.clear(),
        throwsUnsupportedError,
      );
      final wire = request.toJson();
      (wire['answers'] as List<Object?>).clear();
      expect(request.answers, hasLength(2));
    },
  );
}
