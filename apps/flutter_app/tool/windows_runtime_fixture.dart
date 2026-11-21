// TEST ONLY pinned SDK/HTTP fixtures with real Windows vault and native journal.
// Never contacts a service, accepts live credentials or enters the normal app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/persistent_account_access.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/auth/data/windows_session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const runtimePhases = {
  'runtime-login',
  'runtime-restore-profile-held',
  'runtime-restore',
  'runtime-logout',
  'runtime-signedout',
  'runtime-rejected',
  'runtime-late-refresh',
  'runtime-late-profile',
  'runtime-native-same-owner-profile-generation',
  'runtime-close-restore',
  'runtime-owner-hold',
  'runtime-owner-contend',
  'runtime-owner-reacquire',
  'runtime-native-read-failure',
  'runtime-native-rotation-write-failure',
  'runtime-native-rotation-write-failure-late-profile',
  'runtime-native-rotation-write-fail-before',
  'runtime-native-logout-clear-failure',
  'runtime-native-logout-clear-commit-failure',
};
const _owner = 'a1000000-0000-4000-8000-000000000001';
const _ownerB = 'a1000000-0000-4000-8000-000000000002';
const _sessionA = 'c1000000-0000-4000-8000-000000000001';
const _sessionB = 'c1000000-0000-4000-8000-000000000002';
const _first = 'TEST_ONLY_RUNTIME_FIRST';
const _second = 'TEST_ONLY_RUNTIME_SECOND';
const _third = 'TEST_ONLY_RUNTIME_THIRD';
const _fourth = 'TEST_ONLY_RUNTIME_FOURTH';
const _rejected = 'TEST_ONLY_RUNTIME_REJECTED';
const _pending = <String, Object>{
  'client_event_id': 'c2000000-0000-4000-8000-000000000001',
  'item_type': 'VOCABULARY',
  'item_id': 'b2000000-0000-4000-8000-000000000001',
  'rating': 2,
  'is_correct': true,
  'response_ms': 200,
  'occurred_at': '2026-10-14T02:00:00.123456789+07:00',
};

void _check(bool value) {
  if (!value) {
    throw const FormatException('Runtime fixture verification failed');
  }
}

Future<void> _injectNativeVaultFault(
  String target, {
  required String operation,
  required String fault,
}) async {
  try {
    final injected = await const MethodChannel('nihongo_daily/session_vault_v1')
        .invokeMethod<bool>('testInjectFault', {
          'target': target,
          'operation': operation,
          'fault': fault,
        });
    _check(injected == true);
  } on Object {
    throw const FormatException('Native vault fault injection unavailable');
  }
}

Directory runtimeFixtureDirectory(String scope) {
  _check(RegExp(r'^bridge-[a-f0-9]{32}$').hasMatch(scope));
  return Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}nd-$scope',
  );
}

final class _EmptyReviewStore implements DurableReviewStore {
  @override
  Future<List<StoredReview>> list(String userId) async =>
      const <StoredReview>[];

  @override
  Future<StoredReview> stage(String userId, Map<String, Object> request) =>
      Future<StoredReview>.error(const ReviewStorageFailure());

  @override
  Future<void> acknowledge(
    String userId,
    String eventId,
    ReviewSuccess receipt,
  ) => Future<void>.error(const ReviewStorageFailure());

  @override
  Future<void> reject(String userId, String eventId, ReviewFailure rejection) =>
      Future<void>.error(const ReviewStorageFailure());
}

