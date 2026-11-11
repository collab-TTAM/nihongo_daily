import 'dart:async';

import 'package:supabase/supabase.dart';

import 'quiz_report_v2_transport.dart';

/// Read-only view of the caller-owned Supabase SDK Auth lifecycle.
/// The server, not this local snapshot, verifies the bearer JWT.
final class SupabaseQuizReportV2Auth implements QuizReportV2Auth {
  SupabaseQuizReportV2Auth({
    required SupabaseClient client,
    bool Function()? isReady,
    Stream<void>? readinessChanges,
  }) : _client = client,
       _isReady = isReady ?? _alwaysReady {
    _syncFromSdk(notify: false);
    _subscription = _client.auth.onAuthStateChange.listen(
      (_) => _syncFromSdk(),
      onError: (Object _, StackTrace __) => _fail(),
      onDone: _fail,
    );
    if (readinessChanges != null) {
      _readinessSubscription = readinessChanges.listen(
        (_) => _syncFromSdk(),
        onError: (Object _, StackTrace __) => _fail(),
        onDone: _fail,
      );
    }
  }

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  static bool _alwaysReady() => true;

  final SupabaseClient _client;
  final bool Function() _isReady;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  StreamSubscription<AuthState>? _subscription;
  StreamSubscription<void>? _readinessSubscription;
  String? _userId;
  String? _accessToken;
  int _generation = 0;
  bool _failed = false;
  bool _closed = false;

  @override
  Stream<void> get sessionChanges => _changes.stream;

  @override
  QuizReportV2CapturedSession? capture() {
    if (_closed || _failed) return null;
    _syncFromSdk();
    final userId = _userId;
    final accessToken = _accessToken;
    if (userId == null || accessToken == null) return null;
    return QuizReportV2CapturedSession(
      userId: userId,
      accessToken: accessToken,
      generation: _generation,
    );
  }

  @override
  bool isCurrent(QuizReportV2CapturedSession captured) {
    if (_closed || _failed) return false;
    _syncFromSdk();
    return captured.generation == _generation &&
        captured.userId == _userId &&
        captured.accessToken == _accessToken;
  }

  void _syncFromSdk({bool notify = true}) {
    if (_closed || _failed) return;
    String? nextUserId;
    String? nextAccessToken;
    bool ready;
    try {
      ready = _isReady();
    } on Object {
      ready = false;
    }
    try {
      final session = ready ? _client.auth.currentSession : null;
      final userId = session?.user.id.toLowerCase();
      final accessToken = session?.accessToken;
      if (userId != null &&
          _uuid.hasMatch(userId) &&
          accessToken != null &&
          _validToken(accessToken)) {
        nextUserId = userId;
        nextAccessToken = accessToken;
      }
    } on Object {
      nextUserId = null;
      nextAccessToken = null;
    }
    if (nextUserId != _userId || nextAccessToken != _accessToken) {
      _userId = nextUserId;
      _accessToken = nextAccessToken;
      _generation++;
      if (notify && !_changes.isClosed) _changes.add(null);
    }
  }

  static bool _validToken(String value) =>
      value.isNotEmpty &&
      value.length <= 8192 &&
      !value.contains(RegExp(r'\s')) &&
      value.codeUnits.every((unit) => unit >= 0x21 && unit <= 0x7e);

  void _fail() {
    if (_closed || _failed) return;
    _failed = true;
    _userId = null;
    _accessToken = null;
    _generation++;
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Dispose this observer before the owner disposes [SupabaseClient].
  /// It never signs out, refreshes, persists, or disposes the borrowed client.
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _userId = null;
    _accessToken = null;
    _generation++;
    if (!_changes.isClosed) _changes.add(null);
    await _subscription?.cancel();
    _subscription = null;
    await _readinessSubscription?.cancel();
    _readinessSubscription = null;
    await _changes.close();
  }
}
