// TEST ONLY service/vault ports. Actual pinned SDK, native review journal,
// Windows owner, startup/controller, Riverpod, router and mounted tutor.
// Not hosted Auth/JWT/provider, Windows credential hardware or learner proof.
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
import 'package:nihongo_daily/features/ai/application/conversation_workspace_provider.dart';
import 'package:nihongo_daily/features/ai/application/conversation_workspace_binding.dart';
import 'package:nihongo_daily/features/ai/application/conversation_workspace_controller.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_controller.dart';
import 'package:nihongo_daily/features/ai/application/ai_conversation_controller.dart';
import 'package:nihongo_daily/features/ai/application/ai_conversation_view_binding.dart';
import 'package:nihongo_daily/features/ai/application/ai_conversation_scenario_binding.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_view_binding.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_account_startup.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/auth/data/persistent_account_access.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_runtime.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import '../srs/own_profile_fixtures.dart' as profile;
import '../srs/session_lifecycle_fixtures.dart' as lifecycle;
import '../srs/supabase_review_binding_test.dart' as wire;

late Map<String, Object?> _fixtures;

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.StreamedResponse _answer(String operation, {String? marker}) {
  final body = Map<String, Object?>.from(
    _fixtures['${operation}_response']! as Map<String, Object?>,
  );
  if (marker != null) {
    body['answer_vi'] = marker;
  }
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    200,
    headers: {'content-type': 'application/json'},
  );
}

final class _Server {
  String user = wire.a;
  int generation = 0;
  final now = DateTime.utc(2026, 10, 24);
  final requests = <http.Request>[];
  Completer<http.Response>? profileWait;
  bool failProfile = false;
  String get secret => 'TEST_ONLY_AI_JOURNEY_$generation';
  String get bearer => wire.token(user, wire.sid1, now, generation: generation);
  Future<http.Response> respond(http.Request r) async {
    requests.add(r);
    if (r.url.path == '/auth/v1/token') {
      generation++;
      return _json({
        'access_token': bearer,
        'refresh_token': secret,
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': user,
          'aud': 'authenticated',
          'role': 'authenticated',
          'created_at': '2026-10-24T00:00:00Z',
          'app_metadata': <String, Object>{},
          'user_metadata': <String, Object>{},
        },
      });
    }
    if (r.url.path == '/auth/v1/logout') return http.Response('', 204);
    if (r.url.path == '/rest/v1/rpc/ensure_profile') {
      return profileWait?.future ??
          Future.value(
            failProfile
                ? _json({'message': 'TEST_ONLY_PRIVATE_PROFILE'}, 500)
                : _json(profile.profile(user)),
          );
    }
    throw StateError('Unexpected TEST ONLY startup endpoint');
  }
}

final class _AiHttp extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  Future<http.StreamedResponse> Function(http.BaseRequest)? onSend;
  Completer<http.StreamedResponse>? held;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return Future<http.StreamedResponse>.sync(
      () => onSend?.call(request) ?? _answer(request.url.path.split('/').last),
    );
  }

  void hold() {
    held = Completer<http.StreamedResponse>();
    onSend = (_) => held!.future; // Deliberately ignores abort until released.
  }

  void release({bool error = false}) {
    final pending = held;
    if (pending == null || pending.isCompleted) return;
    if (error) {
      pending.completeError(StateError('TEST_ONLY_PRIVATE_OLD_HTTP'));
    } else {
      pending.complete(
        _answer('tutor_explain', marker: 'TEST_ONLY_OLD_ANSWER'),
      );
    }
    onSend = null;
  }

  @override
  void close() => closed = true;
}

final class _App {
  _App(
    this.directory,
    this.server,
    this.vault,
    this.auth,
    this.ai,
    this.runtime,
    this.owner,
    this.controller,
  );
  final Directory directory;
  final _Server server;
  final lifecycle.MemoryVault vault;
  final MockClient auth;
  final _AiHttp ai;
  final PersistentSupabaseRuntime runtime;
  final WindowsStagingOwner owner;
  final AccountStartupController<AccountController<SrsStudyRuntime>> controller;
  Future<void>? starting;

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
    expect(runtime.account.readyRuntime, isNotNull);
  }

  Future<void> login() async {
    await runtime.account.signIn(
      'fixture@example.invalid',
      'TEST_ONLY_PASSWORD',
    );
    await ready();
  }

  Future<void> close() async {
    // Release deliberately stalled test ports even if an assertion failed.
    final write = vault.writeWait;
    if (write != null && !write.isCompleted) {
      write.complete();
    }
    final reply = server.profileWait;
    if (reply != null && !reply.isCompleted) {
      reply.complete(_json(profile.profile(server.user)));
    }
    ai.release(error: true);
    await controller.close().timeout(const Duration(seconds: 5));
    auth.close();
    ai.close();
    await directory.delete(recursive: true);
  }
}

Future<_App> _open({
  bool enabled = true,
  bool conversationEnabled = false,
}) async {
  final directory = await Directory.systemTemp.createTemp('nd-ai-startup-');
  final journal = await NativeReviewJournal.open(directory);
  final server = _Server();
  final vault = lifecycle.MemoryVault();
  final auth = MockClient(server.respond);
  final ai = _AiHttp();
  final runtime = PersistentSupabaseRuntime(
    projectUrl: wire.origin,
    publishableKey: wire.key,
    vault: SessionCredentialVault(projectUrl: wire.origin, backend: vault),
    store: journal,
    httpClient: auth,
    aiHttpClient: ai,
    now: () => server.now,
    aiTextEnabled: enabled, // TEST ONLY opt-in, never build/default activation.
    aiConversationEnabled: conversationEnabled,
  );
  final owner = WindowsStagingOwner(PersistentAccountStartup(runtime), journal);
  final controller =
      AccountStartupController<AccountController<SrsStudyRuntime>>(
        () async => owner,
      );
  return _App(directory, server, vault, auth, ai, runtime, owner, controller);
}

