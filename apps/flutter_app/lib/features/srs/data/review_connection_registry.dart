import 'dart:async';
import 'dart:convert';

import 'review_repository.dart';

/// The future Supabase binding supplies a closure over *captured* authenticated
/// credentials, not a shared client's current account. This is NOT JWT validation
/// or an SDK implementation. Tokens never enter this registry's public state.
typedef CapturedReviewRpc =
    Future<Object?> Function(String function, Map<String, Object> params);

final class _Connection {
  const _Connection(this.session, this.expiresAt, this.rpc);
  final ReviewSession session;
  final DateTime expiresAt;
  final CapturedReviewRpc rpc;
}

/// Process-local lifecycle/dispatch boundary. begin() always creates a fresh
/// identity, including another login by the same user. Only refresh() can retain
/// the active identity. Sign-out, expiry and disposal revoke old prepared events.
/// Call these synchronously from the trusted Auth lifecycle binding. No disk
/// cache, token refresh, profile provisioning or real authorization is provided.
final class ReviewConnectionRegistry implements ReviewAuth, ReviewRpcTransport {
  ReviewConnectionRegistry({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _changes = StreamController<void>.broadcast(sync: true);
  late final Stream<void> _sessionChanges = _changes.stream;
  _Connection? _connection;
  Timer? _expiry;
  bool _disposed = false;

  Stream<void> get sessionChanges => _sessionChanges;

  @override
  ReviewSession? get currentSession {
    final connection = _connection;
    if (connection != null && !_now().toUtc().isBefore(connection.expiresAt)) {
      end();
    }
    return _connection?.session;
  }

  void begin({
    required String userId,
    required DateTime expiresAt,
    required CapturedReviewRpc rpc,
  }) {
    _ensureOpen();
    // Invalidate an old account even when the new Auth event is malformed.
    final ReviewSession session;
    try {
      session = ReviewSession(userId: userId);
      _checkExpiry(expiresAt);
    } on Object {
      end();
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
    _install(_Connection(session, expiresAt.toUtc(), rpc));
    _changes.add(null);
  }

  void refresh({
    required String userId,
    required DateTime expiresAt,
    required CapturedReviewRpc rpc,
  }) {
    _ensureOpen();
    final session = currentSession;
    try {
      if (session == null ||
          session.userId != ReviewSession(userId: userId).userId) {
        throw const FormatException();
      }
      _checkExpiry(expiresAt);
    } on Object {
      end();
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
    _install(_Connection(session, expiresAt.toUtc(), rpc));
    // Same-user refresh does not clear an uncertain review or learner snapshot.
  }

  void _ensureOpen() {
    if (_disposed) {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
  }

  void _checkExpiry(DateTime expiresAt) {
    if (expiresAt.year < 1 ||
        expiresAt.year > 9999 ||
        !expiresAt.toUtc().isAfter(_now().toUtc())) {
      throw const FormatException();
    }
  }

  void _install(_Connection connection) {
    _expiry?.cancel();
    _connection = connection;
    _armExpiry(connection);
  }

  void _armExpiry(_Connection connection) {
    final delay = connection.expiresAt.difference(_now().toUtc());
    // Browser timers use signed 32-bit milliseconds. Re-arm long lifetimes
    // rather than overflowing into a rapid callback loop.
    final boundedDelay = delay > const Duration(hours: 24)
        ? const Duration(hours: 24)
        : delay;
    _expiry = Timer(boundedDelay.isNegative ? Duration.zero : boundedDelay, () {
      if (!identical(_connection, connection) || _disposed) return;
      // Clock moving backwards must not expire a still-valid session early.
      if (_now().toUtc().isBefore(connection.expiresAt)) {
        _armExpiry(connection);
      } else {
        end();
      }
    });
  }

  void end() {
    _expiry?.cancel();
    _expiry = null;
    if (_connection == null) return;
    _connection = null;
    if (!_disposed) _changes.add(null);
  }

  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String function,
    required Map<String, Object> params,
  }) async {
    if (!identical(currentSession, capturedSession) || _disposed) {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
    final connection = _connection!;
    try {
      final request = _boundedEnvelope(function, params);
      if (!identical(currentSession, capturedSession) ||
          !identical(_connection, connection)) {
        throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
      }
      // Snapshot the dispatch closure before await; never redirect on refresh.
      // Its owner must actually capture credentials, not a mutable shared client.
      final result = await connection.rpc(function, request);
      if (!identical(currentSession, capturedSession) || _disposed) {
        throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
      }
      return result;
    } on Object catch (error) {
      if (!identical(currentSession, capturedSession) || _disposed) {
        throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
      }
      if (error is ReviewTransportFailure) rethrow;
      if (error is TimeoutException) {
        throw const ReviewTransportFailure(
          ReviewErrorCode.networkUnavailable,
          retryable: true,
        );
      }
      throw const ReviewTransportFailure(ReviewErrorCode.internalError);
    }
  }

  void dispose() {
    if (_disposed) return;
    end();
    _disposed = true;
    unawaited(_changes.close());
  }
}

Map<String, Object> _boundedEnvelope(
  String function,
  Map<String, Object> params,
) {
  final expected = switch (function) {
    'submit_review' => const {
      'client_event_id',
      'item_type',
      'item_id',
      'rating',
      'is_correct',
      'response_ms',
      'occurred_at',
    },
    'get_review_queue' => const {'jlpt_level', 'limit'},
    'ensure_profile' => const <String>{},
    'get_daily_plan' => const {'date'},
    'get_study_day' => const <String>{},
    'submit_study_session' => const {
      'client_event_id',
      'plan_date',
      'session_type',
      'started_at',
      'ended_at',
    },
    _ => throw const ReviewTransportFailure(ReviewErrorCode.validationFailure),
  };
  final request = params['p_request'];
  if (params.length != 1 ||
      request is! Map<String, Object> ||
      request.length != expected.length ||
      !expected.every(request.containsKey) ||
      request.values.any(
        (value) =>
            value is! String &&
            value is! bool &&
            !(value is num && value.isFinite),
      )) {
    throw const ReviewTransportFailure(ReviewErrorCode.validationFailure);
  }
  // Bound allocation before JSON/UTF-8 encoding, not only after it.
  if (request.values.any((value) => value is String && value.length > 32768)) {
    throw const ReviewTransportFailure(ReviewErrorCode.validationFailure);
  }
  if (utf8.encode(jsonEncode(params)).length > 32768) {
    throw const ReviewTransportFailure(ReviewErrorCode.validationFailure);
  }
  return Map<String, Object>.unmodifiable({
    'p_request': Map<String, Object>.unmodifiable(request),
  });
}
