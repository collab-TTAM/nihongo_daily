// Manual-only hosted staging fixture. Never used by the learner entrypoint.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/persistent_account_access.dart';
import 'package:nihongo_daily/features/auth/data/windows_session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/supabase_review_binding.dart';

const _phases = {
  'login-a',
  'restore-a',
  'logout-a',
  'prepare-revoked-a',
  'restore-revoked-a',
  'login-b',
  'cleanup',
};

final class _HostedSettings {
  const _HostedSettings({
    required this.projectUrl,
    required this.publishableKey,
    required this.emailA,
    required this.passwordA,
    required this.emailB,
    required this.passwordB,
  });

  final String projectUrl;
  final String publishableKey;
  final String emailA;
  final String passwordA;
  final String emailB;
  final String passwordB;
}

final class _HostedProbeHttpClient extends http.BaseClient {
  _HostedProbeHttpClient(this._inner);

  final http.Client _inner;
  final events = <String>[];
  Future<void> Function()? beforePasswordAuth;
  Future<void> Function()? beforeProfile;

  String? _rotatedRefreshToken;

  String? get rotatedRefreshToken => _rotatedRefreshToken;

  String? _refreshTokenFromRequest(http.BaseRequest request) {
    if (request is! http.Request) return null;
    try {
      final payload = jsonDecode(request.body);
      if (payload is Map<String, dynamic>) {
        final token = payload['refresh_token'];
        if (token is String && token.isNotEmpty) return token;
      }
    } on Object {
      // Keep the request secret private; restore-a fails closed if it cannot
      // prove the exact refresh rotation.
    }
    return null;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isTokenRequest = request.url.path == '/auth/v1/token';
    final grant = isTokenRequest
        ? request.url.queryParameters['grant_type'] ?? 'unknown'
        : null;
    final submittedRefreshToken = grant == 'refresh_token'
        ? _refreshTokenFromRequest(request)
        : null;

    if (isTokenRequest) {
      events.add('auth.$grant');
      if (grant == 'password') await beforePasswordAuth?.call();
    } else if (request.url.path == '/auth/v1/logout') {
      events.add('auth.logout');
    } else if (request.url.path == '/rest/v1/rpc/ensure_profile') {
      await beforeProfile?.call();
      events.add('profile.ensure');
    }

    final response = await _inner.send(request);
    if (grant == 'refresh_token') {
      // Read only this bounded Auth response so the fixture can compare the
      // returned rotation with the OS vault before the profile request. The
      // raw response is reconstructed for the SDK; neither token is logged.
      final bytes = await response.stream.toBytes();
      if (response.statusCode == 200 &&
          submittedRefreshToken != null &&
          bytes.length <= 256 * 1024) {
        try {
          final payload = jsonDecode(utf8.decode(bytes));
          final rotated = payload is Map<String, dynamic>
              ? payload['refresh_token']
              : null;
          if (rotated is String &&
              rotated.isNotEmpty &&
              rotated != submittedRefreshToken) {
            _rotatedRefreshToken = rotated;
            events.add('auth.refresh.response');
          }
        } on Object {
          // The startup profile barrier below fails if rotation is unverified.
        }
      }
      return http.StreamedResponse(
        Stream<List<int>>.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    }
    return response;
  }

  @override
  void close() => _inner.close();
}

String _required(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty || value.length > 4096) {
    throw const FormatException('Hosted staging configuration unavailable');
  }
  return value;
}

_HostedSettings _settings() {
  final projectUrl = SupabaseReviewBinding.validateProjectUrl(
    _required('ND_STAGING_SUPABASE_URL'),
  );
  final uri = Uri.parse(projectUrl);
  if (uri.scheme != 'https' ||
      uri.port != 443 ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !const {'', '/'}.contains(uri.path) ||
      !RegExp(r'^[a-z0-9-]+\.supabase\.co$').hasMatch(uri.host)) {
    throw const FormatException('Hosted staging project unavailable');
  }
  final publishableKey = SupabaseReviewBinding.validatePublicKey(
    _required('ND_STAGING_SUPABASE_PUBLISHABLE_KEY'),
  );
  final emailA = _required('ND_STAGING_USER_A_EMAIL').trim();
  final passwordA = _required('ND_STAGING_USER_A_PASSWORD');
  final emailB = _required('ND_STAGING_USER_B_EMAIL').trim();
  final passwordB = _required('ND_STAGING_USER_B_PASSWORD');
  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (emailA.length > 254 ||
      emailB.length > 254 ||
      !emailPattern.hasMatch(emailA) ||
      !emailPattern.hasMatch(emailB) ||
      emailA.toLowerCase() == emailB.toLowerCase() ||
      passwordA.length > 4096 ||
      passwordB.length > 4096) {
    throw const FormatException('Hosted staging accounts unavailable');
  }
  return _HostedSettings(
    projectUrl: projectUrl,
    publishableKey: publishableKey,
    emailA: emailA,
    passwordA: passwordA,
    emailB: emailB,
    passwordB: passwordB,
  );
}

