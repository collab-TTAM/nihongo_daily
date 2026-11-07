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
import 'package:nihongo_daily/features/quiz/application/vocabulary_quiz_provider.dart';
import 'package:nihongo_daily/features/quiz/data/native_vocabulary_quiz_journal.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
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

final class _ObservedVocabularyStore implements VocabularyQuizAttemptStore {
  _ObservedVocabularyStore(this.journal);
  final NativeVocabularyQuizJournal journal;
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
    this.vocabularyJournal,
    this.vocabularyStore,
    this.runtime,
    this.controller,
    this.client,
  );
  final NativeGrammarQuizJournal journal;
  final _ObservedStore store;
  final NativeVocabularyQuizJournal vocabularyJournal;
  final _ObservedVocabularyStore vocabularyStore;
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
  NativeGrammarQuizJournal? journal;
  NativeVocabularyQuizJournal? vocabularyJournal;
  PersistentSupabaseRuntime? runtime;
  final client = MockClient(server.respond);
  try {
    journal = await NativeGrammarQuizJournal.open(directory);
    final store = _ObservedStore(journal);
    vocabularyJournal = await NativeVocabularyQuizJournal.open(directory);
    final vocabularyStore = _ObservedVocabularyStore(vocabularyJournal);
    runtime = PersistentSupabaseRuntime(
      projectUrl: wire.origin,
      publishableKey: wire.key,
      vault: SessionCredentialVault(projectUrl: wire.origin, backend: vault),
      store: reviews,
      grammarStore: store,
      quizStore: vocabularyStore,
      httpClient: client,
      now: () => server.now,
    );
    final owner = WindowsStagingOwner(
      PersistentAccountStartup(runtime),
      reviews,
      grammarJournal: journal,
      quizJournal: vocabularyJournal,
    );
    final controller =
        AccountStartupController<AccountController<SrsStudyRuntime>>(
          () async => owner,
        );
    await controller.start();
    return _DiskApp(
      journal,
      store,
      vocabularyJournal,
      vocabularyStore,
      runtime,
      controller,
      client,
    );
  } catch (_) {
    await runtime?.close();
    await journal?.close();
    await vocabularyJournal?.close();
    await reviews.close();
    client.close();
    rethrow;
  }
}

