import 'dart:async';

import '../../srs/data/review_repository.dart';
import 'daily_plan_repository.dart';

/// Borrows the existing captured SDK transport; owns no client, token or store.
/// Readiness must include the owned vault/profile/runtime barrier, not only Auth.
final class CapturedDailyPlanGateway implements DailyPlanStudySessionGateway {
  CapturedDailyPlanGateway({
    required ReviewAuth auth,
    required ReviewRpcTransport transport,
    required bool Function() isReady,
    Duration timeout = const Duration(seconds: 15),
  }) : _auth = auth,
       _transport = transport,
       _ready = isReady,
       _session = _capture(auth),
       _timeout = timeout {
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 15)) {
      throw ArgumentError('Expected timeout in (0,15 seconds]');
    }
    if (!isCurrent) {
      throw const DailyPlanFailure(DailyPlanErrorCode.unauthorized);
    }
  }

  final ReviewAuth _auth;
  final ReviewRpcTransport _transport;
  final bool Function() _ready;
  final ReviewSession _session;
  final Duration _timeout;
  bool _revoked = false;

  @override
  bool get isCurrent {
    if (_revoked) return false;
    try {
      if (_ready() && identical(_auth.currentSession, _session)) return true;
    } on Object {
      // Raw Auth/owner errors never become display state or revive this lease.
    }
    _revoked = true;
    return false;
  }

  @override
  Future<Object?> getDailyPlan(Map<String, Object> parameters) =>
      _invoke('get_daily_plan', parameters);

  @override
  Future<Object?> submitStudySession(Map<String, Object> parameters) =>
      _invoke('submit_study_session', parameters);

  Future<Object?> _invoke(
    String function,
    Map<String, Object> parameters,
  ) async {
    _requireCurrent();
    try {
      final value = await _transport
          .invoke(
            capturedSession: _session,
            function: function,
            params: parameters,
          )
          .timeout(_timeout);
      _requireCurrent();
      return value;
    } on ReviewTransportFailure catch (failure) {
      _requireCurrent();
      final code = DailyPlanErrorCode.values.singleWhere(
        (code) => code.wireName == failure.code.wireName,
      );
      throw DailyPlanFailure(code, retryable: failure.retryable);
    } on TimeoutException {
      _requireCurrent();
      // A timeout may follow a committed mutation. The caller retains the exact
      // immutable event; this gateway neither retries nor marks it unsaved.
      throw const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
        retryable: true,
      );
    } on DailyPlanFailure {
      rethrow;
    } on Object {
      _requireCurrent();
      throw const DailyPlanFailure(DailyPlanErrorCode.internalError);
    }
  }

  void _requireCurrent() {
    if (!isCurrent) {
      throw const DailyPlanFailure(DailyPlanErrorCode.unauthorized);
    }
  }
}

ReviewSession _capture(ReviewAuth auth) {
  try {
    final session = auth.currentSession;
    if (session != null) return session;
  } on Object {
    // Construction also discards raw owner/SDK error details.
  }
  throw const DailyPlanFailure(DailyPlanErrorCode.unauthorized);
}
