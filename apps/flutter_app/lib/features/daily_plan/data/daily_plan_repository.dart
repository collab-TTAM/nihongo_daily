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
    DailyPlanErrorCode.forbidden => 'Bạn không có quyền tải kế hoạch này.',
    DailyPlanErrorCode.notFound => 'Chưa tìm thấy hồ sơ học tập.',
    DailyPlanErrorCode.validationFailure => 'Ngày học không hợp lệ.',
    DailyPlanErrorCode.rateLimited => 'Vui lòng thử lại sau.',
    DailyPlanErrorCode.networkUnavailable => 'Không có kết nối mạng.',
    DailyPlanErrorCode.providerUnavailable => 'Dịch vụ tạm thời chưa sẵn sàng.',
    DailyPlanErrorCode.syncConflict => 'Dữ liệu đã thay đổi. Vui lòng tải lại.',
    DailyPlanErrorCode.internalError =>
      'Chưa thể tải kế hoạch. Vui lòng thử lại.',
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

/// Read-only, account-scoped repository; has no cache, writes or automatic retry.
/// Not installed in the preview app until the owned Auth runtime is integrated.
final class DailyPlanRepository {
  const DailyPlanRepository(this._session);
  final DailyPlanSessionGateway _session;

  Future<DailyPlan> load(DailyPlanDate date) async {
    _requireCurrent();
    Object? value;
    try {
      value = await _session.getDailyPlan({'p_request': date.toRequestJson()});
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
