// TEST ONLY pinned SDK + simulated HTTP/vault and real disposable quiz files.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/quiz/data/native_vocabulary_quiz_journal.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_history_repository.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';

import '../srs/own_profile_fixtures.dart' as profile;
import '../srs/session_lifecycle_fixtures.dart' as fixture;
import '../srs/supabase_review_binding_test.dart' as wire;
import 'quiz_history_store_fixtures.dart';
import 'quiz_journal_fixtures.dart';

void main() {
  late Directory directory;
  late NativeReviewJournal reviews;
  late NativeVocabularyQuizJournal journal;
  late ControlledQuizStore store;
  late fixture.MemoryVault backend;
  late MockClient network;
  late PersistentSupabaseRuntime runtime;
  late DateTime now;
  late String secret;
  Completer<http.Response>? profileWait;
  Completer<void>? profileEntered;
  final requests = <http.Request>[];
  final changed = throwsA(isA<VocabularyQuizSessionChanged>());

  http.Response ownProfile() => http.Response(
    jsonEncode(profile.profile(wire.a)),
    200,
    headers: {'content-type': 'application/json'},
  );

  PersistentSupabaseRuntime buildRuntime({bool withQuiz = true}) =>
      PersistentSupabaseRuntime(
        projectUrl: wire.origin,
        publishableKey: wire.key,
        vault: SessionCredentialVault(
          projectUrl: wire.origin,
          backend: backend,
        ),
        store: reviews,
        quizStore: withQuiz ? store : null,
        httpClient: network,
        now: () => now,
      );

  Future<void> until(bool Function() condition) async {
    final elapsed = Stopwatch()..start();
    while (!condition() && elapsed.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(condition(), isTrue, reason: 'Bounded SDK state did not settle');
  }

  Future<void> ready() async {
    await until(() => runtime.account.state.phase == AccountPhase.ready);
    expect(runtime.createVocabularyQuizHistoryRepository(), isNotNull);
  }

  Future<void> login() async {
    await runtime.account.signIn(
      'fixture@example.invalid',
      'TEST_ONLY_PASSWORD',
    );
    await ready();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nd-quiz-sdk-');
    reviews = await NativeReviewJournal.open(directory);
    journal = await NativeVocabularyQuizJournal.open(directory);
    store = ControlledQuizStore(journal);
    backend = fixture.MemoryVault();
    now = DateTime.utc(2026, 10, 14, 3);
    secret = 'TEST_ONLY_QUIZ_ROTATION_1';
    profileWait = null;
    profileEntered = null;
    requests.clear();
    network = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/auth/v1/token') {
        return http.Response(
          jsonEncode({
            'access_token': wire.token(wire.a, wire.sid1, now),
            'refresh_token': secret,
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': wire.a,
              'aud': 'authenticated',
              'role': 'authenticated',
              'created_at': '2026-10-14T00:00:00Z',
              'app_metadata': <String, Object>{},
              'user_metadata': <String, Object>{},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/auth/v1/logout') return http.Response('', 204);
      if (request.url.path == '/rest/v1/rpc/ensure_profile') {
        if (!(profileEntered?.isCompleted ?? true)) profileEntered!.complete();
        return profileWait?.future ?? Future.value(ownProfile());
      }
      throw StateError('Unexpected TEST ONLY quiz HTTP request');
    });
    runtime = buildRuntime();
  });

  tearDown(() async {
    store.release();
    final write = backend.writeWait;
    if (write != null && !write.isCompleted) write.complete();
    if (profileWait != null && !profileWait!.isCompleted) {
      profileWait!.complete(ownProfile());
    }
    await runtime.close();
    await journal.close();
    await reviews.close();
    await directory.delete(recursive: true);
    network.close();
  });

  test('factory waits for persisted secret and own profile', () async {
    expect(runtime.createVocabularyQuizHistoryRepository(), isNull);
    backend.secret = 'TEST_ONLY_SAVED_QUIZ';
    backend.writeWait = Completer<void>();
    profileWait = Completer<http.Response>();
    profileEntered = Completer<void>();
    final starting = runtime.start();
    await until(() => backend.writes == 1);
    expect(runtime.createVocabularyQuizHistoryRepository(), isNull);
    expect(requests.where((r) => r.url.path.startsWith('/rest/v1/')), isEmpty);
    backend.writeWait!.complete();
    await starting;
    await profileEntered!.future.timeout(const Duration(seconds: 5));
    expect(backend.secret, secret);
    expect(runtime.createVocabularyQuizHistoryRepository(), isNull);
    profileWait!.complete(ownProfile());
    await ready();
    final service = runtime.createVocabularyQuizHistoryRepository()!;
    final before = requests.length;
    final saved = await service.save(quizReport(1));
    expect(saved.ownerId, wire.a);
    final loaded = (await service.load()).single;
    expect(loaded.attempt.eventId, quizReport(1).eventId);
    expect(requests.length, before);
    expect(await journal.list(wire.a), hasLength(1));
  });

  test('omitted quiz store never manufactures a history source', () async {
    await runtime.close();
    runtime = buildRuntime(withQuiz: false);
    await runtime.start();
    await runtime.account.signIn(
      'fixture@example.invalid',
      'TEST_ONLY_PASSWORD',
    );
    await until(() => runtime.account.state.phase == AccountPhase.ready);
    expect(runtime.createVocabularyQuizHistoryRepository(), isNull);
    expect(store.appends + store.loads, 0);
    expect(await quizData(directory).length(), 0);
  });

  test('refresh barrier revokes the old ready-runtime lease', () async {
    await runtime.start();
    await login();
    final old = runtime.createVocabularyQuizHistoryRepository()!;
    await old.save(quizReport(1));
    final writes = backend.writes;
    secret = 'TEST_ONLY_QUIZ_ROTATION_2';
    backend.writeWait = Completer<void>();
    final rotation = runtime.refresh();
    await until(() => backend.writes > writes);
    expect(runtime.createVocabularyQuizHistoryRepository(), isNull);
    await expectLater(old.load(), changed);
    final calls = store.appends + store.loads;
    backend.writeWait!.complete();
    await rotation;
    await ready();
    await expectLater(old.save(quizReport(2)), changed);
    expect(store.appends + store.loads, calls);
    final fresh = runtime.createVocabularyQuizHistoryRepository()!;
    expect((await fresh.load()).single.attempt.eventId, quizReport(1).eventId);
    expect(backend.secret, secret);
  });

  test('logout and same-owner login require a fresh wrapper', () async {
    await runtime.start();
    await login();
    final old = runtime.createVocabularyQuizHistoryRepository()!;
    await old.save(quizReport(1));
    await runtime.account.signOut();
    expect(runtime.createVocabularyQuizHistoryRepository(), isNull);
    await login();
    await expectLater(old.load(), changed);
    final fresh = runtime.createVocabularyQuizHistoryRepository()!;
    expect((await fresh.load()).single.attempt.eventId, quizReport(1).eventId);
    expect(await journal.list(wire.b), isEmpty);
  });

  test('runtime close drains quiz work before caller releases store', () async {
    await runtime.start();
    await login();
    final service = runtime.createVocabularyQuizHistoryRepository()!;
    store.appendWait = Completer<void>();
    store.appended = Completer<void>();
    final saving = expectLater(service.save(quizReport(1)), changed);
    await store.appended!.future.timeout(const Duration(seconds: 5));
    var closed = false;
    final closing = runtime.close().then((_) => closed = true);
    expect(runtime.createVocabularyQuizHistoryRepository(), isNull);
    await expectLater(service.load(), changed);
    await Future<void>.value();
    expect(closed, isFalse);
    await expectLater(
      NativeVocabularyQuizJournal.open(directory),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    store.appendWait!.complete();
    await saving;
    await closing;
    expect(closed, isTrue);
    final retained = (await journal.list(wire.a)).single;
    expect(retained.attempt.eventId, quizReport(1).eventId);
    await journal.close();
    final reopened = await NativeVocabularyQuizJournal.open(directory);
    try {
      final recovered = (await reopened.list(wire.a)).single;
      expect(recovered.attempt.eventId, quizReport(1).eventId);
    } finally {
      await reopened.close();
    }
  });
}
