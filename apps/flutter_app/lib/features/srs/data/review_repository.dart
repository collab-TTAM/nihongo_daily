import 'dart:async';

import '../domain/srs_models.dart';

/// A local identity/lifecycle hint, never a credential or server authorization.
/// The Auth binding must replace this object on logout/account/session changes,
/// including A -> B -> A. An ordinary token refresh may retain it for the same
/// authenticated lifecycle. The hosted binding remains Issue #20 work.
final class ReviewSession {
  ReviewSession({required String userId}) : userId = userId.toLowerCase() {
    if (this.userId.length != 36 ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(this.userId)) {
      throw ArgumentError('Expected an account UUID');
    }
  }
  final String userId;
}

abstract interface class ReviewAuth {
  ReviewSession? get currentSession;
}

/// Must use capturedSession's authenticated client/credentials, rechecking the
/// session immediately before dispatch. Never silently select a different user's
/// current client. This port has no SDK implementation yet; fixture transports
/// cannot establish JWT validity, RPC availability or deployed authorization.
abstract interface class ReviewRpcTransport {
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String function,
    required Map<String, Object> params,
  });
}

enum ReviewErrorCode {
  unauthorized('UNAUTHORIZED', 'Phiên đăng nhập đã thay đổi hoặc hết hạn.'),
  forbidden('FORBIDDEN', 'Bạn không có quyền thực hiện thao tác này.'),
  notFound('NOT_FOUND', 'Nội dung học không còn khả dụng.'),
  validationFailure('VALIDATION_FAILURE', 'Dữ liệu ôn tập không hợp lệ.'),
  rateLimited('RATE_LIMITED', 'Đã đạt giới hạn yêu cầu. Vui lòng thử lại sau.'),
  networkUnavailable(
    'NETWORK_UNAVAILABLE',
    'Chưa xác nhận được kết quả lưu. Giữ nguyên lượt ôn để thử lại.',
  ),
  providerUnavailable(
    'PROVIDER_UNAVAILABLE',
    'Dịch vụ tạm thời không khả dụng.',
  ),
  syncConflict(
    'SYNC_CONFLICT',
    'Lượt ôn bị xung đột. Cần kiểm tra lịch ôn trên máy chủ.',
  ),
  internalError('INTERNAL_ERROR', 'Không thể xác nhận kết quả ôn tập.');

  const ReviewErrorCode(this.wireName, this.messageVi);
  final String wireName;
  final String messageVi;
}

/// A concrete transport binding translates recognized SDK/HTTP failures to this
/// safe type. No raw message, URL, headers, token, SQL or provider detail crosses
/// the repository. Unknown exceptions fail closed as INTERNAL_ERROR.
final class ReviewTransportFailure implements Exception {
  const ReviewTransportFailure(this.code, {this.retryable = false});
  final ReviewErrorCode code;
  final bool retryable;
}

sealed class ReviewOutcome {
  const ReviewOutcome();
}

final class ReviewFailure extends ReviewOutcome {
  ReviewFailure(this.code, {bool retryable = false})
    : retryable = retryable && _mayRetry(code);
  final ReviewErrorCode code;
  final bool retryable;
  String get messageVi => code.messageVi;
  Map<String, Object> toJson() => {
    'code': code.wireName,
    'message_vi': messageVi,
    'retryable': retryable,
  };
}

bool _mayRetry(ReviewErrorCode code) =>
    code == ReviewErrorCode.networkUnavailable ||
    code == ReviewErrorCode.providerUnavailable ||
    code == ReviewErrorCode.rateLimited;

/// Immutable server response only; never runs the local scheduler or mutates a
/// card. Original replies may precede newer card state on idempotent replay.
final class ReviewSuccess extends ReviewOutcome {
  const ReviewSuccess._({
    required this.state,
    required this.nextReviewAt,
    required this.nextReviewAtWire,
    required this.intervalDays,
    required this.difficulty,
    required this.reviewCount,
  });
  final SrsState state;
  final DateTime nextReviewAt;
  final String nextReviewAtWire;
  final double intervalDays;
  final double difficulty;
  final int reviewCount;
  Map<String, Object> toJson() => {
    'srs_state': state.wireName,
    'next_review_at': nextReviewAtWire,
    'interval_days': intervalDays,
    'difficulty': difficulty,
    'review_count': reviewCount,
  };
}

