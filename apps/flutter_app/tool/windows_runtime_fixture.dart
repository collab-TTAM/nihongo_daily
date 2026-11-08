// TEST ONLY pinned SDK/HTTP fixtures with real Windows vault and native journal.
// Never contacts a service, accepts live credentials or enters the normal app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/windows_session_credential_vault.dart';
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
  'runtime-close-restore',
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

Directory runtimeFixtureDirectory(String scope) {
  _check(RegExp(r'^bridge-[a-f0-9]{32}$').hasMatch(scope));
  return Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}nd-$scope',
  );
}

String _segment(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

Future<void> verifyWindowsRuntimePhase(String phase, String scope) async {
  _check(Platform.isWindows && runtimePhases.contains(phase));
  final directory = runtimeFixtureDirectory(scope);
  final origin = 'https://$scope.invalid';
  final vault = createWindowsSessionCredentialVault(origin);
  final now = DateTime.now().toUtc();
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
  var profileResponseReleased = false;
  final profileOwners = <String>[];

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
      'display_name': '学習者',
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
                phase == 'runtime-close-restore'
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
      }
      return authResponse();
    }
    if (request.url.path == '/rest/v1/rpc/ensure_profile') {
      profileCalls++;
      profileOwners.add(userId);
      // The real OS write must already be observable before profile dispatch.
      _check(await vault.readRefreshToken() == secret);
      if (phase == 'runtime-late-refresh' ||
          phase == 'runtime-restore-profile-held') {
        _check(request.headers['authorization'] == 'Bearer ${accessToken()}');
      }
      if (phase == 'runtime-restore-profile-held') {
        final wait = heldProfile;
        _check(wait != null);
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

      heldProfile!.complete(profileResponse());
      await waitForReady();
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
    if (heldProfile != null && !heldProfile!.isCompleted) {
      heldProfile!.complete(profileResponse());
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
