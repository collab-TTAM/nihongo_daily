import 'dart:async';

enum SessionVaultError { unavailable, invalidInput, corrupt }

final class SessionVaultFailure implements Exception {
  const SessionVaultFailure(this.code);
  final SessionVaultError code;
  @override
  String toString() => 'SessionVaultFailure(${code.name})';
}

/// Internal transport port; arguments/results may contain a refresh secret.
/// Implementations must never log them or include raw errors in exceptions.
abstract interface class SessionCredentialBackend {
  Future<Object?> invoke(String method, Map<String, Object> arguments);
}

/// One refresh secret per trusted project origin and OS user. No Auth/session
/// validity is inferred from a stored value, and no password/profile is stored.
final class SessionCredentialVault {
  SessionCredentialVault({
    required String projectUrl,
    required SessionCredentialBackend backend,
  }) : target = _target(projectUrl),
       _backend = backend;

  static const targetPrefix = 'NihongoDaily.Refresh.v1|';
  static const maxTokenLength = 2048;
  final String target;
  final SessionCredentialBackend _backend;

  // Shared scope queue: separate facade instances cannot reorder write/clear
  // within this isolate. Finished entries are removed; failures don't poison it.
  static final _tails = <String, Future<void>>{};

  static String _target(String value) {
    try {
      final uri = Uri.parse(value);
      if (value.length > 480 ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          !const {'', '/'}.contains(uri.path) ||
          uri.hasQuery ||
          uri.hasFragment ||
          uri.port < 1 ||
          uri.port > 65535) {
        throw const SessionVaultFailure(SessionVaultError.invalidInput);
      }
      final origin = uri.origin.toLowerCase();
      if (!RegExp(r'^https://[a-z0-9.\-:\[\]]+$').hasMatch(origin)) {
        throw const SessionVaultFailure(SessionVaultError.invalidInput);
      }
      return '$targetPrefix$origin';
    } on Object {
      throw const SessionVaultFailure(SessionVaultError.invalidInput);
    }
  }

  static bool _validToken(String value) =>
      value.isNotEmpty &&
      value.length <= maxTokenLength &&
      value.codeUnits.every((unit) => unit >= 0x21 && unit <= 0x7e);

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = (_tails[target] ?? Future<void>.value()).then(
      (_) => action(),
    );
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _tails[target] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tails[target], tail)) {
          _tails.remove(target);
        }
      }),
    );
    return result;
  }

  Future<Object?> _invoke(String method, [String? token]) async {
    try {
      return await _backend.invoke(method, {
        'target': target,
        if (token != null) 'token': token,
      });
    } on SessionVaultFailure {
      rethrow;
    } on Object {
      throw const SessionVaultFailure(SessionVaultError.unavailable);
    }
  }

  Future<String?> readRefreshToken() => _serial(() async {
    final result = await _invoke('read');
    if (result == null) {
      return null;
    }
    if (result is! String || !_validToken(result)) {
      throw const SessionVaultFailure(SessionVaultError.corrupt);
    }
    return result;
  });

  Future<void> writeRefreshToken(String token) {
    if (!_validToken(token)) {
      return Future.error(
        const SessionVaultFailure(SessionVaultError.invalidInput),
      );
    }
    return _serial(() async {
      if (await _invoke('write', token) != true) {
        throw const SessionVaultFailure(SessionVaultError.corrupt);
      }
    });
  }

  Future<void> clear() => _serial(() async {
    if (await _invoke('clear') != true) {
      throw const SessionVaultFailure(SessionVaultError.corrupt);
    }
  });
}
