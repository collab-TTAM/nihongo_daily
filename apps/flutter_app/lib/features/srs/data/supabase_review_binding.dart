import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:supabase/supabase.dart';

import 'review_connection_registry.dart';
import 'review_repository.dart';

/// Concrete Supabase Auth/PostgREST bridge, explicitly constructed by the owner.
/// Does not initialize/deploy, provision profiles or persist credentials.
/// Credential methods require an explicitly configured client and caller.
/// The server verifies JWTs; decoded claims below are only fail-closed local hints.
final class SupabaseReviewBinding implements ReviewAuth, ReviewRpcTransport {
  static String validateProjectUrl(String value) => _projectUrl(value);
  static String validatePublicKey(String value) => _publicKey(value);

  SupabaseReviewBinding({
    required SupabaseClient client,
    required String projectUrl,
    required String publishableKey,
    http.Client? httpClient,
    DateTime Function()? now,
  }) : _client = client,
       _url = _projectUrl(projectUrl),
       _key = _publicKey(publishableKey),
       _http = httpClient,
       _now = now ?? DateTime.now,
       _registry = ReviewConnectionRegistry(now: now) {
    // Pinned SDK's finest Auth logs interpolate Session including tokens; its
    // PostgREST logs also include headers/raw errors. Never enable these sinks.
    hierarchicalLoggingEnabled = true;
    Logger('supabase').level = Level.OFF;
    Logger('supabase.auth').level = Level.OFF;
    Logger('supabase.postgrest').level = Level.OFF;
    if (_client.rest.url != '$_url/rest/v1' ||
        _client.auth.headers['apikey'] != _key) {
      throw ArgumentError('Supabase endpoint mismatch');
    }
    _accept(
      AuthState(AuthChangeEvent.initialSession, _client.auth.currentSession),
    );
    _subscription = _client.auth.onAuthStateChange.listen(
      _accept,
      onError: (Object _, StackTrace __) => _revoke(),
      onDone: dispose,
    );
  }

  final SupabaseClient _client;
  final String _url;
  final String _key;
  final http.Client? _http;
  final DateTime Function() _now;
  final ReviewConnectionRegistry _registry;
  StreamSubscription<AuthState>? _subscription;
  _SessionHint? _hint;
  bool _disposed = false;

  Stream<void> get sessionChanges => _registry.sessionChanges;

  @override
  ReviewSession? get currentSession {
    if (!_sameSdkLifecycle(_hint)) {
      _revoke();
    }
    return _registry.currentSession;
  }

  void _revoke() {
    _hint = null;
    _registry.end();
  }

  bool _sameSdkLifecycle(_SessionHint? captured) {
    if (_disposed || captured == null) {
      return false;
    }
    try {
      final current = _SessionHint.from(_client.auth.currentSession, _now());
      return captured.sameLifecycle(current);
    } on Object {
      return false;
    }
  }

