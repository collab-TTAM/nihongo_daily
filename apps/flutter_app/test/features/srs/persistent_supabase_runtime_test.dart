// TEST ONLY actual pinned SDK plus simulated HTTP/OS, not hosted Auth evidence.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'recovery_fixtures.dart' as recovery;
import 'session_lifecycle_fixtures.dart' as fixture;
import 'supabase_review_binding_test.dart' as wire;
import 'own_profile_fixtures.dart' as profile;

void main() {
  late fixture.MemoryVault backend;
  late SessionCredentialVault vault;
  late MockClient network;
  late PersistentSupabaseRuntime runtime;
  late DateTime now;
  late Directory directory;
  late NativeReviewJournal journal;
  final requests = <http.Request>[];
  late String secret;
  late int authStatus;
  late Completer<http.Response>? authWait;
  late Completer<http.Response>? profileWait;
  http.Response authResponse() => http.Response(
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

  Future<void> waitForReady() async {
    if (runtime.account.state.phase != AccountPhase.ready) {
      final state = await runtime.account.changes
          .firstWhere(
            (state) => const {
              AccountPhase.ready,
              AccountPhase.profileError,
              AccountPhase.signInError,
              AccountPhase.unavailable,
            }.contains(state.phase),
          )
          .timeout(const Duration(seconds: 5));
      expect(state.phase, AccountPhase.ready);
    }
    expect(runtime.account.readyRuntime, isNotNull);
  }

  setUp(() async {
    requests.clear();
    backend = fixture.MemoryVault();
    directory = await Directory.systemTemp.createTemp('nd-sdk-lifecycle-');
    journal = await NativeReviewJournal.open(directory);
    now = DateTime.utc(2026, 10, 14, 3);
    secret = 'TEST_ONLY_ROTATED_SDK_1';
    authStatus = 200;
    authWait = null;
    profileWait = null;
    vault = SessionCredentialVault(projectUrl: wire.origin, backend: backend);
    network = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/auth/v1/token') {
        if (authWait != null) return authWait!.future;
        return authStatus == 200
            ? authResponse()
            : http.Response(
                '{"message":"TEST ONLY PRIVATE FAILURE"}',
                authStatus,
              );
      }
      if (request.url.path == '/auth/v1/logout') return http.Response('', 204);
      if (request.url.path == '/rest/v1/rpc/ensure_profile') {
        return profileWait?.future ??
            Future.value(
              http.Response(
                jsonEncode(profile.profile(wire.a)),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
      }
      throw StateError('unexpected fixture endpoint');
    });
    runtime = PersistentSupabaseRuntime(
      projectUrl: wire.origin,
      publishableKey: wire.key,
      vault: vault,
      store: journal,
      httpClient: network,
      now: () => now,
    );
  });
  tearDown(() async {
    await runtime.close();
    await journal.close();
    await directory.delete(recursive: true);
    network.close();
  });

  test(
    'SDK startup server refresh persists rotation before own profile',
    () async {
      backend.secret = 'TEST_ONLY_SAVED_SDK';
      backend.writeWait = Completer();
      profileWait = Completer();
      final starting = runtime.start();
      await fixture.flush();
      expect(runtime.account.readyRuntime, isNull);
      expect(
        requests.where((r) => r.url.path.contains('ensure_profile')),
        isEmpty,
      );
      expect(jsonDecode(requests.single.body), {
        'refresh_token': 'TEST_ONLY_SAVED_SDK',
      });
      expect(
        requests.single.url.queryParameters['grant_type'],
        'refresh_token',
      );
      backend.writeWait!.complete();
      await starting;
      await fixture.flush();
      expect(backend.secret, secret);
      expect(runtime.account.state.phase, AccountPhase.loadingProfile);
      expect(runtime.account.readyRuntime, isNull);
      profileWait!.complete(
        http.Response(
          jsonEncode(profile.profile(wire.a)),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await fixture.flush();
      expect(runtime.account.state.phase, AccountPhase.ready);
      expect(runtime.account.readyRuntime, isNotNull);
      expect(requests.every((r) => !r.followRedirects), isTrue);
    },
  );

  test(
    'SDK login explicit rotation and logout use vault readiness barrier',
    () async {
      await runtime.start();
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await fixture.flush();
      expect(runtime.account.readyRuntime, isNotNull);
      secret = 'TEST_ONLY_ROTATED_SDK_2';
      backend.writeWait = Completer();
      final rotation = runtime.refresh();
      expect(runtime.account.readyRuntime, isNull);
      await fixture.flush();
      expect(runtime.account.readyRuntime, isNull);
      backend.writeWait!.complete();
      await rotation;
      await fixture.flush();
      expect(backend.secret, secret);
      expect(runtime.account.readyRuntime, isNotNull);
      final logout = runtime.account.signOut();
      expect(runtime.account.readyRuntime, isNull);
      await logout;
      expect(backend.secret, isNull);
      expect(runtime.account.state.phase, AccountPhase.signedOut);
    },
  );

  test(
    'SDK logout while startup request pending cannot restore late response',
    () async {
      backend.secret = 'TEST_ONLY_SAVED_SDK';
      authWait = Completer();
      final starting = runtime.start();
      final failed = expectLater(
        starting,
        throwsA(isA<ReviewTransportFailure>()),
      );
      await fixture.flush();
      await runtime.account.signOut();
      authWait!.complete(authResponse());
      await failed;
      await fixture.flush();
      expect(backend.secret, isNull);
      expect(runtime.account.readyRuntime, isNull);
      expect(
        requests.where((r) => r.url.path.contains('ensure_profile')),
        isEmpty,
      );
    },
  );

  test(
    'SDK rejected stored token stays fenced and explicit new login recovers',
    () async {
      backend.secret = 'TEST_ONLY_SAVED_SDK';
      authStatus = 401;
      await expectLater(
        runtime.start(),
        throwsA(isA<ReviewTransportFailure>()),
      );
      expect(runtime.account.readyRuntime, isNull);
      expect(
        requests.where((r) => r.url.path.contains('ensure_profile')),
        isEmpty,
      );
      authStatus = 200;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();
      expect(runtime.account.readyRuntime, isNotNull);
      expect(backend.secret, secret);
    },
  );

  test(
    'SDK safe logging and scope reject another project before requests',
    () async {
      final records = <LogRecord>[];
      final old = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(records.add);
      try {
        await runtime.start();
        await runtime.account.signIn(
          'fixture@example.invalid',
          'TEST_ONLY_PASSWORD',
        );
        await fixture.flush();
        expect(
          records.where((r) => r.toString().contains('TEST_ONLY')),
          isEmpty,
        );
        expect(
          () => PersistentSupabaseRuntime(
            projectUrl: 'https://other.supabase.invalid',
            publishableKey: wire.key,
            vault: vault,
            store: journal,
            httpClient: network,
          ),
          throwsA(isA<SessionVaultFailure>()),
        );
        expect(
          () => PersistentSupabaseRuntime(
            projectUrl: wire.origin,
            publishableKey: wire.key,
            vault: vault,
            store: journal,
            httpClient: network,
          ),
          throwsA(isA<SessionVaultFailure>()),
        );
      } finally {
        await subscription.cancel();
        Logger.root.level = old;
      }
    },
  );

  test(
    'SDK timeout discards late response and never dispatches profile',
    () async {
      await runtime.close();
      runtime = PersistentSupabaseRuntime(
        projectUrl: wire.origin,
        publishableKey: wire.key,
        vault: vault,
        store: journal,
        httpClient: network,
        now: () => now,
        requestTimeout: const Duration(milliseconds: 30),
      );
      backend.secret = 'TEST_ONLY_SAVED_SDK';
      authWait = Completer();
      await expectLater(
        runtime.start(),
        throwsA(isA<ReviewTransportFailure>()),
      );
      authWait!.complete(authResponse());
      await fixture.flush();
      expect(runtime.account.readyRuntime, isNull);
      expect(
        requests.where((r) => r.url.path.contains('ensure_profile')),
        isEmpty,
      );
    },
  );
  test(
    'SDK rotation and logout preserve original pending review on real disk',
    () async {
      await runtime.start();
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await fixture.flush();
      final request = recovery.recoveryRequest();
      await journal.stage(wire.a, request);
      secret = 'TEST_ONLY_ROTATED_SDK_2';
      await runtime.refresh();
      await fixture.flush();
      var reviews = runtime.account.readyRuntime!.reviews as ReviewRecovery;
      expect((await reviews.recoverPending()).single.request, request);
      await runtime.account.signOut();
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await fixture.flush();
      reviews = runtime.account.readyRuntime!.reviews as ReviewRecovery;
      expect((await reviews.recoverPending()).single.request, request);
      expect((await journal.list(wire.a)).single.isPending, isTrue);
      expect(
        requests.where((r) => r.url.path.contains('submit_review')),
        isEmpty,
      );
    },
  );
}