/// Strict decoded-object boundary. Unknown/mixed/missing fields, invalid scalar
/// types and malformed dates cannot be mistaken for persisted success. The wire
/// timestamp is retained exactly; DateTime is a microsecond display projection.
ReviewOutcome decodeReviewOutcome(Object? raw) {
  try {
    if (raw is! Map<String, Object?>) throw const FormatException();
    if (raw.containsKey('code')) {
      _keys(raw, const {'code', 'message_vi', 'retryable'});
      final message = raw['message_vi'];
      final retryable = raw['retryable'];
      if (message is! String ||
          message.runes.isEmpty ||
          message.runes.length > 500 ||
          retryable is! bool) {
        throw const FormatException();
      }
      final code = ReviewErrorCode.values.firstWhere(
        (value) => value.wireName == raw['code'],
      );
      if (retryable && !_mayRetry(code)) throw const FormatException();
      return ReviewFailure(code, retryable: retryable);
    }
    _keys(raw, const {
      'srs_state',
      'next_review_at',
      'interval_days',
      'difficulty',
      'review_count',
    });
    final state = SrsState.values.firstWhere(
      (value) => value.wireName == raw['srs_state'],
    );
    if (state == SrsState.newItem || state == SrsState.mastered) {
      throw const FormatException();
    }
    final interval = _number(raw['interval_days']);
    final difficulty = _number(raw['difficulty']);
    final count = _number(raw['review_count']);
    if (interval <= 0 ||
        difficulty < 0 ||
        difficulty > 1 ||
        count < 1 ||
        count > maxSrsCounter ||
        count != count.truncateToDouble()) {
      throw const FormatException();
    }
    final wire = raw['next_review_at'];
    if (wire is! String) throw const FormatException();
    return ReviewSuccess._(
      state: state,
      nextReviewAt: _timestamp(wire),
      nextReviewAtWire: wire,
      intervalDays: interval,
      difficulty: difficulty,
      reviewCount: count.toInt(),
    );
  } on Object {
    return ReviewFailure(ReviewErrorCode.internalError);
  }
}

void _keys(Map<String, Object?> value, Set<String> expected) {
  if (value.length != expected.length || !expected.every(value.containsKey)) {
    throw const FormatException();
  }
}

double _number(Object? value) {
  if (value is! num || !value.isFinite) throw const FormatException();
  return value.toDouble();
}

DateTime _timestamp(String value) {
  if (value.length > 4096) throw const FormatException();
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (match == null || match.end != value.length) throw const FormatException();
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match[i]!)];
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parts[0] < 1 ||
      date.year != parts[0] ||
      date.month != parts[1] ||
      date.day != parts[2] ||
      parts[3] > 23 ||
      parts[4] > 59 ||
      parts[5] > 59) {
    throw const FormatException();
  }
  final zone = match[8]!;
  if (zone != 'Z' &&
      (int.parse(zone.substring(1, 3)) > 23 ||
          int.parse(zone.substring(4)) > 59)) {
    throw const FormatException();
  }
  final instant = DateTime.parse(value).toUtc();
  if (instant.year < 1 || instant.year > 9999) throw const FormatException();
  return instant;
}

/// Session-bound immutable retry token. Reuse it after uncertain timeout/network
/// failure; do not regenerate the event ID, occurred_at or rating. Durable pending
/// event storage/restart recovery belongs to #15, not this in-memory token.
final class PreparedReview {
  PreparedReview._(this.session, SrsReview review)
    : request = Map<String, Object>.unmodifiable(review.toJson());
  final ReviewSession session;
  final Map<String, Object> request;
}

abstract interface class ReviewRepository {
  PreparedReview? prepare(SrsReview review);
  Future<ReviewOutcome> submit(PreparedReview review);
}

/// Typed RPC repository with injected Auth/transport ports. No hosted SDK wiring,
/// credential storage, automatic retry, demo success or direct table access.
final class RpcReviewRepository implements ReviewRepository {
  RpcReviewRepository({
    required this.auth,
    required this.transport,
    this.timeout = const Duration(seconds: 15),
  }) {
    if (timeout <= Duration.zero || timeout > const Duration(minutes: 2)) {
      throw ArgumentError('Expected a timeout in (0, 2 minutes]');
    }
  }
  final ReviewAuth auth;
  final ReviewRpcTransport transport;
  final Duration timeout;

  @override
  PreparedReview? prepare(SrsReview review) {
    final session = auth.currentSession;
    return session == null ? null : PreparedReview._(session, review);
  }

  @override
  Future<ReviewOutcome> submit(PreparedReview review) async {
    if (!identical(auth.currentSession, review.session)) {
      return ReviewFailure(ReviewErrorCode.unauthorized);
    }
    ReviewOutcome outcome;
    try {
      final raw = await transport
          .invoke(
            capturedSession: review.session,
            function: 'submit_review',
            params: Map<String, Object>.unmodifiable({
              'p_request': review.request,
            }),
          )
          .timeout(timeout);
      outcome = decodeReviewOutcome(raw);
    } on TimeoutException {
      outcome = ReviewFailure(
        ReviewErrorCode.networkUnavailable,
        retryable: true,
      );
    } on ReviewTransportFailure catch (failure) {
      outcome = ReviewFailure(failure.code, retryable: failure.retryable);
    } on Object {
      outcome = ReviewFailure(ReviewErrorCode.internalError);
    }
    // A completed/failed old-user call must not update the new account's UI.
    if (!identical(auth.currentSession, review.session)) {
      return ReviewFailure(ReviewErrorCode.unauthorized);
    }
    return outcome;
  }
}
