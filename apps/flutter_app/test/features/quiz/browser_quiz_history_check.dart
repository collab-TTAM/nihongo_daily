import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/data/browser_quiz_history_journal.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_progress.dart';

const _ownerA = 'a1000000-0000-4000-8000-000000000001';
const _ownerB = 'a1000000-0000-4000-8000-000000000002';
const _target = 'a2000000-0000-4000-8000-000000000001';
const _wrong = 'a2000000-0000-4000-8000-000000000002';
const _third = 'a2000000-0000-4000-8000-000000000003';
const _fourth = 'a2000000-0000-4000-8000-000000000004';

String _eventId(int number) =>
    'a3000000-0000-4000-8000-' + number.toString().padLeft(12, '0');

String _databaseName(String kind, int sequence) =>
    'nd-' + kind + '-' + DateTime.now().microsecondsSinceEpoch.toString() +
    '-' + sequence.toString();

VocabularyQuizAttempt _vocabularyAttempt(
  int number, {
  bool correct = false,
}) => VocabularyQuizAttempt.fromJson({
  'format_version': 1,
  'event_id': _eventId(number),
  'level': 'N5',
  'completed_at': DateTime.utc(2026, 11, 6, 15, number).toIso8601String(),
  'answers': [
    {
      'item_id': _target,
      'content_version': 1,
      'selected_id': correct ? _target : _wrong,
      'choices': [_target, _wrong, _third, _fourth],
    },
  ],
});

GrammarQuizAttempt _grammarAttempt(
  int number, {
  bool correct = false,
  GrammarQuizAttemptKind kind = GrammarQuizAttemptKind.primary,
}) => GrammarQuizAttempt.fromJson({
  'format_version': 1,
  'quiz_type': 'grammar_meaning',
  'practice_kind': kind.name,
  'event_id': _eventId(number),
  'level': 'N5',
  'completed_at': DateTime.utc(2026, 11, 6, 15, number).toIso8601String(),
  'answers': [
    {
      'item_id': _target,
      'content_version': 1,
      'selected_id': correct ? _target : _wrong,
      'choices': [_target, _wrong, _third, _fourth],
    },
  ],
});

void main() {
  var sequence = 0;
  String name(String kind) => _databaseName(kind, sequence++);

  test('browser vocabulary journal serializes two real IndexedDB connections',
      () async {
    final database = name('vocabulary');
    final first = await openBrowserVocabularyQuizJournal(
      databaseName: database,
    );
    final second = await openBrowserVocabularyQuizJournal(
      databaseName: database,
    );
    try {
      final original = _vocabularyAttempt(1);
      final saved = await Future.wait([
        first.append(_ownerA, original),
        second.append(
          _ownerA,
          VocabularyQuizAttempt.fromJson(original.toJson()),
        ),
        first.append(_ownerA, _vocabularyAttempt(2, correct: true)),
        second.append(_ownerB, _vocabularyAttempt(1, correct: true)),
      ]);
      expect(saved, hasLength(4));
      expect(
        saved.take(2).every(
          (record) => sameVocabularyQuizAttempt(record.attempt, original),
        ),
        isTrue,
      );
      expect(await first.list(_ownerA), hasLength(2));
      expect(await second.list(_ownerB), hasLength(1));
      expect(
        (await second.list(_ownerA)).every(
          (record) => record.ownerId == _ownerA,
        ),
        isTrue,
      );
      await expectLater(
        first.list(_ownerA).then((rows) => rows.clear()),
        throwsUnsupportedError,
      );
      await expectLater(
        second.append(_ownerA, _vocabularyAttempt(1, correct: true)),
        throwsA(isA<VocabularyQuizHistoryConflict>()),
      );
      expect(await first.list(_ownerA), hasLength(2));
    } finally {
      await first.close();
      await second.close();
    }
    final restored = await openBrowserVocabularyQuizJournal(
      databaseName: database,
    );
    try {
      final rows = await restored.list(_ownerA);
      expect(rows, hasLength(2));
      expect(rows.first.attempt.eventId, _eventId(1));
      expect(rows.last.attempt.score, 1);
      expect(await restored.list(_ownerB), hasLength(1));
    } finally {
      await restored.close();
    }
  });

  test('browser vocabulary journal drains accepted writes before close',
      () async {
    final database = name('vocabulary-drain');
    final journal = await openBrowserVocabularyQuizJournal(
      databaseName: database,
    );
    final first = journal.append(_ownerA, _vocabularyAttempt(1));
    final second = journal.append(_ownerA, _vocabularyAttempt(2));
    final closing = journal.close();
    await expectLater(
      journal.list(_ownerA),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    await Future.wait([first, second]);
    await closing;
    final restored = await openBrowserVocabularyQuizJournal(
      databaseName: database,
    );
    try {
      expect(await restored.list(_ownerA), hasLength(2));
    } finally {
      await restored.close();
    }
  });

  test('browser grammar journal preserves primary and correction attempts',
      () async {
    final database = name('grammar');
    var journal = await openBrowserGrammarQuizJournal(
      databaseName: database,
    );
    try {
      await journal.append(
        _ownerA,
        _grammarAttempt(1, kind: GrammarQuizAttemptKind.primary),
      );
      await journal.append(
        _ownerA,
        _grammarAttempt(2, kind: GrammarQuizAttemptKind.correction),
      );
      await journal.append(
        _ownerB,
        _grammarAttempt(1, correct: true),
      );
      final rows = await journal.list(_ownerA);
      expect(rows.map((row) => row.attempt.kind), [
        GrammarQuizAttemptKind.primary,
        GrammarQuizAttemptKind.correction,
      ]);
      expect(rows.every((row) => row.ownerId == _ownerA), isTrue);
      await expectLater(
        journal.append(_ownerA, _grammarAttempt(1, correct: true)),
        throwsA(isA<GrammarQuizHistoryConflict>()),
      );
      await journal.close();
      journal = await openBrowserGrammarQuizJournal(
        databaseName: database,
      );
      final restored = await journal.list(_ownerA);
      expect(restored, hasLength(2));
      expect(restored.last.attempt.kind, GrammarQuizAttemptKind.correction);
      expect(await journal.list(_ownerB), hasLength(1));
    } finally {
      await journal.close();
    }
  });

  test('browser quiz journals reject invalid database names safely', () async {
    await expectLater(
      openBrowserVocabularyQuizJournal(databaseName: '../private'),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    await expectLater(
      openBrowserGrammarQuizJournal(databaseName: '../private'),
      throwsA(isA<GrammarQuizStorageFailure>()),
    );
  });
}
