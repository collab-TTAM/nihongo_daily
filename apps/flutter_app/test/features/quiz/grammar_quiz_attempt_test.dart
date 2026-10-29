// Synthetic local reports, not hosted attempts or mastery evidence.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import 'grammar_quiz_test.dart' show sample;

const event = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
final completed = DateTime.utc(2026, 10, 29, 20);
String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
GrammarQuizRound round({PreviewLevel level = PreviewLevel.n5}) =>
    GrammarQuizRound(
      buildGrammarQuiz([
        for (var i = 0; i < 4; i++)
          sample(i, id: id(i), level: level, version: i + 1),
      ], level),
    );

GrammarQuizAttempt capture({
  PreviewLevel level = PreviewLevel.n5,
  GrammarQuizAttemptKind kind = GrammarQuizAttemptKind.primary,
}) {
  final practice = round(level: level);
  var index = 0;
  while (!practice.isComplete) {
    final q = practice.current!;
    final choice = index.isEven
        ? q.target.id
        : q.choices.firstWhere((c) => c.id != q.target.id).id;
    expect(practice.answer(q.id, choice), isTrue);
    expect(practice.answer(q.id, q.target.id), isFalse);
    expect(practice.advance(q.id), isTrue);
    index++;
  }
  return GrammarQuizAttempt.capture(
    eventId: event,
    completedAt: completed,
    round: practice,
    kind: kind,
  );
}

Map<String, Object?> record() =>
    jsonDecode(jsonEncode(capture().toJson())) as Map<String, Object?>;
List<dynamic> answers(Map<String, Object?> json) => json['answers'] as List;

