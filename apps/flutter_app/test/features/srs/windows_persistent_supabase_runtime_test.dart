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
import 'package:nihongo_daily/features/auth/application/persistent_account_startup.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/persistent_account_access.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
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
  late SessionCredentialVault vault;
  late MockClient network;
  late NativeReviewJournal journal;
  late Directory directory;
  late DateTime now;
  late String? storedSecret;
  late String authUser;
  late String authSession;
  late String refreshSecret;
  late Completer<http.Response>? authWait;
  late Completer<void>? readWait;
  late Completer<void>? writeWait;
  late bool failRead;
  late bool failWrite;
  late bool failWriteAfterCommit;
  late bool failClear;
  late bool failOwnerAcquire;
  late bool failOwnerRelease;
  late bool rejectRefresh;
  final requests = <http.Request>[];
  final timeline = <String>[];
  final ownerLeaseCalls = <String>[];
  final startupOrder = <String>[];
  final closeOrder = <String>[];

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
    ownerLeaseCalls.clear();
    startupOrder.clear();
    closeOrder.clear();
    now = DateTime.utc(2026, 10, 14, 3);
    storedSecret = null;
    authUser = wire.a;
    authSession = wire.sid1;
    refreshSecret = 'TEST_ONLY_ROTATED_WINDOWS_REFRESH';
    authWait = null;
    readWait = null;
    writeWait = null;
    failRead = false;
    failWrite = false;
    failWriteAfterCommit = false;
    failClear = false;
    failOwnerAcquire = false;
    failOwnerRelease = false;
    rejectRefresh = false;

    messenger.setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments as Map<Object?, Object?>;
      expect(
        arguments['target'],
        'NihongoDaily.Refresh.v1|https://example.supabase.invalid',
      );
      switch (call.method) {
        case 'acquireOwner':
          ownerLeaseCalls.add(call.method);
          startupOrder.add('owner.acquire');
          if (failOwnerAcquire) return false;
          return true;
        case 'releaseOwner':
          ownerLeaseCalls.add(call.method);
          closeOrder.add('owner.release');
          if (failOwnerRelease) {
            throw PlatformException(
              code: 'PRIVATE_STORAGE',
              message: 'PRIVATE_REFRESH_SECRET',
              details: {'token': 'PRIVATE_REFRESH_SECRET'},
            );
          }
          return true;
        case 'read':
          startupOrder.add('vault.read');
          timeline.add('vault.read');
          await (readWait?.future ?? Future<void>.value());
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
          if (failWriteAfterCommit) {
            throw PlatformException(
              code: 'PRIVATE_STORAGE',
              message: 'PRIVATE_REFRESH_SECRET',
              details: {'token': 'PRIVATE_REFRESH_SECRET'},
            );
          }
          return true;
        case 'clear':
          closeOrder.add('vault.clear');
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
        if (grant == 'refresh_token' && rejectRefresh) {
          return http.Response(
            jsonEncode({
              'code': 400,
              'error_code': 'refresh_token_not_found',
              'msg': 'Invalid Refresh Token',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
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
    vault = createWindowsSessionCredentialVault(wire.origin);
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
    if (readWait != null && !readWait!.isCompleted) {
      readWait!.complete();
    }
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
    'Windows owner acquisition failure blocks vault and Auth until caller close',
    () async {
      storedSecret = 'TEST_ONLY_SAVED_WINDOWS_REFRESH';
      failOwnerAcquire = true;

      final startup = PersistentAccountStartup(runtime);
      await expectLater(
        startup.start(),
        throwsA(
          isA<ReviewTransportFailure>()
              .having(
                (error) => error.code,
                'safe error code',
                ReviewErrorCode.unauthorized,
              )
              .having(
                (error) => error.toString().contains('PRIVATE_REFRESH_SECRET'),
                'redacted owner error',
                false,
              ),
        ),
      );
      expect(
        startup.canOfferLogin,
        isFalse,
        reason:
            'password login must remain fenced until the native owner is acquired',
      );
      expect(ownerLeaseCalls, ['acquireOwner']);
      expect(startupOrder, ['owner.acquire']);
      expect(timeline, isEmpty);
      expect(requests, isEmpty);
      expect(storedSecret, 'TEST_ONLY_SAVED_WINDOWS_REFRESH');
      expect(runtime.account.readyRuntime, isNull);
      expect(PersistentAccountAccess.isTargetOwned(vault.target), isTrue);

      await runtime.close();

      expect(ownerLeaseCalls, ['acquireOwner']);
      expect(closeOrder, isEmpty);
      expect(PersistentAccountAccess.isTargetOwned(vault.target), isFalse);

      failOwnerAcquire = false;
      vault = createWindowsSessionCredentialVault(wire.origin);
      runtime = PersistentSupabaseRuntime(
        projectUrl: wire.origin,
        publishableKey: wire.key,
        vault: vault,
        store: journal,
        httpClient: network,
        now: () => now,
      );
      await runtime.start();
      await waitForReady();

      expect(ownerLeaseCalls, ['acquireOwner', 'acquireOwner']);
      expect(startupOrder, ['owner.acquire', 'owner.acquire', 'vault.read']);
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
      expect(storedSecret, refreshSecret);
      expect(runtime.account.state.profile?.id, wire.a);

      await runtime.close();
      expect(ownerLeaseCalls, ['acquireOwner', 'acquireOwner', 'releaseOwner']);
      expect(closeOrder.last, 'owner.release');
    },
  );

  test(
    'Windows runtime leases vault before read and releases on close',
    () async {
      await runtime.start();

      expect(startupOrder, ['owner.acquire', 'vault.read']);
      expect(ownerLeaseCalls, ['acquireOwner']);
      expect(closeOrder, isEmpty);

      await runtime.close();

      expect(ownerLeaseCalls, ['acquireOwner', 'releaseOwner']);
      expect(closeOrder, ['owner.release']);
    },
  );

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

  test(
    'Windows rejected restore clears through vault before explicit login and profile',
    () async {
      storedSecret = 'TEST_ONLY_REJECTED_WINDOWS_REFRESH';
      rejectRefresh = true;

      await expectLater(
        runtime.start(),
        throwsA(isA<ReviewTransportFailure>()),
      );

      expect(timeline, ['vault.read', 'auth.refresh']);
      expect(storedSecret, 'TEST_ONLY_REJECTED_WINDOWS_REFRESH');
      expect(runtime.account.readyRuntime, isNull);
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        isEmpty,
      );

      rejectRefresh = false;
      failClear = true;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );

      expect(runtime.account.state.phase, AccountPhase.signInError);
      expect(runtime.account.readyRuntime, isNull);
      expect(storedSecret, 'TEST_ONLY_REJECTED_WINDOWS_REFRESH');
      expect(timeline.where((value) => value == 'auth.password'), isEmpty);
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        isEmpty,
      );
      final failedClear = timeline.lastIndexOf('vault.clear');
      expect(failedClear, greaterThan(timeline.indexOf('auth.refresh')));

      failClear = false;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();

      final successfulClear = timeline.lastIndexOf('vault.clear');
      final passwordAuth = timeline.indexOf('auth.password');
      final rotatedWrite = timeline.lastIndexOf('vault.write');
      final profileRead = timeline.lastIndexOf('profile.ensure');
      expect(successfulClear, greaterThan(failedClear));
      expect(passwordAuth, greaterThan(successfulClear));
      expect(rotatedWrite, greaterThan(passwordAuth));
      expect(profileRead, greaterThan(rotatedWrite));
      expect(storedSecret, refreshSecret);
      expect(runtime.account.state.profile?.id, wire.a);

      final profileRequests = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .toList();
      expect(profileRequests, hasLength(1));
      expect(
        profileRequests.single.headers['authorization'],
        'Bearer ${wire.token(wire.a, wire.sid1, now)}',
      );
    },
  );

  test(
    'Windows transient vault read failure stays fenced until explicit login recovery',
    () async {
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
      expect(
        PersistentAccountStartup(runtime).canOfferLogin,
        isTrue,
        reason:
            'a recoverable read failure may offer login while the owner lease is held',
      );

      // A transient read error is non-destructive. Explicit login on this same
      // owner must clear the unread secret before sending a new password grant.
      failRead = false;
      authUser = wire.b;
      authSession = wire.sid2;
      refreshSecret = 'TEST_ONLY_B_AFTER_TRANSIENT_READ_FAILURE';

      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();

      final authRequests = requests
          .where((request) => request.url.path == '/auth/v1/token')
          .toList();
      expect(authRequests, hasLength(1));
      expect(authRequests.single.url.queryParameters['grant_type'], 'password');
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
        greaterThan(timeline.indexOf('vault.read')),
      );
      expect(
        timeline.lastIndexOf('vault.clear'),
        lessThan(timeline.indexOf('auth.password')),
      );
      expect(
        timeline.indexOf('auth.password'),
        lessThan(timeline.lastIndexOf('vault.write')),
      );
      expect(
        timeline.lastIndexOf('vault.write'),
        lessThan(timeline.lastIndexOf('profile.ensure')),
      );
      expect(
        timeline.where((value) => value == 'auth.refresh'),
        isEmpty,
        reason: 'the unread User A secret must never reach Auth',
      );
    },
  );

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
    'Windows logout fences a held vault read before User B can authenticate',
    () async {
      storedSecret = 'TEST_ONLY_SAVED_A_REFRESH';
      readWait = Completer<void>();

      final starting = runtime.start();
      final startupFailure = expectLater(
        starting,
        throwsA(isA<ReviewTransportFailure>()),
      );
      await fixture.flush();

      expect(timeline, ['vault.read']);
      expect(
        requests.where((request) => request.url.path == '/auth/v1/token'),
        isEmpty,
      );
      expect(runtime.persistence.phase, SessionPersistencePhase.restoring);
      expect(runtime.account.readyRuntime, isNull);

      authUser = wire.b;
      authSession = wire.sid2;
      refreshSecret = 'TEST_ONLY_B_REFRESH_AFTER_READ_LOGOUT';
      final logout = runtime.account.signOut();
      await fixture.flush();

      expect(runtime.account.state.phase, AccountPhase.signingOut);
      expect(runtime.account.readyRuntime, isNull);
      expect(storedSecret, 'TEST_ONLY_SAVED_A_REFRESH');
      expect(
        timeline.where((value) => value == 'vault.clear'),
        isEmpty,
        reason: 'clear must remain ordered behind the held vault read',
      );
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      expect(runtime.account.state.phase, AccountPhase.signingOut);
      expect(
        requests.where((request) => request.url.path == '/auth/v1/token'),
        isEmpty,
        reason: 'User B Auth must wait for the cancelled startup and clear',
      );

      readWait!.complete();
      await startupFailure;
      await logout;
      await fixture.flush();

      expect(storedSecret, isNull);
      expect(runtime.persistence.currentSession, isNull);
      expect(runtime.account.readyRuntime, isNull);
      expect(
        timeline.lastIndexOf('vault.clear'),
        greaterThan(timeline.indexOf('vault.read')),
      );
      expect(
        timeline.where((value) => value == 'auth.refresh'),
        isEmpty,
        reason: 'the stale User A secret must never reach Auth',
      );
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        isEmpty,
        reason:
            'neither stale User A nor blocked User B may provision a profile',
      );

      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();

      final authRequests = requests
          .where((request) => request.url.path == '/auth/v1/token')
          .toList();
      expect(authRequests, hasLength(1));
      expect(authRequests.single.url.queryParameters['grant_type'], 'password');
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
        lessThan(timeline.indexOf('auth.password')),
      );
      expect(
        timeline.indexOf('auth.password'),
        lessThan(timeline.lastIndexOf('vault.write')),
      );
      expect(
        timeline.lastIndexOf('vault.write'),
        lessThan(timeline.lastIndexOf('profile.ensure')),
      );
    },
  );

  test(
    'late User A startup refresh is drained and cleared before User B can authenticate',
    () async {
      storedSecret = 'TEST_ONLY_SAVED_A_REFRESH';
      authUser = wire.a;
      authSession = wire.sid1;
      refreshSecret = 'TEST_ONLY_LATE_A_ROTATED_REFRESH';
      authWait = Completer<http.Response>();
      final lateARefresh = authWait!;

      final starting = runtime.start();
      final startupFailure = expectLater(
        starting,
        throwsA(isA<ReviewTransportFailure>()),
      );
      await fixture.flush();

      expect(timeline, ['vault.read', 'auth.refresh']);
      expect(runtime.persistence.phase, SessionPersistencePhase.restoring);
      expect(runtime.account.readyRuntime, isNull);
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        isEmpty,
      );

      // Capture A's actual delayed rotation before starting caller-owned logout.
      final lateAResponse = authResponse();
      var logoutSettled = false;
      final logout = runtime.account.signOut().then((_) {
        logoutSettled = true;
      });
      await fixture.flush();

      expect(runtime.account.state.phase, AccountPhase.signingOut);
      expect(runtime.account.readyRuntime, isNull);
      expect(storedSecret, isNull);
      expect(logoutSettled, isFalse);
      expect(
        timeline.lastIndexOf('vault.clear'),
        greaterThan(timeline.indexOf('vault.read')),
      );

      authWait = null;
      authUser = wire.b;
      authSession = wire.sid2;
      refreshSecret = 'TEST_ONLY_B_REFRESH_AFTER_LATE_RESTORE';

      // A replacement login is rejected while logout still drains A's startup
      // refresh; it must not dispatch another Auth request or load a profile.
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      expect(runtime.account.state.phase, AccountPhase.signingOut);
      expect(logoutSettled, isFalse);
      expect(
        requests.where((request) => request.url.path == '/auth/v1/token'),
        hasLength(1),
      );
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        isEmpty,
      );

      lateARefresh.complete(lateAResponse);
      await startupFailure;
      await logout;
      await fixture.flush();
      expect(logoutSettled, isTrue);

      expect(storedSecret, isNull);
      expect(runtime.persistence.currentSession, isNull);
      expect(runtime.account.readyRuntime, isNull);
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        isEmpty,
      );
      expect(
        timeline.lastIndexOf('vault.clear'),
        greaterThan(timeline.indexOf('auth.refresh')),
      );

      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();

      final authRequests = requests
          .where((request) => request.url.path == '/auth/v1/token')
          .toList();
      expect(authRequests, hasLength(2));
      expect(
        authRequests.first.url.queryParameters['grant_type'],
        'refresh_token',
      );
      expect(authRequests.last.url.queryParameters['grant_type'], 'password');
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
    'late User A explicit refresh is drained and cleared before User B can authenticate',
    () async {
      await runtime.start();
      authUser = wire.a;
      authSession = wire.sid1;
      refreshSecret = 'TEST_ONLY_A_INITIAL_REFRESH';
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();
      expect(storedSecret, refreshSecret);

      final profileCountBeforeRefresh = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .length;
      authWait = Completer<http.Response>();
      final lateARefresh = authWait!;
      refreshSecret = 'TEST_ONLY_LATE_A_ROTATED_REFRESH';
      final refreshFailure = expectLater(
        runtime.refresh(),
        throwsA(isA<ReviewTransportFailure>()),
      );
      await fixture.flush();

      expect(timeline, contains('auth.refresh'));
      expect(runtime.persistence.phase, SessionPersistencePhase.saving);
      expect(runtime.account.readyRuntime, isNull);
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        hasLength(profileCountBeforeRefresh),
      );

      final lateAResponse = authResponse();
      var logoutSettled = false;
      final logout = runtime.account.signOut().then((_) {
        logoutSettled = true;
      });
      await fixture.flush();

      expect(runtime.account.state.phase, AccountPhase.signingOut);
      expect(runtime.account.readyRuntime, isNull);
      expect(storedSecret, isNull);
      expect(logoutSettled, isFalse);

      authWait = null;
      authUser = wire.b;
      authSession = wire.sid2;
      refreshSecret = 'TEST_ONLY_B_REFRESH_AFTER_LATE_A_REFRESH';
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      expect(runtime.account.state.phase, AccountPhase.signingOut);
      expect(logoutSettled, isFalse);
      expect(
        requests.where((request) => request.url.path == '/auth/v1/token'),
        hasLength(2),
        reason: 'User B must wait for User A refresh cleanup to finish',
      );
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        hasLength(profileCountBeforeRefresh),
      );

      lateARefresh.complete(lateAResponse);
      await refreshFailure;
      await logout;
      await fixture.flush();
      expect(logoutSettled, isTrue);
      expect(storedSecret, isNull);
      expect(runtime.persistence.currentSession, isNull);
      expect(runtime.account.readyRuntime, isNull);
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        hasLength(profileCountBeforeRefresh),
      );

      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();

      final authRequests = requests
          .where((request) => request.url.path == '/auth/v1/token')
          .toList();
      expect(authRequests, hasLength(3));
      expect(authRequests[0].url.queryParameters['grant_type'], 'password');
      expect(
        authRequests[1].url.queryParameters['grant_type'],
        'refresh_token',
      );
      expect(authRequests[2].url.queryParameters['grant_type'], 'password');

      final profileRequests = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .toList();
      expect(profileRequests, hasLength(profileCountBeforeRefresh + 1));
      expect(
        profileRequests.last.headers['authorization'],
        'Bearer ${wire.token(wire.b, wire.sid2, now)}',
      );
      expect(runtime.account.state.profile?.id, wire.b);
      expect(runtime.persistence.currentSession?.userId, wire.b);
      expect(storedSecret, refreshSecret);

      final refreshIndex = timeline.indexOf('auth.refresh');
      final clearIndex = timeline.lastIndexOf('vault.clear');
      final passwordIndex = timeline.lastIndexOf('auth.password');
      final writeIndex = timeline.lastIndexOf('vault.write');
      final profileIndex = timeline.lastIndexOf('profile.ensure');
      expect(clearIndex, greaterThan(refreshIndex));
      expect(clearIndex, lessThan(passwordIndex));
      expect(writeIndex, greaterThan(passwordIndex));
      expect(profileIndex, greaterThan(writeIndex));
    },
  );

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
    'late User A vault write plus failed logout clear stays fenced until explicit retry',
    () async {
      await runtime.start();
      authUser = wire.a;
      authSession = wire.sid1;
      refreshSecret = 'TEST_ONLY_LATE_A_REFRESH_BEFORE_CLEAR_FAILURE';
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

      failClear = true;
      final logout = runtime.account.signOut();
      await fixture.flush();

      expect(runtime.account.readyRuntime, isNull);
      expect(timeline, contains('auth.logout'));
      expect(
        timeline.where((value) => value == 'vault.clear'),
        isEmpty,
        reason: 'clear must remain queued behind the late A write',
      );

      writeWait!.complete();
      await lateLogin;
      await logout;
      await fixture.flush();

      expect(runtime.account.state.phase, AccountPhase.signOutError);
      expect(runtime.persistence.phase, SessionPersistencePhase.failed);
      expect(runtime.persistence.currentSession, isNull);
      expect(runtime.account.readyRuntime, isNull);
      expect(storedSecret, refreshSecret);
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        isEmpty,
      );

      final failedClear = timeline.lastIndexOf('vault.clear');
      expect(failedClear, greaterThan(timeline.indexOf('auth.logout')));
      expect(failedClear, greaterThan(timeline.indexOf('vault.write')));

      authUser = wire.b;
      authSession = wire.sid2;
      refreshSecret = 'TEST_ONLY_B_REFRESH_AFTER_LATE_WRITE_CLEAR_RETRY';
      final authCallsBeforeRetry = requests
          .where((request) => request.url.path == '/auth/v1/token')
          .length;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      expect(runtime.account.state.phase, AccountPhase.signOutError);
      expect(
        requests.where((request) => request.url.path == '/auth/v1/token'),
        hasLength(authCallsBeforeRetry),
        reason: 'User B must not authenticate while User A clear is uncertain',
      );
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        isEmpty,
      );

      failClear = false;
      await runtime.account.signOut();
      await fixture.flush();
      expect(storedSecret, isNull);
      expect(runtime.account.state.phase, AccountPhase.signedOut);
      expect(runtime.persistence.phase, SessionPersistencePhase.idle);
      final successfulClear = timeline.lastIndexOf('vault.clear');
      expect(successfulClear, greaterThan(failedClear));

      writeWait = null;
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
        requests.where((request) => request.url.path == '/auth/v1/token'),
        hasLength(authCallsBeforeRetry + 1),
      );
      expect(
        profileRequests.single.headers['authorization'],
        'Bearer ${wire.token(wire.b, wire.sid2, now)}',
      );
      expect(runtime.account.state.profile?.id, wire.b);
      expect(runtime.persistence.currentSession?.userId, wire.b);
      expect(storedSecret, refreshSecret);
      expect(successfulClear, lessThan(timeline.lastIndexOf('vault.write')));
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

  test(
    'Windows refresh rotation write failure fences A before B profile readiness',
    () async {
      authUser = wire.a;
      authSession = wire.sid1;
      refreshSecret = 'TEST_ONLY_A_INITIAL_REFRESH';
      await runtime.start();
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();

      expect(storedSecret, refreshSecret);
      final profileCountBeforeRefresh = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .length;
      expect(profileCountBeforeRefresh, 1);

      failWrite = true;
      refreshSecret = 'TEST_ONLY_A_ROTATED_REFRESH';
      await expectLater(
        runtime.refresh(),
        throwsA(isA<ReviewTransportFailure>()),
      );

      expect(runtime.persistence.phase, SessionPersistencePhase.failed);
      expect(runtime.persistence.currentSession, isNull);
      expect(runtime.account.readyRuntime, isNull);
      expect(storedSecret, isNull);
      final refreshIndex = timeline.indexOf('auth.refresh');
      final failedWriteIndex = timeline.lastIndexOf('vault.write');
      final failedClearIndex = timeline.lastIndexOf('vault.clear');
      expect(refreshIndex, greaterThan(-1));
      expect(failedWriteIndex, greaterThan(refreshIndex));
      expect(failedClearIndex, greaterThan(failedWriteIndex));
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        hasLength(profileCountBeforeRefresh),
      );

      failWrite = false;
      authUser = wire.b;
      authSession = wire.sid2;
      refreshSecret = 'TEST_ONLY_B_REFRESH_AFTER_A_ROTATION_WRITE_FAILURE';
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();

      final authRequests = requests
          .where((request) => request.url.path == '/auth/v1/token')
          .toList();
      expect(authRequests, hasLength(3));
      expect(authRequests[0].url.queryParameters['grant_type'], 'password');
      expect(
        authRequests[1].url.queryParameters['grant_type'],
        'refresh_token',
      );
      expect(authRequests[2].url.queryParameters['grant_type'], 'password');

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

      final cleanupIndex = timeline.lastIndexOf('vault.clear');
      final passwordIndex = timeline.lastIndexOf('auth.password');
      final savedIndex = timeline.lastIndexOf('vault.write');
      final profileIndex = timeline.lastIndexOf('profile.ensure');
      expect(cleanupIndex, greaterThan(failedClearIndex));
      expect(passwordIndex, greaterThan(cleanupIndex));
      expect(savedIndex, greaterThan(passwordIndex));
      expect(profileIndex, greaterThan(savedIndex));
    },
  );

  test(
    'Windows ambiguous rotation write commit and failed clear stay fenced until B retry',
    () async {
      authUser = wire.a;
      authSession = wire.sid1;
      refreshSecret = 'TEST_ONLY_A_INITIAL_REFRESH';
      await runtime.start();
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();

      List<http.Request> authRequests() => requests
          .where((request) => request.url.path == '/auth/v1/token')
          .toList();
      List<http.Request> profileRequests() => requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .toList();
      final initialProfileCount = profileRequests().length;
      expect(initialProfileCount, 1);

      failWriteAfterCommit = true;
      failClear = true;
      refreshSecret = 'TEST_ONLY_A_COMMITTED_WITHOUT_ACK';
      await expectLater(
        runtime.refresh(),
        throwsA(
          isA<ReviewTransportFailure>().having(
            (error) => error.toString().contains('PRIVATE'),
            'redacted platform failure',
            false,
          ),
        ),
      );

      expect(storedSecret, 'TEST_ONLY_A_COMMITTED_WITHOUT_ACK');
      expect(runtime.persistence.phase, SessionPersistencePhase.failed);
      expect(runtime.persistence.currentSession, isNull);
      expect(runtime.account.readyRuntime, isNull);
      expect(profileRequests(), hasLength(initialProfileCount));
      final failedWrite = timeline.lastIndexOf('vault.write');
      final failedCompensation = timeline.lastIndexOf('vault.clear');
      expect(failedCompensation, greaterThan(failedWrite));

      // A's write committed, but its acknowledgement and compensating clear
      // both failed. B must remain blocked until an explicit cleanup succeeds.
      failWriteAfterCommit = false;
      authUser = wire.b;
      authSession = wire.sid2;
      refreshSecret = 'TEST_ONLY_B_REFRESH_AFTER_AMBIGUOUS_A_WRITE';
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );

      expect(runtime.account.state.phase, AccountPhase.signInError);
      expect(runtime.persistence.currentSession, isNull);
      expect(runtime.account.readyRuntime, isNull);
      expect(storedSecret, 'TEST_ONLY_A_COMMITTED_WITHOUT_ACK');
      expect(authRequests(), hasLength(2));
      expect(
        authRequests()
            .map((request) => request.url.queryParameters['grant_type'])
            .toList(),
        ['password', 'refresh_token'],
      );
      expect(profileRequests(), hasLength(initialProfileCount));
      final blockedRetryClear = timeline.lastIndexOf('vault.clear');
      expect(blockedRetryClear, greaterThan(failedCompensation));

      failClear = false;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();

      expect(
        authRequests()
            .map((request) => request.url.queryParameters['grant_type'])
            .toList(),
        ['password', 'refresh_token', 'password'],
      );
      expect(profileRequests(), hasLength(initialProfileCount + 1));
      expect(
        profileRequests().last.headers['authorization'],
        'Bearer ${wire.token(wire.b, wire.sid2, now)}',
      );
      expect(runtime.account.state.profile?.id, wire.b);
      expect(runtime.persistence.currentSession?.userId, wire.b);
      expect(storedSecret, refreshSecret);

      final successfulClear = timeline.lastIndexOf('vault.clear');
      final replacementPassword = timeline.lastIndexOf('auth.password');
      final replacementWrite = timeline.lastIndexOf('vault.write');
      final replacementProfile = timeline.lastIndexOf('profile.ensure');
      expect(successfulClear, greaterThan(blockedRetryClear));
      expect(successfulClear, lessThan(replacementPassword));
      expect(replacementPassword, lessThan(replacementWrite));
      expect(replacementWrite, lessThan(replacementProfile));
    },
  );

  test(
    'Windows caller close retries failed logout clear before releasing owned runtime',
    () async {
      await runtime.start();
      authUser = wire.a;
      authSession = wire.sid1;
      refreshSecret = 'TEST_ONLY_WINDOWS_CLOSE_CLEAR_RETRY';
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();
      expect(storedSecret, refreshSecret);

      failClear = true;
      await runtime.account.signOut();
      expect(runtime.account.state.phase, AccountPhase.signOutError);
      expect(runtime.account.readyRuntime, isNull);
      expect(runtime.persistence.currentSession, isNull);
      expect(storedSecret, refreshSecret);

      await expectLater(runtime.close(), throwsA(isA<SessionVaultFailure>()));
      expect(runtime.persistence.phase, SessionPersistencePhase.closed);
      expect(storedSecret, refreshSecret);
      expect(ownerLeaseCalls, ['acquireOwner']);
      expect(closeOrder, ['vault.clear', 'vault.clear']);
      expect(
        () => PersistentSupabaseRuntime(
          projectUrl: wire.origin,
          publishableKey: wire.key,
          vault: createWindowsSessionCredentialVault(wire.origin),
          store: journal,
          httpClient: network,
          now: () => now,
        ),
        throwsA(isA<SessionVaultFailure>()),
        reason: 'the failed close must retain exclusive vault ownership',
      );

      failClear = false;
      await runtime.close();
      expect(storedSecret, isNull);
      expect(runtime.account.readyRuntime, isNull);
      expect(timeline.where((value) => value == 'vault.clear'), hasLength(3));
      expect(ownerLeaseCalls, ['acquireOwner', 'releaseOwner']);
      expect(closeOrder.last, 'owner.release');
      expect(
        closeOrder.lastIndexOf('vault.clear'),
        lessThan(closeOrder.lastIndexOf('owner.release')),
      );
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'Windows caller close retries failed rotation clear before releasing owned runtime',
    () async {
      await runtime.start();
      authUser = wire.a;
      authSession = wire.sid1;
      refreshSecret = 'TEST_ONLY_WINDOWS_CLOSE_ROTATION_INITIAL';
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForReady();
      expect(storedSecret, refreshSecret);

      // The native write may commit even when its acknowledgement is lost.
      // A failed compensation leaves an uncertain secret that close must drain.
      failWriteAfterCommit = true;
      failClear = true;
      refreshSecret = 'TEST_ONLY_WINDOWS_CLOSE_ROTATION_COMMITTED';
      await expectLater(
        runtime.refresh(),
        throwsA(isA<ReviewTransportFailure>()),
      );

      expect(storedSecret, 'TEST_ONLY_WINDOWS_CLOSE_ROTATION_COMMITTED');
      expect(runtime.persistence.phase, SessionPersistencePhase.failed);
      expect(runtime.persistence.currentSession, isNull);
      expect(runtime.account.readyRuntime, isNull);
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        hasLength(1),
      );
      final failedWrite = timeline.lastIndexOf('vault.write');
      final failedClear = timeline.lastIndexOf('vault.clear');
      expect(failedWrite, greaterThan(timeline.lastIndexOf('auth.refresh')));
      expect(failedClear, greaterThan(failedWrite));

      await expectLater(runtime.close(), throwsA(isA<SessionVaultFailure>()));
      expect(runtime.persistence.phase, SessionPersistencePhase.closed);
      expect(storedSecret, 'TEST_ONLY_WINDOWS_CLOSE_ROTATION_COMMITTED');
      expect(ownerLeaseCalls, ['acquireOwner']);
      expect(closeOrder, ['vault.clear', 'vault.clear']);
      expect(
        () => PersistentSupabaseRuntime(
          projectUrl: wire.origin,
          publishableKey: wire.key,
          vault: createWindowsSessionCredentialVault(wire.origin),
          store: journal,
          httpClient: network,
          now: () => now,
        ),
        throwsA(isA<SessionVaultFailure>()),
        reason: 'failed rotation cleanup must retain exclusive vault ownership',
      );

      failClear = false;
      await runtime.close();
      expect(storedSecret, isNull);
      expect(runtime.account.readyRuntime, isNull);
      expect(timeline.where((value) => value == 'vault.clear'), hasLength(3));
      expect(ownerLeaseCalls, ['acquireOwner', 'releaseOwner']);
      expect(closeOrder.last, 'owner.release');
      expect(
        closeOrder.lastIndexOf('vault.clear'),
        lessThan(closeOrder.lastIndexOf('owner.release')),
      );
      expect(
        requests.where(
          (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
        ),
        hasLength(1),
      );
    },
  );

  test('Windows caller close retries a failed native owner release', () async {
    await runtime.start();
    expect(ownerLeaseCalls, ['acquireOwner']);
    expect(PersistentAccountAccess.isTargetOwned(vault.target), isTrue);
    expect(requests, isEmpty);

    failOwnerRelease = true;
    await expectLater(
      runtime.close(),
      throwsA(
        isA<SessionVaultFailure>()
            .having(
              (error) => error.code,
              'safe owner-release error',
              SessionVaultError.unavailable,
            )
            .having(
              (error) => error.toString().contains('PRIVATE_REFRESH_SECRET'),
              'redacted owner-release error',
              false,
            ),
      ),
    );

    expect(runtime.persistence.phase, SessionPersistencePhase.closed);
    expect(ownerLeaseCalls, ['acquireOwner', 'releaseOwner']);
    expect(closeOrder, ['owner.release']);
    expect(PersistentAccountAccess.isTargetOwned(vault.target), isTrue);
    expect(requests, isEmpty);
    expect(timeline, ['vault.read']);

    expect(
      () => PersistentSupabaseRuntime(
        projectUrl: wire.origin,
        publishableKey: wire.key,
        vault: createWindowsSessionCredentialVault(wire.origin),
        store: journal,
        httpClient: network,
        now: () => now,
      ),
      throwsA(isA<SessionVaultFailure>()),
      reason: 'a failed native release must retain the Dart project owner',
    );

    failOwnerRelease = false;
    await runtime.close();
    expect(ownerLeaseCalls, ['acquireOwner', 'releaseOwner', 'releaseOwner']);
    expect(closeOrder, ['owner.release', 'owner.release']);
    expect(PersistentAccountAccess.isTargetOwned(vault.target), isFalse);

    vault = createWindowsSessionCredentialVault(wire.origin);
    runtime = PersistentSupabaseRuntime(
      projectUrl: wire.origin,
      publishableKey: wire.key,
      vault: vault,
      store: journal,
      httpClient: network,
      now: () => now,
    );
    await runtime.start();
    expect(ownerLeaseCalls, [
      'acquireOwner',
      'releaseOwner',
      'releaseOwner',
      'acquireOwner',
    ]);
    await runtime.close();
    expect(ownerLeaseCalls, [
      'acquireOwner',
      'releaseOwner',
      'releaseOwner',
      'acquireOwner',
      'releaseOwner',
    ]);
    expect(PersistentAccountAccess.isTargetOwned(vault.target), isFalse);
    expect(requests, isEmpty);
  });
}
