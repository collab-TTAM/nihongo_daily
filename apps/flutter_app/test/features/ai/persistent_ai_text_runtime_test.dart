// TEST ONLY actual pinned SDK/runtime with simulated Auth/vault/HTTP. No hosted
// JWT verification, provider activation or live learner acceptance.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import '../srs/session_lifecycle_fixtures.dart' as lifecycle;
import '../srs/supabase_review_binding_test.dart' as wire;
import '../srs/own_profile_fixtures.dart' as profile;

final unauthorized = isA<AiTextFailure>().having(
  (e) => e.code,
  'code',
  AiTextErrorCode.unauthorized,
);
final question = TutorExplainRequest(
  level: AiTextLevel.n5,
  questionVi: 'TEST ONLY',
);
late Map<String, Object?> fixtures;
http.StreamedResponse answer([String operation = 'tutor_explain']) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(fixtures['${operation}_response']))),
      200,
      headers: {'content-type': 'application/json'},
    );

final class _AiHttp extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  Future<http.StreamedResponse> Function(http.BaseRequest)? onSend;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return Future<http.StreamedResponse>.sync(() => onSend!(request));
  }

  @override
  void close() {
    closed = true;
  }
}

void main() {
  late lifecycle.MemoryVault backend;
  late SessionCredentialVault vault;
  late Directory directory;
  late NativeReviewJournal journal;
  late MockClient authHttp;
  late _AiHttp aiHttp;
  late PersistentSupabaseRuntime runtime;
  late DateTime now;
  late String user;
  late String secret;
  late int generation;
  late int profileStatus;
  Completer<http.Response>? profileWait;
  final authRequests = <http.Request>[];

  PersistentSupabaseRuntime build({bool enabled = true}) =>
      PersistentSupabaseRuntime(
        projectUrl: wire.origin,
        publishableKey: wire.key,
        vault: vault,
        store: journal,
        httpClient: authHttp,
        aiHttpClient: aiHttp,
        now: () => now,
        aiTextEnabled: enabled,
        requestTimeout: const Duration(seconds: 2),
      );
  Future<void> ready() async {
    if (runtime.account.state.phase != AccountPhase.ready) {
      final state = await runtime.account.changes
          .firstWhere(
            (s) => const {
              AccountPhase.ready,
              AccountPhase.profileError,
              AccountPhase.signInError,
              AccountPhase.unavailable,
            }.contains(s.phase),
          )
          .timeout(const Duration(seconds: 5));
      expect(state.phase, AccountPhase.ready);
    }
    expect(runtime.account.readyRuntime, isNotNull);
  }

  Future<void> login() async {
    await runtime.account.signIn(
      'fixture@example.invalid',
      'TEST_ONLY_PASSWORD',
    );
    await ready();
  }

  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  setUp(() async {
    backend = lifecycle.MemoryVault();
    vault = SessionCredentialVault(projectUrl: wire.origin, backend: backend);
    directory = await Directory.systemTemp.createTemp('nd-ai-owned-');
    journal = await NativeReviewJournal.open(directory);
    now = DateTime.utc(2026, 10, 24);
    user = wire.a;
    secret = 'TEST_ONLY_REFRESH_1';
    generation = 0;
    profileStatus = 200;
    profileWait = null;
    authRequests.clear();
    aiHttp = _AiHttp()
      ..onSend = (r) async => answer(r.url.path.split('/').last);
    authHttp = MockClient((r) async {
      authRequests.add(r);
      if (r.url.path == '/auth/v1/token') {
        return http.Response(
          jsonEncode({
            'access_token': wire.token(
              user,
              wire.sid1,
              now,
              generation: generation,
            ),
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
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (r.url.path == '/auth/v1/logout') return http.Response('', 204);
      if (r.url.path == '/rest/v1/rpc/ensure_profile') {
        return profileWait?.future ??
            Future.value(
              http.Response(
                profileStatus == 200
                    ? jsonEncode(profile.profile(user))
                    : '{"message":"TEST_ONLY_PROFILE_SECRET"}',
                profileStatus,
                headers: {'content-type': 'application/json'},
              ),
            );
      }
      throw StateError('unexpected TEST ONLY Auth/REST endpoint');
    });
    runtime = build();
  });
  tearDown(() async {
    await runtime.close();
    await journal.close();
    await directory.delete(recursive: true);
    authHttp.close();
    aiHttp.close();
  });

  test(
    'AI owner flag defaults off even with an authenticated ready runtime',
    () async {
      await runtime.close();
      runtime = PersistentSupabaseRuntime(
        projectUrl: wire.origin,
        publishableKey: wire.key,
        vault: vault,
        store: journal,
        httpClient: authHttp,
        aiHttpClient: aiHttp,
        now: () => now,
      );
      await runtime.start();
      await login();
      expect(runtime.isAiTextEnabled, isFalse);
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, isEmpty);
    },
  );
  test(
    'AI factory waits for persisted rotation and own profile then caches one capability',
    () async {
      backend.secret = 'TEST_ONLY_SAVED';
      backend.writeWait = Completer<void>();
      profileWait = Completer<http.Response>();
      final starting = runtime.start();
      await lifecycle.flush();
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, isEmpty);
      expect(
        authRequests.where((r) => r.url.path.contains('ensure_profile')),
        isEmpty,
      );
      backend.writeWait!.complete();
      await starting;
      await lifecycle.flush();
      expect(backend.secret, secret);
      expect(runtime.account.state.phase, AccountPhase.loadingProfile);
      expect(runtime.createAiTextRepository(), isNull);
      profileWait!.complete(
        http.Response(
          jsonEncode(profile.profile(user)),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await ready();
      final repo = runtime.createAiTextRepository();
      expect(repo, isNotNull);
      expect(identical(repo, runtime.createAiTextRepository()), isTrue);
      expect(aiHttp.requests, isEmpty);
      expect(
        (await repo!.explain(question)).toJson(),
        fixtures['tutor_explain_response'],
      );
      expect(aiHttp.requests.single.url.path, '/functions/v1/tutor_explain');
      expect(
        aiHttp.requests.single.headers['authorization'],
        'Bearer ${wire.token(user, wire.sid1, now)}',
      );
      expect(
        authRequests.every(
          (r) =>
              r.url.path.startsWith('/auth/v1/') ||
              r.url.path.startsWith('/rest/v1/'),
        ),
        isTrue,
      );
    },
  );
  test(
    'refresh revokes AI synchronously and holds new generation until old headers drain',
    () async {
      await runtime.start();
      await login();
      final old = runtime.createAiTextRepository()!;
      final pending = Completer<http.StreamedResponse>();
      aiHttp.onSend = (_) => pending.future;
      final rejected = expectLater(
        old.explain(question),
        throwsA(unauthorized),
      );
      final first = aiHttp.requests.single as http.AbortableRequest;
      secret = 'TEST_ONLY_REFRESH_2';
      generation++;
      backend.writeWait = Completer<void>();
      final rotating = runtime.refresh();
      expect(old.isCurrent, isFalse);
      expect(runtime.createAiTextRepository(), isNull);
      await rejected;
      await expectLater(first.abortTrigger, completes);
      await lifecycle.flush();
      backend.writeWait!.complete();
      await rotating;
      await ready();
      expect(backend.secret, secret);
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, hasLength(1));
      pending.complete(answer());
      await lifecycle.flush();
      final next = runtime.createAiTextRepository();
      expect(next, isNotNull);
      expect(identical(old, next), isFalse);
      await expectLater(old.explain(question), throwsA(unauthorized));
      aiHttp.onSend = (r) async => answer();
      await next!.explain(question);
      expect(
        first.headers['authorization'],
        'Bearer ${wire.token(user, wire.sid1, now)}',
      );
      expect(
        aiHttp.requests.last.headers['authorization'],
        'Bearer ${wire.token(user, wire.sid1, now, generation: generation)}',
      );
      expect(aiHttp.requests, hasLength(2));
    },
  );
  test(
    'logout and new account cannot reuse or overlap a late old AI request',
    () async {
      await runtime.start();
      await login();
      final old = runtime.createAiTextRepository()!;
      final pending = Completer<http.StreamedResponse>();
      aiHttp.onSend = (_) => pending.future;
      final rejected = expectLater(
        old.explain(question),
        throwsA(unauthorized),
      );
      final logout = runtime.account.signOut();
      expect(old.isCurrent, isFalse);
      expect(runtime.createAiTextRepository(), isNull);
      await rejected;
      await logout;
      expect(backend.secret, isNull);
      user = wire.b;
      secret = 'TEST_ONLY_ACCOUNT_B';
      generation++;
      await login();
      expect(runtime.createAiTextRepository(), isNull);
      pending.completeError(StateError('TEST_ONLY_OLD_SECRET'));
      await lifecycle.flush();
      final next = runtime.createAiTextRepository();
      expect(next, isNotNull);
      aiHttp.onSend = (r) async => answer();
      await next!.explain(question);
      expect(aiHttp.requests, hasLength(2));
      expect(
        aiHttp.requests.last.headers['authorization'],
        'Bearer ${wire.token(wire.b, wire.sid1, now, generation: generation)}',
      );
      await expectLater(old.explain(question), throwsA(unauthorized));
    },
  );
  test(
    'shutdown revokes AI immediately and waits for ignored abort before SDK disposal',
    () async {
      await runtime.start();
      await login();
      final repo = runtime.createAiTextRepository()!;
      final pending = Completer<http.StreamedResponse>();
      aiHttp.onSend = (_) => pending.future;
      final rejected = expectLater(
        repo.explain(question),
        throwsA(unauthorized),
      );
      var closed = false;
      final closing = runtime.close()
        ..then((_) {
          closed = true;
        });
      expect(identical(closing, runtime.close()), isTrue);
      expect(repo.isCurrent, isFalse);
      expect(runtime.createAiTextRepository(), isNull);
      await rejected;
      await lifecycle.flush();
      expect(closed, isFalse);
      expect(backend.secret, secret);
      pending.completeError(StateError('TEST_ONLY_LATE_SECRET'));
      await closing;
      expect(closed, isTrue);
      expect(aiHttp.closed, isFalse);
      expect(runtime.createAiTextRepository(), isNull);
    },
  );
  test(
    'vault write failure cannot grant an AI repository or reach own profile',
    () async {
      backend.failWrite = true;
      await runtime.start();
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await lifecycle.flush();
      expect(runtime.account.readyRuntime, isNull);
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, isEmpty);
      expect(
        authRequests.where((r) => r.url.path.contains('ensure_profile')),
        isEmpty,
      );
    },
  );
  test(
    'profile failure blocks AI until an explicit successful profile retry',
    () async {
      profileStatus = 500;
      await runtime.start();
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await lifecycle.flush();
      expect(runtime.account.state.phase, AccountPhase.profileError);
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, isEmpty);
      profileStatus = 200;
      await runtime.account.retryProfile();
      await ready();
      expect(runtime.createAiTextRepository(), isNotNull);
      expect(aiHttp.requests, isEmpty);
    },
  );
  test(
    'HTTP unauthorized cannot reconstruct an AI capability without a fresh ready barrier',
    () async {
      await runtime.start();
      await login();
      final repo = runtime.createAiTextRepository()!;
      aiHttp.onSend = (_) async => http.StreamedResponse(
        Stream.value(utf8.encode('TEST_ONLY_RAW_SECRET')),
        401,
      );
      await expectLater(repo.explain(question), throwsA(unauthorized));
      expect(runtime.createAiTextRepository(), isNull);
      await lifecycle.flush();
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, hasLength(1));
      secret = 'TEST_ONLY_REFRESH_2';
      generation++;
      await runtime.refresh();
      await ready();
      expect(runtime.createAiTextRepository(), isNotNull);
      expect(aiHttp.requests, hasLength(1));
    },
  );
}
