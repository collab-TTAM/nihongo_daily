import 'dart:async';
import 'dart:collection';
import '../data/own_profile_repository.dart';
import '../../srs/data/review_repository.dart';

abstract interface class AccountAccess implements ReviewAuth {
  Stream<void> get sessionChanges;
  Future<void> signIn(String email, String password);
  Future<void> signOut();
}

enum AccountPhase {
  signedOut,
  signingIn,
  loadingProfile,
  ready,
  signInError,
  profileError,
  signingOut,
  signOutError,
  unavailable,
}

final class AccountState {
  const AccountState(this.phase, {this.profile, this.messageVi});
  final AccountPhase phase;
  final OwnProfile? profile;
  final String? messageVi;
}

/// Credentials are transient method arguments only, never controller state.
/// A profile barrier gates every study read/write and clears on lifecycle changes.
final class AccountController<T> {
  AccountController({
    required this.access,
    required this.ensureProfile,
    required this.buildStudyRuntime,
  }) {
    _gate = _ReadyAuth(this);
    _subscription = access.sessionChanges.listen(
      (_) => _sessionChanged(),
      onError: (Object _, StackTrace __) => _disable(),
      onDone: _disable,
    );
    _sessionChanged();
  }
  final AccountAccess access;
  final Future<OwnProfile> Function() ensureProfile;
  final T Function(ReviewAuth auth, Stream<void> changes) buildStudyRuntime;
  final _changes = StreamController<AccountState>.broadcast(sync: true);
  final _sessions = StreamController<void>.broadcast(sync: true);
  final _notifications = Queue<AccountState>();
  late final Stream<void> _sessionStream = _sessions.stream;
  late final Stream<AccountState> changes = _changes.stream;
  late final _ReadyAuth<T> _gate;
  StreamSubscription<void>? _subscription;
  AccountState _state = const AccountState(AccountPhase.signedOut);
  AccountState get state => _state;
  T? _runtime;
  ReviewSession? _readySession;
  ReviewSession? _profileSession;
  int _generation = 0;
  bool _disposed = false;
  bool _dead = false;
  bool _notifying = false;
  bool _signInBusy = false;
  bool _signOutBusy = false;
  bool _logoutFence = false;

  ReviewSession? _current() {
    try {
      return access.currentSession;
    } on Object {
      _disable();
      return null;
    }
  }

  ReviewSession? get readySession {
    if (_disposed ||
        _dead ||
        _logoutFence ||
        _state.phase != AccountPhase.ready) {
      return null;
    }
    final current = _current();
    return !_disposed &&
            !_dead &&
            !_logoutFence &&
            _state.phase == AccountPhase.ready &&
            identical(current, _readySession)
        ? current
        : null;
  }

  T? get readyRuntime => readySession == null ? null : _runtime;

  void _publish(AccountState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _notifications.add(next);
    if (_notifying) {
      return;
    }
    _notifying = true;
    try {
      while (!_disposed && _notifications.isNotEmpty) {
        final value = _notifications.removeFirst();
        _sessions.add(null); // Clear existing study data synchronously first.
        if (!_disposed) {
          _changes.add(value);
        }
      }
    } finally {
      _notifying = false;
      if (_disposed) {
        _closeStreams();
      }
    }
  }

  void _block(AccountPhase phase, {String? message}) {
    _generation++;
    _readySession = null;
    _profileSession = null;
    _runtime = null;
    _publish(AccountState(phase, messageVi: message));
  }

  void _disable() {
    if (_dead || _disposed) {
      return;
    }
    _dead = true;
    _block(
      AccountPhase.unavailable,
      message: 'Phiên tài khoản hiện không khả dụng.',
    );
  }

  void _sessionChanged() {
    if (_disposed || _dead || _logoutFence) {
      return;
    }
    final session = _current();
    if (_dead) {
      return;
    }
    if (session == null) {
      _block(_signInBusy ? AccountPhase.signingIn : AccountPhase.signedOut);
      return;
    }
    if (identical(session, _readySession) ||
        identical(session, _profileSession)) {
      return;
    }
    unawaited(_loadProfile(session));
  }