void main() {
  testWidgets(
    'same owned SDK keeps both quiz journals separate through UI account switch and restart',
    (tester) async {
      final server = _Server();
      final vault = fixture.MemoryVault();
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('nd-dual-quiz-journey-'),
      ))!;
      _DiskApp? current;
      ProviderSubscription<AsyncValue<List<QuizQuestion>>>? vocabularyContent;
      ProviderSubscription<AsyncValue<List<GrammarQuizQuestion>>>?
      grammarContent;
      addTearDown(() async {
        vocabularyContent?.close();
        grammarContent?.close();
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
      expect(first.runtime.account.state.profile!.id, wire.a);
      Future<ProviderContainer> mount(_DiskApp app) async {
        await tester.pumpWidget(AccountStartupApp(controller: app.controller));
        await tester.pumpAndSettle();
        return ProviderScope.containerOf(
          tester.element(find.byType(NihongoDailyApp)),
        );
      }

      Future<void> diskAction(
        _DiskApp app,
        String key, {
        bool grammar = false,
      }) async {
        final button = find.byKey(Key(key));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(button.hitTestable(), findsOneWidget);
        expect(
          await tester.runAsync(() async {
            final done = Completer<void>();
            if (grammar) {
              app.store.settled = done;
            } else {
              app.vocabularyStore.settled = done;
            }
            await tester.tap(button);
            await done.future.timeout(const Duration(seconds: 5));
            await Future<void>.delayed(Duration.zero);
            return true;
          }),
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      var container = await mount(first);
      final vocabulary = (await tester.runAsync(() async {
        final provider = vocabularyQuizProvider(PreviewLevel.n5);
        vocabularyContent = container.listen(provider, (_, _) {});
        return container.read(provider.future);
      }))!.take(10).toList();
      final grammar = (await tester.runAsync(() async {
        final provider = grammarQuizProvider(PreviewLevel.n5);
        grammarContent = container.listen(provider, (_, _) {});
        return container.read(provider.future);
      }))!.take(10).toList();
      expect(vocabulary, hasLength(10));
      expect(grammar, hasLength(10));
      final quizHttp = server.paths.length;
      container.read(routerProvider).go('/quiz');
      await tester.pumpAndSettle();
      for (var i = 0; i < vocabulary.length; i++) {
        final q = vocabulary[i];
        final choice = i == 0
            ? q.choices.firstWhere((c) => c.id != q.target.id)
            : q.target;
        await tapQuiz(tester, find.byKey(ValueKey('quiz-choice-${choice.id}')));
        await tapQuiz(tester, find.byKey(const Key('quiz-next')));
      }
      expect(find.text('Kết quả bộ này: 9 / 10'), findsOneWidget);
      expect(first.vocabularyStore.appends, 0);
      expect(first.store.appends, 0);
      await diskAction(first, 'quiz-save');
      expect(find.byKey(const Key('quiz-saved')), findsOneWidget);
      expect(first.vocabularyStore.appends, 1);
      expect(first.store.appends, 0);
      final vocabularyAttempt = (await tester.runAsync(
        () => first.vocabularyJournal.list(wire.a),
      ))!.single.attempt;
      expect(vocabularyAttempt.score, 9);
      final vocabularyBytes = (await tester.runAsync(
        () => File('${directory.path}/quiz-attempts.ndjson').readAsBytes(),
      ))!;

      container.read(routerProvider).go('/quiz/grammar');
      await tester.pumpAndSettle();
      for (var i = 0; i < grammar.length; i++) {
        final q = grammar[i];
        final choice = i < 2
            ? q.choices.firstWhere((c) => c.id != q.target.id)
            : q.target;
        await tapQuiz(
          tester,
          find.byKey(ValueKey('grammar-choice-${choice.id}')),
        );
        await tapQuiz(tester, find.byKey(const Key('grammar-quiz-next')));
      }
      expect(find.text('Kết quả theo bài gốc: 8 / 10'), findsOneWidget);
      expect(first.store.appends, 0);
      await diskAction(first, 'grammar-quiz-save', grammar: true);
      expect(find.byKey(const Key('grammar-quiz-saved')), findsOneWidget);
      expect(first.store.appends, 1);
      expect(first.vocabularyStore.appends, 1);
      final grammarAttempt = (await tester.runAsync(
        () => first.journal.list(wire.a),
      ))!.single.attempt;
      expect(grammarAttempt.kind, GrammarQuizAttemptKind.primary);
      expect(grammarAttempt.score, 8);
      final grammarBytes = (await tester.runAsync(
        () => File(
          '${directory.path}/grammar-quiz-attempts.ndjson',
        ).readAsBytes(),
      ))!;
      expect(
        (await tester.runAsync(
          () => File('${directory.path}/quiz-attempts.ndjson').readAsBytes(),
        ))!,
        vocabularyBytes,
      );
      expect(server.paths.length, quizHttp);

      // Owned recall dashboard assertions.
      void noRecallSnapshot() {
        expect(find.textContaining('đạt mốc ôn cách ngày:'), findsNothing);
        expect(find.textContaining('ít nhất 24 giờ'), findsNothing);
        expect(
          find.textContaining('không xác nhận đã thuộc bài'),
          findsNothing,
        );
      }

      void recallSummary(String label) {
        expect(find.text(label), findsOneWidget);
        expect(find.textContaining('ít nhất 24 giờ'), findsOneWidget);
        expect(find.textContaining('tính lại từ đầu'), findsOneWidget);
        expect(
          find.textContaining('không xác nhận đã thuộc bài'),
          findsOneWidget,
        );
      }

      expect(vocabularyAttempt.answers, hasLength(10));
      expect(grammarAttempt.answers, hasLength(10));
      // End owned recall dashboard assertions.
      void vocabularySummary({bool empty = false}) {
        expect(find.text('N5 · ${empty ? 0 : 1} bộ đã lưu'), findsOneWidget);
        expect(
          find.text('Câu đúng theo bài gốc: ${empty ? '0 / 0' : '9 / 10'}'),
          findsOneWidget,
        );
        expect(find.text('Từ cần ôn: ${empty ? 0 : 1}'), findsOneWidget);
        // Owned recall dashboard assertions.
        recallSummary('N5 · Từ đạt mốc ôn cách ngày: 0');
        // End owned recall dashboard assertions.
        expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
      }

      void grammarSummary({bool empty = false}) {
        expect(
          find.text('Vòng gốc · N5 · ${empty ? 0 : 1} bộ đã lưu'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Vòng gốc · Câu đúng theo bài gốc: ${empty ? '0 / 0' : '8 / 10'}',
          ),
          findsOneWidget,
        );
        expect(find.text('Mẫu cần ôn: ${empty ? 0 : 2}'), findsOneWidget);
        // Owned recall dashboard assertions.
        recallSummary('Vòng gốc · N5 · Mẫu đạt mốc ôn cách ngày: 0');
        // End owned recall dashboard assertions.
        expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      }

      Future<void> navigate(String key, String route) async {
        await tapQuiz(tester, find.byKey(Key(key)));
        expect(
          container
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          route,
        );
        expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
        expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
        // Owned recall dashboard assertions.
        noRecallSnapshot();
        // End owned recall dashboard assertions.
      }

      container.read(routerProvider).go('/progress');
      await tester.pumpAndSettle();
      expect(first.vocabularyStore.reads, 0);
      expect(first.store.reads, 0);
      // Owned recall dashboard assertions.
      noRecallSnapshot();
      // End owned recall dashboard assertions.
      await diskAction(first, 'quiz-progress-load');
      vocabularySummary();
      await navigate('progress-grammar', '/quiz/grammar/progress');
      expect(first.vocabularyStore.reads, 1);
      expect(first.store.reads, 0);
      await diskAction(first, 'grammar-progress-load', grammar: true);
      grammarSummary();
      await navigate('progress-vocabulary', '/progress');
      expect(first.store.reads, 1);
      expect(first.vocabularyStore.reads, 1);
      await diskAction(first, 'quiz-progress-load');
      vocabularySummary();
      expect(first.vocabularyStore.reads, 2);
      expect(server.paths.length, quizHttp);

      // The same ready owner exposes both stores; neither carries A into B.
      await tester.runAsync(() async {
        await first.runtime.account.signOut();
        server.user = wire.b;
        await first.login();
      });
      await tester.pumpAndSettle();
      expect(first.runtime.account.state.profile!.id, wire.b);
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      // Owned recall dashboard assertions.
      noRecallSnapshot();
      // End owned recall dashboard assertions.
      await diskAction(first, 'quiz-progress-load');
      vocabularySummary(empty: true);
      expect(find.text(vocabulary.first.target.heading), findsNothing);
      await navigate('progress-grammar', '/quiz/grammar/progress');
      await diskAction(first, 'grammar-progress-load', grammar: true);
      grammarSummary(empty: true);
      expect(find.text(grammar.first.target.heading), findsNothing);
      await tester.runAsync(() async {
        await first.runtime.account.signOut();
        server.user = wire.a;
        await first.login();
      });
      await tester.pumpAndSettle();
      expect(first.runtime.account.state.profile!.id, wire.a);
      expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
      // Owned recall dashboard assertions.
      noRecallSnapshot();
      // End owned recall dashboard assertions.
      await diskAction(first, 'grammar-progress-load', grammar: true);
      grammarSummary();
      await navigate('progress-vocabulary', '/progress');
      await diskAction(first, 'quiz-progress-load');
      vocabularySummary();
      expect(first.store.appends, 1);
      expect(first.vocabularyStore.appends, 1);

      vocabularyContent?.close();
      vocabularyContent = null;
      grammarContent?.close();
      grammarContent = null;
      await tester.runAsync(first.close);
      expect(first.controller.grammarQuizHistorySource, isNull);
      expect(first.controller.quizHistorySource, isNull);
      await tester.pumpWidget(const SizedBox());
      final refreshes = server.paths.where((p) => p == '/auth/v1/token').length;
      final second = (await tester.runAsync(() async {
        final app = await _open(directory, server, vault);
        current = app;
        await app.ready();
        return app;
      }))!;
      expect(
        server.paths.where((p) => p == '/auth/v1/token').length,
        refreshes + 1,
      );
      expect(second.runtime.account.state.profile!.id, wire.a);
      container = await mount(second);
      final restoredHttp = server.paths.length;
      container.read(routerProvider).go('/progress');
      await tester.pumpAndSettle();
      expect(second.vocabularyStore.reads, 0);
      expect(second.store.reads, 0);
      expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
      // Owned recall dashboard assertions.
      noRecallSnapshot();
      // End owned recall dashboard assertions.
      await diskAction(second, 'quiz-progress-load');
      vocabularySummary();
      await navigate('progress-grammar', '/quiz/grammar/progress');
      expect(second.store.reads, 0);
      await diskAction(second, 'grammar-progress-load', grammar: true);
      grammarSummary();
      expect(second.vocabularyStore.reads, 1);
      expect(second.store.reads, 1);
      expect(second.vocabularyStore.appends, 0);
      expect(second.store.appends, 0);
      expect(server.paths.length, restoredHttp);
      final restoredVocabulary = (await tester.runAsync(
        () => second.vocabularyJournal.list(wire.a),
      ))!;
      final restoredGrammar = (await tester.runAsync(
        () => second.journal.list(wire.a),
      ))!;
      expect(restoredVocabulary, hasLength(1));
      expect(restoredGrammar, hasLength(1));
      expect(
        sameVocabularyQuizAttempt(
          restoredVocabulary.single.attempt,
          vocabularyAttempt,
        ),
        isTrue,
      );
      expect(
        sameGrammarQuizAttempt(restoredGrammar.single.attempt, grammarAttempt),
        isTrue,
      );
      expect(
        (await tester.runAsync(() => second.vocabularyJournal.list(wire.b)))!,
        isEmpty,
      );
      expect(
        (await tester.runAsync(() => second.journal.list(wire.b)))!,
        isEmpty,
      );
      expect(
        (await tester.runAsync(
          () => File('${directory.path}/quiz-attempts.ndjson').readAsBytes(),
        ))!,
        vocabularyBytes,
      );
      expect(
        (await tester.runAsync(
          () => File(
            '${directory.path}/grammar-quiz-attempts.ndjson',
          ).readAsBytes(),
        ))!,
        grammarBytes,
      );
      expect(server.paths.toSet(), {
        '/auth/v1/token',
        '/auth/v1/logout',
        '/rest/v1/rpc/ensure_profile',
      });
      expect(find.textContaining('TEST_ONLY'), findsNothing);
      expect(find.textContaining(wire.a), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
