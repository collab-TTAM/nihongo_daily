import '../domain/completed_study_session.dart';
import '../domain/daily_plan.dart';

enum DailyPlanErrorCode {
  unauthorized('UNAUTHORIZED'),
  forbidden('FORBIDDEN'),
  notFound('NOT_FOUND'),
  validationFailure('VALIDATION_FAILURE'),
  rateLimited('RATE_LIMITED'),
  networkUnavailable('NETWORK_UNAVAILABLE'),
  providerUnavailable('PROVIDER_UNAVAILABLE'),
  syncConflict('SYNC_CONFLICT'),
  internalError('INTERNAL_ERROR');

  const DailyPlanErrorCode(this.wireName);
  final String wireName;
}

/// Fixed local messages: raw server/transport text is never displayed or logged.
final class DailyPlanFailure implements Exception {
  const DailyPlanFailure(this.code, {this.retryable = false});
  final DailyPlanErrorCode code;
  final bool retryable;

  String get messageVi => switch (code) {
    DailyPlanErrorCode.unauthorized => 'Vui lòng đăng nhập lại.',
    DailyPlanErrorCode.forbidden =>
      'Bạn không có quyền thực hiện thao tác này.',
    DailyPlanErrorCode.notFound => 'Chưa tìm thấy dữ liệu học tập.',
    DailyPlanErrorCode.validationFailure => 'Dữ liệu học tập không hợp lệ.',
    DailyPlanErrorCode.rateLimited => 'Vui lòng thử lại sau.',
    DailyPlanErrorCode.networkUnavailable => 'Không có kết nối mạng.',
    DailyPlanErrorCode.providerUnavailable => 'Dịch vụ tạm thời chưa sẵn sàng.',
    DailyPlanErrorCode.syncConflict => 'Dữ liệu đã thay đổi. Vui lòng tải lại.',
    DailyPlanErrorCode.internalError =>
      'Chưa thể xử lý dữ liệu học tập. Vui lòng thử lại.',
  };

  @override
  String toString() => 'DailyPlanFailure(${code.wireName})';
}

/// Implemented by the Auth integration using one captured, verified session.
///
/// Never dispatch through a mutable global current-user client. isCurrent must
/// become false on logout, account change, session replacement or disposal, even
/// when the same user later signs in again. The implementation owns bounded
/// transport/size/deadline controls and maps known offline failures to
/// DailyPlanFailure. It sends parameters to the fixed get_daily_plan RPC only.
/// No credential, URL or arbitrary RPC name is accepted by this interface.
abstract interface class DailyPlanSessionGateway {
  bool get isCurrent;
  Future<Object?> getDailyPlan(Map<String, Object> parameters);
}

/// Optional fixed submit_study_session RPC on the same captured session lease.
/// Implementations must never accept an owner or use service-role authority.
abstract interface class DailyPlanStudySessionGateway
    implements DailyPlanSessionGateway {
  Future<Object?> submitStudySession(Map<String, Object> parameters);
}

/// Borrowed factory, published only by an active owned startup runtime.
abstract interface class DailyPlanRepositorySource {
  DailyPlanRepository? createDailyPlanRepository();
}

/// Account-scoped repository; no cache, local completion or automatic retry.
final class DailyPlanRepository {
  const DailyPlanRepository(this._session);
  final DailyPlanSessionGateway _session;

  Future<DailyPlan> load(DailyPlanDate date) => _execute(
    date,
    () => _session.getDailyPlan({'p_request': date.toRequestJson()}),
  );

  Future<DailyPlan> submit(CompletedStudySession event) async {
    _requireCurrent();
    final session = _session;
    if (session is! DailyPlanStudySessionGateway) {
      throw const DailyPlanFailure(DailyPlanErrorCode.providerUnavailable);
    }
    return _execute(
      event.date,
      () => session.submitStudySession({'p_request': event.toJson()}),
    );
  }

  Future<DailyPlan> _execute(
    DailyPlanDate date,
    Future<Object?> Function() request,
  ) async {
    _requireCurrent();
    Object? value;
    try {
      value = await request();
    } on DailyPlanFailure catch (failure) {
      _requireCurrent();
      // A gateway cannot make a permanent failure advertise an automatic retry.
      throw _safeFailure(failure.code, failure.retryable);
    } catch (_) {
      _requireCurrent();
      throw const DailyPlanFailure(DailyPlanErrorCode.internalError);
    }
    _requireCurrent();
    final serverFailure = _error(value);
    if (serverFailure != null) throw serverFailure;
    try {
      final plan = DailyPlan.fromJson(value);
      if (plan.date.value != date.value) {
        throw const FormatException('Unexpected plan date');
      }
      return plan;
    } on FormatException {
      throw const DailyPlanFailure(DailyPlanErrorCode.internalError);
    }
  }

  void _requireCurrent() {
    if (!_session.isCurrent) {
      throw const DailyPlanFailure(DailyPlanErrorCode.unauthorized);
    }
  }
}

DailyPlanFailure _safeFailure(DailyPlanErrorCode code, bool retryable) {
  final transient =
      code == DailyPlanErrorCode.networkUnavailable ||
      code == DailyPlanErrorCode.providerUnavailable ||
      code == DailyPlanErrorCode.rateLimited;
  return DailyPlanFailure(code, retryable: retryable && transient);
}

DailyPlanFailure? _error(Object? value) {
  if (value is! Map<String, Object?> || !value.containsKey('code')) return null;
  final message = value['message_vi'];
  final retryable = value['retryable'];
  final codes = DailyPlanErrorCode.values.where(
    (code) => code.wireName == value['code'],
  );
  if (value.length != 3 ||
      codes.length != 1 ||
      message is! String ||
      message.isEmpty ||
      message.runes.length > 500 ||
      retryable is! bool) {
    return const DailyPlanFailure(DailyPlanErrorCode.internalError);
  }
  return _safeFailure(codes.single, retryable);
}