  Future<void> _loadProfile(ReviewSession session) async {
    _block(AccountPhase.loadingProfile);
    if (_disposed || _dead || _logoutFence || !identical(_current(), session)) {
      return;
    }
    _profileSession = session;
    final generation = _generation;
    bool current() =>
        !_disposed &&
        !_dead &&
        !_logoutFence &&
        generation == _generation &&
        identical(_current(), session);
    try {
      final profile = await ensureProfile();
      if (!current()) {
        return;
      }
      if (profile.id != session.userId) {
        throw const ReviewTransportFailure(ReviewErrorCode.internalError);
      }
      final runtime = buildStudyRuntime(_gate, _sessionStream);
      if (!current()) {
        return;
      }
      _profileSession = null;
      _readySession = session;
      _runtime = runtime;
      _publish(AccountState(AccountPhase.ready, profile: profile));
    } on Object {
      if (!current()) {
        return;
      }
      _block(
        AccountPhase.profileError,
        message: 'Không thể tải hồ sơ học tập. Vui lòng thử lại.',
      );
    }
  }

  Future<void> retryProfile() async {
    if (_disposed ||
        _dead ||
        _logoutFence ||
        _state.phase != AccountPhase.profileError) {
      return;
    }
    final session = _current();
    if (session == null) {
      _sessionChanged();
      return;
    }
    await _loadProfile(session);
  }

  Future<void> signIn(String email, String password) async {
    if (_disposed ||
        _dead ||
        _logoutFence ||
        _signInBusy ||
        _signOutBusy ||
        !const {
          AccountPhase.signedOut,
          AccountPhase.signInError,
        }.contains(_state.phase)) {
      return;
    }
    email = email.trim();
    if (email.length > 254 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ||
        password.isEmpty ||
        password.length > 4096) {
      _block(
        AccountPhase.signInError,
        message: 'Kiểm tra địa chỉ email và mật khẩu.',
      );
      return;
    }
    _signInBusy = true;
    _block(AccountPhase.signingIn);
    try {
      if (_disposed || _dead || _logoutFence) {
        return;
      }
      await access.signIn(email, password);
      if (_disposed || _dead || _logoutFence) {
        return;
      }
      if (_current() == null) {
        _block(
          AccountPhase.signInError,
          message: 'Chưa xác nhận được phiên đăng nhập. Vui lòng thử lại.',
        );
      } else {
        _sessionChanged();
      }
    } on Object {
      if (!_disposed && !_dead && !_logoutFence && _current() == null) {
        _block(
          AccountPhase.signInError,
          message: 'Không thể đăng nhập. Kiểm tra thông tin và thử lại.',
        );
      }
    } finally {
      _signInBusy = false;
      if (_logoutFence && !_disposed && !_dead) {
        await signOut(); // Clean up a late SDK success after explicit logout.
      }
    }
  }

  Future<void> signOut() async {
    if (_disposed || _dead || _signOutBusy) {
      return;
    }
    _logoutFence = true;
    _signOutBusy = true;
    _block(AccountPhase.signingOut);
    try {
      // The study gate is already revoked. Dispatch after an active Auth/state
      // listener returns, so synchronous SDK/port streams cannot be reentered.
      await Future<void>.value();
      await access.signOut();
      if (_disposed || _dead) {
        return;
      }
      if (_current() != null) {
        throw const ReviewTransportFailure(ReviewErrorCode.internalError);
      }
      // A pending SDK sign-in may still install a session later. Keep fenced.
      if (!_signInBusy) {
        _logoutFence = false;
      }
      _block(_signInBusy ? AccountPhase.signingOut : AccountPhase.signedOut);
    } on Object {
      if (!_disposed && !_dead) {
        _block(
          AccountPhase.signOutError,
          message: 'Chưa xác nhận đăng xuất. Vui lòng thử lại.',
        );
      }
    } finally {
      _signOutBusy = false;
    }
  }

  void _closeStreams() {
    _notifications.clear();
    unawaited(_changes.close());
    unawaited(_sessions.close());
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _generation++;
    _runtime = null;
    _readySession = null;
    unawaited(_subscription?.cancel());
    if (!_notifying) {
      _closeStreams();
    }
  }
}

final class _ReadyAuth<T> implements ReviewAuth {
  _ReadyAuth(this.owner);
  final AccountController<T> owner;
  @override
  ReviewSession? get currentSession => owner.readySession;
}
