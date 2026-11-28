// TEST ONLY pinned SDK + simulated HTTP/vault and real disposable quiz files.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/app/staging_bootstrap.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_account_startup.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart';
import 'package:nihongo_daily/features/daily_plan/data/native_study_session_journal.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/data/native_grammar_quiz_journal.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_runtime.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';

import '../srs/own_profile_fixtures.dart' as profile;
import '../srs/session_lifecycle_fixtures.dart' as fixture;
import '../srs/supabase_review_binding_test.dart' as wire;
import 'native_grammar_quiz_journal_test.dart' show attempt;

File quizData(Directory directory) =>
    File('${directory.path}/grammar-quiz-attempts.ndjson');

void main() {
  late Directory directory;
  late NativeReviewJournal reviews;
  late NativeGrammarQuizJournal journal;
  late ControlledGrammarStore store;
  late fixture.MemoryVault backend;
  late MockClient network;
  late PersistentSupabaseRuntime runtime;
  late DateTime now;
  late String secret;
  late String currentOwner;
  late bool profileFails;
  Completer<http.Response>? profileWait;
  Completer<void>? profileEntered;
  final requests = <http.Request>[];
  final changed = throwsA(isA<GrammarQuizSessionChanged>());

  http.Response ownProfile() => http.Response(
    jsonEncode(profile.profile(currentOwner)),
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
        grammarStore: withQuiz ? store : null,
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
    expect(runtime.createGrammarQuizHistoryRepository(), isNotNull);
  }

  Future<void> login() async {
    await runtime.account.signIn(
      'fixture@example.invalid',
      'TEST_ONLY_PASSWORD',
    );
    await ready();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nd-grammar-sdk-');
    reviews = await NativeReviewJournal.open(directory);
    journal = await NativeGrammarQuizJournal.open(directory);
    store = ControlledGrammarStore(journal);
    backend = fixture.MemoryVault();
    now = DateTime.utc(2026, 10, 14, 3);
    secret = 'TEST_ONLY_GRAMMAR_ROTATION_1';
    currentOwner = wire.a;
    profileFails = false;
    profileWait = null;
    profileEntered = null;
    requests.clear();
    network = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/auth/v1/token') {
        return http.Response(
          jsonEncode({
            'access_token': wire.token(currentOwner, wire.sid1, now),
            'refresh_token': secret,
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': currentOwner,
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
        if (profileFails) return http.Response('{}', 500);
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

  test(
    'owned grammar factory waits for persisted secret and own profile',
    () async {
      expect(runtime.createGrammarQuizHistoryRepository(), isNull);
      backend.secret = 'TEST_ONLY_SAVED_QUIZ';
      backend.writeWait = Completer<void>();
      profileWait = Completer<http.Response>();
      profileEntered = Completer<void>();
      final starting = runtime.start();
      await until(() => backend.writes == 1);
      expect(runtime.createGrammarQuizHistoryRepository(), isNull);
      expect(
        requests.where((r) => r.url.path.startsWith('/rest/v1/')),
        isEmpty,
      );
      backend.writeWait!.complete();
      await starting;
      await profileEntered!.future.timeout(const Duration(seconds: 5));
      expect(backend.secret, secret);
      expect(runtime.createGrammarQuizHistoryRepository(), isNull);
      profileWait!.complete(ownProfile());
      await ready();
      final service = runtime.createGrammarQuizHistoryRepository()!;
      final before = requests.length;
      final saved = await service.save(attempt(1));
      expect(saved.ownerId, wire.a);
      final primary = await service.save(attempt(0));
      expect(primary.attempt.kind, GrammarQuizAttemptKind.primary);
      final loaded = await service.load();
      expect(loaded.map((r) => r.attempt.eventId), [
        attempt(0).eventId,
        attempt(1).eventId,
      ]);
      expect(loaded.map((r) => r.attempt.kind), [
        GrammarQuizAttemptKind.primary,
        GrammarQuizAttemptKind.correction,
      ]);
      expect(requests.length, before);
      expect(await journal.list(wire.a), hasLength(2));
    },
  );

  test(
    'owned grammar omitted quiz store never manufactures a history source',
    () async {
      await runtime.close();
      runtime = buildRuntime(withQuiz: false);
      await runtime.start();
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await until(() => runtime.account.state.phase == AccountPhase.ready);
      expect(runtime.createGrammarQuizHistoryRepository(), isNull);
      expect(store.appends + store.loads, 0);
      expect(await quizData(directory).length(), 0);
    },
  );

  test(
    'owned grammar refresh barrier revokes the old ready-runtime lease',
    () async {
      await runtime.start();
      await login();
      final old = runtime.createGrammarQuizHistoryRepository()!;
      await old.save(attempt(1));
      final writes = backend.writes;
      secret = 'TEST_ONLY_GRAMMAR_ROTATION_2';
      backend.writeWait = Completer<void>();
      final rotation = runtime.refresh();
      await until(() => backend.writes > writes);
      expect(runtime.createGrammarQuizHistoryRepository(), isNull);
      await expectLater(old.load(), changed);
      final calls = store.appends + store.loads;
      backend.writeWait!.complete();
      await rotation;
      await ready();
      await expectLater(old.save(attempt(2)), changed);
      expect(store.appends + store.loads, calls);
      final fresh = runtime.createGrammarQuizHistoryRepository()!;
      expect((await fresh.load()).single.attempt.eventId, attempt(1).eventId);
      expect(backend.secret, secret);
    },
  );

  test(
    'owned grammar logout and same-owner login require a fresh wrapper',
    () async {
      await runtime.start();
      await login();
      final old = runtime.createGrammarQuizHistoryRepository()!;
      await old.save(attempt(1));
      await runtime.account.signOut();
      expect(runtime.createGrammarQuizHistoryRepository(), isNull);
      await login();
      await expectLater(old.load(), changed);
      final fresh = runtime.createGrammarQuizHistoryRepository()!;
      expect((await fresh.load()).single.attempt.eventId, attempt(1).eventId);
      expect(await journal.list(wire.b), isEmpty);
    },
  );

  test(
    'owned grammar owner forwards only the current ready quiz capability',
    () async {
      final startup = PersistentAccountStartup(runtime);
      final owner = WindowsStagingOwner(
        startup,
        reviews,
        grammarJournal: journal,
      );
      final GrammarQuizHistorySource source = owner;
      expect(source.createGrammarQuizHistoryRepository(), isNull);
      await owner.start();
      await login();
      final service = source.createGrammarQuizHistoryRepository()!;
      await service.save(attempt(1));
      final before = requests.length;
      expect(
        await startup.createGrammarQuizHistoryRepository()!.load(),
        hasLength(1),
      );
      expect(requests.length, before);
      await owner.account.signOut();
      expect(source.createGrammarQuizHistoryRepository(), isNull);
      await expectLater(service.load(), changed);
      await login();
      expect(
        await source.createGrammarQuizHistoryRepository()!.load(),
        hasLength(1),
      );
      await owner.close();
      expect(source.createGrammarQuizHistoryRepository(), isNull);
      expect(startup.createGrammarQuizHistoryRepository(), isNull);
    },
  );

  test('owned grammar owner keeps leases while a quiz write is held', () async {
    final studies = await NativeStudySessionJournal.open(directory);
    final owner = WindowsStagingOwner(
      PersistentAccountStartup(runtime),
      reviews,
      studyJournal: studies,
      grammarJournal: journal,
    );
    try {
      await owner.start();
      await login();
      final service = owner.createGrammarQuizHistoryRepository()!;
      store.appendWait = Completer<void>();
      store.appended = Completer<void>();
      final saving = expectLater(service.save(attempt(1)), changed);
      await store.appended!.future.timeout(const Duration(seconds: 5));
      var closed = false;
      final closing = owner.close();
      expect(identical(closing, owner.close()), isTrue);
      final observing = closing.then((_) => closed = true);
      expect(owner.createGrammarQuizHistoryRepository(), isNull);
      await expectLater(service.load(), changed);
      await Future<void>.value();
      expect(closed, isFalse);
      await expectLater(
        NativeGrammarQuizJournal.open(directory),
        throwsA(isA<GrammarQuizStorageFailure>()),
      );
      await expectLater(
        NativeStudySessionJournal.open(directory),
        throwsA(isA<StudySessionStorageFailure>()),
      );
      await expectLater(
        NativeReviewJournal.open(directory),
        throwsA(isA<ReviewStorageFailure>()),
      );
      store.appendWait!.complete();
      await saving;
      await observing;
      expect(closed, isTrue);
      final reopened = await NativeGrammarQuizJournal.open(directory);
      try {
        expect(
          (await reopened.list(wire.a)).single.attempt.eventId,
          attempt(1).eventId,
        );
        expect(await reopened.list(wire.b), isEmpty);
      } finally {
        await reopened.close();
      }
      final reopenedStudies = await NativeStudySessionJournal.open(directory);
      await reopenedStudies.close();
      final reopenedReviews = await NativeReviewJournal.open(directory);
      await reopenedReviews.close();
    } finally {
      store.release();
      await owner.close();
      await studies.close();
    }
  });

  test('owned grammar owner without quiz storage has no capability', () async {
    await runtime.close();
    runtime = buildRuntime(withQuiz: false);
    final owner = WindowsStagingOwner(
      PersistentAccountStartup(runtime),
      reviews,
    );
    await owner.start();
    await runtime.account.signIn(
      'fixture@example.invalid',
      'TEST_ONLY_PASSWORD',
    );
    await until(() => runtime.account.state.phase == AccountPhase.ready);
    expect(owner.createGrammarQuizHistoryRepository(), isNull);
    await owner.close();
    // This unrelated journal was not transferred to the owner.
    expect(await journal.list(wire.a), isEmpty);
    expect(store.appends + store.loads, 0);
  });

  test(
    'owned grammar runtime close drains quiz work before caller releases store',
    () async {
      await runtime.start();
      await login();
      final service = runtime.createGrammarQuizHistoryRepository()!;
      store.appendWait = Completer<void>();
      store.appended = Completer<void>();
      final saving = expectLater(service.save(attempt(1)), changed);
      await store.appended!.future.timeout(const Duration(seconds: 5));
      var closed = false;
      final closing = runtime.close().then((_) => closed = true);
      expect(runtime.createGrammarQuizHistoryRepository(), isNull);
      await expectLater(service.load(), changed);
      await Future<void>.value();
      expect(closed, isFalse);
      await expectLater(
        NativeGrammarQuizJournal.open(directory),
        throwsA(isA<GrammarQuizStorageFailure>()),
      );
      store.appendWait!.complete();
      await saving;
      await closing;
      expect(closed, isTrue);
      final retained = (await journal.list(wire.a)).single;
      expect(retained.attempt.eventId, attempt(1).eventId);
      await journal.close();
      final reopened = await NativeGrammarQuizJournal.open(directory);
      try {
        final recovered = (await reopened.list(wire.a)).single;
        expect(recovered.attempt.eventId, attempt(1).eventId);
      } finally {
        await reopened.close();
      }
    },
  );

  test(
    'owned grammar storage failure is safe and explicit replay writes once',
    () async {
      await runtime.start();
      await login();
      final service = runtime.createGrammarQuizHistoryRepository()!;
      store.appendFailure = StateError('PRIVATE GRAMMAR STORAGE');
      await expectLater(
        service.save(attempt(0)),
        throwsA(isA<GrammarQuizStorageFailure>()),
      );
      expect(await journal.list(wire.a), hasLength(1));
      final bytes = await quizData(directory).readAsBytes();
      store.appendFailure = null;
      final httpBefore = requests.length;
      final recovered = await service.save(attempt(0));
      expect(sameGrammarQuizAttempt(recovered.attempt, attempt(0)), isTrue);
      expect(await quizData(directory).readAsBytes(), bytes);
      store.listFailure = StateError('PRIVATE GRAMMAR STORAGE');
      await expectLater(
        service.load(),
        throwsA(isA<GrammarQuizStorageFailure>()),
      );
      store.listFailure = null;
      expect((await service.load()).single.ownerId, wire.a);
      expect(requests.length, httpBefore);
    },
  );

  for (final operation in ['save', 'load']) {
    for (final failLate in [false, true]) {
      test(
        'owned grammar late $operation fenced through A B A error=$failLate',
        () async {
          await runtime.start();
          await login();
          final old = runtime.createGrammarQuizHistoryRepository()!;
          if (operation == 'load') {
            await old.save(attempt(0));
          }
          final gate = Completer<void>();
          final entered = Completer<void>();
          if (operation == 'save') {
            store.appendWait = gate;
            store.appended = entered;
            if (failLate) {
              store.appendFailure = StateError('PRIVATE GRAMMAR STORAGE');
            }
          } else {
            store.listWait = gate;
            store.listed = entered;
            if (failLate) {
              store.listFailure = StateError('PRIVATE GRAMMAR STORAGE');
            }
          }
          final pending = expectLater(
            operation == 'save' ? old.save(attempt(0)) : old.load(),
            changed,
          );
          await entered.future.timeout(const Duration(seconds: 5));
          await runtime.account.signOut();
          expect(runtime.createGrammarQuizHistoryRepository(), isNull);
          currentOwner = wire.b;
          secret = 'TEST_ONLY_GRAMMAR_B';
          await login();
          // The underlying old write was already accepted; it belongs only to A.
          expect(await journal.list(wire.a), hasLength(1));
          expect(await journal.list(wire.b), isEmpty);
          final heldList = store.listWait;
          final heldFailure = store.listFailure;
          store.listWait = null;
          store.listFailure = null;
          expect(
            await runtime.createGrammarQuizHistoryRepository()!.load(),
            isEmpty,
          );
          store.listWait = heldList;
          store.listFailure = heldFailure;
          final before = store.appends + store.loads;
          await expectLater(old.save(attempt(2)), changed);
          expect(store.appends + store.loads, before);
          await runtime.account.signOut();
          currentOwner = wire.a;
          secret = 'TEST_ONLY_GRAMMAR_A_RETURN';
          await login();
          gate.complete();
          await pending;
          store.appendFailure = null;
          store.listFailure = null;
          await expectLater(old.load(), changed);
          final fresh = runtime.createGrammarQuizHistoryRepository()!;
          final history = await fresh.load();
          expect(history.single.ownerId, wire.a);
          expect(
            sameGrammarQuizAttempt(history.single.attempt, attempt(0)),
            isTrue,
          );
          expect(await journal.list(wire.b), isEmpty);
          final httpBefore = requests.length;
          await fresh.save(attempt(1));
          expect(requests.length, httpBefore);
          expect((await fresh.load()).map((r) => r.attempt.kind), [
            GrammarQuizAttemptKind.primary,
            GrammarQuizAttemptKind.correction,
          ]);
        },
      );
    }
  }

  for (final failure in ['vault', 'profile']) {
    test(
      'owned grammar failed $failure barrier has no storage capability',
      () async {
        backend.failWrite = failure == 'vault';
        profileFails = failure == 'profile';
        await runtime.start();
        await runtime.account.signIn(
          'fixture@example.invalid',
          'TEST_ONLY_PASSWORD',
        );
        await until(
          () =>
              runtime.account.state.phase ==
              (failure == 'vault'
                  ? AccountPhase.signInError
                  : AccountPhase.profileError),
        );
        expect(runtime.account.readyRuntime, isNull);
        expect(runtime.createGrammarQuizHistoryRepository(), isNull);
        expect(store.appends + store.loads, 0);
        if (failure == 'vault') {
          expect(
            requests.where((r) => r.url.path.contains('ensure_profile')),
            isEmpty,
          );
        }
        expect(await journal.list(wire.a), isEmpty);
      },
    );
  }

  test(
    'owned grammar startup controller publishes only active source',
    () async {
      final owner = WindowsStagingOwner(
        PersistentAccountStartup(runtime),
        reviews,
        grammarJournal: journal,
      );
      final controller =
          AccountStartupController<AccountController<SrsStudyRuntime>>(
            () async => owner,
          );
      expect(controller.grammarQuizHistorySource, isNull);
      await controller.start();
      expect(controller.grammarQuizHistorySource, same(owner));
      expect(
        controller.grammarQuizHistorySource!
            .createGrammarQuizHistoryRepository(),
        isNull,
      );
      await login();
      final captured = controller.grammarQuizHistorySource!
          .createGrammarQuizHistoryRepository()!;
      await captured.save(attempt(0));
      final closing = controller.close();
      expect(controller.grammarQuizHistorySource, isNull);
      await expectLater(captured.load(), changed);
      await closing;
      expect(owner.createGrammarQuizHistoryRepository(), isNull);
      final reopened = await NativeGrammarQuizJournal.open(directory);
      try {
        expect(
          (await reopened.list(wire.a)).single.attempt.eventId,
          attempt(0).eventId,
        );
        expect(await reopened.list(wire.b), isEmpty);
      } finally {
        await reopened.close();
      }
    },
  );
}

final class ControlledGrammarStore implements GrammarQuizAttemptStore {
  ControlledGrammarStore(this.base);
  final GrammarQuizAttemptStore base;
  int appends = 0;
  int loads = 0;
  Object? appendFailure;
  Object? listFailure;
  Completer<void>? appendWait;
  Completer<void>? listWait;
  Completer<void>? appended;
  Completer<void>? listed;

  @override
  Future<OwnedGrammarQuizAttempt> append(
    String ownerId,
    GrammarQuizAttempt attempt,
  ) {
    appends++;
    return _append(ownerId, attempt);
  }

  Future<OwnedGrammarQuizAttempt> _append(
    String ownerId,
    GrammarQuizAttempt attempt,
  ) async {
    final result = await base.append(ownerId, attempt);
    if (!(appended?.isCompleted ?? true)) appended!.complete();
    await appendWait?.future;
    if (appendFailure != null) throw appendFailure!;
    return result;
  }

  @override
  Future<List<OwnedGrammarQuizAttempt>> list(String ownerId) {
    loads++;
    return _list(ownerId);
  }

  Future<List<OwnedGrammarQuizAttempt>> _list(String ownerId) async {
    final result = await base.list(ownerId);
    if (!(listed?.isCompleted ?? true)) listed!.complete();
    await listWait?.future;
    if (listFailure != null) throw listFailure!;
    return result;
  }

  void release() {
    for (final pending in [appendWait, listWait]) {
      if (pending != null && !pending.isCompleted) pending.complete();
    }
  }
}
