// TEST ONLY HTTP/vault. Actual SDK, owned startup, bundled N5 and native files.
// Not hosted Auth/JWT/RLS, real Windows vault or power-loss proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/app/staging_bootstrap.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_account_startup.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:nihongo_daily/features/quiz/application/vocabulary_quiz_provider.dart';
import 'package:nihongo_daily/features/quiz/data/native_vocabulary_quiz_journal.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_runtime.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import '../srs/own_profile_fixtures.dart' as profile;
import '../srs/session_lifecycle_fixtures.dart' as fixture;
import '../srs/supabase_review_binding_test.dart' as wire;
import 'vocabulary_quiz_widget_test.dart' show tapQuiz;

final class _Server {
  String user = wire.a;
  int generation = 0;
  final now = DateTime.utc(2026, 10, 22);
  final paths = <String>[];

  Future<http.Response> respond(http.Request request) async {
    paths.add(request.url.path);
    final Object body;
    if (request.url.path == '/auth/v1/token') {
      generation++;
      body = {
        'access_token': wire.token(
          user,
          wire.sid1,
          now,
          generation: generation,
        ),
        'refresh_token': 'TEST_ONLY_JOURNEY_REFRESH_$generation',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': user,
          'aud': 'authenticated',
          'role': 'authenticated',
          'created_at': '2026-10-14T00:00:00Z',
          'app_metadata': <String, Object>{},
          'user_metadata': <String, Object>{},
        },
      };
    } else if (request.url.path == '/rest/v1/rpc/ensure_profile') {
      body = profile.profile(user);
    } else if (request.url.path == '/auth/v1/logout') {
      return http.Response('', 204);
    } else {
      throw StateError('Unexpected TEST ONLY quiz journey endpoint');
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

// Observe completion without substituting stored data or UI success. Each
// method still awaits the actual native journal. UI assertions independently
// distinguish success from a failed operation after the completion barrier.
final class _ObservedStore implements VocabularyQuizAttemptStore {
  _ObservedStore(this.journal);
  final NativeVocabularyQuizJournal journal;
  int appends = 0;
  Completer<void>? settled;

  Future<T> observe<T>(Future<T> Function() action) async {
    try {
      return await action();
    } finally {
      final waiting = settled;
      if (waiting != null && !waiting.isCompleted) waiting.complete();
    }
  }

  @override
  Future<OwnedVocabularyQuizAttempt> append(
    String ownerId,
    VocabularyQuizAttempt attempt,
  ) {
    appends++;
    return observe(() => journal.append(ownerId, attempt));
  }

  @override
  Future<List<OwnedVocabularyQuizAttempt>> list(String ownerId) =>
      observe(() => journal.list(ownerId));
}

final class _DiskApp {
  _DiskApp(
    this.journal,
    this.store,
    this.runtime,
    this.controller,
    this.client,
  );
  final NativeVocabularyQuizJournal journal;
  final _ObservedStore store;
  final PersistentSupabaseRuntime runtime;
  final AccountStartupController<AccountController<SrsStudyRuntime>> controller;
  final MockClient client;

  Future<void> ready() async {
    final elapsed = Stopwatch()..start();
    while (runtime.account.state.phase != AccountPhase.ready &&
        elapsed.elapsed < const Duration(seconds: 5)) {
      if (const {
        AccountPhase.profileError,
        AccountPhase.signInError,
        AccountPhase.unavailable,
      }.contains(runtime.account.state.phase)) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(runtime.account.state.phase, AccountPhase.ready);
    expect(runtime.createVocabularyQuizHistoryRepository(), isNotNull);
  }

  Future<void> login() async {
    await runtime.account.signIn(
      'fixture@example.invalid',
      'TEST_ONLY_PASSWORD',
    );
    await ready();
  }

  Future<void> close() async {
    await controller.close().timeout(const Duration(seconds: 5));
    client.close();
  }
}

Future<_DiskApp> _open(
  Directory directory,
  _Server server,
  fixture.MemoryVault vault,
) async {
  final reviews = await NativeReviewJournal.open(directory);
  NativeVocabularyQuizJournal? journal;
  PersistentSupabaseRuntime? runtime;
  final client = MockClient(server.respond);
  try {
    journal = await NativeVocabularyQuizJournal.open(directory);
    final store = _ObservedStore(journal);
    runtime = PersistentSupabaseRuntime(
      projectUrl: wire.origin,
      publishableKey: wire.key,
      vault: SessionCredentialVault(projectUrl: wire.origin, backend: vault),
      store: reviews,
      quizStore: store,
      httpClient: client,
      now: () => server.now,
    );
    final owner = WindowsStagingOwner(
      PersistentAccountStartup(runtime),
      reviews,
      quizJournal: journal,
    );
    final controller =
        AccountStartupController<AccountController<SrsStudyRuntime>>(
          () async => owner,
        );
    await controller.start();
    return _DiskApp(journal, store, runtime, controller, client);
  } catch (_) {
    await runtime?.close();
    await journal?.close();
    await reviews.close();
    client.close();
    rethrow;
  }
}

void main() {
  testWidgets(
    'real disk quiz save history progress survives owned restart and A B A',
    (tester) async {
      final server = _Server();
      final vault = fixture.MemoryVault();
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('nd-quiz-journey-'),
      ))!;
      _DiskApp? current;
      ProviderSubscription<AsyncValue<List<QuizQuestion>>>? content;
      addTearDown(() async {
        content?.close();
        await tester.runAsync(() async {
          await current?.close();
        });
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await directory.delete(recursive: true);
        });
      });
      final first = (await tester.runAsync(() async {
        final app = await _open(directory, server, vault);
        current = app;
        await app.login();
        return app;
      }))!;

      Future<ProviderContainer> mount(_DiskApp app) async {
        await tester.pumpWidget(AccountStartupApp(controller: app.controller));
        await tester.pumpAndSettle();
        return ProviderScope.containerOf(
          tester.element(find.byType(NihongoDailyApp)),
        );
      }

      // Dispatch the real UI action on the real loop and await its real-disk
      // completion. One event turn lets repository/UI microtasks settle before
      // pumping frames; no fake clock is asked to drive filesystem futures.
      Future<void> diskAction(_DiskApp app, String key) async {
        final button = find.byKey(Key(key));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(button.hitTestable(), findsOneWidget);
        expect(
          await tester.runAsync(() async {
            app.store.settled = Completer<void>();
            await tester.tap(button);
            await app.store.settled!.future.timeout(const Duration(seconds: 5));
            await Future<void>.delayed(Duration.zero);
            return true;
          }),
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      var container = await mount(first);
      final questions = (await tester.runAsync(() async {
        final provider = vocabularyQuizProvider(PreviewLevel.n5);
        content = container.listen(provider, (_, _) {});
        return container.read(provider.future);
      }))!.take(10).toList();
      expect(questions, hasLength(10));
      container.read(routerProvider).go('/quiz');
      await tester.pumpAndSettle();
      final requestsBeforeQuiz = server.paths.length;
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        final choice = i == 0
            ? q.choices.firstWhere((c) => c.id != q.target.id)
            : q.target;
        await tapQuiz(tester, find.byKey(ValueKey('quiz-choice-${choice.id}')));
        await tapQuiz(tester, find.byKey(const Key('quiz-next')));
      }
      expect(find.text('Kết quả bộ này: 9 / 10'), findsOneWidget);
      final staleSave = tester
          .widget<FilledButton>(find.byKey(const Key('quiz-save')))
          .onPressed!;
      await diskAction(first, 'quiz-save');
      expect(find.byKey(const Key('quiz-saved')), findsOneWidget);
      staleSave();
      await tester.pumpAndSettle();
      expect(first.store.appends, 1);
      final saved = (await tester.runAsync(() => first.journal.list(wire.a)))!;
      expect(saved, hasLength(1));
      final original = saved.single.attempt;
      expect(original.score, 9);
      expect(original.answers, hasLength(10));
      expect(original.completedAt.isUtc, isTrue);
      expect(original.eventId[14], '4');

      container.read(routerProvider).go('/quiz/history');
      await tester.pumpAndSettle();
      await diskAction(first, 'quiz-history-load');
      expect(find.text('N5 · 9 / 10'), findsOneWidget);
      container.read(routerProvider).go('/progress');
      await tester.pumpAndSettle();
      await diskAction(first, 'quiz-progress-load');
      expect(find.text('N5 · 1 bộ đã lưu'), findsOneWidget);
      expect(find.text('Câu đúng theo bài gốc: 9 / 10'), findsOneWidget);
      expect(find.text('Từ hiện tại đã luyện: 10'), findsOneWidget);
      expect(find.text('Từ cần ôn: 1'), findsOneWidget);
      expect(find.text(questions.first.target.heading), findsOneWidget);
      expect(server.paths.length, requestsBeforeQuiz);
      final bytesBeforeRestart = (await tester.runAsync(
        () => File('${directory.path}/quiz-attempts.ndjson').readAsBytes(),
      ))!;
      content!.close();
      content = null;
      await tester.runAsync(first.close);
      await tester.pumpWidget(const SizedBox());
      expect(first.controller.quizHistorySource, isNull);

      final tokens = server.paths.where((p) => p == '/auth/v1/token').length;
      final second = (await tester.runAsync(() async {
        final app = await _open(directory, server, vault);
        current = app;
        await app.ready();
        return app;
      }))!;
      expect(
        server.paths.where((p) => p == '/auth/v1/token').length,
        tokens + 1,
      );
      expect(second.runtime.account.state.profile!.id, wire.a);
      container = await mount(second);
      container.read(routerProvider).go('/progress');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      await diskAction(second, 'quiz-progress-load');
      expect(find.text('N5 · 1 bộ đã lưu'), findsOneWidget);
      expect(find.text('Từ cần ôn: 1'), findsOneWidget);
      final restored = (await tester.runAsync(
        () => second.journal.list(wire.a),
      ))!;
      expect(
        sameVocabularyQuizAttempt(restored.single.attempt, original),
        isTrue,
      );

      await tester.runAsync(() async {
        await second.runtime.account.signOut();
        server.user = wire.b;
        await second.login();
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      await diskAction(second, 'quiz-progress-load');
      expect(find.text('N5 · 0 bộ đã lưu'), findsOneWidget);
      expect(find.text('Từ cần ôn: 0'), findsOneWidget);
      expect(find.text(questions.first.target.heading), findsNothing);
      expect(second.runtime.account.state.profile!.id, wire.b);
      expect(second.store.appends, 0);

      await tester.runAsync(() async {
        await second.runtime.account.signOut();
        server.user = wire.a;
        await second.login();
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      await diskAction(second, 'quiz-progress-load');
      expect(find.text('N5 · 1 bộ đã lưu'), findsOneWidget);
      expect(find.text('Câu đúng theo bài gốc: 9 / 10'), findsOneWidget);
      expect(find.text('Từ cần ôn: 1'), findsOneWidget);
      final bytesAfterAccounts = (await tester.runAsync(
        () => File('${directory.path}/quiz-attempts.ndjson').readAsBytes(),
      ))!;
      expect(bytesAfterAccounts, bytesBeforeRestart);
      final otherRecords = await tester.runAsync(
        () => second.journal.list(wire.b),
      );
      expect(otherRecords, isEmpty);
      expect(find.textContaining(wire.a), findsNothing);
      expect(find.textContaining('TEST_ONLY'), findsNothing);
      expect(server.paths.toSet(), {
        '/auth/v1/token',
        '/auth/v1/logout',
        '/rest/v1/rpc/ensure_profile',
      });
      expect(second.store.appends, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