void _check(bool value) {
  if (!value) {
    throw const FormatException('Hosted Windows runtime check failed');
  }
}

/// Auth-only fixture store. No review event is staged or dispatched by this
/// probe.
final class _EmptyReviewStore implements DurableReviewStore {
  @override
  Future<List<StoredReview>> list(String userId) =>
      Future<List<StoredReview>>.value(const <StoredReview>[]);

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

void _requireReady(PersistentSupabaseRuntime runtime) {
  final session = runtime.persistence.currentSession;
  final profile = runtime.account.state.profile;
  _check(runtime.persistence.phase == SessionPersistencePhase.ready);
  _check(runtime.account.state.phase == AccountPhase.ready);
  _check(runtime.account.readyRuntime != null);
  _check(session != null && profile != null && profile.id == session.userId);
}

Future<void> _signInAndWait(
  PersistentSupabaseRuntime runtime,
  String email,
  String password,
) async {
  await runtime.account.signIn(email, password);
  await runtime.account.waitForCurrentProfile();
  _requireReady(runtime);
}

Future<void> _verifyWindowsHostedRuntimePhase(
  String phase,
  _HostedSettings settings,
) async {
  final vault = createWindowsSessionCredentialVault(settings.projectUrl);
  if (phase == 'cleanup') {
    await vault.acquireOwner();
    var cleared = false;
    try {
      await vault.clear();
      _check(await vault.readRefreshToken() == null);
      cleared = true;
    } finally {
      // On failure, process exit abandons the native mutex; do not release a
      // project owner while a failed credential clear may still be unresolved.
      if (cleared) await vault.releaseOwner();
    }
    return;
  }

  final httpClient = _HostedProbeHttpClient(http.Client());
  if (phase == 'restore-revoked-a') {
    httpClient.beforePasswordAuth = () async {
      _check(await vault.readRefreshToken() == null);
      httpClient.events.add('vault.empty-before-password');
    };
    httpClient.beforeProfile = () async {
      final persisted = await vault.readRefreshToken();
      _check(persisted != null && persisted.isNotEmpty);
      httpClient.events.add('vault.persisted-before-profile');
    };
  }
  final runtime = PersistentSupabaseRuntime(
    projectUrl: settings.projectUrl,
    publishableKey: settings.publishableKey,
    vault: vault,
    store: _EmptyReviewStore(),
    httpClient: httpClient,
  );
  var closed = false;
  try {
    switch (phase) {
      case 'login-a':
        await runtime.start();
        _check(runtime.persistence.phase == SessionPersistencePhase.idle);
        _check(await vault.readRefreshToken() == null);
        await _signInAndWait(runtime, settings.emailA, settings.passwordA);
        final saved = await vault.readRefreshToken();
        _check(saved != null && saved.isNotEmpty);
        await runtime.close();
        closed = true;
        _check(await vault.readRefreshToken() == saved);
        break;
      case 'restore-a':
        // This is a fresh Windows process. GoTrue must rotate the saved secret,
        // and the exact returned value must be in Credential Manager before the
        // first own-profile request is sent.
        httpClient.beforeProfile = () async {
          final rotated = httpClient.rotatedRefreshToken;
          final persisted = await vault.readRefreshToken();
          _check(
            rotated != null && rotated.isNotEmpty && persisted == rotated,
          );
          httpClient.events.add('vault.rotated-before-profile');
        };
        await runtime.start();
        await runtime.account.waitForCurrentProfile();
        _requireReady(runtime);
        final events = httpClient.events;
        final refreshIndex = events.indexOf('auth.refresh');
        final responseIndex = events.indexOf('auth.refresh.response');
        final persistedIndex = events.indexOf('vault.rotated-before-profile');
        final profileIndex = events.indexOf('profile.ensure');
        _check(
          refreshIndex >= 0 &&
              responseIndex > refreshIndex &&
              persistedIndex > responseIndex &&
              profileIndex > persistedIndex &&
              events.where((event) => event == 'profile.ensure').length == 1,
        );
        final saved = await vault.readRefreshToken();
        _check(
          saved != null &&
              saved.isNotEmpty &&
              saved == httpClient.rotatedRefreshToken,
        );
        await runtime.close();
        closed = true;
        _check(await vault.readRefreshToken() == saved);
        break;
      case 'logout-a':
        await runtime.start();
        await runtime.account.waitForCurrentProfile();
        _requireReady(runtime);
        await runtime.account.signOut();
        _check(runtime.account.state.phase == AccountPhase.signedOut);
        _check(runtime.persistence.currentSession == null);
        _check(await vault.readRefreshToken() == null);
        await runtime.close();
        closed = true;
        break;
      case 'prepare-revoked-a':
        await runtime.start();
        _check(runtime.persistence.phase == SessionPersistencePhase.idle);
        _check(await vault.readRefreshToken() == null);
        await _signInAndWait(runtime, settings.emailA, settings.passwordA);
        final revoked = await vault.readRefreshToken();
        if (revoked == null || revoked.isEmpty) {
          throw const FormatException('Hosted refresh token unavailable');
        }
        await runtime.account.signOut();
        _check(runtime.account.state.phase == AccountPhase.signedOut);
        _check(runtime.persistence.currentSession == null);
        _check(await vault.readRefreshToken() == null);
        // TEST ONLY: local logout revokes this token; seed that same revoked
        // value back into the OS slot so the next process tests real restore.
        await vault.writeRefreshToken(revoked);
        _check(await vault.readRefreshToken() == revoked);
        await runtime.close();
        closed = true;
        _check(await vault.readRefreshToken() == revoked);
        break;
      case 'restore-revoked-a':
        var restoreRejected = false;
        try {
          await runtime.start();
        } on ReviewTransportFailure {
          restoreRejected = true;
        }
        _check(restoreRejected);
        _check(runtime.persistence.phase == SessionPersistencePhase.failed);
        _check(runtime.account.state.phase == AccountPhase.signedOut);
        _check(runtime.account.readyRuntime == null);
        final rejected = await vault.readRefreshToken();
        _check(rejected != null && rejected.isNotEmpty);
        _check(
          httpClient.events.where((event) => event == 'profile.ensure').isEmpty,
        );

        // Explicit login must clear the server-revoked value before password
        // Auth, then persist the replacement rotation before own-profile.
        await _signInAndWait(runtime, settings.emailA, settings.passwordA);
        final events = httpClient.events;
        final refreshIndex = events.indexOf('auth.refresh');
        final passwordIndex = events.indexOf('auth.password');
        final emptyIndex = events.indexOf('vault.empty-before-password');
        final persistedIndex = events.indexOf('vault.persisted-before-profile');
        final profileIndex = events.indexOf('profile.ensure');
        _check(
          refreshIndex >= 0 &&
              passwordIndex > refreshIndex &&
              emptyIndex > passwordIndex &&
              persistedIndex > passwordIndex &&
              profileIndex > persistedIndex &&
              events.where((event) => event == 'profile.ensure').length == 1,
        );
        await runtime.account.signOut();
        _check(runtime.account.state.phase == AccountPhase.signedOut);
        _check(runtime.persistence.currentSession == null);
        _check(await vault.readRefreshToken() == null);
        await runtime.close();
        closed = true;
        break;
      case 'login-b':
        await runtime.start();
        _check(await vault.readRefreshToken() == null);
        await _signInAndWait(runtime, settings.emailB, settings.passwordB);
        final saved = await vault.readRefreshToken();
        _check(saved != null && saved.isNotEmpty);
        await runtime.account.signOut();
        _check(runtime.account.state.phase == AccountPhase.signedOut);
        _check(await vault.readRefreshToken() == null);
        await runtime.close();
        closed = true;
        break;
      default:
        throw const FormatException('Hosted Windows runtime phase unavailable');
    }
  } finally {
    try {
      if (!closed) await runtime.close();
    } finally {
      httpClient.close();
    }
  }
}

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  var passed = false;
  try {
    if (!Platform.isWindows ||
        arguments.length != 1 ||
        !_phases.contains(arguments.single)) {
      throw const FormatException('Hosted Windows runtime phase unavailable');
    }
    final settings = _settings();
    await _verifyWindowsHostedRuntimePhase(arguments.single, settings);
    passed = true;
  } on Object {
    // Do not print exception text, emails, passwords, access tokens or refresh
    // tokens.
    stderr.writeln('Hosted Windows runtime verification failed');
  }
  await stdout.flush();
  await stderr.flush();
  exit(passed ? 0 : 1);
}
