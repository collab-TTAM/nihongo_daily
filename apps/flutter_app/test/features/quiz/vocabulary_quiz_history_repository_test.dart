import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/data/native_vocabulary_quiz_journal.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_progress.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

import 'quiz_history_store_fixtures.dart';
import 'quiz_journal_fixtures.dart';

final class _QuizAuth implements ReviewAuth {
  ReviewSession? session = ReviewSession(userId: quizOwner);
  bool fail = false;

  @override
  ReviewSession? get currentSession {
    if (fail) throw StateError('PRIVATE AUTH TOKEN');
    return session;
  }
}

void main() {
  late Directory directory;
  late NativeVocabularyQuizJournal journal;
  late ControlledQuizStore store;
  late _QuizAuth auth;
  late VocabularyQuizOperationDrain operations;
  var ready = true;
  var readinessFailure = false;
  final changed = throwsA(isA<VocabularyQuizSessionChanged>());
  final storage = throwsA(isA<VocabularyQuizStorageFailure>());
  final conflict = throwsA(isA<VocabularyQuizHistoryConflict>());

  VocabularyQuizHistoryRepository repository() =>
      VocabularyQuizHistoryRepository(
        auth: auth,
        store: store,
        operations: operations,
        isReady: () {
          if (readinessFailure) throw StateError('PRIVATE READY TOKEN');
          return ready;
        },
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nd-quiz-session-');
    journal = await NativeVocabularyQuizJournal.open(directory);
    store = ControlledQuizStore(journal);
    auth = _QuizAuth();
    operations = VocabularyQuizOperationDrain();
    ready = true;
    readinessFailure = false;
  });

  tearDown(() async {
    store.release();
    await operations.revokeAndDrain();
    await journal.close();
    await directory.delete(recursive: true);
  });

  test('construction requires ready Auth and open lifetime', () async {
    ready = false;
    expect(repository, changed);
    ready = true;
    auth.session = null;
    expect(repository, changed);
    auth.fail = true;
    expect(repository, changed);
    auth.fail = false;
    auth.session = ReviewSession(userId: quizOwner);
    readinessFailure = true;
    expect(repository, changed);
    readinessFailure = false;
    await operations.revokeAndDrain();
    expect(repository, changed);
    expect(store.appends + store.loads, 0);
  });

  test('save and load isolate immutable owner data', () async {
    final service = repository();
    final event = quizReport(1);
    final saved = await service.save(event);
    await journal.append(quizOther, quizReport(1, correct: true));
    final history = await service.load();
    expect(saved.ownerId, quizOwner);
    expect(sameVocabularyQuizAttempt(saved.attempt, event), isTrue);
    expect(history.single.ownerId, quizOwner);
    expect(history.single.attempt.score, 0);
    expect(store.owners.every((owner) => owner == quizOwner), isTrue);
    expect(() => history.clear(), throwsUnsupportedError);
    expect(
      () => history.single.attempt.answers.clear(),
      throwsUnsupportedError,
    );
    expect((await journal.list(quizOther)).single.attempt.score, 1);
  });

  test('concurrent replay shares one original dispatch', () async {
    final service = repository();
    final event = quizReport(1);
    store.appendWait = Completer<void>();
    store.appended = Completer<void>();
    final first = service.save(event);
    final second = service.save(event);
    expect(identical(first, second), isTrue);
    await expectLater(service.save(quizReport(1, correct: true)), conflict);
    await store.appended!.future.timeout(const Duration(seconds: 5));
    expect(store.appends, 1);
    store.appendWait!.complete();
    final saved = await first;
    expect(identical(saved, await second), isTrue);
    final size = await quizData(directory).length();
    await service.save(event);
    expect(await quizData(directory).length(), size);
  });

  test('reentrant save shares the registered dispatch', () async {
    final service = repository();
    final event = quizReport(1);
    Future<OwnedVocabularyQuizAttempt>? reentered;
    store.onAppend = () => reentered = service.save(event);
    final first = service.save(event);
    await first;
    expect(identical(first, reentered), isTrue);
    expect(store.appends, 1);
    expect(await journal.list(quizOwner), hasLength(1));
  });

  test('load copies sorts and deduplicates history', () async {
    final first = VocabularyQuizAttempt.fromJson({
      ...quizReport(1).toJson(),
      'completed_at': '2026-10-20T00:02:00.000Z',
    });
    final a = OwnedVocabularyQuizAttempt(quizOwner, first);
    final b = OwnedVocabularyQuizAttempt(quizOwner, quizReport(2));
    final c = OwnedVocabularyQuizAttempt(quizOwner, quizReport(3));
    final input = [a, c, b, c];
    store.listOverride = input;
    final history = await repository().load();
    expect(history.map((record) => record.attempt.eventId), [
      b.attempt.eventId,
      c.attempt.eventId,
      a.attempt.eventId,
    ]);
    input.clear();
    expect(history, hasLength(3));
    expect(() => history.clear(), throwsUnsupportedError);
  });

  test('load rejects mixed owners and oversized history', () async {
    final local = OwnedVocabularyQuizAttempt(quizOwner, quizReport(1));
    final foreign = OwnedVocabularyQuizAttempt(
      quizOther,
      quizReport(1, correct: true),
    );
    final service = repository();
    store.listOverride = [local, foreign];
    await expectLater(service.load(), storage);
    store.listOverride = List.filled(10001, local);
    await expectLater(service.load(), storage);
    store.listOverride = [];
    expect(await service.load(), isEmpty);
  });

  test('conflicting stored replay fails atomically', () async {
    store.listOverride = [
      OwnedVocabularyQuizAttempt(quizOwner, quizReport(1)),
      OwnedVocabularyQuizAttempt(quizOwner, quizReport(1, correct: true)),
    ];
    await expectLater(repository().load(), conflict);
  });

  test('save rejects a foreign or changed return', () async {
    final service = repository();
    for (final wrong in [
      OwnedVocabularyQuizAttempt(quizOther, quizReport(1)),
      OwnedVocabularyQuizAttempt(quizOwner, quizReport(2)),
      OwnedVocabularyQuizAttempt(quizOwner, quizReport(1, correct: true)),
    ]) {
      store.appendOverride = wrong;
      await expectLater(service.save(quizReport(1)), storage);
    }
    store.appendOverride = null;
    final saved = await service.save(quizReport(1));
    expect(saved.attempt.score, 0);
    expect(await journal.list(quizOwner), hasLength(1));
  });

  test('storage errors are redacted and exact retry works', () async {
    final service = repository();
    for (final synchronous in [true, false]) {
      store.synchronousFailure = synchronous;
      store.appendFailure = StateError('PRIVATE FILE PATH');
      store.listFailure = StateError('PRIVATE FILE PATH');
      for (final operation in <Future<Object?> Function()>[
        () => service.save(quizReport(1)),
        () => service.load(),
      ]) {
        Object? failure;
        try {
          await operation();
        } on Object catch (error) {
          failure = error;
        }
        expect(failure, isA<VocabularyQuizStorageFailure>());
        expect(failure.toString(), isNot(contains('PRIVATE')));
        expect(failure.toString(), isNot(contains(directory.path)));
      }
    }
    store.appendFailure = null;
    store.listFailure = null;
    final size = await quizData(directory).length();
    await service.save(quizReport(1));
    expect(await quizData(directory).length(), size);
    expect(await service.load(), hasLength(1));
  });

  test('late A save remains on disk and is hidden from B', () async {
    final old = repository();
    store.appendWait = Completer<void>();
    store.appended = Completer<void>();
    final saving = expectLater(old.save(quizReport(1)), changed);
    await store.appended!.future.timeout(const Duration(seconds: 5));
    auth.session = ReviewSession(userId: quizOther);
    store.appendWait!.complete();
    await saving;
    expect(await repository().load(), isEmpty);
    await expectLater(old.load(), changed);
    auth.session = ReviewSession(userId: quizOwner);
    final fresh = repository();
    expect((await fresh.load()).single.attempt.eventId, quizReport(1).eventId);
    await expectLater(old.load(), changed);
  });

  test('late failed read prioritizes session revocation', () async {
    final service = repository();
    store.listWait = Completer<void>();
    store.listed = Completer<void>();
    store.listFailure = StateError('PRIVATE FILE PATH');
    final loading = expectLater(service.load(), changed);
    await store.listed!.future.timeout(const Duration(seconds: 5));
    auth.session = null;
    store.listWait!.complete();
    await loading;
    expect(store.loads, 1);
  });

  test('same-user replacement invalidates the old lease', () async {
    final old = repository();
    await old.save(quizReport(1));
    auth.session = ReviewSession(userId: quizOwner);
    final before = store.appends + store.loads;
    await expectLater(old.load(), changed);
    await expectLater(old.save(quizReport(2)), changed);
    expect(store.appends + store.loads, before);
    expect(await repository().load(), hasLength(1));
  });

  test('readiness and getter failures revoke permanently', () async {
    final old = repository();
    ready = false;
    await expectLater(old.load(), changed);
    ready = true;
    await expectLater(old.load(), changed);
    final next = repository();
    readinessFailure = true;
    await expectLater(next.save(quizReport(1)), changed);
    readinessFailure = false;
    await expectLater(next.load(), changed);
    final another = repository();
    auth.fail = true;
    await expectLater(another.load(), changed);
    auth.fail = false;
    await expectLater(another.load(), changed);
    expect(store.appends + store.loads, 0);
  });

  test('close revokes publication and drains a held durable write', () async {
    final service = repository();
    store.appendWait = Completer<void>();
    store.appended = Completer<void>();
    final saving = expectLater(service.save(quizReport(1)), changed);
    await store.appended!.future.timeout(const Duration(seconds: 5));
    var closed = false;
    final closing = operations.revokeAndDrain();
    expect(identical(closing, operations.revokeAndDrain()), isTrue);
    final observing = closing.then((_) => closed = true);
    expect(operations.isClosing, isTrue);
    await expectLater(service.load(), changed);
    await expectLater(service.save(quizReport(2)), changed);
    await Future<void>.value();
    expect(closed, isFalse);
    final retained = (await journal.list(quizOwner)).single;
    expect(retained.attempt.eventId, quizReport(1).eventId);
    store.appendWait!.complete();
    await saving;
    await observing;
    expect(closed, isTrue);
    expect(store.appends, 1);
    await journal.close();
    journal = await NativeVocabularyQuizJournal.open(directory);
    expect(await journal.list(quizOwner), hasLength(1));
  });
  test('close prevents queued operations from reaching storage', () async {
    final service = repository();
    final saving = expectLater(service.save(quizReport(1)), changed);
    final loading = expectLater(service.load(), changed);
    final closing = operations.revokeAndDrain();
    await saving;
    await loading;
    await closing;
    expect(store.appends + store.loads, 0);
    expect(await journal.list(quizOwner), isEmpty);
  });
}
