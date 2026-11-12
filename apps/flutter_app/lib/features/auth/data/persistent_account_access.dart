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
  PersistentAccountAccess({
    required RefreshableAccountAccess sdk,
    required this.vault,
  }) : _sdk = sdk {
    if (!_owners.add(vault.target)) {
      throw const SessionVaultFailure(SessionVaultError.unavailable);
    }
    try {
      _subscription = _sdk.sessionChanges.listen(
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
  final RefreshableAccountAccess _sdk;
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
  // A failed sign-out/rotation cleanup must be retried before close releases
  // this target owner; otherwise a stale OS credential could survive shutdown.
  bool _cleanupRequired = false;
  bool _vaultOwnerAcquired = false;
  // One SDK sign-out can reach both lifecycle observers. Coalesce delayed
  // null-session notifications until a new session is observed.
  bool _noSessionClearPending = false;
  // Out-of-band null-session clears must drain before a replacement password grant.
  int _pendingSessionClears = 0;
  SessionPersistencePhase _phase = SessionPersistencePhase.idle;
  SessionPersistencePhase get phase => _phase;

  @override
  ReviewSession? get currentSession {
    if (_closed || _failed || !_allowed || _accepted == null) return null;
    try {
      return identical(_sdk.currentSession, _accepted) &&
              _sdk.currentRefreshToken == _acceptedSecret
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
      return identical(_sdk.currentSession, session) &&
          _sdk.currentRefreshToken == secret;
    } on Object {
      return false;
    }
  }

  void _changed() {
    if (_closed || _failed || !_allowed || _authInFlight) return;
    try {
      final session = _sdk.currentSession;
      final secret = _sdk.currentRefreshToken;
      if (session == null) {
        if (_noSessionClearPending) return;
        _noSessionClearPending = true;
        _pendingSessionClears++;
        _revoke(SessionPersistencePhase.idle);
        unawaited(
          _enqueue(() async {
            try {
              await vault.clear();
            } on Object {
              _cleanupRequired = true;
              _fail();
            } finally {
              _pendingSessionClears--;
            }
          }),
        );
        return;
      }
      _noSessionClearPending = false;
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
            _cleanupRequired = true;
            _fail();
            try {
              await vault.clear();
            } on Object {
              // Explicit signOut/close retries SDK cleanup and storage clear.
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

  Future<void> _drainTail() async {
    while (true) {
      final tail = _tail;
      await tail;
      if (identical(tail, _tail)) return;
    }
  }

  Future<void> _settle() async {
    // SDK Auth streams may be asynchronously queued. Consult current state as
    // well, then drain all writes that those events scheduled.
    await Future<void>.delayed(Duration.zero);
    _authInFlight = false;
    _changed();
    await _drainTail();
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
    return _runTracked(() async {
      try {
        await vault.acquireOwner();
        _vaultOwnerAcquired = true;
      } on Object {
        _fail();
        rethrow;
      }
      if (_closed || generation != _generation) throw _failure();
      final String? secret;
      try {
        secret = await vault.readRefreshToken();
      } on SessionVaultFailure catch (error) {
        // A corrupt value is known to be unusable. Require a successful clear
        // before caller close releases this project's exclusive vault owner.
        if (error.code == SessionVaultError.corrupt) {
          _cleanupRequired = true;
        }
        _fail();
        rethrow;
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
      await _sdk.restore(secret);
      await _settle();
    });
  }

  /// Reserve the operation slot before scheduling Auth work. A fast empty-vault
  /// read can otherwise finish before the caller assigns [_operation], leaving a
  /// completed future in the slot and rejecting the first explicit sign-in.
  Future<void> _runTracked(Future<void> Function() action) {
    final completer = Completer<void>();
    final result = completer.future;
    // Cancellation can arrive after this slot is published but before the
    // deferred runner starts. Reset before publication, never inside _run.
    _cancelledOperation = false;
    _operation = result;
    unawaited(
      Future<void>.microtask(() async {
        try {
          await _run(action);
          completer.complete();
        } on Object catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      }),
    );
    return result;
  }

  Future<void> _run(Future<void> Function() action) async {
    _authInFlight = true;
    try {
      await action();
    } on ReviewTransportFailure {
      if (_allowed && !_closed) _fail();
      rethrow;
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
        !_vaultOwnerAcquired ||
        _closed ||
        (!_allowed && !_failed) ||
        _operation != null ||
        _logout != null ||
        currentSession != null) {
      return Future.error(_failure());
    }
    late final bool needsCleanup;
    try {
      needsCleanup =
          _failed ||
          _cleanupRequired ||
          _pendingSessionClears > 0 ||
          _pending != null ||
          _sdk.currentSession != null;
    } on Object {
      _fail();
      return Future.error(_failure());
    }
    // Invalidate any out-of-band rotation before the replacement Auth request.
    _revoke(SessionPersistencePhase.restoring);
    return _runTracked(() async {
      if (needsCleanup) {
        // A session whose rotated secret is not accepted must be signed out and
        // its exact-project vault slot cleared before a new password grant.
        await _cleanup();
        if (_closed || _logout != null || _cancelledOperation) throw _failure();
        _failed = false;
        _allowed = true;
      }
      await _sdk.signIn(email, password);
      await _settle();
    });
  }

  /// Explicit refresh, with the same persistence barrier as sign-in/restore.
  /// SDK automatic refresh is disabled by the owned assembly; no retry loop.
  Future<void> refresh() {
    if (currentSession == null || _operation != null || _logout != null) {
      return Future.error(_failure());
    }
    _revoke(SessionPersistencePhase.saving);
    return _runTracked(() async {
      await _sdk.refresh();
      await _settle();
    });
  }

  Future<void> _cleanup() async {
    if (!_vaultOwnerAcquired) throw _failure();
    var failed = false;
    // Mark cleanup before SDK sign-out; its duplicate/late null-session events
    // must not enqueue a second clear after a replacement login has started.
    _noSessionClearPending = true;
    // No SDK calls inside a synchronous Auth callback. Gate already revoked.
    await Future<void>.value();
    try {
      await _sdk.signOut();
    } on Object {
      failed = true;
    }
    try {
      await _enqueue(vault.clear);
    } on Object {
      failed = true;
    }
    if (failed) {
      _cleanupRequired = true;
      _fail();
      throw _failure();
    }
    _cleanupRequired = false;
  }

  @override
  Future<void> signOut() {
    if (_closed || !_vaultOwnerAcquired) return Future.error(_failure());
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
    late final Future<void> result;
    result = () async {
      try {
        await _subscription?.cancel();
        for (final pending in [operation, logout]) {
          try {
            await pending;
          } on Object {
            // A failed operation may have set _cleanupRequired below.
          }
        }
        await _tail;
        if (_cleanupRequired) {
          // Never release the owner while a failed logout/rotation clear could
          // leave an old credential for a later startup to restore.
          await _cleanup();
        }
        if (_vaultOwnerAcquired) {
          await vault.releaseOwner();
          _vaultOwnerAcquired = false;
        }
        await _events.close();
        _owners.remove(vault.target);
      } on Object {
        if (identical(_close, result)) _close = null;
        throw const SessionVaultFailure(SessionVaultError.unavailable);
      }
    }();
    _close = result;
    return result;
  }
}