void main() {
  test(
    'grammar attempt captures exact first answers versions and choice order',
    () {
      final attempt = capture();
      final questions = round().questions;
      expect(attempt.eventId, event);
      expect(attempt.completedAt, completed);
      expect(attempt.score, 2);
      expect(attempt.answers, hasLength(4));
      for (var i = 0; i < 4; i++) {
        final answer = attempt.answers[i];
        expect(answer.itemId, questions[i].target.id);
        expect(answer.contentVersion, i + 1);
        expect(answer.choices, questions[i].choices.map((c) => c.id).toList());
        expect(answer.isCorrect, i.isEven);
      }
    },
  );

  test(
    'grammar attempt round trips both levels and explicit practice kinds',
    () {
      for (final level in PreviewLevel.values) {
        for (final kind in GrammarQuizAttemptKind.values) {
          final original = capture(level: level, kind: kind);
          final decoded = GrammarQuizAttempt.fromJson(
            jsonDecode(jsonEncode(original.toJson())),
          );
          expect(decoded.level, level);
          expect(decoded.kind, kind);
          expect(decoded.score, 2);
          expect(sameGrammarQuizAttempt(original, decoded), isTrue);
        }
      }
    },
  );

  test('grammar capture rejects empty unanswered and unadvanced rounds', () {
    final partial = round();
    final q = partial.current!;
    partial.answer(q.id, q.target.id);
    for (final practice in [GrammarQuizRound([]), round(), partial]) {
      expect(
        () => GrammarQuizAttempt.capture(
          eventId: event,
          completedAt: completed,
          round: practice,
          kind: GrammarQuizAttemptKind.primary,
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'grammar record rejects missing unknown and derived or owner fields',
    () {
      for (final key in record().keys) {
        final json = record()..remove(key);
        expect(() => GrammarQuizAttempt.fromJson(json), throwsFormatException);
      }
      for (final key in [
        'score',
        'owner_id',
        'question_text',
        'mastery',
        'extra',
      ]) {
        final json = record()..[key] = 'TEST ONLY';
        expect(() => GrammarQuizAttempt.fromJson(json), throwsFormatException);
      }
    },
  );

  test(
    'grammar record cannot be confused with vocabulary or unknown practice',
    () {
      final vocabulary = record()
        ..remove('quiz_type')
        ..remove('practice_kind');
      expect(VocabularyQuizAttempt.fromJson(vocabulary).score, 2);
      expect(
        () => GrammarQuizAttempt.fromJson(vocabulary),
        throwsFormatException,
      );
      expect(
        () => VocabularyQuizAttempt.fromJson(record()),
        throwsFormatException,
      );
      for (final value in ['vocabulary', 'GRAMMAR', null, 1]) {
        final json = record()..['quiz_type'] = value;
        expect(() => GrammarQuizAttempt.fromJson(json), throwsFormatException);
      }
      for (final value in ['mastered', '', null, true]) {
        final json = record()..['practice_kind'] = value;
        expect(() => GrammarQuizAttempt.fromJson(json), throwsFormatException);
      }
    },
  );

  test('grammar record rejects invalid version level and answer count', () {
    for (final value in [0, 2, 1.0, true, '1', null]) {
      final json = record()..['format_version'] = value;
      expect(() => GrammarQuizAttempt.fromJson(json), throwsFormatException);
    }
    for (final value in ['N3', 'n5', null, 5]) {
      final json = record()..['level'] = value;
      expect(() => GrammarQuizAttempt.fromJson(json), throwsFormatException);
    }
    for (final value in [
      null,
      <Object?>[],
      List.filled(11, answers(record()).first),
    ]) {
      final json = record()..['answers'] = value;
      expect(() => GrammarQuizAttempt.fromJson(json), throwsFormatException);
    }
  });

  test(
    'grammar record rejects duplicate targets and invalid answer structure',
    () {
      final duplicate = record();
      answers(duplicate)[1] = answers(duplicate)[0];
      expect(
        () => GrammarQuizAttempt.fromJson(duplicate),
        throwsFormatException,
      );
      for (final key in [
        'item_id',
        'content_version',
        'selected_id',
        'choices',
      ]) {
        final json = record();
        (answers(json).first as Map).remove(key);
        expect(() => GrammarQuizAttempt.fromJson(json), throwsFormatException);
      }
      final unknown = record();
      (answers(unknown).first as Map)['is_correct'] = true;
      expect(() => GrammarQuizAttempt.fromJson(unknown), throwsFormatException);
      for (final version in [0, -1, 2147483648, 1.0, true, '1', null]) {
        final json = record();
        (answers(json).first as Map)['content_version'] = version;
        expect(() => GrammarQuizAttempt.fromJson(json), throwsFormatException);
      }
    },
  );

  test(
    'grammar record rejects missing target foreign selection and repeated choices',
    () {
      for (final choices in [
        [id(1), id(2), id(3), id(4)],
        [id(0), id(1), id(2), id(2)],
        [id(0), id(1), id(2)],
        [id(0), id(1), id(2), id(3), id(4)],
        [id(0), id(1), id(2), 'TEST ONLY invalid'],
      ]) {
        final json = record();
        (answers(json).first as Map)['choices'] = choices;
        expect(() => GrammarQuizAttempt.fromJson(json), throwsFormatException);
      }
      final foreign = record();
      (answers(foreign).first as Map)['selected_id'] = id(99);
      expect(() => GrammarQuizAttempt.fromJson(foreign), throwsFormatException);
    },
  );

  test(
    'grammar record requires canonical identity and bounded UTC instant',
    () {
      for (final value in [event.toUpperCase(), 'not-an-id', '', null, 1]) {
        final json = record()..['event_id'] = value;
        expect(() => GrammarQuizAttempt.fromJson(json), throwsFormatException);
      }
      for (final value in [
        '2026-10-29T20:00:00Z',
        '2026-10-29T20:00:00.000+00:00',
        '1999-12-31T00:00:00.000Z',
        '2101-01-01T00:00:00.000Z',
        'TEST ONLY private time',
        null,
      ]) {
        final json = record()..['completed_at'] = value;
        expect(() => GrammarQuizAttempt.fromJson(json), throwsFormatException);
      }
    },
  );

  test('grammar attempt detaches input output and immutable nested lists', () {
    final json = record();
    final attempt = GrammarQuizAttempt.fromJson(json);
    (answers(json).first as Map)['selected_id'] = id(99);
    ((answers(json).first as Map)['choices'] as List).clear();
    expect(attempt.score, 2);
    expect(attempt.answers.first.choices, hasLength(4));
    expect(() => attempt.answers.clear(), throwsUnsupportedError);
    expect(() => attempt.answers.first.choices.clear(), throwsUnsupportedError);
    final output = attempt.toJson();
    answers(output).clear();
    expect(attempt.answers, hasLength(4));
    expect(sameGrammarQuizAttempt(attempt, capture()), isTrue);
  });

  test(
    'grammar equality includes event time kind version choice order and answers',
    () {
      final original = capture();
      for (final field in ['event_id', 'completed_at', 'practice_kind']) {
        final json = record();
        json[field] = switch (field) {
          'event_id' => id(99),
          'completed_at' =>
            completed.add(const Duration(seconds: 1)).toIso8601String(),
          _ => 'correction',
        };
        expect(
          sameGrammarQuizAttempt(original, GrammarQuizAttempt.fromJson(json)),
          isFalse,
        );
      }
      for (final mode in ['version', 'order', 'answer']) {
        final json = record();
        final first = answers(json).first as Map;
        if (mode == 'version') first['content_version'] = 2;
        if (mode == 'order')
          first['choices'] = (first['choices'] as List).reversed.toList();
        if (mode == 'answer') first['selected_id'] = id(1);
        expect(
          sameGrammarQuizAttempt(original, GrammarQuizAttempt.fromJson(json)),
          isFalse,
        );
      }
    },
  );
  test(
    'grammar record accepts ten unique targets and maximum integer version',
    () {
      final json = record();
      json['answers'] = [
        for (var i = 0; i < 10; i++)
          {
            'item_id': id(i),
            'content_version': 2147483647,
            'selected_id': id(i),
            'choices': [id(i), id(i + 1), id(i + 2), id(i + 3)],
          },
      ];
      final attempt = GrammarQuizAttempt.fromJson(json);
      expect(attempt.answers, hasLength(10));
      expect(attempt.score, 10);
    },
  );
}
