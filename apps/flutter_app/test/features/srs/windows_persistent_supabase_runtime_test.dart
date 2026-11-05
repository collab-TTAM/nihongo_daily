// TEST ONLY pinned Supabase SDK + mocked Windows MethodChannel, not hosted Auth proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/windows_session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

import 'own_profile_fixtures.dart' as profile;
import 'session_lifecycle_fixtures.dart' as fixture;
import 'supabase_review_binding_test.dart' as wire;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nihongo_daily/session_vault_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late PersistentSupabaseRuntime runtime;
  late MockClient network;
  late NativeReviewJournal journal;
  late Directory directory;
  late DateTime now;
  late String? storedSecret;
  late String authUser;
  late String authSession;
  late String refreshSecret;
  late Completer<http.Response>? authWait;
  late Completer<void>? writeWait;
  late bool failRead;
  late bool failWrite;
  late bool failClear;
  final requests = <http.Request>[];
  final timeline = <String>[];

  http.Response authResponse() => http.Response(
    jsonEncode({
      'access_token': wire.token(authUser, authSession, now),
      'refresh_token': refreshSecret,
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': authUser,
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
          .firstWhere((value) => value.phase == AccountPhase.ready)
          .timeout(const Duration(seconds: 5));
      expect(state.phase, AccountPhase.ready);
    }
    expect(runtime.account.readyRuntime, isNotNull);
  }

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    requests.clear();
    timeline.clear();
    now = DateTime.utc(2026, 10, 14, 3);
    storedSecret = null;
    authUser = wire.a;
    authSession = wire.sid1;
    refreshSecret = 'TEST_ONLY_ROTATED_WINDOWS_REFRESH';
    authWait = null;
    writeWait = null;
    failRead = false;
    failWrite = false;
    failClear = false;

    messenger.setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments as Map<Object?, Object?>;
      expect(
        arguments['target'],
        'NihongoDaily.Refresh.v1|https://example.supabase.invalid',
      );
      switch (call.method) {
        case 'read':
          timeline.add('vault.read');
          if (failRead) {
            throw PlatformException(
              code: 'PRIVATE_STORAGE',
              message: 'PRIVATE_REFRESH_SECRET',
              details: {'token': 'PRIVATE_REFRESH_SECRET'},
            );
          }
          return storedSecret;
        case 'write':
          timeline.add('vault.write');
          if (failWrite) {
            throw PlatformException(
              code: 'PRIVATE_STORAGE',
              message: 'PRIVATE_REFRESH_SECRET',
              details: {'token': 'PRIVATE_REFRESH_SECRET'},
            );
          }
          final token = arguments['token'];
          if (token is! String) {
            throw PlatformException(code: 'invalid_argument');
          }
          await (writeWait?.future ?? Future<void>.value());
          storedSecret = token;
          return true;
        case 'clear':
          timeline.add('vault.clear');
          if (failClear) {
            throw PlatformException(
              code: 'PRIVATE_STORAGE',
              message: 'PRIVATE_REFRESH_SECRET',
              details: {'token': 'PRIVATE_REFRESH_SECRET'},
            );
          }
          storedSecret = null;
          return true;
        default:
          throw MissingPluginException();
      }
    });

    directory = await Directory.systemTemp.createTemp(
      'nd-windows-supabase-vault-',
    );
    journal = await NativeReviewJournal.open(directory);
    network = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/auth/v1/token') {
        final grant = request.url.queryParameters['grant_type'];
        timeline.add(
          grant == 'refresh_token' ? 'auth.refresh' : 'auth.password',
        );
        if (authWait != null) return authWait!.future;
        return authResponse();
      }
      if (request.url.path == '/auth/v1/logout') {
        timeline.add('auth.logout');
        return http.Response('', 204);
      }
      if (request.url.path == '/rest/v1/rpc/ensure_profile') {
        timeline.add('profile.ensure');
        return http.Response(
          jsonEncode(profile.profile(authUser)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      throw StateError('unexpected TEST ONLY endpoint');
    });
    runtime = PersistentSupabaseRuntime(
      projectUrl: wire.origin,
      publishableKey: wire.key,
      vault: createWindowsSessionCredentialVault(wire.origin),
      store: journal,
      httpClient: network,
      now: () => now,
    );
  });

  tearDown(() async {
    if (writeWait != null && !writeWait!.isCompleted) {
      writeWait!.complete();
    }
    await runtime.close();
    await journal.close();
    await directory.delete(recursive: true);
    network.close();
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Windows vault restores through SDK and persists rotation before own profile',
    () async {
      storedSecret = 'TEST_ONLY_SAVED_WINDOWS_REFRESH';

      await runtime.start();
      await waitForReady();

      expect(storedSecret, refreshSecret);
      expect(
        timeline.indexOf('auth.refresh'),
        greaterThan(timeline.indexOf('vault.read')),
      );
      expect(
        timeline.indexOf('vault.write'),
        greaterThan(timeline.indexOf('auth.refresh')),
      );
      expect(
        timeline.indexOf('profile.ensure'),
        greaterThan(timeline.indexOf('vault.write')),
      );
      expect(runtime.account.state.profile?.id, wire.a);
      expect(requests.every((request) => !request.followRedirects), isTrue);

      await runtime.account.signOut();
      expect(storedSecret, isNull);
      expect(timeline, contains('auth.logout'));
      expect(
        timeline.lastIndexOf('vault.clear'),
        greaterThan(timeline.lastIndexOf('auth.logout')),
      );
      expect(runtime.account.state.phase, AccountPhase.signedOut);
    },
  );

  test('Windows vault read failure blocks Auth restore and profile', () async {
    storedSecret = 'TEST_ONLY_SAVED_WINDOWS_REFRESH';
    failRead = true;

    await expectLater(
      runtime.start(),
      throwsA(
        isA<ReviewTransportFailure>().having(
          (error) => error.toString().contains('PRIVATE'),
          'redacted storage error',
          false,
        ),
      ),
    );

    expect(timeline, ['vault.read']);
    expect(requests, isEmpty);
    expect(storedSecret, 'TEST_ONLY_SAVED_WINDOWS_REFRESH');
    expect(runtime.account.readyRuntime, isNull);
  });

  test('Windows vault write failure clears and blocks own profile', () async {
    storedSecret = 'TEST_ONLY_SAVED_WINDOWS_REFRESH';
    failWrite = true;

    await expectLater(runtime.start(), throwsA(isA<ReviewTransportFailure>()));

    expect(timeline.indexOf('auth.refresh'), greaterThan(-1));
    expect(timeline.indexOf('vault.write'), greaterThan(-1));
    expect(
      timeline.lastIndexOf('vault.clear'),
      greaterThan(timeline.indexOf('vault.write')),
    );
    expect(timeline.where((value) => value == 'profile.ensure'), isEmpty);
    expect(runtime.account.readyRuntime, isNull);
    expect(storedSecret, isNull);
  });

  test(
    'late User A login cannot restore after logout before User B login',
    () async {
      await runtime.start();
      authUser = wire.a;
      authSession = wire.sid1;
      refreshSecret = 'TEST_ONLY_LATE_A_REFRESH';
      authWait = Completer<http.Response>();

      final lateLogin = runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await fixture.flush();
      expect(
        requests.where((request) => request.url.path == '/auth/v1/token'),
        hasLength(1),
      );

      await runtime.account.signOut();
      expect(storedSecret, isNull);
      final lateAResponse = authResponse();
      authWait!.complete(lateAResponse);
      await lateLogin;
      await fixture.flush();

      expect(runtime.account.readyRuntime, isNull);
      expect(storedSecret, isNull);
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        isEmpty,
      );

      authWait = null;
      authUser = wire.b;
      authSession = wire.sid2;
      refreshSecret = 'TEST_ONLY_B_REFRESH';
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();

      expect(runtime.account.state.profile?.id, wire.b);
      expect(runtime.persistence.currentSession?.userId, wire.b);
      expect(storedSecret, refreshSecret);
      final profileRequests = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .toList();
      expect(profileRequests, hasLength(1));
      expect(
        profileRequests.single.headers['authorization'],
        'Bearer ${wire.token(wire.b, wire.sid2, now)}',
      );
    },
  );

  test(
    'late User A vault write is cleared before User B profile readiness',
    () async {
      await runtime.start();
      authUser = wire.a;
      authSession = wire.sid1;
      refreshSecret = 'TEST_ONLY_LATE_A_REFRESH';
      writeWait = Completer<void>();

      final lateLogin = runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await fixture.flush();

      expect(timeline, contains('vault.write'));
      expect(storedSecret, isNull);
      expect(runtime.account.readyRuntime, isNull);
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        isEmpty,
      );

      final logout = runtime.account.signOut();
      await fixture.flush();
      expect(runtime.account.readyRuntime, isNull);
      expect(timeline, contains('auth.logout'));
      expect(
        timeline.where((value) => value == 'vault.clear'),
        isEmpty,
        reason: 'clear must wait for the in-flight credential write',
      );

      writeWait!.complete();
      await lateLogin;
      await logout;
      await fixture.flush();

      expect(storedSecret, isNull);
      expect(
        timeline.indexOf('auth.logout'),
        lessThan(timeline.lastIndexOf('vault.clear')),
      );
      expect(
        timeline.indexOf('vault.write'),
        lessThan(timeline.lastIndexOf('vault.clear')),
      );
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        isEmpty,
      );

      writeWait = null;
      authUser = wire.b;
      authSession = wire.sid2;
      refreshSecret = 'TEST_ONLY_B_AFTER_LATE_A_WRITE';
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();

      final profileRequests = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .toList();
      expect(profileRequests, hasLength(1));
      expect(
        profileRequests.single.headers['authorization'],
        'Bearer ${wire.token(wire.b, wire.sid2, now)}',
      );
      expect(runtime.account.state.profile?.id, wire.b);
      expect(runtime.persistence.currentSession?.userId, wire.b);
      expect(storedSecret, refreshSecret);
      expect(
        timeline.lastIndexOf('vault.clear'),
        lessThan(timeline.lastIndexOf('vault.write')),
      );
      expect(
        timeline.lastIndexOf('vault.write'),
        lessThan(timeline.lastIndexOf('profile.ensure')),
      );
    },
  );

  test(
    'vault clear failure keeps logout fenced until explicit retry before User B',
    () async {
      await runtime.start();
      authUser = wire.a;
      authSession = wire.sid1;
      refreshSecret = 'TEST_ONLY_A_REFRESH_BEFORE_CLEAR_FAILURE';
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();
      expect(storedSecret, refreshSecret);

      failClear = true;
      await runtime.account.signOut();

      expect(runtime.account.state.phase, AccountPhase.signOutError);
      expect(
        runtime.account.state.messageVi,
        'Chưa xác nhận đăng xuất. Vui lòng thử lại.',
      );
      expect(runtime.account.readyRuntime, isNull);
      expect(runtime.persistence.currentSession, isNull);
      expect(storedSecret, refreshSecret);
      final failedClear = timeline.lastIndexOf('vault.clear');
      expect(failedClear, greaterThan(-1));
      expect(failedClear, greaterThan(timeline.lastIndexOf('auth.logout')));

      authUser = wire.b;
      authSession = wire.sid2;
      refreshSecret = 'TEST_ONLY_B_REFRESH_AFTER_CLEAR_RETRY';
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      expect(runtime.account.state.phase, AccountPhase.signOutError);
      expect(
        requests.where((request) => request.url.path == '/auth/v1/token'),
        hasLength(1),
        reason: 'User B must not authenticate while A vault clear is uncertain',
      );
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        hasLength(1),
      );

      failClear = false;
      await runtime.account.signOut();
      expect(runtime.account.state.phase, AccountPhase.signedOut);
      expect(runtime.persistence.currentSession, isNull);
      expect(storedSecret, isNull);

      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();
      final profileRequests = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .toList();
      expect(profileRequests, hasLength(2));
      expect(
        profileRequests.last.headers['authorization'],
        'Bearer ${wire.token(wire.b, wire.sid2, now)}',
      );
      expect(runtime.account.state.profile?.id, wire.b);
      expect(runtime.persistence.currentSession?.userId, wire.b);
      expect(storedSecret, refreshSecret);
    },
  );
}