  void _accept(AuthState state) {
    if (_disposed) {
      return;
    }
    try {
      if (state.event == AuthChangeEvent.signedOut || state.session == null) {
        _revoke();
        return;
      }
      final hint = _SessionHint.from(state.session, _now());
      // Ignore queued/replayed old events; consult current SDK state too.
      if (!_sameSdkLifecycle(hint)) {
        _revoke();
        return;
      }
      final preserve =
          _hint?.sameLifecycle(hint) == true &&
          _registry.currentSession != null;
      _hint = hint;
      Future<Object?> rpc(String function, Map<String, Object> params) =>
          _rpc(hint, function, params);
      if (preserve) {
        _registry.refresh(
          userId: hint.userId,
          expiresAt: hint.expiresAt,
          rpc: rpc,
        );
      } else {
        _registry.begin(
          userId: hint.userId,
          expiresAt: hint.expiresAt,
          rpc: rpc,
        );
      }
    } on Object {
      _revoke();
    }
  }

  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String function,
    required Map<String, Object> params,
  }) async {
    if (!identical(currentSession, capturedSession)) {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
    try {
      final result = await _registry.invoke(
        capturedSession: capturedSession,
        function: function,
        params: params,
      );
      if (!identical(currentSession, capturedSession)) {
        throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
      }
      return result;
    } on Object {
      if (!identical(currentSession, capturedSession)) {
        throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
      }
      rethrow;
    }
  }

  /// Explicit credential operation for #20. Return no SDK session/token object;
  /// the existing lifecycle stream is the sole application identity signal.
  Future<void> authenticateWithPassword(String email, String password) async {
    if (_disposed) {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
    if (email.trim().isEmpty ||
        email.length > 254 ||
        password.isEmpty ||
        password.length > 4096) {
      throw const ReviewTransportFailure(ReviewErrorCode.validationFailure);
    }
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      await Future<void>.delayed(
        Duration.zero,
      ); // Let queued SDK Auth events bind.
      if (_disposed) {
        throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
      }
    } on Object {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
  }

  Future<void> signOutLocally() async {
    if (_disposed) {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } on Object {
      throw const ReviewTransportFailure(ReviewErrorCode.internalError);
    }
  }

  Future<Object?> _rpc(
    _SessionHint hint,
    String function,
    Map<String, Object> params,
  ) async {
    void guard() {
      if (!_sameSdkLifecycle(hint) ||
          _registry.currentSession == null ||
          !_now().toUtc().isBefore(hint.expiresAt)) {
        throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
      }
    }

    guard();
    // Per-request immutable captured token. Do not use _client.rpc(), setAuth(),
    // current-access-token callback, automatic refresh or implicit retry here.
    final transport = _GuardedHttp(
      _http ?? http.Client(),
      _http == null,
      guard,
    );
    final rest = PostgrestClient(
      '$_url/rest/v1',
      headers: {'apikey': _key, 'Authorization': 'Bearer ${hint.token}'},
      httpClient: transport,
      retryEnabled: false,
      retryCount: 0,
      requestTimeout: const Duration(seconds: 15),
    );
    try {
      return await rest.rpc<Object?>(function, params: params);
    } on ReviewTransportFailure {
      rethrow;
    } on TimeoutException {
      throw const ReviewTransportFailure(
        ReviewErrorCode.networkUnavailable,
        retryable: true,
      );
    } on http.ClientException {
      throw const ReviewTransportFailure(
        ReviewErrorCode.networkUnavailable,
        retryable: true,
      );
    } on Object {
      throw const ReviewTransportFailure(ReviewErrorCode.internalError);
    } finally {
      transport.close();
      await rest.dispose();
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _hint = null;
    _registry.dispose();
    unawaited(_subscription?.cancel());
    _subscription = null;
    // Owner still owns configured SDK client/HTTP client and secure storage.
    // No sign-out/network mutation or disposal of borrowed clients occurs here.
  }
}

final class _SessionHint {
  const _SessionHint(this.userId, this.lifecycle, this.token, this.expiresAt);
  final String userId;
  final String lifecycle;
  final String token;
  final DateTime expiresAt;
  bool sameLifecycle(_SessionHint other) =>
      userId == other.userId && lifecycle == other.lifecycle;
  static _SessionHint from(Session? session, DateTime now) {
    if (session == null || session.tokenType.toLowerCase() != 'bearer') {
      throw const FormatException();
    }
    final token = session.accessToken;
    final payload = _jwtPayload(token);
    final id = ReviewSession(userId: session.user.id).userId;
    final lifecycle = ReviewSession(
      userId: payload['session_id'] as String,
    ).userId;
    final exp = payload['exp'];
    if (payload['role'] != 'authenticated' ||
        (payload['sub'] as String).toLowerCase() != id ||
        exp is! int ||
        exp < 1 ||
        exp > 253402300799) {
      throw const FormatException();
    }
    final expires = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    );
    if (!expires.isAfter(now.toUtc())) {
      throw const FormatException();
    }
    return _SessionHint(id, lifecycle, token, expires);
  }
}

Map<String, Object?> _jwtPayload(String token) {
  if (token.length > 32768 || token.contains(RegExp(r'\s'))) {
    throw const FormatException();
  }
  final parts = token.split('.');
  if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
    throw const FormatException();
  }
  final value = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
  );
  if (value is! Map<String, Object?>) {
    throw const FormatException();
  }
  return value;
}

String _projectUrl(String value) {
  final uri = Uri.tryParse(value);
  if (value.length > 2048 ||
      value != value.trim() ||
      uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw ArgumentError('Expected trusted HTTPS Supabase project origin');
  }
  return uri.replace(path: '').toString();
}

String _publicKey(String value) {
  try {
    if (value.contains(RegExp(r'\s'))) {
      throw const FormatException();
    }
    if (RegExp(r'^sb_publishable_[A-Za-z0-9_-]{10,200}$').hasMatch(value)) {
      return value;
    }
    if (_jwtPayload(value)['role'] == 'anon') {
      return value;
    }
  } on Object {
    /* No credential detail in errors. */
  }
  throw ArgumentError(
    'Expected public publishable/anon key, never service-role',
  );
}

final class _GuardedHttp extends http.BaseClient {
  _GuardedHttp(this._inner, this._owns, this._guard);
  final http.Client _inner;
  final bool _owns;
  final void Function() _guard;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _guard();
    request.followRedirects = false;
    final response = await _inner.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.listen((_) {}).cancel();
      final code = switch (response.statusCode) {
        401 => ReviewErrorCode.unauthorized,
        403 => ReviewErrorCode.forbidden,
        400 => ReviewErrorCode.validationFailure,
        404 => ReviewErrorCode.notFound,
        409 => ReviewErrorCode.syncConflict,
        429 => ReviewErrorCode.rateLimited,
        408 || >= 500 => ReviewErrorCode.networkUnavailable,
        _ => ReviewErrorCode.internalError,
      };
      throw ReviewTransportFailure(
        code,
        retryable:
            code == ReviewErrorCode.networkUnavailable ||
            code == ReviewErrorCode.rateLimited,
      );
    }
    const maxResponseBytes = 1024 * 1024;
    if ((response.contentLength ?? 0) > maxResponseBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const ReviewTransportFailure(ReviewErrorCode.internalError);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const ReviewTransportFailure(ReviewErrorCode.internalError);
      }
      bytes.add(chunk);
    }
    return http.StreamedResponse(
      Stream.value(bytes.takeBytes()),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() {
    if (_owns) {
      _inner.close();
    }
  }
}
