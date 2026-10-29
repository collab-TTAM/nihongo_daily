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
  int reads = 0;
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
  Future<List<OwnedVocabularyQuizAttempt>> list(String ownerId) {
    reads++;
    return observe(() => journal.list(ownerId));
  }
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

      // Focused correction survives a second owned restart. Keep the actual
      // original event; the UI must explicitly capture and save a new event.
      final requestsBeforeReview = server.paths.length;
      await tapQuiz(tester, find.byKey(const Key('quiz-review-start')));
      expect(find.text('Luyện lại 1 từ cần ôn'), findsOneWidget);
      expect(find.text(questions.first.target.heading), findsOneWidget);
      for (final choice in questions.first.choices) {
        expect(
          find.byKey(ValueKey('quiz-choice-${choice.id}')),
          findsOneWidget,
        );
      }
      await tapQuiz(
        tester,
        find.byKey(ValueKey('quiz-choice-${questions.first.target.id}')),
      );
      await tapQuiz(tester, find.byKey(const Key('quiz-next')));
      expect(find.text('Kết quả bộ này: 1 / 1'), findsOneWidget);
      expect(second.store.appends, 0);
      expect(
        (await tester.runAsync(() => second.journal.list(wire.a)))!,
        hasLength(1),
      );
      expect(
        (await tester.runAsync(
          () => File('${directory.path}/quiz-attempts.ndjson').readAsBytes(),
        ))!,
        bytesBeforeRestart,
      );
      final staleReviewSave = tester
          .widget<FilledButton>(find.byKey(const Key('quiz-save')))
          .onPressed!;
      await diskAction(second, 'quiz-save');
      expect(find.byKey(const Key('quiz-saved')), findsOneWidget);
      staleReviewSave();
      await tester.pumpAndSettle();
      expect(second.store.appends, 1);
      final corrected = (await tester.runAsync(
        () => second.journal.list(wire.a),
      ))!;
      expect(corrected, hasLength(2));
      expect(
        sameVocabularyQuizAttempt(
          corrected
              .singleWhere((r) => r.attempt.eventId == original.eventId)
              .attempt,
          original,
        ),
        isTrue,
      );
      final correction = corrected
          .singleWhere((r) => r.attempt.eventId != original.eventId)
          .attempt;
      expect(correction.score, 1);
      expect(correction.answers, hasLength(1));
      expect(correction.answers.single.itemId, questions.first.target.id);
      expect(correction.answers.single.selectedId, questions.first.target.id);
      expect(
        correction.answers.single.contentVersion,
        questions.first.target.contentVersion,
      );
      expect(
        correction.answers.single.choices,
        questions.first.choices.map((c) => c.id),
      );
      expect(correction.eventId[14], '4');
      expect(correction.completedAt.isUtc, isTrue);
      await tapQuiz(tester, find.byKey(const Key('quiz-review-back')));
      // The prior statistics snapshot stays unchanged until an explicit reload.
      expect(find.text('Từ cần ôn: 1'), findsOneWidget);
      await diskAction(second, 'quiz-progress-load');
      expect(find.text('N5 · 2 bộ đã lưu'), findsOneWidget);
      expect(find.text('Câu đúng theo bài gốc: 10 / 11'), findsOneWidget);
      expect(find.text('Từ hiện tại đã luyện: 10'), findsOneWidget);
      expect(find.text('Từ cần ôn: 0'), findsOneWidget);
      expect(find.byKey(const Key('quiz-review-start')), findsNothing);
      expect(server.paths.length, requestsBeforeReview);
      final correctedBytes = (await tester.runAsync(
        () => File('${directory.path}/quiz-attempts.ndjson').readAsBytes(),
      ))!;
      expect(correctedBytes.length, greaterThan(bytesBeforeRestart.length));
      expect(
        correctedBytes.take(bytesBeforeRestart.length),
        bytesBeforeRestart,
      );
      await tester.runAsync(second.close);
      await tester.pumpWidget(const SizedBox());
      expect(second.controller.quizHistorySource, isNull);

      final tokensBeforeCorrectionRestore = server.paths
          .where((p) => p == '/auth/v1/token')
          .length;
      final third = (await tester.runAsync(() async {
        final app = await _open(directory, server, vault);
        current = app;
        await app.ready();
        return app;
      }))!;
      expect(
        server.paths.where((p) => p == '/auth/v1/token').length,
        tokensBeforeCorrectionRestore + 1,
      );
      expect(third.runtime.account.state.profile!.id, wire.a);
      container = await mount(third);
      final requestsBeforeRestoredViews = server.paths.length;
      container.read(routerProvider).go('/progress');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      await diskAction(third, 'quiz-progress-load');
      expect(find.text('N5 · 2 bộ đã lưu'), findsOneWidget);
      expect(find.text('Câu đúng theo bài gốc: 10 / 11'), findsOneWidget);
      expect(find.text('Từ hiện tại đã luyện: 10'), findsOneWidget);
      expect(find.text('Từ cần ôn: 0'), findsOneWidget);
      expect(find.byKey(const Key('quiz-review-start')), findsNothing);
      container.read(routerProvider).go('/quiz/history');
      await tester.pumpAndSettle();
      await diskAction(third, 'quiz-history-load');
      expect(find.text('N5 · 9 / 10'), findsOneWidget);
      expect(find.text('N5 · 1 / 1'), findsOneWidget);
      expect(server.paths.length, requestsBeforeRestoredViews);
      final restoredCorrections = (await tester.runAsync(
        () => third.journal.list(wire.a),
      ))!;
      expect(restoredCorrections, hasLength(2));
      for (final attempt in [original, correction]) {
        expect(
          sameVocabularyQuizAttempt(
            restoredCorrections
                .singleWhere((r) => r.attempt.eventId == attempt.eventId)
                .attempt,
            attempt,
          ),
          isTrue,
        );
      }

      container.read(routerProvider).go('/progress');
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await third.runtime.account.signOut();
        server.user = wire.b;
        await third.login();
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      await diskAction(third, 'quiz-progress-load');
      expect(find.text('N5 · 0 bộ đã lưu'), findsOneWidget);
      expect(find.text('Từ cần ôn: 0'), findsOneWidget);
      expect(find.byKey(const Key('quiz-review-start')), findsNothing);
      expect(find.text(questions.first.target.heading), findsNothing);
      expect(
        (await tester.runAsync(() => third.journal.list(wire.b)))!,
        isEmpty,
      );
      await tester.runAsync(() async {
        await third.runtime.account.signOut();
        server.user = wire.a;
        await third.login();
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      await diskAction(third, 'quiz-progress-load');
      expect(find.text('N5 · 2 bộ đã lưu'), findsOneWidget);
      expect(find.text('Câu đúng theo bài gốc: 10 / 11'), findsOneWidget);
      expect(find.text('Từ cần ôn: 0'), findsOneWidget);
      expect(find.byKey(const Key('quiz-review-start')), findsNothing);
      expect(
        (await tester.runAsync(
          () => File('${directory.path}/quiz-attempts.ndjson').readAsBytes(),
        ))!,
        correctedBytes,
      );
      expect(third.store.appends, 0);
      expect(find.textContaining(wire.a), findsNothing);
      expect(find.textContaining('TEST_ONLY'), findsNothing);
      expect(tester.takeException(), isNull);

      // Filter the actual restored journal, then replace its captured account
      // while history is mounted. No synthetic rows or saved UI are injected.
      Future<void> chooseHistoryLevel(String label) async {
        await tapQuiz(tester, find.byKey(const Key('quiz-history-level')));
        await tapQuiz(tester, find.text(label).last);
      }

      final readsBeforeFilters = third.store.reads;
      final requestsBeforeFilters = server.paths.length;
      final errorsOnly = find.byKey(const Key('quiz-history-errors-only'));
      final summary = find.byKey(const Key('quiz-history-summary'));
      container.read(routerProvider).go('/quiz/history');
      await tester.pumpAndSettle();
      expect(summary, findsNothing);
      await diskAction(third, 'quiz-history-load');
      expect(find.text('2 bộ đã lưu'), findsOneWidget);
      expect(find.text('Câu đúng theo bài gốc: 10 / 11'), findsOneWidget);
      await tapQuiz(tester, errorsOnly);
      expect(find.text('1 bộ đã lưu'), findsOneWidget);
      expect(find.text('N5 · 9 / 10'), findsOneWidget);
      expect(find.text('N5 · 1 / 1'), findsNothing);
      expect(find.text('Câu đúng theo bài gốc: 9 / 10'), findsOneWidget);
      await chooseHistoryLevel('N4');
      expect(find.text('0 bộ đã lưu'), findsOneWidget);
      expect(find.text('Câu đúng theo bài gốc: 0 / 0'), findsOneWidget);
      expect(find.text('N5 · 9 / 10'), findsNothing);
      expect(find.byKey(const Key('quiz-history-range')), findsNothing);
      expect(third.store.reads, readsBeforeFilters + 1);
      await diskAction(third, 'quiz-history-load');
      expect(tester.widget<CheckboxListTile>(errorsOnly).value, isTrue);
      expect(find.text('N4'), findsOneWidget);
      expect(find.text('0 bộ đã lưu'), findsOneWidget);
      await chooseHistoryLevel('N5');
      expect(find.text('1 bộ đã lưu'), findsOneWidget);
      expect(find.text('N5 · 9 / 10'), findsOneWidget);
      expect(find.text('N5 · 1 / 1'), findsNothing);
      expect(third.store.reads, readsBeforeFilters + 2);
      expect(server.paths.length, requestsBeforeFilters);
      await chooseHistoryLevel('N4');
      final staleFilter = tester
          .widget<CheckboxListTile>(errorsOnly)
          .onChanged!;
      await tester.runAsync(() async {
        await third.runtime.account.signOut();
        server.user = wire.b;
        await third.login();
      });
      staleFilter(true); // Old capability, before the replacement frame.
      await tester.pumpAndSettle();
      expect(summary, findsNothing);
      expect(tester.widget<CheckboxListTile>(errorsOnly).value, isFalse);
      expect(find.text('Tất cả cấp độ'), findsOneWidget);
      final requestsBeforeBHistory = server.paths.length;
      await diskAction(third, 'quiz-history-load');
      expect(find.text('0 bộ đã lưu'), findsOneWidget);
      expect(find.text('Câu đúng theo bài gốc: 0 / 0'), findsOneWidget);
      expect(find.text('N5 · 9 / 10'), findsNothing);
      expect(find.text('N5 · 1 / 1'), findsNothing);
      staleFilter(true);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(errorsOnly).value, isFalse);
      expect(server.paths.length, requestsBeforeBHistory);
      await tester.runAsync(() async {
        await third.runtime.account.signOut();
        server.user = wire.a;
        await third.login();
      });
      await tester.pumpAndSettle();
      expect(summary, findsNothing);
      expect(tester.widget<CheckboxListTile>(errorsOnly).value, isFalse);
      expect(find.text('Tất cả cấp độ'), findsOneWidget);
      final requestsBeforeAHistory = server.paths.length;
      await diskAction(third, 'quiz-history-load');
      expect(find.text('2 bộ đã lưu'), findsOneWidget);
      expect(find.text('N5 · 9 / 10'), findsOneWidget);
      expect(find.text('N5 · 1 / 1'), findsOneWidget);
      expect(find.text('Câu đúng theo bài gốc: 10 / 11'), findsOneWidget);
      expect(third.store.reads, readsBeforeFilters + 4);
      expect(third.store.appends, 0);
      expect(server.paths.length, requestsBeforeAHistory);
      expect(
        (await tester.runAsync(
          () => File('${directory.path}/quiz-attempts.ndjson').readAsBytes(),
        ))!,
        correctedBytes,
      );
      expect(find.textContaining(wire.a), findsNothing);
      expect(find.textContaining(wire.b), findsNothing);
      expect(find.textContaining('TEST_ONLY'), findsNothing);
      expect(tester.takeException(), isNull);

      // Order the actual restored events without replacing their stored reports.
      final orderToggle = find.byKey(const Key('quiz-history-oldest-first'));
      final readsBeforeOrder = third.store.reads;
      final requestsBeforeOrder = server.paths.length;
      final chronological = [original, correction]
        ..sort((left, right) {
          final time = left.completedAt.compareTo(right.completedAt);
          return time == 0 ? left.eventId.compareTo(right.eventId) : time;
        });
      final oldestKeys = [
        for (final attempt in chronological) 'quiz-history-${attempt.eventId}',
      ];
      List<String> shownEvents() => tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => tile.key)
          .whereType<ValueKey<String>>()
          .map((key) => key.value)
          .where((key) => key.startsWith('quiz-history-'))
          .toList();
      expect(tester.widget<CheckboxListTile>(orderToggle).value, isFalse);
      expect(shownEvents(), oldestKeys.reversed.toList());
      await tapQuiz(tester, orderToggle);
      expect(tester.widget<CheckboxListTile>(orderToggle).value, isTrue);
      expect(shownEvents(), oldestKeys);
      expect(find.text('Hiển thị 1–2 / 2 bộ (cũ nhất trước)'), findsOneWidget);
      expect(find.text('Câu đúng theo bài gốc: 10 / 11'), findsOneWidget);
      await chooseHistoryLevel('N4');
      expect(shownEvents(), isEmpty);
      await chooseHistoryLevel('N5');
      expect(shownEvents(), oldestKeys);
      expect(third.store.reads, readsBeforeOrder);
      expect(server.paths.length, requestsBeforeOrder);
      await diskAction(third, 'quiz-history-load');
      expect(tester.widget<CheckboxListTile>(orderToggle).value, isTrue);
      expect(shownEvents(), oldestKeys);
      expect(third.store.reads, readsBeforeOrder + 1);
      final staleOrder = tester
          .widget<CheckboxListTile>(orderToggle)
          .onChanged!;
      await tester.runAsync(() async {
        await third.runtime.account.signOut();
        server.user = wire.b;
        await third.login();
      });
      staleOrder(true); // Captured A control, before B's replacement frame.
      await tester.pumpAndSettle();
      expect(summary, findsNothing);
      expect(tester.widget<CheckboxListTile>(orderToggle).value, isFalse);
      expect(shownEvents(), isEmpty);
      final requestsBeforeOrderedB = server.paths.length;
      await diskAction(third, 'quiz-history-load');
      expect(find.text('0 bộ đã lưu'), findsOneWidget);
      expect(shownEvents(), isEmpty);
      staleOrder(true);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(orderToggle).value, isFalse);
      expect(third.store.reads, readsBeforeOrder + 2);
      expect(server.paths.length, requestsBeforeOrderedB);
      await tester.runAsync(() async {
        await third.runtime.account.signOut();
        server.user = wire.a;
        await third.login();
      });
      await tester.pumpAndSettle();
      expect(summary, findsNothing);
      expect(tester.widget<CheckboxListTile>(orderToggle).value, isFalse);
      final requestsBeforeOrderedA = server.paths.length;
      await diskAction(third, 'quiz-history-load');
      expect(shownEvents(), oldestKeys.reversed.toList());
      expect(find.text('Câu đúng theo bài gốc: 10 / 11'), findsOneWidget);
      await tapQuiz(tester, orderToggle);
      expect(shownEvents(), oldestKeys);
      await tapQuiz(tester, orderToggle);
      expect(shownEvents(), oldestKeys.reversed.toList());
      expect(third.store.reads, readsBeforeOrder + 3);
      expect(third.store.appends, 0);
      expect(server.paths.length, requestsBeforeOrderedA);
      expect(
        (await tester.runAsync(
          () => File('${directory.path}/quiz-attempts.ndjson').readAsBytes(),
        ))!,
        correctedBytes,
      );
      expect(find.textContaining(wire.a), findsNothing);
      expect(find.textContaining(wire.b), findsNothing);
      expect(find.textContaining('TEST_ONLY'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
