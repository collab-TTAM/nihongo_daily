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
import 'package:nihongo_daily/features/quiz/application/grammar_quiz_provider.dart';
import 'package:nihongo_daily/features/quiz/data/native_grammar_quiz_journal.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
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
final class _ObservedStore implements GrammarQuizAttemptStore {
  _ObservedStore(this.journal);
  final NativeGrammarQuizJournal journal;
  int appends = 0;
  int reads = 0;
  Completer<void>? settled;

  Future<T> observe<T>(Future<T> Function() action) async {
    try {
      return await action();
    } finally {
      final waiting = settled;
      if (waiting != null && !waiting.isCompleted) {
        waiting.complete();
      }
    }
  }

  @override
  Future<OwnedGrammarQuizAttempt> append(
    String ownerId,
    GrammarQuizAttempt attempt,
  ) {
    appends++;
    return observe(() => journal.append(ownerId, attempt));
  }

  @override
  Future<List<OwnedGrammarQuizAttempt>> list(String ownerId) {
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
  final NativeGrammarQuizJournal journal;
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
    expect(runtime.createGrammarQuizHistoryRepository(), isNotNull);
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
  NativeGrammarQuizJournal? journal;
  PersistentSupabaseRuntime? runtime;
  final client = MockClient(server.respond);
  try {
    journal = await NativeGrammarQuizJournal.open(directory);
    final store = _ObservedStore(journal);
    runtime = PersistentSupabaseRuntime(
      projectUrl: wire.origin,
      publishableKey: wire.key,
      vault: SessionCredentialVault(projectUrl: wire.origin, backend: vault),
      store: reviews,
      grammarStore: store,
      httpClient: client,
      now: () => server.now,
    );
    final owner = WindowsStagingOwner(
      PersistentAccountStartup(runtime),
      reviews,
      grammarJournal: journal,
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
    'real disk grammar primary correction save restart and A B A remain separate',
    (tester) async {
      final server = _Server();
      final vault = fixture.MemoryVault();
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('nd-grammar-journey-'),
      ))!;
      _DiskApp? current;
      ProviderSubscription<AsyncValue<List<GrammarQuizQuestion>>>? content;
      addTearDown(() async {
        content?.close();
        await tester.runAsync(() async {
          await current?.close();
        });
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => directory.delete(recursive: true));
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

      Future<void> kind(String value) async {
        final selector = find.byKey(const Key('grammar-history-kind'));
        await tester.ensureVisible(selector);
        await tester.pumpAndSettle();
        await tester.tap(selector);
        await tester.pumpAndSettle();
        await tester.tap(find.text(value).last);
        await tester.pumpAndSettle();
      }

      var container = await mount(first);
      final questions = (await tester.runAsync(() async {
        final provider = grammarQuizProvider(PreviewLevel.n5);
        content = container.listen(provider, (_, _) {});
        return container.read(provider.future);
      }))!.take(10).toList();
      expect(questions.length, greaterThanOrEqualTo(4));
      container.read(routerProvider).go('/quiz/grammar');
      await tester.pumpAndSettle();
      final before = server.paths.length;
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        final choice = i == 0
            ? q.choices.firstWhere((c) => c.id != q.target.id)
            : q.target;
        await tapQuiz(
          tester,
          find.byKey(ValueKey('grammar-choice-${choice.id}')),
        );
        await tapQuiz(tester, find.byKey(const Key('grammar-quiz-next')));
      }
      final score = questions.length - 1;
      expect(
        find.text('Kết quả theo bài gốc: $score / ${questions.length}'),
        findsOneWidget,
      );
      expect(first.store.appends, 0);
      final stalePrimary = tester
          .widget<FilledButton>(find.byKey(const Key('grammar-quiz-save')))
          .onPressed!;
      await diskAction(first, 'grammar-quiz-save');
      expect(find.byKey(const Key('grammar-quiz-saved')), findsOneWidget);
      stalePrimary();
      await tester.pumpAndSettle();
      expect(first.store.appends, 1);
      final primary = (await tester.runAsync(
        () => first.journal.list(wire.a),
      ))!.single.attempt;
      expect(primary.kind, GrammarQuizAttemptKind.primary);
      expect(primary.score, score);
      await tapQuiz(tester, find.byKey(const Key('grammar-review-errors')));
      await tapQuiz(
        tester,
        find.byKey(ValueKey('grammar-choice-${questions.first.target.id}')),
      );
      await tapQuiz(tester, find.byKey(const Key('grammar-quiz-next')));
      expect(find.text('Bộ gốc: $score / ${questions.length}'), findsOneWidget);
      expect(find.text('Kết quả theo bài gốc: 1 / 1'), findsOneWidget);
      expect(first.store.appends, 1);
      await diskAction(first, 'grammar-quiz-save');
      expect(find.byKey(const Key('grammar-quiz-saved')), findsOneWidget);
      final saved = (await tester.runAsync(() => first.journal.list(wire.a)))!;
      expect(saved, hasLength(2));
      final correction = saved
          .singleWhere(
            (r) => r.attempt.kind == GrammarQuizAttemptKind.correction,
          )
          .attempt;
      expect(correction.score, 1);
      expect(correction.answers, hasLength(1));
      expect(correction.eventId, isNot(primary.eventId));
      expect(
        sameGrammarQuizAttempt(
          saved
              .singleWhere(
                (r) => r.attempt.kind == GrammarQuizAttemptKind.primary,
              )
              .attempt,
          primary,
        ),
        isTrue,
      );
      container.read(routerProvider).go('/quiz/grammar/history');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grammar-history-summary')), findsNothing);
      await diskAction(first, 'grammar-history-load');
      expect(
        find.text('Vòng gốc · N5 · $score / ${questions.length}'),
        findsOneWidget,
      );
      expect(find.text('Vòng luyện sai · N5 · 1 / 1'), findsNothing);
      await kind('Vòng luyện sai');
      expect(find.text('Vòng luyện sai · N5 · 1 / 1'), findsOneWidget);
      expect(
        find.text('Vòng gốc · N5 · $score / ${questions.length}'),
        findsNothing,
      );
      expect(server.paths.length, before);
      final bytes = (await tester.runAsync(
        () => File(
          '${directory.path}/grammar-quiz-attempts.ndjson',
        ).readAsBytes(),
      ))!;
      content!.close();
      content = null;
      await tester.runAsync(first.close);
      await tester.pumpWidget(const SizedBox());
      expect(first.controller.grammarQuizHistorySource, isNull);
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
      container.read(routerProvider).go('/quiz/grammar/history');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grammar-history-summary')), findsNothing);
      await diskAction(second, 'grammar-history-load');
      expect(
        find.text('Vòng gốc · N5 · $score / ${questions.length}'),
        findsOneWidget,
      );
      await kind('Vòng luyện sai');
      expect(find.text('Vòng luyện sai · N5 · 1 / 1'), findsOneWidget);
      final restored = (await tester.runAsync(
        () => second.journal.list(wire.a),
      ))!;
      for (final original in [primary, correction]) {
        expect(
          sameGrammarQuizAttempt(
            restored
                .singleWhere((r) => r.attempt.eventId == original.eventId)
                .attempt,
            original,
          ),
          isTrue,
        );
      }
      await tester.runAsync(() async {
        await second.runtime.account.signOut();
        server.user = wire.b;
        await second.login();
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grammar-history-summary')), findsNothing);
      await diskAction(second, 'grammar-history-load');
      expect(find.text('Vòng gốc: 0 bộ đã lưu'), findsOneWidget);
      await kind('Vòng luyện sai');
      expect(find.text('Vòng luyện sai: 0 bộ đã lưu'), findsOneWidget);
      expect(
        (await tester.runAsync(() => second.journal.list(wire.b)))!,
        isEmpty,
      );
      await tester.runAsync(() async {
        await second.runtime.account.signOut();
        server.user = wire.a;
        await second.login();
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grammar-history-summary')), findsNothing);
      await diskAction(second, 'grammar-history-load');
      expect(
        find.text('Vòng gốc · N5 · $score / ${questions.length}'),
        findsOneWidget,
      );
      await kind('Vòng luyện sai');
      expect(find.text('Vòng luyện sai · N5 · 1 / 1'), findsOneWidget);
      expect(
        (await tester.runAsync(
          () => File(
            '${directory.path}/grammar-quiz-attempts.ndjson',
          ).readAsBytes(),
        ))!,
        bytes,
      );
      expect(second.store.appends, 0);
      expect(find.textContaining(wire.a), findsNothing);
      expect(find.textContaining('TEST_ONLY'), findsNothing);
      expect(server.paths.toSet(), {
        '/auth/v1/token',
        '/auth/v1/logout',
        '/rest/v1/rpc/ensure_profile',
      });
      expect(tester.takeException(), isNull);
    },
  );
}