// Complete real-loop owned cleanup before the widget-test body finishes,
// before the binding's automatic disposal can initiate it from FakeAsync.
_App? _activeApp;
void _ownedTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    _activeApp = null;
    try {
      await body(tester);
    } finally {
      final app = _activeApp;
      if (app != null) {
        await tester.runAsync(() async {
          await app.close();
          expect(
            PersistentAccountAccess.isTargetOwned(
              app.runtime.persistence.vault.target,
            ),
            isFalse,
            reason: 'each fixture must release its real exclusive vault owner',
          );
        });
      }
      await tester.pumpWidget(const SizedBox());
      _activeApp = null;
    }
  });
}

Future<_App> _fixture(
  WidgetTester tester, {
  bool enabled = true,
  bool conversationEnabled = false,
  bool start = true,
}) async {
  final app = (await tester.runAsync(
    () => _open(enabled: enabled, conversationEnabled: conversationEnabled),
  ))!;
  _activeApp = app;
  if (start) {
    await tester.runAsync(app.controller.start);
  }
  return app;
}

// Nonvisual source/SDK journeys must create, listen, await and cancel in one
// real event-loop zone. Bound the whole journey instead of waiting ten minutes
// for a mixed FakeAsync/real-loop stream completion that cannot be pumped.
Future<void> _sourceJourney(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  await tester.runAsync(() => body().timeout(const Duration(seconds: 15)));
}

Future<ProviderContainer> _mount(WidgetTester tester, _App app) async {
  await tester.pumpWidget(AccountStartupApp(controller: app.controller));
  // The account route can still show an intentionally held profile spinner.
  // Publish the real scope, then navigate before settling static tutor frames.
  await tester.pump();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(NihongoDailyApp)),
  );
  expect(
    identical(container.read(aiTextRepositorySourceProvider), app.owner),
    isTrue,
  );
  container.read(routerProvider).go('/ai');
  await tester.pumpAndSettle();
  return container;
}

Future<VoidCallback> _draft(WidgetTester tester, String text) async {
  final field = find.byKey(const Key('ai-draft'));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
  return tester
      .widget<FilledButton>(find.byKey(const Key('ai-send')))
      .onPressed!;
}

Future<void> _send(WidgetTester tester) async {
  final button = find.byKey(const Key('ai-send'));
  await tester.ensureVisible(button);
  expect(button.hitTestable(), findsOneWidget);
  await tester.runAsync(() async {
    await tester.tap(button);
    await lifecycle.flush();
  });
  await tester.pump();
}

