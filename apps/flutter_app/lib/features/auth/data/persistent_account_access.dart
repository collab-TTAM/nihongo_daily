import 'dart:async';
import '../application/account_controller.dart';
import '../../srs/data/review_repository.dart';
import 'session_credential_vault.dart';

/// Internal, exclusively owned SDK port. No other caller may mutate its Auth.
/// Refresh secrets must never be logged or copied into application state.
abstract interface class RefreshableAccountAccess implements AccountAccess {
  String? get currentRefreshToken;
  Future<void> restore(String refreshToken);
  Future<void> refresh();
}

enum SessionPersistencePhase { idle, restoring, saving, ready, failed, closed }

/// Explicit opt-in barrier: SDK identity is visible only after its exact current
/// refresh secret is persisted. A stored secret alone never grants study access.
final class PersistentAccountAccess implements AccountAccess {
  PersistentAccountAccess({required this.sdk, required this.vault}) {
    if (!_owners.add(vault.target)) {
      throw const SessionVaultFailure(SessionVaultError.unavailable);
    }
    try {
      _subscription = sdk.sessionChanges.listen(
        (_) => _changed(),
        onError: (Object _, StackTrace __) => _fail(),
        onDone: _fail,
      );
    } on Object {
      _owners.remove(vault.target);
      throw const SessionVaultFailure(SessionVaultError.unavailable);
    }
  }
  static final _owners = <String>{};
  static bool isTargetOwned(String target) => _owners.contains(target);
  final RefreshableAccountAccess sdk;
  final SessionCredentialVault vault;
  final _events = StreamController<void>.broadcast();
  @override
  late final Stream<void> sessionChanges = _events.stream;
  StreamSubscription<void>? _subscription;
  Future<void> _tail = Future<void>.value();
  Future<void>? _operation;
  Future<void>? _logout;
  Future<void>? _close;
  ReviewSession? _accepted;
  ReviewSession? _pending;
  String? _acceptedSecret;
  String? _pendingSecret;
  int _generation = 0;
  bool _started = false;
  bool _allowed = false;
  bool _failed = false;
  bool _closed = false;
  bool _authInFlight = false;
  bool _cancelledOperation = false;
  SessionPersistencePhase _phase = SessionPersistencePhase.idle;
  SessionPersistencePhase get phase => _phase;

  @override
  ReviewSession? get currentSession {
    if (_closed || _failed || !_allowed || _accepted == null) return null;
    try {
      return identical(sdk.currentSession, _accepted) &&
              sdk.currentRefreshToken == _acceptedSecret
          ? _accepted
          : null;
    } on Object {
      _fail();
      return null;
    }
  }

  void _notify() {
    if (!_closed) _events.add(null);
  }

  void _revoke(SessionPersistencePhase phase) {
    _generation++;
    _accepted = null;
    _pending = null;
    _acceptedSecret = null;
    _pendingSecret = null;
    _phase = phase;
    _notify();
  }

