import 'dart:convert';

import '../domain/srs_models.dart';
import 'review_repository.dart';

/// Local learning data only; owner is an isolation key, never RPC authorization.
final class StoredReview {
  StoredReview({
    required String userId,
    required Object? request,
    this.receipt,
    this.rejection,
  }) : userId = ReviewSession(userId: userId).userId,
       request = decodeStoredReviewRequest(request) {
    if ((receipt != null && rejection != null) ||
        (rejection != null && !isDefinitiveReviewRejection(rejection!))) {
      throw const ReviewStorageFailure();
    }
  }
  final String userId;
  final Map<String, Object> request;
  final ReviewSuccess? receipt;
  final ReviewFailure? rejection;
  bool get isPending => receipt == null && rejection == null;
  String get eventId => request['client_event_id']! as String;
}

/// Safe local failure. Never include paths, file contents or raw exceptions.
final class ReviewStorageFailure implements Exception {
  const ReviewStorageFailure();
  @override
  String toString() =>
      'Không thể xác nhận dữ liệu ôn tập đã lưu trên thiết bị.';
}

/// Implementations must serialize writes, flush pending before returning stage,
/// preserve immutable identities/receipts, and fail closed on corruption.
abstract interface class DurableReviewStore {
  Future<List<StoredReview>> list(String userId);
  Future<StoredReview> stage(String userId, Map<String, Object> request);
  Future<void> acknowledge(
    String userId,
    String eventId,
    ReviewSuccess receipt,
  );
  Future<void> reject(String userId, String eventId, ReviewFailure rejection);
}

bool isDefinitiveReviewRejection(ReviewFailure failure) =>
    !failure.isLocalStorage &&
    !failure.retryable &&
    const {
      ReviewErrorCode.validationFailure,
      ReviewErrorCode.notFound,
      ReviewErrorCode.forbidden,
      ReviewErrorCode.syncConflict,
    }.contains(failure.code);

abstract interface class ReviewRecovery {
  Future<List<PreparedReview>> recoverPending();
}

bool sameReviewRequest(Map<String, Object> a, Map<String, Object> b) =>
    jsonEncode(decodeStoredReviewRequest(a)) ==
    jsonEncode(decodeStoredReviewRequest(b));

/// Write-before-dispatch and durable original-receipt replay. Explicit opt-in;
/// configured controllers recover through ReviewRecovery; default app is unconfigured.
/// Call recoverPending under fresh Auth before loading new due cards. Recovered
/// events need explicit manual submit; never auto-send or mutate server state.
final class DurableReviewRepository
    implements ReviewRepository, ReviewRecovery {
  DurableReviewRepository({
    required this.auth,
    required this.delegate,
    required this.store,
  });
  final ReviewAuth auth;
  final ReviewRepository delegate;
  final DurableReviewStore store;
  final _active = <String, _Dispatch>{};

  @override
  PreparedReview? prepare(SrsReview review) => delegate.prepare(review);

  bool _current(ReviewSession session) =>
      identical(session, auth.currentSession);

  /// Reads only the currently authenticated owner's journal. Old lifecycle
  /// results are rejected, including A -> B -> A and same-user fresh sign-in.
  @override
  Future<List<PreparedReview>> recoverPending() async {
    final session = auth.currentSession;
    if (session == null) {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
    List<StoredReview> records;
    try {
      records = await store.list(session.userId);
    } on Object {
      if (!_current(session)) {
        throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
      }
      throw const ReviewStorageFailure();
    }
    if (!_current(session)) {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
    if (records.any((record) => record.userId != session.userId)) {
      throw const ReviewStorageFailure();
    }
    return List<PreparedReview>.unmodifiable([
      for (final record in records)
        if (record.isPending) PreparedReview.restore(session, record.request),
    ]);
  }

  @override
  Future<ReviewOutcome> submit(PreparedReview review) {
    if (!_current(review.session)) {
      return Future.value(ReviewFailure(ReviewErrorCode.unauthorized));
    }
    final key = '${review.session.userId}/${review.request['client_event_id']}';
    final active = _active[key];
    if (active != null) {
      if (!identical(active.review.session, review.session) ||
          !sameReviewRequest(active.review.request, review.request)) {
        return Future.value(ReviewFailure(ReviewErrorCode.syncConflict));
      }
      return active.result;
    }
    final result = _submit(review);
    final dispatch = _Dispatch(review, result);
    _active[key] = dispatch;
    // _submit always normalizes failures; the cleanup future cannot leak one.
    result.then((_) {
      if (identical(_active[key], dispatch)) _active.remove(key);
    });
    return result;
  }

  Future<ReviewOutcome> _submit(PreparedReview review) async {
    try {
      StoredReview record;
      try {
        record = await store.stage(review.session.userId, review.request);
      } on ReviewTransportFailure {
        rethrow;
      } on Object {
        throw const ReviewStorageFailure();
      }
      if (!_current(review.session)) {
        return ReviewFailure(ReviewErrorCode.unauthorized);
      }
      if (record.userId != review.session.userId ||
          !sameReviewRequest(record.request, review.request)) {
        return ReviewFailure(ReviewErrorCode.syncConflict);
      }
      // An immutable historical receipt, never current scheduling authority.
      if (record.receipt != null) return record.receipt!;
      if (record.rejection != null) return record.rejection!;
      final result = await delegate.submit(review);
      try {
        if (result is ReviewSuccess) {
          await store.acknowledge(record.userId, record.eventId, result);
        } else if (result is ReviewFailure &&
            isDefinitiveReviewRejection(result)) {
          await store.reject(record.userId, record.eventId, result);
        }
      } on Object {
        throw const ReviewStorageFailure();
      }
      if (!_current(review.session)) {
        return ReviewFailure(ReviewErrorCode.unauthorized);
      }
      return result;
    } on ReviewStorageFailure {
      return _current(review.session)
          ? ReviewFailure.storage()
          : ReviewFailure(ReviewErrorCode.unauthorized);
    } on ReviewTransportFailure catch (failure) {
      return ReviewFailure(
        _current(review.session) ? failure.code : ReviewErrorCode.unauthorized,
        retryable: failure.retryable,
      );
    } on Object {
      // Disk failure before dispatch sends nothing. Failure after server success
      // retains an uncertain event; only the original replay can reconcile it.
      return ReviewFailure(
        _current(review.session)
            ? ReviewErrorCode.internalError
            : ReviewErrorCode.unauthorized,
      );
    }
  }
}

final class _Dispatch {
  const _Dispatch(this.review, this.result);
  final PreparedReview review;
  final Future<ReviewOutcome> result;
}