void _empty(WidgetTester tester) {
  expect(find.byKey(const Key('ai-draft')), findsNothing);
  expect(find.byKey(const Key('ai-result')), findsNothing);
  expect(find.textContaining('TEST_ONLY_PRIVATE'), findsNothing);
  expect(find.text('TEST_ONLY_OLD_ANSWER'), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() {
    _fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });

  _ownedTest(
    'Windows owner startup waits for rotation and profile before first tutor binding',
    (tester) async {
      final app = await _fixture(tester, start: false);
      app.vault.secret = 'TEST_ONLY_SAVED';
      app.vault.writeWait = Completer<void>();
      app.server.profileWait = Completer<http.Response>();
      await tester.runAsync(() async {
        app.starting = app.controller.start();
        await lifecycle.flush();
      });
      await tester.pumpWidget(AccountStartupApp(controller: app.controller));
      await tester.pump();
      expect(find.text('Đang khôi phục phiên đăng nhập…'), findsOneWidget);
      _empty(tester);
      expect(app.controller.aiTextSource, isNull);
      expect(app.owner.createAiTextRepository(), isNull);
      expect(
        app.server.requests.where((r) => r.url.path.contains('ensure_profile')),
        isEmpty,
      );
      await tester.runAsync(() async {
        app.vault.writeWait!.complete();
        await app.starting;
        await lifecycle.flush();
      });
      expect(app.vault.secret, app.server.secret);
      expect(app.runtime.account.state.phase, AccountPhase.loadingProfile);
      final container = await _mount(tester, app);
      expect(container.read(aiTextViewBindingProvider), isNull);
      _empty(tester);
      await tester.runAsync(() async {
        app.server.profileWait!.complete(
          _json(profile.profile(app.server.user)),
        );
        await app.ready();
        await lifecycle.flush();
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-draft')), findsOneWidget);
      final binding = container.read(aiTextViewBindingProvider)!;
      expect(
        identical(binding.repository, app.owner.createAiTextRepository()),
        isTrue,
      );
      expect(
        identical(app.owner.aiTextChanges, app.runtime.aiTextChanges),
        isTrue,
      );
      expect(app.ai.requests, isEmpty);
      const text = '  Cách dùng ます?  ';
      await _draft(tester, text);
      await _send(tester);
      await tester.pumpAndSettle();
      final request = app.ai.requests.single as http.Request;
      expect(request.url.path, '/functions/v1/tutor_explain');
      expect(request.headers['authorization'], 'Bearer ${app.server.bearer}');
      expect(jsonDecode(request.body), {
        'jlpt_level': 'N5',
        'question_vi': text,
        'context': {
          'recent_grammar_ids': <String>[],
          'recent_vocabulary_ids': <String>[],
        },
      });
      expect(find.text('Đây là thể lịch sự.'), findsOneWidget);
      expect(
        find.text('Kết quả tham khảo. Chưa lưu vào tiến độ.'),
        findsOneWidget,
      );
      expect(
        app.server.requests.every(
          (r) =>
              r.url.path.startsWith('/auth/v1/') ||
              r.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  _ownedTest(
    'disabled owned runtime never activates tutor by mounting or navigation',
    (tester) async {
      final app = await _fixture(tester, enabled: false);
      await tester.runAsync(app.login);
      final container = await _mount(tester, app);
      expect(container.read(aiTextViewBindingProvider), isNull);
      expect(app.owner.createAiTextRepository(), isNull);
      expect(app.runtime.isAiTextEnabled, isFalse);
      _empty(tester);
      expect(app.ai.requests, isEmpty);
    },
  );

  for (final error in [false, true]) {
    _ownedTest(
      'mounted tutor refresh fences old callback and ignored HTTP abort error=$error',
      (tester) async {
        final app = await _fixture(tester);
        await tester.runAsync(app.login);
        final container = await _mount(tester, app);
        final old = container.read(aiTextViewBindingProvider)!;
        final oldBearer = app.server.bearer;
        final retained = await _draft(tester, 'TEST ONLY OLD DRAFT');
        app.ai.hold();
        await _send(tester);
        expect(app.ai.requests, hasLength(1));
        final first = app.ai.requests.single as http.AbortableRequest;
        app.vault.writeWait = Completer<void>();
        app.server.profileWait = Completer<http.Response>();
        Future<void>? refreshing;
        await tester.runAsync(() async {
          refreshing = app.owner.refresh();
          expect(old.repository.isCurrent, isFalse);
          retained(); // Old widget callback before another frame is fenced too.
          await lifecycle.flush();
          await first.abortTrigger;
        });
        await tester.pumpAndSettle();
        _empty(tester);
        expect(container.read(aiTextViewBindingProvider), isNull);
        expect(app.ai.requests, hasLength(1));
        await tester.runAsync(() async {
          app.vault.writeWait!.complete();
          await refreshing;
          await lifecycle.flush();
        });
        expect(app.runtime.account.state.phase, AccountPhase.loadingProfile);
        expect(app.vault.secret, app.server.secret);
        await tester.pumpAndSettle();
        _empty(tester);
        await tester.runAsync(() async {
          app.server.profileWait!.complete(
            _json(profile.profile(app.server.user)),
          );
          await app.ready();
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        // Auth/profile are ready; old real HTTP still prevents capability allocation.
        expect(container.read(aiTextViewBindingProvider), isNull);
        _empty(tester);
        retained();
        expect(app.ai.requests, hasLength(1));
        await tester.runAsync(() async {
          app.ai.release(error: error);
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        final next = container.read(aiTextViewBindingProvider)!;
        expect(identical(next.repository, old.repository), isFalse);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('ai-draft')))
              .controller!
              .text,
          isEmpty,
        );
        expect(find.byKey(const Key('ai-result')), findsNothing);
        expect(find.text('TEST_ONLY_OLD_ANSWER'), findsNothing);
        retained();
        expect(app.ai.requests, hasLength(1));
        tester
            .widget<DropdownButtonFormField<AiTextOperation>>(
              find.byKey(const Key('ai-operation')),
            )
            .onChanged!(AiTextOperation.correct);
        await tester.pump();
        tester
            .widget<DropdownButtonFormField<AiTextLevel>>(
              find.byKey(const Key('ai-level')),
            )
            .onChanged!(AiTextLevel.n4);
        await tester.pump();
        await _draft(tester, '水を飲みます。');
        await _send(tester);
        await tester.pumpAndSettle();
        expect(app.ai.requests, hasLength(2));
        final last = app.ai.requests.last as http.Request;
        expect(last.url.path, '/functions/v1/correct_sentence');
        expect(jsonDecode(last.body), {
          'jlpt_level': 'N4',
          'sentence_ja': '水を飲みます。',
        });
        expect(first.headers['authorization'], 'Bearer $oldBearer');
        expect(last.headers['authorization'], 'Bearer ${app.server.bearer}');
        expect(oldBearer, isNot(app.server.bearer));
        expect(find.text('Kết quả N4'), findsOneWidget);
        expect(find.textContaining('TEST_ONLY_PRIVATE'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  _ownedTest(
    'mounted tutor A B A clears results and never retargets old callbacks',
    (tester) async {
      final app = await _fixture(tester);
      await tester.runAsync(app.login);
      final container = await _mount(tester, app);
      final firstA = container.read(aiTextViewBindingProvider)!;
      final staleA = await _draft(tester, 'TEST ONLY ACCOUNT A');
      await _send(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-result')), findsOneWidget);
      await tester.runAsync(app.runtime.account.signOut);
      staleA();
      await tester.pumpAndSettle();
      _empty(tester);
      expect(app.vault.secret, isNull);
      expect(firstA.repository.isCurrent, isFalse);
      app.server.user = wire.b;
      await tester.runAsync(app.login);
      await tester.pumpAndSettle();
      final bindingB = container.read(aiTextViewBindingProvider)!;
      expect(identical(bindingB.repository, firstA.repository), isFalse);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-draft')))
            .controller!
            .text,
        isEmpty,
      );
      staleA();
      expect(app.ai.requests, hasLength(1));
      final staleB = await _draft(tester, 'TEST ONLY ACCOUNT B');
      app.ai.hold();
      await _send(tester);
      final bBearer = app.server.bearer;
      await tester.runAsync(app.runtime.account.signOut);
      app.server.user = wire.a;
      await tester.runAsync(app.login);
      await tester.pumpAndSettle();
      expect(container.read(aiTextViewBindingProvider), isNull);
      _empty(tester);
      await tester.runAsync(() async {
        app.ai.release(error: true);
        await lifecycle.flush();
      });
      await tester.pumpAndSettle();
      final secondA = container.read(aiTextViewBindingProvider)!;
      expect(identical(secondA.repository, firstA.repository), isFalse);
      expect(identical(secondA.repository, bindingB.repository), isFalse);
      staleA();
      staleB();
      expect(app.ai.requests, hasLength(2));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-draft')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.byKey(const Key('ai-result')), findsNothing);
      await _draft(tester, 'TEST ONLY FRESH A');
      await _send(tester);
      await tester.pumpAndSettle();
      expect(app.ai.requests, hasLength(3));
      expect(app.ai.requests[1].headers['authorization'], 'Bearer $bBearer');
      expect(
        app.ai.requests.last.headers['authorization'],
        'Bearer ${app.server.bearer}',
      );
      expect(bindingB.repository.isCurrent, isFalse);
      expect(find.textContaining('TEST_ONLY_PRIVATE'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final storage in [true, false]) {
    _ownedTest(
      'mounted tutor stays unavailable after failed barrier storage=$storage',
      (tester) async {
        final app = await _fixture(tester);
        final container = await _mount(tester, app);
        app.vault.failWrite = storage;
        app.server.failProfile = !storage;
        await tester.runAsync(() async {
          await app.runtime.account.signIn(
            'fixture@example.invalid',
            'TEST_ONLY_PASSWORD',
          );
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        expect(app.runtime.account.readyRuntime, isNull);
        expect(container.read(aiTextViewBindingProvider), isNull);
        _empty(tester);
        expect(app.ai.requests, isEmpty);
        if (storage) {
          expect(
            app.server.requests.where(
              (r) => r.url.path.contains('ensure_profile'),
            ),
            isEmpty,
          );
        } else {
          expect(app.runtime.account.state.phase, AccountPhase.profileError);
        }
        app.vault.failWrite = false;
        app.server.failProfile = false;
        await tester.runAsync(() async {
          if (storage) {
            await app.login();
          } else {
            await app.runtime.account.retryProfile();
            await app.ready();
          }
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('ai-draft')), findsOneWidget);
        expect(
          app.ai.requests,
          isEmpty,
        ); // Explicit recovery never submits text.
        expect(tester.takeException(), isNull);
      },
    );
  }

  _ownedTest(
    'owned startup close removes tutor and drains ignored HTTP without closing borrowed client',
    (tester) async {
      final app = await _fixture(tester);
      await tester.runAsync(app.login);
      final container = await _mount(tester, app);
      final binding = container.read(aiTextViewBindingProvider)!;
      final retained = await _draft(tester, 'TEST ONLY CLOSING');
      app.ai.hold();
      await _send(tester);
      var closed = false;
      Future<void>? closing;
      await tester.runAsync(() async {
        closing = app.controller.close()
          ..then((_) {
            closed = true;
          });
        expect(app.controller.aiTextSource, isNull);
        retained();
        await lifecycle.flush();
        expect(binding.repository.isCurrent, isFalse);
        expect(app.owner.createAiTextRepository(), isNull);
      });
      await tester.pumpAndSettle();
      _empty(tester);
      expect(app.controller.aiTextSource, isNull);
      expect(closed, isFalse);
      expect(app.ai.requests, hasLength(1));
      await tester.runAsync(() async {
        app.ai.release(error: true);
        await closing;
      });
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(app.ai.closed, isFalse);
      expect(app.vault.secret, app.server.secret); // Shutdown is not logout.
      retained();
      expect(app.ai.requests, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  _ownedTest(
    'mounted tutor HTTP401 clears private state and requires fresh explicit refresh',
    (tester) async {
      final app = await _fixture(tester);
      await tester.runAsync(app.login);
      final container = await _mount(tester, app);
      final old = container.read(aiTextViewBindingProvider)!;
      final oldBearer = app.server.bearer;
      await _draft(tester, 'TEST ONLY PREVIOUS ANSWER');
      await _send(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-result')), findsOneWidget);
      final retained = await _draft(tester, 'TEST ONLY REJECTED DRAFT');
      final authCount = app.server.requests.length;
      app.ai.onSend = (_) async => http.StreamedResponse(
        Stream.value(utf8.encode('TEST_ONLY_PRIVATE_401_BODY')),
        401,
        headers: {'content-type': 'text/plain'},
      );
      await _send(tester);
      await tester.pumpAndSettle();
      _empty(tester);
      expect(find.text('TEST ONLY PREVIOUS ANSWER'), findsNothing);
      expect(find.text('TEST ONLY REJECTED DRAFT'), findsNothing);
      expect(old.repository.isCurrent, isFalse);
      expect(app.runtime.account.state.phase, AccountPhase.ready);
      expect(app.server.requests, hasLength(authCount));
      expect(app.ai.requests, hasLength(2));
      retained();
      expect(app.owner.createAiTextRepository(), isNull);
      await tester.runAsync(lifecycle.flush);
      await tester.pumpAndSettle();
      expect(container.read(aiTextViewBindingProvider), isNull);
      container.read(routerProvider).go('/conversation');
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/ai');
      await tester.pumpAndSettle();
      _empty(tester);
      retained();
      expect(app.owner.createAiTextRepository(), isNull);
      expect(app.ai.requests, hasLength(2));
      expect(app.server.requests, hasLength(authCount));
      app.ai.onSend = null;
      await tester.runAsync(() async {
        await app.owner.refresh();
        await app.ready();
        await lifecycle.flush();
      });
      await tester.pumpAndSettle();
      final fresh = container.read(aiTextViewBindingProvider)!;
      expect(identical(fresh.repository, old.repository), isFalse);
      expect(app.vault.secret, app.server.secret);
      expect(oldBearer, isNot(app.server.bearer));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-draft')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.byKey(const Key('ai-result')), findsNothing);
      retained();
      expect(app.ai.requests, hasLength(2));
      await _draft(tester, 'TEST ONLY FRESH REQUEST');
      await _send(tester);
      await tester.pumpAndSettle();
      expect(app.ai.requests, hasLength(3));
      expect(app.ai.requests[1].headers['authorization'], 'Bearer $oldBearer');
      expect(
        app.ai.requests.last.headers['authorization'],
        'Bearer ${app.server.bearer}',
      );
      expect(find.byKey(const Key('ai-result')), findsOneWidget);
      expect(find.textContaining('TEST_ONLY_PRIVATE'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  _ownedTest(
    'conversation source forwards actual startup owner readiness refresh and close',
    (tester) async {
      final app = await _fixture(
        tester,
        enabled: false,
        conversationEnabled: true,
        start: false,
      );
      await _sourceJourney(tester, () async {
        expect(app.controller.aiConversationSource, isNull);
        expect(app.owner.createAiConversationSession(), isNull);
        expect(app.ai.requests, isEmpty);
        await app.controller.start();
        final source = app.controller.aiConversationSource!;
        expect(identical(source, app.owner), isTrue);
        expect(
          identical(
            source.aiConversationChanges,
            app.runtime.aiConversationChanges,
          ),
          isTrue,
        );
        expect(
          identical(
            app.owner.session.aiConversationChanges,
            source.aiConversationChanges,
          ),
          isTrue,
        );
        expect(source.createAiConversationSession(), isNull);
        var hints = 0;
        final listener = source.aiConversationChanges.listen((_) {
          hints++;
        });
        try {
          await app.login();
          final flow = source.createAiConversationSession()!;
          expect(
            identical(app.owner.session.createAiConversationSession(), flow),
            isTrue,
          );
          expect(
            identical(app.runtime.createAiConversationSession(), flow),
            isTrue,
          );
          expect(identical(source.createAiConversationSession(), flow), isTrue);
          expect(app.owner.createAiTextRepository(), isNull);
          expect(app.ai.requests, isEmpty);
          await flow.start(
            StartConversationRequest.fromJson(
              _fixtures['start_conversation_request'],
            ),
          );
          expect(flow.snapshot.phase, ConversationSessionPhase.active);
          expect(app.ai.requests, hasLength(1));
          final oldSecret = app.vault.secret;
          await app.owner.refresh();
          await app.ready();
          expect(flow.snapshot.messages, isEmpty);
          expect(app.vault.secret, isNot(oldSecret));
          final next = source.createAiConversationSession()!;
          expect(identical(next, flow), isFalse);
          expect(next.snapshot.phase, ConversationSessionPhase.notStarted);
          await Future<void>.delayed(Duration.zero);
          expect(hints, greaterThan(0));
          await app.runtime.account.signOut();
          expect(next.snapshot.messages, isEmpty);
          expect(source.createAiConversationSession(), isNull);
          await app.controller.close();
          expect(app.controller.aiConversationSource, isNull);
          expect(app.owner.createAiConversationSession(), isNull);
        } finally {
          await listener.cancel();
        }
      });
    },
  );
  _ownedTest(
    'default-off conversation source stays unavailable through Windows startup',
    (tester) async {
      final app = await _fixture(tester);
      await _sourceJourney(tester, () async {
        await app.login();
        final source = app.controller.aiConversationSource!;
        expect(identical(source, app.owner), isTrue);
        expect(app.runtime.isAiConversationEnabled, isFalse);
        expect(source.createAiConversationSession(), isNull);
        expect(app.owner.session.createAiConversationSession(), isNull);
        expect(app.owner.createAiTextRepository(), isNotNull);
        expect(app.ai.requests, isEmpty);
      });
    },
  );

  _ownedTest(
    'mounted conversation binding waits for vault profile and fences refresh logout',
    (tester) async {
      final app = await _fixture(
        tester,
        start: false,
        enabled: false,
        conversationEnabled: true,
      );
      AiConversationController? view;
      ProviderSubscription<AiConversationViewBinding?>? subscription;
      try {
        await tester.runAsync(() async {
          // The SDK awaits these futures in the real event loop. Constructing
          // them in FakeAsync can queue completion behind the blocked widget zone.
          app.vault.secret = 'TEST_ONLY_SAVED';
          app.vault.writeWait = Completer<void>();
          app.server.profileWait = Completer<http.Response>();
          app.starting = app.controller.start();
          await lifecycle.flush();
        });
        await tester.pumpWidget(AccountStartupApp(controller: app.controller));
        await tester.pump();
        expect(find.text('Đang khôi phục phiên đăng nhập…'), findsOneWidget);
        expect(app.controller.aiConversationSource, isNull);
        expect(app.ai.requests, isEmpty);
        await tester.runAsync(() async {
          app.vault.writeWait!.complete();
          await app.starting;
          await lifecycle.flush();
        });
        expect(app.vault.secret, app.server.secret);
        expect(app.runtime.account.state.phase, AccountPhase.loadingProfile);
        final container = await _mount(tester, app);
        await tester.runAsync(() async {
          expect(container.read(aiConversationSourceProvider), same(app.owner));
          subscription = container.listen(
            aiConversationViewBindingProvider,
            (_, _) {},
          );
          expect(container.read(aiConversationViewBindingProvider), isNull);
          expect(app.owner.createAiConversationSession(), isNull);
          expect(app.ai.requests, isEmpty);
          app.server.profileWait!.complete(
            _json(profile.profile(app.server.user)),
          );
          await app.ready();
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        late AiConversationViewBinding old;
        late String oldBearer;
        await tester.runAsync(() async {
          old = container.read(aiConversationViewBindingProvider)!;
          expect(old.session, same(app.owner.createAiConversationSession()));
          expect(
            old.availabilityChanges,
            same(app.owner.aiConversationChanges),
          );
          expect(
            old.session.snapshot.phase,
            ConversationSessionPhase.notStarted,
          );
          expect(container.read(aiTextViewBindingProvider), isNull);
          expect(app.ai.requests, isEmpty);
          final controller = AiConversationController(
            session: old.session,
            availabilityChanges: old.availabilityChanges,
          );
          view = controller;
          final request = StartConversationRequest.fromJson(
            _fixtures['start_conversation_request'],
          );
          oldBearer = app.server.bearer;
          await controller.start(
            scenarioId: request.scenarioId,
            level: request.level,
            clientEventId: request.clientEventId,
          );
          expect(
            controller.state.conversation!.phase,
            ConversationSessionPhase.active,
          );
          final sent = app.ai.requests.single as http.Request;
          expect(sent.url.path, '/functions/v1/start_conversation');
          expect(sent.headers['authorization'], 'Bearer $oldBearer');
          expect(jsonDecode(sent.body), request.toJson());
        });
        Future<void>? refreshing;
        await tester.runAsync(() async {
          app.vault.writeWait = Completer<void>();
          app.server.profileWait = Completer<http.Response>();
          refreshing = app.owner.refresh();
          expect(old.session.isCurrent, isFalse);
          expect(view!.state.phase, AiConversationPhase.unavailable);
          expect(view!.state.conversation, isNull);
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          expect(container.read(aiConversationViewBindingProvider), isNull);
          expect(app.ai.requests, hasLength(1));
          app.vault.writeWait!.complete();
          await refreshing;
          await lifecycle.flush();
          expect(app.vault.secret, app.server.secret);
          expect(app.runtime.account.state.phase, AccountPhase.loadingProfile);
          expect(container.read(aiConversationViewBindingProvider), isNull);
          app.server.profileWait!.complete(
            _json(profile.profile(app.server.user)),
          );
          await app.ready();
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final next = container.read(aiConversationViewBindingProvider)!;
          expect(next.session, isNot(same(old.session)));
          expect(next.session, same(app.owner.createAiConversationSession()));
          expect(
            next.session.snapshot.phase,
            ConversationSessionPhase.notStarted,
          );
          expect(next.session.snapshot.messages, isEmpty);
          expect(old.session.snapshot.messages, isEmpty);
          expect(view!.state.conversation, isNull);
          expect(app.server.bearer, isNot(oldBearer));
          expect(app.ai.requests, hasLength(1)); // Refresh never resends start.
          await app.runtime.account.signOut();
          await lifecycle.flush();
          expect(next.session.isCurrent, isFalse);
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          expect(container.read(aiConversationViewBindingProvider), isNull);
          expect(app.owner.createAiConversationSession(), isNull);
          expect(app.ai.requests, hasLength(1));
        });
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(() async {
          view?.dispose();
          subscription?.close();
        });
      }
    },
  );

  _ownedTest('mounted App conversation binding remains off by default', (
    tester,
  ) async {
    final app = await _fixture(tester);
    await tester.runAsync(app.login);
    final container = await _mount(tester, app);
    await tester.runAsync(() async {
      expect(container.read(aiConversationSourceProvider), same(app.owner));
      expect(container.read(aiConversationViewBindingProvider), isNull);
      expect(app.owner.createAiConversationSession(), isNull);
      expect(app.owner.createAiTextRepository(), isNotNull);
      expect(app.ai.requests, isEmpty);
    });
    expect(tester.takeException(), isNull);
  });

  _ownedTest(
    'mounted scenario binding waits for owned barriers and fences refresh logout',
    (tester) async {
      final app = await _fixture(
        tester,
        start: false,
        enabled: false,
        conversationEnabled: true,
      );
      ProviderSubscription<AiConversationScenarioBinding?>? subscription;
      try {
        await tester.runAsync(() async {
          // Keep barriers in the real SDK event loop, as in the conversation case.
          app.vault.secret = 'TEST_ONLY_SAVED';
          app.vault.writeWait = Completer<void>();
          app.server.profileWait = Completer<http.Response>();
          app.starting = app.controller.start();
          await lifecycle.flush();
        });
        await tester.pumpWidget(AccountStartupApp(controller: app.controller));
        await tester.pump();
        expect(find.text('Đang khôi phục phiên đăng nhập…'), findsOneWidget);
        expect(app.controller.aiConversationScenarioSource, isNull);
        expect(app.ai.requests, isEmpty);
        await tester.runAsync(() async {
          app.vault.writeWait!.complete();
          await app.starting;
          await lifecycle.flush();
        });
        expect(app.vault.secret, app.server.secret);
        expect(app.runtime.account.state.phase, AccountPhase.loadingProfile);
        final container = await _mount(tester, app);
        await tester.runAsync(() async {
          expect(
            container.read(aiConversationScenarioSourceProvider),
            same(app.owner),
          );
          subscription = container.listen(
            aiConversationScenarioBindingProvider,
            (_, _) {},
          );
          expect(container.read(aiConversationScenarioBindingProvider), isNull);
          expect(app.owner.createAiConversationScenarios(), isNull);
          expect(app.ai.requests, isEmpty);
          app.server.profileWait!.complete(
            _json(profile.profile(app.server.user)),
          );
          await app.ready();
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        late AiConversationScenarioBinding old;
        late String oldBearer;
        await tester.runAsync(() async {
          old = container.read(aiConversationScenarioBindingProvider)!;
          expect(old.reader, same(app.owner.createAiConversationScenarios()));
          expect(
            old.availabilityChanges,
            same(app.owner.aiConversationScenarioChanges),
          );
          expect(container.read(aiTextViewBindingProvider), isNull);
          expect(app.ai.requests, isEmpty);
          oldBearer = app.server.bearer;
          app.ai.onSend = (_) async => http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode([
                  {
                    'id': wire.a,
                    'jlpt_level': 'N5',
                    'title_vi': 'Tình huống',
                    'title_ja': '会話',
                    'description_vi': 'Mô tả',
                    'content_version': 1,
                    'is_active': true,
                  },
                ]),
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
          expect((await old.reader.load(AiTextLevel.n5)).single.id, wire.a);
          expect(app.ai.requests.single.method, 'GET');
          expect(
            app.ai.requests.single.url.path,
            '/rest/v1/conversation_scenarios',
          );
          expect(
            app.ai.requests.single.headers['authorization'],
            'Bearer $oldBearer',
          );
        });
        Future<void>? refreshing;
        await tester.runAsync(() async {
          app.vault.writeWait = Completer<void>();
          app.server.profileWait = Completer<http.Response>();
          refreshing = app.owner.refresh();
          expect(old.reader.isCurrent, isFalse);
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          expect(container.read(aiConversationScenarioBindingProvider), isNull);
          expect(app.ai.requests, hasLength(1));
          app.vault.writeWait!.complete();
          await refreshing;
          await lifecycle.flush();
          expect(app.vault.secret, app.server.secret);
          expect(app.runtime.account.state.phase, AccountPhase.loadingProfile);
          expect(container.read(aiConversationScenarioBindingProvider), isNull);
          app.server.profileWait!.complete(
            _json(profile.profile(app.server.user)),
          );
          await app.ready();
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final fresh = container.read(aiConversationScenarioBindingProvider)!;
          expect(fresh.reader, isNot(same(old.reader)));
          expect(fresh.reader, same(app.owner.createAiConversationScenarios()));
          expect(old.reader.isCurrent, isFalse);
          expect(app.server.bearer, isNot(oldBearer));
          expect(app.ai.requests, hasLength(1));
          await fresh.reader.load(AiTextLevel.n5);
          expect(app.ai.requests, hasLength(2));
          expect(
            app.ai.requests.last.headers['authorization'],
            'Bearer ${app.server.bearer}',
          );
          await app.runtime.account.signOut();
          await lifecycle.flush();
          expect(fresh.reader.isCurrent, isFalse);
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          expect(container.read(aiConversationScenarioBindingProvider), isNull);
          expect(app.owner.createAiConversationScenarios(), isNull);
          expect(app.ai.requests, hasLength(2));
        });
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(() async {
          subscription?.close();
        });
      }
    },
  );
  _ownedTest(
    'mounted App scenario binding remains off by default without HTTP',
    (tester) async {
      final app = await _fixture(tester);
      await tester.runAsync(app.login);
      final container = await _mount(tester, app);
      await tester.runAsync(() async {
        expect(
          container.read(aiConversationScenarioSourceProvider),
          same(app.owner),
        );
        expect(container.read(aiConversationScenarioBindingProvider), isNull);
        expect(app.owner.createAiConversationScenarios(), isNull);
        expect(app.owner.createAiTextRepository(), isNotNull);
        expect(app.ai.requests, isEmpty);
      });
      expect(tester.takeException(), isNull);
    },
  );
  _ownedTest(
    'mounted workspace pair binds actual owner and secure start after barriers then fences refresh logout',
    (tester) async {
      final app = await _fixture(
        tester,
        start: false,
        enabled: false,
        conversationEnabled: true,
      );
      ProviderSubscription<ConversationWorkspaceBinding?>? subscription;
      ConversationWorkspaceController? view;
      try {
        await tester.runAsync(() async {
          // Keep barriers in the real SDK event loop, as in the conversation case.
          app.vault.secret = 'TEST_ONLY_SAVED';
          app.vault.writeWait = Completer<void>();
          app.server.profileWait = Completer<http.Response>();
          app.starting = app.controller.start();
          await lifecycle.flush();
        });
        await tester.pumpWidget(AccountStartupApp(controller: app.controller));
        await tester.pump();
        expect(find.text('Đang khôi phục phiên đăng nhập…'), findsOneWidget);
        expect(app.controller.aiConversationScenarioSource, isNull);
        expect(app.ai.requests, isEmpty);
        await tester.runAsync(() async {
          app.vault.writeWait!.complete();
          await app.starting;
          await lifecycle.flush();
        });
        expect(app.vault.secret, app.server.secret);
        expect(app.runtime.account.state.phase, AccountPhase.loadingProfile);
        final container = await _mount(tester, app);
        await tester.runAsync(() async {
          expect(
            container.read(aiConversationScenarioSourceProvider),
            same(app.owner),
          );
          subscription = container.listen(
            conversationWorkspaceBindingProvider,
            (_, _) {},
          );
          expect(container.read(conversationWorkspaceBindingProvider), isNull);
          expect(app.owner.createAiConversationScenarios(), isNull);
          expect(app.ai.requests, isEmpty);
          app.server.profileWait!.complete(
            _json(profile.profile(app.server.user)),
          );
          await app.ready();
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        late ConversationWorkspaceBinding old;
        late String oldBearer;
        await tester.runAsync(() async {
          old = container.read(conversationWorkspaceBindingProvider)!;
          expect(old.reader, same(app.owner.createAiConversationScenarios()));
          expect(
            old.availabilityChanges,
            same(app.owner.aiConversationScenarioChanges),
          );
          expect(container.read(aiTextViewBindingProvider), isNull);
          expect(app.ai.requests, isEmpty);
          expect(container.read(aiConversationSourceProvider), same(app.owner));
          expect(old.session, same(app.owner.createAiConversationSession()));
          expect(
            old.createEventId,
            same(container.read(conversationEventFactoryProvider)),
          );
          view = ConversationWorkspaceController(
            reader: old.reader,
            session: old.session,
            availabilityChanges: old.availabilityChanges,
            createEventId: old.createEventId,
          );
          expect(app.ai.requests, isEmpty);
          oldBearer = app.server.bearer;
          app.ai.onSend = (request) async => request.method == 'GET'
              ? http.StreamedResponse(
                  Stream.value(
                    utf8.encode(
                      jsonEncode([
                        {
                          'id': wire.a,
                          'jlpt_level': 'N5',
                          'title_vi': 'Tình huống',
                          'title_ja': '会話',
                          'description_vi': 'Mô tả',
                          'content_version': 1,
                          'is_active': true,
                        },
                      ]),
                    ),
                  ),
                  200,
                  headers: {'content-type': 'application/json'},
                )
              : _answer(request.url.path.split('/').last);
          await view!.loadScenarios();
          final row = view!.state.scenarios!.rows.single;
          expect(row.id, wire.a);
          expect(view!.select(row), isTrue);
          expect(app.ai.requests, hasLength(1));
          await view!.startSelected();
          expect(
            view!.state.conversation!.conversation!.phase,
            ConversationSessionPhase.active,
          );
          final sent = app.ai.requests.last as http.Request;
          expect(sent.method, 'POST');
          expect(sent.url.path, '/functions/v1/start_conversation');
          expect(sent.headers['authorization'], 'Bearer $oldBearer');
          final body = jsonDecode(sent.body) as Map<String, Object?>;
          expect(body.keys.toSet(), {
            'scenario_id',
            'jlpt_level',
            'client_event_id',
          });
          expect(body['scenario_id'], row.id);
          expect(body['jlpt_level'], 'N5');
          expect(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ).hasMatch(body['client_event_id']! as String),
            isTrue,
          );
          expect(app.ai.requests.first.method, 'GET');
          expect(
            app.ai.requests.first.url.path,
            '/rest/v1/conversation_scenarios',
          );
          expect(
            app.ai.requests.first.headers['authorization'],
            'Bearer $oldBearer',
          );
        });
        Future<void>? refreshing;
        await tester.runAsync(() async {
          app.vault.writeWait = Completer<void>();
          app.server.profileWait = Completer<http.Response>();
          refreshing = app.owner.refresh();
          expect(old.reader.isCurrent, isFalse);
          expect(old.session.isCurrent, isFalse);
          expect(view!.state.isAvailable, isFalse);
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          expect(container.read(conversationWorkspaceBindingProvider), isNull);
          expect(app.ai.requests, hasLength(2));
          app.vault.writeWait!.complete();
          await refreshing;
          await lifecycle.flush();
          expect(app.vault.secret, app.server.secret);
          expect(app.runtime.account.state.phase, AccountPhase.loadingProfile);
          expect(container.read(conversationWorkspaceBindingProvider), isNull);
          app.server.profileWait!.complete(
            _json(profile.profile(app.server.user)),
          );
          await app.ready();
          await lifecycle.flush();
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final fresh = container.read(conversationWorkspaceBindingProvider)!;
          expect(fresh.reader, isNot(same(old.reader)));
          expect(fresh.session, isNot(same(old.session)));
          expect(fresh.session, same(app.owner.createAiConversationSession()));
          expect(
            fresh.session.snapshot.phase,
            ConversationSessionPhase.notStarted,
          );
          expect(view!.state.isAvailable, isFalse);
          expect(fresh.reader, same(app.owner.createAiConversationScenarios()));
          expect(old.reader.isCurrent, isFalse);
          expect(app.server.bearer, isNot(oldBearer));
          expect(app.ai.requests, hasLength(2));
          await view!.startSelected();
          await view!.turn('TEST_ONLY_OLD_DRAFT');
          expect(app.ai.requests, hasLength(2));
          await fresh.reader.load(AiTextLevel.n5);
          expect(app.ai.requests, hasLength(3));
          expect(
            app.ai.requests.last.headers['authorization'],
            'Bearer ${app.server.bearer}',
          );
          await app.runtime.account.signOut();
          await lifecycle.flush();
          expect(fresh.reader.isCurrent, isFalse);
          expect(fresh.session.isCurrent, isFalse);
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          expect(container.read(conversationWorkspaceBindingProvider), isNull);
          expect(app.owner.createAiConversationScenarios(), isNull);
          expect(app.ai.requests, hasLength(3));
        });
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(() async {
          view?.dispose();
          subscription?.close();
        });
      }
    },
  );
  _ownedTest('mounted App workspace pair remains off by default without HTTP', (
    tester,
  ) async {
    final app = await _fixture(tester);
    await tester.runAsync(app.login);
    final container = await _mount(tester, app);
    await tester.runAsync(() async {
      expect(container.read(aiConversationSourceProvider), same(app.owner));
      expect(
        container.read(aiConversationScenarioSourceProvider),
        same(app.owner),
      );
      expect(container.read(conversationWorkspaceBindingProvider), isNull);
      expect(app.owner.createAiConversationSession(), isNull);
      expect(app.owner.createAiConversationScenarios(), isNull);
      expect(app.owner.createAiTextRepository(), isNotNull);
      expect(app.ai.requests, isEmpty);
    });
    expect(tester.takeException(), isNull);
  });
}