  void _fail() {
    if (_closed) return;
    _failed = true;
    _allowed = false;
    _revoke(SessionPersistencePhase.failed);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  bool _matches(int generation, ReviewSession session, String secret) {
    if (_closed || _failed || !_allowed || generation != _generation) {
      return false;
    }
    try {
      return identical(sdk.currentSession, session) &&
          sdk.currentRefreshToken == secret;
    } on Object {
      return false;
    }
  }

  void _changed() {
    if (_closed || _failed || !_allowed || _authInFlight) return;
    try {
      final session = sdk.currentSession;
      final secret = sdk.currentRefreshToken;
      if (session == null) {
        _revoke(SessionPersistencePhase.idle);
        unawaited(
          _enqueue(() async {
            try {
              await vault.clear();
            } on Object {
              _fail();
            }
          }),
        );
        return;
      }
      if (secret == null) {
        _fail();
        return;
      }
      if ((identical(session, _accepted) && secret == _acceptedSecret) ||
          (identical(session, _pending) && secret == _pendingSecret)) {
        return;
      }
      _revoke(SessionPersistencePhase.saving);
      _pending = session;
      _pendingSecret = secret;
      final generation = _generation;
      unawaited(
        _enqueue(() async {
          if (!_matches(generation, session, secret)) return;
          try {
            await vault.writeRefreshToken(secret);
            if (!_matches(generation, session, secret)) return;
            _pending = null;
            _pendingSecret = null;
            _accepted = session;
            _acceptedSecret = secret;
            _phase = SessionPersistencePhase.ready;
            _notify();
          } on Object {
            // Fail closed even if an older event's in-flight write failed. Its
            // OS result is uncertain; never publish a newer unpersisted session.
            _fail();
            try {
              await vault.clear();
            } on Object {
              // Explicit signOut retries both storage clear and SDK cleanup.
            }
          }
        }),
      );
    } on Object {
      _fail();
    }
  }

  static ReviewTransportFailure _failure() =>
      const ReviewTransportFailure(ReviewErrorCode.unauthorized);

  Future<void> _settle() async {
    // SDK Auth streams may be asynchronously queued. Consult current state as
    // well, then drain all writes that those events scheduled.
    await Future<void>.delayed(Duration.zero);
    _authInFlight = false;
    _changed();
    await _tail;
    if (_closed || _failed || !_allowed || currentSession == null) {
      throw _failure();
    }
  }

  /// Once per owned client, before offering login. Refresh-only server request;
  /// do not reconstruct Session JSON or trust an old access JWT from storage.
  Future<void> start() {
    if (_closed || _started || _operation != null) {
      return Future.error(_failure());
    }
    _started = true;
    _revoke(SessionPersistencePhase.restoring);
    final generation = _generation;
    final result = _run(() async {
      final String? secret;
      try {
        secret = await vault.readRefreshToken();
      } on Object {
        _fail();
        rethrow;
      }
      if (_closed || generation != _generation) throw _failure();
      _allowed = true;
      if (secret == null) {
        _phase = SessionPersistencePhase.idle;
        _notify();
        return;
      }
      await sdk.restore(secret);
      await _settle();
    });
    _operation = result;
    return result;
  }

  Future<void> _run(Future<void> Function() action) async {
    _authInFlight = true;
    _cancelledOperation = false;
    try {
      await action();
    } on Object {
      if (_allowed && !_closed) _fail();
      throw _failure();
    } finally {
      _authInFlight = false;
      try {
        if (_closed || _cancelledOperation) {
          // Keep the operation owned until cleanup completes: a new login must
          // not race the sign-out/clear of this cancelled Auth request.
          await _cleanup();
          if (!_closed && !_failed) {
            _allowed = true;
            _phase = SessionPersistencePhase.idle;
            _notify();
          }
        }
      } finally {
        _operation = null;
      }
    }
  }

  @override
  Future<void> signIn(String email, String password) {
    if (!_started ||
        _closed ||
        (!_allowed && !_failed) ||
        _operation != null ||
        _logout != null ||
        currentSession != null) {
      return Future.error(_failure());
    }
    final result = _run(() async {
      if (_failed) {
        await _cleanup();
        if (_closed || _logout != null || _cancelledOperation) throw _failure();
        _failed = false;
        _allowed = true;
      }
      await sdk.signIn(email, password);
      await _settle();
    });
    _operation = result;
    return result;
  }

  /// Explicit refresh, with the same persistence barrier as sign-in/restore.
  /// SDK automatic refresh is disabled by the owned assembly; no retry loop.
  Future<void> refresh() {
    if (currentSession == null || _operation != null || _logout != null) {
      return Future.error(_failure());
    }
    _revoke(SessionPersistencePhase.saving);
    final result = _run(() async {
      await sdk.refresh();
      await _settle();
    });
    _operation = result;
    return result;
  }

  Future<void> _cleanup() async {
    var failed = false;
    // No SDK calls inside a synchronous Auth callback. Gate already revoked.
    await Future<void>.value();
    try {
      await sdk.signOut();
    } on Object {
      failed = true;
    }
    try {
      await _enqueue(vault.clear);
    } on Object {
      failed = true;
    }
    if (failed) {
      _fail();
      throw _failure();
    }
  }

  @override
  Future<void> signOut() {
    if (_closed) return Future.error(_failure());
    if (_logout != null) return _logout!;
    _allowed = false;
    if (_operation != null) _cancelledOperation = true;
    _revoke(SessionPersistencePhase.idle);
    final result = () async {
      try {
        await _cleanup();
        if (!_closed && _operation == null) {
          _failed = false;
          _allowed = true;
          _phase = SessionPersistencePhase.idle;
          _notify();
        }
      } finally {
        _logout = null;
      }
    }();
    _logout = result;
    return result;
  }

  /// Close preserves a fully saved session for next start, but cancels readiness
  /// immediately. Interrupted Auth operations clean up before caller disposes
  /// the exclusively owned SDK. The caller must await this method.
  Future<void> close() {
    if (_close != null) return _close!;
    _closed = true;
    _allowed = false;
    _revoke(SessionPersistencePhase.closed);
    final operation = _operation;
    final logout = _logout;
    final result = () async {
      await _subscription?.cancel();
      for (final pending in [operation, logout]) {
        try {
          await pending;
        } on Object {
          // Safe error already returned to the operation's caller.
        }
      }
      await _tail;
      await _events.close();
      _owners.remove(vault.target);
    }();
    _close = result;
    return result;
  }
}