Future<void> _verifyNativeOwnerLeasePhase(String phase, String scope) async {
  final origin = 'https://$scope.invalid';
  final vault = createWindowsSessionCredentialVault(origin);
  final directory = runtimeFixtureDirectory(scope);
  await directory.create(recursive: true);
  final requests = <http.Request>[];
  final network = MockClient((request) async {
    requests.add(request);
    throw const FormatException('Unexpected owner-lease request');
  });
  final runtime = PersistentSupabaseRuntime(
    projectUrl: origin,
    publishableKey: 'sb_publishable_TEST_ONLY_1234567890',
    vault: vault,
    store: _EmptyReviewStore(),
    httpClient: network,
  );
  var closed = false;
  try {
    if (phase == 'runtime-owner-hold') {
      await runtime.start();
      _check(
        runtime.persistence.phase == SessionPersistencePhase.idle &&
            runtime.persistence.hasVaultOwner &&
            PersistentAccountAccess.isTargetOwned(vault.target) &&
            runtime.account.readyRuntime == null &&
            requests.isEmpty,
      );
      await File(
        '${directory.path}${Platform.pathSeparator}owner-ready',
      ).writeAsString('TEST_ONLY_OWNER_READY', flush: true);
      final release = File(
        '${directory.path}${Platform.pathSeparator}owner-release',
      );
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (!await release.exists() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      _check(await release.exists());
      _check(await release.readAsString() == 'TEST_ONLY_OWNER_RELEASE');
      await runtime.close();
      closed = true;
      _check(
        !runtime.persistence.hasVaultOwner &&
            !PersistentAccountAccess.isTargetOwned(vault.target) &&
            runtime.account.readyRuntime == null &&
            requests.isEmpty,
      );
      await File(
        '${directory.path}${Platform.pathSeparator}owner-done',
      ).writeAsString('TEST_ONLY_OWNER_RELEASED', flush: true);
    } else if (phase == 'runtime-owner-contend') {
      // If start tries a native read before the cross-process lease is won,
      // this one-shot fault will be consumed and the regression will fail.
      await _injectNativeVaultFault(
        vault.target,
        operation: 'read',
        fault: 'fail_before',
      );
      var rejected = false;
      try {
        await runtime.start();
      } on ReviewTransportFailure catch (error) {
        rejected = error.code == ReviewErrorCode.unauthorized;
      }
      _check(
        rejected &&
            runtime.persistence.phase == SessionPersistencePhase.failed &&
            !runtime.persistence.hasVaultOwner &&
            runtime.account.readyRuntime == null &&
            requests.isEmpty,
      );
      var competingLeaseAcquired = false;
      try {
        await vault.acquireOwner();
        competingLeaseAcquired = true;
      } on SessionVaultFailure catch (error) {
        _check(error.code == SessionVaultError.unavailable);
      }
      if (competingLeaseAcquired) await vault.releaseOwner();
      _check(!competingLeaseAcquired);
      var readFaultPreserved = false;
      try {
        await vault.readRefreshToken();
      } on SessionVaultFailure catch (error) {
        readFaultPreserved = error.code == SessionVaultError.unavailable;
      }
      _check(readFaultPreserved);
      _check(await vault.readRefreshToken() == null);
      await runtime.close();
      closed = true;
      _check(
        !PersistentAccountAccess.isTargetOwned(vault.target) &&
            requests.isEmpty,
      );
    } else {
      await runtime.start();
      _check(
        runtime.persistence.phase == SessionPersistencePhase.idle &&
            runtime.persistence.hasVaultOwner &&
            runtime.account.readyRuntime == null &&
            requests.isEmpty,
      );
      await runtime.close();
      closed = true;
      _check(
        !runtime.persistence.hasVaultOwner &&
            !PersistentAccountAccess.isTargetOwned(vault.target) &&
            requests.isEmpty,
      );
    }
  } finally {
    try {
      if (!closed) await runtime.close();
    } finally {
      network.close();
    }
  }
}

String _segment(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

Future<void> verifyWindowsRuntimePhase(String phase, String scope) async {
  _check(Platform.isWindows && runtimePhases.contains(phase));
  final nativeLogoutClearFailure =
      phase == 'runtime-native-logout-clear-failure' ||
      phase == 'runtime-native-logout-clear-commit-failure';
  final directory = runtimeFixtureDirectory(scope);
  final origin = 'https://$scope.invalid';
  final vault = createWindowsSessionCredentialVault(origin);
  final now = DateTime.now().toUtc();
  if (const {
    'runtime-owner-hold',
    'runtime-owner-contend',
    'runtime-owner-reacquire',
  }.contains(phase)) {
    await _verifyNativeOwnerLeasePhase(phase, scope);
    return;
  }
  final journal = await NativeReviewJournal.open(directory);
  var authCalls = 0;
  var profileCalls = 0;
  var logoutCalls = 0;
  var userId = _owner;
  var sessionId = _sessionA;
  var secret = phase == 'runtime-restore-profile-held'
      ? _second
      : phase == 'runtime-restore'
      ? _third
      : phase == 'runtime-logout'
      ? _fourth
      : phase == 'runtime-late-refresh'
      ? _second
      : _first;
  Completer<http.Response>? lateRefresh;
  Completer<http.Response>? heldProfile;
  http.Response? capturedLateProfile;
  var profileResponseReleased = false;
  final profileOwners = <String>[];
  var displayName = '学習者';

  String accessToken() {
    final header = _segment({'alg': 'HS256', 'typ': 'JWT'});
    final payload = _segment({
      'sub': userId,
      'session_id': sessionId,
      'role': 'authenticated',
      'aud': 'authenticated',
      'iss': '$origin/auth/v1',
      'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
    });
    return '$header.$payload.${_segment('TEST ONLY NOT A SIGNATURE')}';
  }

  http.Response authResponse() => http.Response(
    jsonEncode({
      'access_token': accessToken(),
      'refresh_token': secret,
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': userId,
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

  http.Response profileResponse() => http.Response(
    jsonEncode({
      'id': userId,
      'display_name': displayName,
      'preferred_jlpt': 'N5',
      'daily_target_minutes': 120,
      'timezone': 'Asia/Saigon',
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  final requests = <http.Request>[];
  final network = MockClient((request) async {
    requests.add(request);
    _check(request.url.origin == origin && !request.followRedirects);
    if (request.url.path == '/auth/v1/token') {
      authCalls++;
      final grant = request.url.queryParameters['grant_type'];
      final body = jsonDecode(request.body) as Map<String, Object?>;
      if (grant == 'refresh_token') {
        final expected =
            phase == 'runtime-restore-profile-held' ||
                phase == 'runtime-late-refresh' ||
                phase == 'runtime-close-restore' ||
                phase == 'runtime-native-rotation-write-failure' ||
                phase == 'runtime-native-rotation-write-failure-late-profile' ||
                phase == 'runtime-native-rotation-write-fail-before'
            ? _first
            : phase == 'runtime-restore'
            ? _second
            : phase == 'runtime-logout'
            ? _third
            : _rejected;
        _check(body.length == 1 && body['refresh_token'] == expected);
        if (phase == 'runtime-rejected') {
          return http.Response('{"message":"fixture rejected"}', 401);
        }
        if (phase == 'runtime-late-refresh' ||
            phase == 'runtime-close-restore') {
          final wait = lateRefresh;
          _check(wait != null);
          return wait!.future;
        }
      } else {
        _check(grant == 'password');
        _check(body['email'] == 'fixture@example.invalid');
        _check(body['password'] == 'TEST_ONLY_PASSWORD');
        if (phase == 'runtime-native-read-failure') {
          // Explicit recovery must clear the unread A slot before password Auth.
          _check(await vault.readRefreshToken() == null);
        }
        if (phase == 'runtime-native-same-owner-profile-generation') {
          // A1 logout must clear the exact OS slot before A2 can authenticate.
          _check(await vault.readRefreshToken() == null && userId == _owner);
        }
        if (phase == 'runtime-native-rotation-write-failure' ||
            phase == 'runtime-native-rotation-write-failure-late-profile' ||
            phase == 'runtime-native-rotation-write-fail-before') {
          // The initial A grant and replacement B grant both start from a
          // cleared slot; the refresh grant is handled separately above.
          _check(await vault.readRefreshToken() == null);
          if (authCalls == 1) {
            _check(userId == _owner);
          } else {
            _check(authCalls == 3 && userId == _ownerB && logoutCalls >= 1);
          }
        }
        if (nativeLogoutClearFailure) {
          // Both password grants must begin only after A's native slot clears.
          _check(await vault.readRefreshToken() == null);
          if (authCalls == 1) {
            _check(userId == _owner);
          } else {
            _check(authCalls == 2 && userId == _ownerB);
          }
        }
      }
      return authResponse();
    }
    if (request.url.path == '/rest/v1/rpc/ensure_profile') {
      profileCalls++;
      profileOwners.add(userId);
      // The real OS write must already be observable before profile dispatch.
      _check(await vault.readRefreshToken() == secret);
      if (phase == 'runtime-late-refresh' ||
          phase == 'runtime-late-profile' ||
          phase == 'runtime-native-same-owner-profile-generation' ||
          phase == 'runtime-restore-profile-held' ||
          phase == 'runtime-native-read-failure' ||
          phase == 'runtime-native-rotation-write-failure' ||
          phase == 'runtime-native-rotation-write-failure-late-profile' ||
          phase == 'runtime-native-rotation-write-fail-before' ||
          nativeLogoutClearFailure) {
        _check(request.headers['authorization'] == 'Bearer ${accessToken()}');
      }
      if (phase == 'runtime-native-rotation-write-failure' ||
          phase == 'runtime-native-rotation-write-failure-late-profile' ||
          phase == 'runtime-native-rotation-write-fail-before') {
        if (profileCalls == 1) {
          _check(userId == _owner);
        } else {
          _check(profileCalls == 2 && userId == _ownerB);
        }
      }
      if (nativeLogoutClearFailure) {
        if (profileCalls == 1) {
          _check(userId == _owner);
        } else {
          _check(profileCalls == 2 && userId == _ownerB);
        }
      }
      if (phase == 'runtime-restore-profile-held') {
        final wait = heldProfile;
        _check(wait != null);
        final response = await wait!.future;
        profileResponseReleased = true;
        return response;
      }
      if ((phase == 'runtime-late-profile' ||
              phase == 'runtime-native-rotation-write-failure-late-profile' ||
              phase == 'runtime-native-same-owner-profile-generation') &&
          profileCalls == 1) {
        final wait = heldProfile;
        _check(wait != null);
        // Capture A's identity-bearing response before the fixture switches to B.
        capturedLateProfile = profileResponse();
        final response = await wait!.future;
        profileResponseReleased = true;
        return response;
      }
      return profileResponse();
    }
    if (request.url.path == '/auth/v1/logout') {
      logoutCalls++;
      return http.Response('', 204);
    }
    // Includes submit_review: recovery must not dispatch an uncertain event.
    throw const FormatException('Unexpected fixture request');
  });
  final runtime = PersistentSupabaseRuntime(
    projectUrl: origin,
    publishableKey: 'sb_publishable_TEST_ONLY_1234567890',
    vault: vault,
    store: journal,
    httpClient: network,
    now: () => now,
  );
  Future<void> ready() async {
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (runtime.account.readyRuntime == null &&
        DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    _check(runtime.account.state.phase == AccountPhase.ready);
    _check(runtime.account.readyRuntime != null && profileCalls > 0);
  }

  Future<void> waitForAuthCalls(int count) async {
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (authCalls < count && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    _check(authCalls == count);
  }

  Future<void> waitForProfileCalls(int count) async {
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (profileCalls < count && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    _check(profileCalls == count);
  }

  Future<void> pending() async {
    final records = await journal.list(_owner);
    _check(records.length == 1 && records.single.isPending);
    _check(jsonEncode(records.single.request) == jsonEncode(_pending));
  }

  try {
    if (phase == 'runtime-close-restore') {
      // Use the actual Windows Credential Manager slot, then hold the SDK's
      // startup refresh while the caller begins closing its owned runtime.
      _check(await vault.readRefreshToken() == null);
      await vault.writeRefreshToken(_first);
      lateRefresh = Completer<http.Response>();
      final restoring = runtime.start();
      await waitForAuthCalls(1);
      _check(runtime.account.readyRuntime == null && profileCalls == 0);

      final closing = runtime.close();
      final closeDeadline = DateTime.now().add(const Duration(seconds: 5));
      while (runtime.persistence.phase.name != 'closed' &&
          DateTime.now().isBefore(closeDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      _check(runtime.persistence.phase.name == 'closed');
      secret = _second;
      lateRefresh.complete(authResponse());

      var restoreFailed = false;
      try {
        await restoring;
      } on ReviewTransportFailure {
        restoreFailed = true;
      }
      await closing;
      _check(restoreFailed && profileCalls == 0);
      _check(runtime.account.readyRuntime == null);
      _check(await vault.readRefreshToken() == null);
      _check(logoutCalls >= 1);
      await pending();
    } else if (phase == 'runtime-restore-profile-held') {
      // This process must restore the secret written by the preceding process.
      _check(await vault.readRefreshToken() == _first);
      heldProfile = Completer<http.Response>();
      final restoring = runtime.start();
      await waitForAuthCalls(1);
      await waitForProfileCalls(1);
      await restoring.timeout(const Duration(seconds: 5));

      final refreshRequest = requests
          .where(
            (request) =>
                request.url.path == '/auth/v1/token' &&
                request.url.queryParameters['grant_type'] == 'refresh_token',
          )
          .single;
      _check(jsonDecode(refreshRequest.body)['refresh_token'] == _first);
      _check(await vault.readRefreshToken() == _second);
      _check(profileOwners.length == 1 && profileOwners.single == _owner);
      _check(runtime.account.readyRuntime == null);
      _check(runtime.account.state.phase != AccountPhase.ready);
      _check(!profileResponseReleased);

      heldProfile.complete(profileResponse());
      await ready();
      _check(profileResponseReleased);
      _check(runtime.account.readyRuntime != null);
      await pending();
    } else if (phase == 'runtime-late-refresh') {
      _check(await vault.readRefreshToken() == null);
      await vault.writeRefreshToken(_first);
      lateRefresh = Completer<http.Response>();

      final restoring = runtime.start();
      await waitForAuthCalls(1);
      _check(runtime.account.readyRuntime == null && profileCalls == 0);

      // Revoke the account before the held A refresh response is released.
      await runtime.account.signOut();
      _check(await vault.readRefreshToken() == null);
      lateRefresh.complete(authResponse());

      var restoreFailed = false;
      try {
        await restoring;
      } on ReviewTransportFailure {
        restoreFailed = true;
      }
      _check(restoreFailed);
      _check(await vault.readRefreshToken() == null);
      _check(runtime.account.readyRuntime == null && profileCalls == 0);

      // A's captured response is now settled. A fresh B login owns the next
      // generation and must be the only identity allowed through the barrier.
      lateRefresh = null;
      userId = _ownerB;
      sessionId = _sessionB;
      secret = _third;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await ready();
      _check(authCalls == 2 && profileCalls == 1);
      _check(profileOwners.length == 1 && profileOwners.single == _ownerB);
      _check(await vault.readRefreshToken() == _third);
      final profileRequest = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .single;
      _check(
        profileRequest.headers['authorization'] == 'Bearer ${accessToken()}',
      );
      _check((await journal.list(_ownerB)).isEmpty);
      await runtime.account.signOut();
      _check(runtime.account.readyRuntime == null);
      _check(await vault.readRefreshToken() == null);
      _check(logoutCalls >= 1);
      await pending();
    } else if (phase == 'runtime-late-profile') {
      // This phase uses the real Windows Credential Manager and native journal.
      _check(await vault.readRefreshToken() == null);
      await runtime.start();
      heldProfile = Completer<http.Response>();

      // A's Auth succeeds and its rotated secret is committed before its
      // own-profile request, which remains unresolved while the account changes.
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForProfileCalls(1);
      _check(
        runtime.account.state.phase == AccountPhase.loadingProfile &&
            runtime.account.readyRuntime == null &&
            profileOwners.length == 1 &&
            profileOwners.single == _owner &&
            capturedLateProfile != null &&
            !profileResponseReleased &&
            await vault.readRefreshToken() == _first,
      );
      await journal.stage(_owner, _pending);
      final aProfileRequests = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .toList();
      _check(aProfileRequests.length == 1);
      final aAuthorization = aProfileRequests.single.headers['authorization'];
      _check(aAuthorization == 'Bearer ${accessToken()}');

      // Logout must revoke A and clear its OS slot even though A's profile
      // response is still held by the HTTP fixture.
      await runtime.account.signOut();
      _check(
        runtime.account.state.phase == AccountPhase.signedOut &&
            runtime.account.readyRuntime == null &&
            await vault.readRefreshToken() == null &&
            profileCalls == 1 &&
            !profileResponseReleased,
      );

      // B becomes the only current generation. Its real OS write is checked by
      // the profile handler before ensure_profile is allowed to return.
      userId = _ownerB;
      sessionId = _sessionB;
      secret = _second;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await ready();
      final bRuntime = runtime.account.readyRuntime;
      final bProfileRequests = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .toList();
      _check(
        authCalls == 2 &&
            profileCalls == 2 &&
            profileOwners.length == 2 &&
            profileOwners.first == _owner &&
            profileOwners.last == _ownerB &&
            bProfileRequests.length == 2 &&
            bProfileRequests.last.headers['authorization'] ==
                'Bearer ${accessToken()}' &&
            bProfileRequests.first.headers['authorization'] == aAuthorization &&
            runtime.account.state.profile?.id == _ownerB &&
            runtime.account.readySession?.userId == _ownerB &&
            await vault.readRefreshToken() == _second &&
            (await journal.list(_ownerB)).isEmpty,
      );

      // Return the previously captured A response after B is fully ready.
      final lateA = capturedLateProfile;
      _check(lateA != null);
      heldProfile.complete(lateA);
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      _check(
        profileResponseReleased &&
            runtime.account.state.phase == AccountPhase.ready &&
            runtime.account.state.profile?.id == _ownerB &&
            identical(runtime.account.readyRuntime, bRuntime) &&
            runtime.account.readySession?.userId == _ownerB &&
            runtime.persistence.currentSession?.userId == _ownerB &&
            await vault.readRefreshToken() == _second,
      );
      await runtime.account.signOut();
      _check(
        runtime.account.state.phase == AccountPhase.signedOut &&
            runtime.account.readyRuntime == null &&
            await vault.readRefreshToken() == null &&
            logoutCalls >= 2,
      );
      await pending();
    } else if (phase == 'runtime-native-same-owner-profile-generation') {
      // A1 and A2 are the same verified user but distinct Auth session_id
      // generations. The first profile response stays held across logout/A2.
      _check(await vault.readRefreshToken() == null);
      await runtime.start();
      heldProfile = Completer<http.Response>();
      displayName = 'TEST_ONLY_STALE_A1_PROFILE';
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForProfileCalls(1);
      _check(
        runtime.account.state.phase == AccountPhase.loadingProfile &&
            runtime.account.readyRuntime == null &&
            profileOwners.length == 1 &&
            profileOwners.single == _owner &&
            capturedLateProfile != null &&
            !profileResponseReleased &&
            await vault.readRefreshToken() == _first,
      );
      final staleProfile =
          jsonDecode(capturedLateProfile!.body) as Map<String, Object?>;
      _check(
        staleProfile['id'] == _owner &&
            staleProfile['display_name'] == 'TEST_ONLY_STALE_A1_PROFILE',
      );
      await journal.stage(_owner, _pending);
      final a1ProfileRequests = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .toList();
      _check(a1ProfileRequests.length == 1);
      final a1Authorization = a1ProfileRequests.single.headers['authorization'];
      _check(a1Authorization == 'Bearer ${accessToken()}');

      // The A1 profile request remains unresolved while logout revokes A1 and
      // clears its Credential Manager value.
      await runtime.account.signOut();
      _check(
        runtime.account.state.phase == AccountPhase.signedOut &&
            runtime.account.readyRuntime == null &&
            await vault.readRefreshToken() == null &&
            profileCalls == 1 &&
            !profileResponseReleased,
      );

      // Reauthenticate the same owner under a new Auth session_id. A2's rotated
      // refresh value must be committed before its own-profile request.
      sessionId = _sessionB;
      secret = _second;
      displayName = '学習者';
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await ready();
      final a2Session = runtime.persistence.currentSession;
      final a2ReadySession = runtime.account.readySession;
      final a2Runtime = runtime.account.readyRuntime;
      final a2ProfileRequests = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .toList();
      _check(
        authCalls == 2 &&
            profileCalls == 2 &&
            profileOwners.length == 2 &&
            profileOwners.every((owner) => owner == _owner) &&
            a2ProfileRequests.length == 2 &&
            a2ProfileRequests.first.headers['authorization'] == a1Authorization &&
            a2ProfileRequests.last.headers['authorization'] ==
                'Bearer ${accessToken()}' &&
            runtime.account.state.profile?.id == _owner &&
            runtime.account.state.profile?.displayName == '学習者' &&
            a2Session?.userId == _owner &&
            a2ReadySession?.userId == _owner &&
            a2Runtime != null &&
            await vault.readRefreshToken() == _second,
      );
      await pending();

      // A1's delayed response has the same owner ID, so only the captured
      // session-generation guard can stop it replacing A2's accepted profile.
      heldProfile.complete(capturedLateProfile!);
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      _check(
        profileResponseReleased &&
            runtime.account.state.phase == AccountPhase.ready &&
            runtime.account.state.profile?.id == _owner &&
            runtime.account.state.profile?.displayName == '学習者' &&
            identical(runtime.persistence.currentSession, a2Session) &&
            identical(runtime.account.readySession, a2ReadySession) &&
            identical(runtime.account.readyRuntime, a2Runtime) &&
            await vault.readRefreshToken() == _second &&
            profileCalls == 2,
      );
      await runtime.account.signOut();
      _check(
        runtime.account.state.phase == AccountPhase.signedOut &&
            runtime.account.readyRuntime == null &&
            await vault.readRefreshToken() == null &&
            logoutCalls >= 2,
      );
      await pending();
    } else if (phase == 'runtime-native-read-failure') {
      _check(await vault.readRefreshToken() == null);
      await vault.writeRefreshToken(_first);
      await _injectNativeVaultFault(
        vault.target,
        operation: 'read',
        fault: 'fail_before',
      );
      var failed = false;
      try {
        await runtime.start();
      } on ReviewTransportFailure catch (error) {
        // PersistentAccountAccess deliberately maps storage faults to its
        // fixed public UNAUTHORIZED boundary; raw vault errors stay internal.
        failed = error.code == ReviewErrorCode.unauthorized;
      }
      _check(
        failed &&
            runtime.persistence.phase == SessionPersistencePhase.failed &&
            runtime.account.readyRuntime == null &&
            authCalls == 0 &&
            profileCalls == 0,
      );
      _check(await vault.readRefreshToken() == _first);

      userId = _ownerB;
      sessionId = _sessionB;
      secret = _third;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await ready();
      _check(authCalls == 1 && profileCalls == 1);
      _check(
        requests
            .where(
              (request) =>
                  request.url.path == '/auth/v1/token' &&
                  request.url.queryParameters['grant_type'] == 'refresh_token',
            )
            .isEmpty,
      );
      _check(profileOwners.length == 1 && profileOwners.single == _ownerB);
      _check(await vault.readRefreshToken() == _third);
      final profileRequest = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .single;
      _check(
        profileRequest.headers['authorization'] == 'Bearer ${accessToken()}',
      );
      _check((await journal.list(_ownerB)).isEmpty);
      await runtime.account.signOut();
      _check(runtime.account.readyRuntime == null);
      _check(await vault.readRefreshToken() == null);
      _check(logoutCalls >= 1);
      await pending();
    } else if (phase == 'runtime-native-rotation-write-failure-late-profile') {
      _check(await vault.readRefreshToken() == null);
      await runtime.start();
      heldProfile = Completer<http.Response>();

      // A's first own-profile response remains held while the same Auth
      // session rotates its refresh token and the native write fails.
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await waitForProfileCalls(1);
      _check(
        runtime.account.state.phase == AccountPhase.loadingProfile &&
            runtime.account.readyRuntime == null &&
            profileOwners.length == 1 &&
            profileOwners.single == _owner &&
            capturedLateProfile != null &&
            !profileResponseReleased &&
            await vault.readRefreshToken() == _first,
      );
      await journal.stage(_owner, _pending);
      final aProfileRequests = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .toList();
      _check(aProfileRequests.length == 1);
      final aAuthorization = aProfileRequests.single.headers['authorization'];
      _check(aAuthorization == 'Bearer ${accessToken()}');

      // CredWriteW commits the rotated value but reports failure; the first
      // compensating CredDeleteW also fails before deleting the exact slot.
      await _injectNativeVaultFault(
        vault.target,
        operation: 'write',
        fault: 'commit_then_fail',
      );
      await _injectNativeVaultFault(
        vault.target,
        operation: 'clear',
        fault: 'fail_before',
      );
      secret = _second;
      var refreshFailed = false;
      try {
        await runtime.refresh().timeout(const Duration(seconds: 5));
      } on ReviewTransportFailure catch (error) {
        refreshFailed = error.code == ReviewErrorCode.unauthorized;
      }
      _check(
        refreshFailed &&
            runtime.persistence.phase == SessionPersistencePhase.failed &&
            runtime.account.readyRuntime == null &&
            authCalls == 2 &&
            profileCalls == 1 &&
            profileOwners.single == _owner &&
            !profileResponseReleased &&
            await vault.readRefreshToken() == _second,
      );

      // The replacement password grant must wait for the retryable native
      // cleanup. Its rotated secret is then visible before B's profile call.
      userId = _ownerB;
      sessionId = _sessionB;
      secret = _third;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await ready();
      final bRuntime = runtime.account.readyRuntime;
      final bProfileRequests = requests
          .where((request) => request.url.path == '/rest/v1/rpc/ensure_profile')
          .toList();
      _check(
        authCalls == 3 &&
            profileCalls == 2 &&
            profileOwners.length == 2 &&
            profileOwners.first == _owner &&
            profileOwners.last == _ownerB &&
            bProfileRequests.length == 2 &&
            bProfileRequests.first.headers['authorization'] == aAuthorization &&
            bProfileRequests.last.headers['authorization'] ==
                'Bearer ${accessToken()}' &&
            runtime.account.state.profile?.id == _ownerB &&
            runtime.account.readySession?.userId == _ownerB &&
            await vault.readRefreshToken() == _third &&
            (await journal.list(_ownerB)).isEmpty,
      );

      // A's captured response arrives only after B is fully ready. It must not
      // change B's profile generation, session, runtime, or native token.
      final lateAProfile = capturedLateProfile;
      if (lateAProfile == null) {
        throw const FormatException('Late A profile was not captured');
      }
      heldProfile.complete(lateAProfile);
      final responseDeadline = DateTime.now().add(const Duration(seconds: 5));
      while (!profileResponseReleased &&
          DateTime.now().isBefore(responseDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      _check(
        profileResponseReleased &&
            runtime.account.state.phase == AccountPhase.ready &&
            runtime.account.state.profile?.id == _ownerB &&
            identical(runtime.account.readyRuntime, bRuntime) &&
            runtime.account.readySession?.userId == _ownerB &&
            runtime.persistence.currentSession?.userId == _ownerB &&
            await vault.readRefreshToken() == _third &&
            profileCalls == 2,
      );
      await runtime.account.signOut();
      _check(
        runtime.account.state.phase == AccountPhase.signedOut &&
            runtime.account.readyRuntime == null &&
            await vault.readRefreshToken() == null &&
            logoutCalls >= 2,
      );
      await pending();
    } else if (phase == 'runtime-native-rotation-write-failure') {
      _check(await vault.readRefreshToken() == null);
      // Explicit startup acquires the owned vault before offering password Auth.
      await runtime.start();
      _check(
        runtime.persistence.phase == SessionPersistencePhase.idle &&
            runtime.persistence.hasVaultOwner &&
            runtime.account.readyRuntime == null &&
            authCalls == 0 &&
            profileCalls == 0 &&
            await vault.readRefreshToken() == null,
      );
      // Establish a healthy A session first. The one-shot native faults must
      // be consumed by the subsequent refresh rotation, not the password grant.
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await ready();
      _check(
        authCalls == 1 &&
            profileCalls == 1 &&
            profileOwners.single == _owner &&
            await vault.readRefreshToken() == _first,
      );
      // Keep an A-owned pending event across the failed rotation and account switch.
      await journal.stage(_owner, _pending);
      await _injectNativeVaultFault(
        vault.target,
        operation: 'write',
        fault: 'commit_then_fail',
      );
      await _injectNativeVaultFault(
        vault.target,
        operation: 'clear',
        fault: 'fail_before',
      );

      // A's real CredWriteW commits the rotated token but reports unavailable;
      // the first compensating CredDeleteW also fails before the OS call.
      secret = _second;
      var refreshFailed = false;
      try {
        await runtime.refresh();
      } on ReviewTransportFailure catch (error) {
        refreshFailed = error.code == ReviewErrorCode.unauthorized;
      }
      _check(
        refreshFailed &&
            runtime.persistence.phase == SessionPersistencePhase.failed &&
            runtime.account.readyRuntime == null &&
            authCalls == 2 &&
            profileCalls == 1 &&
            profileOwners.single == _owner,
      );
      _check(await vault.readRefreshToken() == _second);

      // B is accepted only after explicit cleanup retries A sign-out + clear.
      userId = _ownerB;
      sessionId = _sessionB;
      secret = _third;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await ready();
      _check(
        authCalls == 3 &&
            profileCalls == 2 &&
            profileOwners.length == 2 &&
            profileOwners.first == _owner &&
            profileOwners.last == _ownerB,
      );
      _check(await vault.readRefreshToken() == _third);
      _check((await journal.list(_ownerB)).isEmpty);
      await runtime.account.signOut();
      _check(
        runtime.account.readyRuntime == null &&
            await vault.readRefreshToken() == null &&
            logoutCalls >= 2,
      );
      await pending();
    } else if (phase == 'runtime-native-rotation-write-fail-before') {
      _check(await vault.readRefreshToken() == null);
      // Explicit startup acquires the owned vault before offering password Auth.
      await runtime.start();
      _check(
        runtime.persistence.phase == SessionPersistencePhase.idle &&
            runtime.persistence.hasVaultOwner &&
            runtime.account.readyRuntime == null &&
            authCalls == 0 &&
            profileCalls == 0 &&
            await vault.readRefreshToken() == null,
      );
      // Establish A, then fail the next native write before CredWriteW executes.
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await ready();
      _check(
        authCalls == 1 &&
            profileCalls == 1 &&
            profileOwners.single == _owner &&
            await vault.readRefreshToken() == _first,
      );
      await journal.stage(_owner, _pending);
      await _injectNativeVaultFault(
        vault.target,
        operation: 'write',
        fault: 'fail_before',
      );

      // The rotated SDK response is real to the pinned SDK, but the native
      // helper rejects before CredWriteW. Persistence must revoke A and clear
      // the old exact-project slot before any replacement account is accepted.
      secret = _second;
      var refreshFailed = false;
      try {
        await runtime.refresh();
      } on ReviewTransportFailure catch (error) {
        refreshFailed = error.code == ReviewErrorCode.unauthorized;
      }
      _check(
        refreshFailed &&
            runtime.persistence.phase == SessionPersistencePhase.failed &&
            runtime.account.readyRuntime == null &&
            authCalls == 2 &&
            profileCalls == 1 &&
            profileOwners.length == 1 &&
            profileOwners.single == _owner,
      );
      // fail_before preserves A's old OS value until the compensating clear;
      // successful clear must leave neither A's old nor the rejected rotation.
      _check(await vault.readRefreshToken() == null);

      userId = _ownerB;
      sessionId = _sessionB;
      secret = _third;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await ready();
      _check(
        authCalls == 3 &&
            profileCalls == 2 &&
            profileOwners.length == 2 &&
            profileOwners.first == _owner &&
            profileOwners.last == _ownerB &&
            logoutCalls >= 1,
      );
      _check(await vault.readRefreshToken() == _third);
      _check((await journal.list(_ownerB)).isEmpty);
      await runtime.account.signOut();
      _check(
        runtime.account.readyRuntime == null &&
            await vault.readRefreshToken() == null &&
            logoutCalls >= 2,
      );
      await pending();
    } else if (nativeLogoutClearFailure) {
      _check(await vault.readRefreshToken() == null);
      await runtime.start();
      _check(
        runtime.persistence.phase == SessionPersistencePhase.idle &&
            runtime.persistence.hasVaultOwner &&
            runtime.account.readyRuntime == null &&
            authCalls == 0 &&
            profileCalls == 0,
      );
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await ready();
      _check(
        authCalls == 1 &&
            profileCalls == 1 &&
            profileOwners.single == _owner &&
            await vault.readRefreshToken() == _first,
      );
      await journal.stage(_owner, _pending);
      await _injectNativeVaultFault(
        vault.target,
        operation: 'clear',
        fault: phase == 'runtime-native-logout-clear-commit-failure'
            ? 'commit_then_fail'
            : 'fail_before',
      );
      final expectedAfterFailedClear =
          phase == 'runtime-native-logout-clear-commit-failure' ? null : _first;

      // A native clear may fail before deletion or report failure after the OS
      // has committed it. Both outcomes must keep A fenced until explicit retry.
      await runtime.account.signOut();
      _check(
        runtime.account.state.phase == AccountPhase.signOutError &&
            runtime.persistence.phase == SessionPersistencePhase.failed &&
            runtime.account.readyRuntime == null &&
            authCalls == 1 &&
            profileCalls == 1 &&
            profileOwners.single == _owner &&
            await vault.readRefreshToken() == expectedAfterFailedClear,
      );

      // A replacement B attempt cannot cross the failed-clear logout fence.
      userId = _ownerB;
      sessionId = _sessionB;
      secret = _third;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      _check(
        authCalls == 1 &&
            profileCalls == 1 &&
            runtime.account.readyRuntime == null &&
            await vault.readRefreshToken() == expectedAfterFailedClear,
      );

      // Only an explicit logout retry can clear A before B password Auth.
      await runtime.account.signOut();
      _check(
        runtime.account.state.phase == AccountPhase.signedOut &&
            runtime.persistence.phase == SessionPersistencePhase.idle &&
            runtime.account.readyRuntime == null &&
            await vault.readRefreshToken() == null,
      );
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await ready();
      _check(
        authCalls == 2 &&
            profileCalls == 2 &&
            profileOwners.length == 2 &&
            profileOwners.first == _owner &&
            profileOwners.last == _ownerB &&
            await vault.readRefreshToken() == _third,
      );
      _check((await journal.list(_ownerB)).isEmpty);
      await runtime.account.signOut();
      _check(
        runtime.account.readyRuntime == null &&
            await vault.readRefreshToken() == null,
      );
      await pending();
    } else if (phase == 'runtime-rejected') {
      _check(await vault.readRefreshToken() == null);
      await vault.writeRefreshToken(_rejected);
      var failed = false;
      try {
        await runtime.start();
      } on ReviewTransportFailure {
        failed = true;
      }
      _check(
        failed && runtime.account.readyRuntime == null && profileCalls == 0,
      );
      secret = _first;
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await ready();
      await runtime.account.signOut();
      _check(await vault.readRefreshToken() == null);
      _check(authCalls == 2);
      await pending();
    } else {
      await runtime.start();
      if (phase == 'runtime-login') {
        _check(authCalls == 0 && profileCalls == 0);
        _check(runtime.account.readyRuntime == null);
        await runtime.account.signIn(
          'fixture@example.invalid',
          'TEST_ONLY_PASSWORD',
        );
        await ready();
        _check(authCalls == 1);
        await journal.stage(_owner, _pending);
      } else if (phase == 'runtime-signedout') {
        _check(authCalls == 0 && profileCalls == 0);
        _check(runtime.account.readyRuntime == null);
        _check(await vault.readRefreshToken() == null);
      } else {
        await ready();
        _check(authCalls == 1 && await vault.readRefreshToken() == secret);
        if (phase == 'runtime-logout') {
          final signingOut = runtime.account.signOut();
          _check(runtime.account.readyRuntime == null);
          await signingOut;
          _check(logoutCalls == 1 && await vault.readRefreshToken() == null);
        }
      }
      await pending();
    }
  } finally {
    // A failed assertion must not strand a held HTTP response while close drains.
    if (heldProfile != null && !heldProfile.isCompleted) {
      heldProfile.complete(
        phase == 'runtime-native-rotation-write-failure-late-profile'
            ? capturedLateProfile ?? profileResponse()
            : profileResponse(),
      );
    }
    if (lateRefresh != null && !lateRefresh.isCompleted) {
      if (phase == 'runtime-close-restore') secret = _second;
      lateRefresh.complete(authResponse());
    }
    await runtime.close();
    await journal.close();
    network.close();
  }
  // Closing the runtime preserves a fully saved session for the next process.
  if (phase == 'runtime-login' ||
      phase == 'runtime-restore-profile-held' ||
      phase == 'runtime-restore') {
    _check(await vault.readRefreshToken() == secret);
  }
}
