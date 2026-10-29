import 'dart:async';

import '../../srs/data/review_repository.dart';
import '../domain/ai_text_models.dart';

enum AiTextErrorCode {
  unauthorized(
    'UNAUTHORIZED',
    'Phiên đăng nhập đã thay đổi. Hãy mở lại trợ lý.',
  ),
  forbidden('FORBIDDEN', 'Bạn không có quyền thực hiện yêu cầu này.'),
  notFound('NOT_FOUND', 'Nội dung yêu cầu chưa khả dụng.'),
  validationFailure('VALIDATION_FAILURE', 'Dữ liệu yêu cầu AI không hợp lệ.'),
  rateLimited('RATE_LIMITED', 'Vui lòng chờ trước khi gửi yêu cầu AI mới.'),
  networkUnavailable(
    'NETWORK_UNAVAILABLE',
    'Chưa nhận được kết quả AI. Gửi lại có thể tạo yêu cầu mới.',
  ),
  providerUnavailable('PROVIDER_UNAVAILABLE', 'Dịch vụ AI chưa khả dụng.'),
  syncConflict(
    'SYNC_CONFLICT',
    'Dữ liệu đã thay đổi. Hãy kiểm tra lại yêu cầu.',
  ),
  internalError('INTERNAL_ERROR', 'Chưa thể xử lý kết quả AI.');

  const AiTextErrorCode(this.wireName, this.messageVi);
  final String wireName;
  final String messageVi;
}

/// A transport may throw this safe type; raw exceptions are discarded.
final class AiTextFailure implements Exception {
  const AiTextFailure(this.code, {this.retryable = false});
  final AiTextErrorCode code;
  final bool retryable;
  String get messageVi => code.messageVi;

  @override
  String toString() => 'AiTextFailure(${code.wireName})';
}

/// Local single-flight state, not a server quota or frozen wire error.
final class AiTextRequestPending implements Exception {
  const AiTextRequestPending();
  String get messageVi => 'Yêu cầu AI trước vẫn đang xử lý.';

  @override
  String toString() => messageVi;
}

/// Borrowed fixed-operation port. It owns bounded HTTP/JSON, credentials and
/// cancellation, checking the captured lease immediately before actual dispatch.
/// It must never select a mutable global current-user client or retry implicitly.
/// No SDK/network implementation or provider is installed by this interface.
abstract interface class AiTextTransport {
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  });

  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  });
}

/// Caller supplies the owned vault/profile/runtime generation readiness fence.
/// ReviewSession is an identity hint, not JWT or hosted authorization proof.
final class CapturedAiTextRepository {
  CapturedAiTextRepository({
    required ReviewAuth auth,
    required AiTextTransport transport,
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
    _requireCurrent();
  }

  final ReviewAuth _auth;
  final AiTextTransport _transport;
  final bool Function() _ready;
  final ReviewSession _session;
  final Duration _timeout;
  Object? _inFlight;
  bool _revoked = false;
  bool _checking = false;

  bool get isBusy => _inFlight != null;

  bool get isCurrent {
    if (_revoked || _checking) return false;
    _checking = true;
    try {
      if (_ready() &&
          identical(_auth.currentSession, _session) &&
          _ready() &&
          identical(_auth.currentSession, _session) &&
          !_revoked) {
        return true;
      }
    } on Object {
      // Readiness/Auth getter failures permanently fence this capability.
    } finally {
      _checking = false;
    }
    _revoked = true;
    return false;
  }

  /// Revokes publication/dispatch only; caller still owns and drains transport.
  void revoke() {
    _revoked = true;
  }

  Future<TutorExplanation> explain(TutorExplainRequest request) => _execute(
    () => _transport.tutorExplain(
      capturedSession: _session,
      body: _body(request.toJson()),
    ),
    TutorExplanation.fromJson,
  );

  Future<SentenceCorrection> correct(CorrectSentenceRequest request) =>
      _execute(
        () => _transport.correctSentence(
          capturedSession: _session,
          body: _body(request.toJson()),
        ),
        SentenceCorrection.fromJson,
      );

  Future<T> _execute<T>(
    Future<Object?> Function() dispatch,
    T Function(Object?) decode,
  ) async {
    _requireCurrent();
    if (isBusy) throw const AiTextRequestPending();
    final ticket = Object();
    _inFlight = ticket;
    var finished = false;
    var settled = false;
    void release() {
      if (finished && settled && identical(_inFlight, ticket)) {
        _inFlight = null;
      }
    }

    // Register before a supplied transport can synchronously reenter us.
    final operation = Future<Object?>.sync(() {
      _requireCurrent();
      return dispatch();
    });
    unawaited(
      operation.then<void>(
        (_) {
          settled = true;
          release();
        },
        onError: (Object _, StackTrace _) {
          settled = true;
          release();
        },
      ),
    );
    try {
      final value = await operation.timeout(_timeout);
      _requireCurrent();
      final failure = _serverFailure(value);
      if (failure != null) throw failure;
      final result = decode(value);
      _requireCurrent();
      return result;
    } on AiTextRequestPending {
      _requireCurrent();
      rethrow;
    } on AiTextFailure catch (failure) {
      _requireCurrent();
      if (failure.code == AiTextErrorCode.unauthorized) _revoked = true;
      throw _safeFailure(failure.code, failure.retryable);
    } on TimeoutException {
      _requireCurrent();
      // Not cancellation/rollback. Hold busy until the original I/O settles.
      throw const AiTextFailure(AiTextErrorCode.networkUnavailable);
    } on Object {
      _requireCurrent();
      throw const AiTextFailure(AiTextErrorCode.internalError);
    } finally {
      finished = true;
      release();
    }
  }

  void _requireCurrent() {
    if (!isCurrent) {
      throw const AiTextFailure(AiTextErrorCode.unauthorized);
    }
  }
}

ReviewSession _capture(ReviewAuth auth) {
  try {
    final session = auth.currentSession;
    if (session != null) return session;
  } on Object {
    // No raw SDK/identity error detail crosses construction.
  }
  throw const AiTextFailure(AiTextErrorCode.unauthorized);
}

AiTextFailure _safeFailure(AiTextErrorCode code, bool retryable) {
  final transient =
      code == AiTextErrorCode.networkUnavailable ||
      code == AiTextErrorCode.providerUnavailable ||
      code == AiTextErrorCode.rateLimited;
  return AiTextFailure(code, retryable: retryable && transient);
}

AiTextFailure? _serverFailure(Object? value) {
  if (value is! Map<String, Object?> || !value.containsKey('code')) return null;
  final message = value['message_vi'];
  final retryable = value['retryable'];
  final matches = AiTextErrorCode.values.where(
    (code) => code.wireName == value['code'],
  );
  if (value.length != 3 ||
      matches.length != 1 ||
      message is! String ||
      message.isEmpty ||
      message.length > 1000 ||
      message.runes.length > 500 ||
      retryable is! bool) {
    return const AiTextFailure(AiTextErrorCode.internalError);
  }
  return _safeFailure(matches.single, retryable);
}

Map<String, Object> _body(Map<String, Object> value) =>
    _freeze(value) as Map<String, Object>;

Object _freeze(Object value) {
  if (value is Map<String, Object>) {
    return Map<String, Object>.unmodifiable(
      value.map((key, entry) => MapEntry(key, _freeze(entry))),
    );
  }
  if (value is List<Object>) {
    return List<Object>.unmodifiable(value.map(_freeze));
  }
  return value;
}
