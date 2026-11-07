import 'dart:async';
import 'dart:convert';
import '../../srs/data/review_repository.dart';
import '../domain/completed_study_session.dart';
import '../domain/daily_plan.dart';
import 'daily_plan_repository.dart';

/// Borrowed capability; the owner retains the store and SDK through shutdown.
abstract interface class DurableStudySessionSource {
  DurableStudySessionRepository? createDurableStudySessionRepository();
}

/// Revoke publication synchronously, then await every accepted operation before
/// releasing the SDK or store. Only unfinished futures are retained.
final class StudySessionOperationDrain {
  final _pending = <Future<void>>{};
  bool _revoked = false;
  Future<void>? _closing;
  bool get isClosing => _revoked;

  Future<T> track<T>(Future<T> operation) {
    final settled = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _pending.add(settled);
    unawaited(
      settled.then<void>((_) {
        _pending.remove(settled);
      }),
    );
    return operation;
  }

  Future<void> revokeAndDrain() => _closing ??= _drain();
  Future<void> _drain() async {
    _revoked = true;
    // Include registration from a reentrant store stage before awaiting it.
    await Future<void>.value();
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }
}

final class StudySessionStorageFailure implements Exception {
  const StudySessionStorageFailure();
  @override
  String toString() => 'Chưa thể xác nhận buổi học đã lưu trên thiết bị.';
}

bool isDefinitiveStudyRejection(DailyPlanFailure failure) =>
    !failure.retryable &&
    const {
      DailyPlanErrorCode.validationFailure,
      DailyPlanErrorCode.notFound,
      DailyPlanErrorCode.forbidden,
      DailyPlanErrorCode.syncConflict,
    }.contains(failure.code);

/// Local isolation keys never authorize RPCs. No token, score or progress cache.
final class StoredStudySession {
  StoredStudySession({
    required String userId,
    required this.event,
    this.acknowledged = false,
    this.rejection,
  }) : userId = ReviewSession(userId: userId).userId {
    if ((acknowledged && rejection != null) ||
        (rejection != null &&
            !isDefinitiveStudyRejection(DailyPlanFailure(rejection!)))) {
      throw const StudySessionStorageFailure();
    }
  }
  final String userId;
  final CompletedStudySession event;
  final bool acknowledged;
  final DailyPlanErrorCode? rejection;
  bool get isPending => !acknowledged && rejection == null;
}

/// stage/acknowledge/reject resolve only after durable commit. Implementations
/// serialize writes, preserve exact event identity, and fail closed on corruption.
abstract interface class StudySessionStore {
  Future<List<StoredStudySession>> list(String userId);
  Future<StoredStudySession> stage(String userId, CompletedStudySession event);
  Future<void> acknowledge(String userId, String eventId);
  Future<void> reject(String userId, String eventId, DailyPlanErrorCode code);
}

bool sameStudyEvent(CompletedStudySession a, CompletedStudySession b) =>
    jsonEncode(a.toJson()) == jsonEncode(b.toJson());

/// A durable server acknowledgment is separate from latest dashboard loading.
/// A reload error cannot turn an acknowledged event into an unsaved event.
final class StudySessionAcknowledgment {
  const StudySessionAcknowledgment._({
    required this.event,
    this.latestPlan,
    this.reloadFailure,
  });
  final CompletedStudySession event;
  final DailyPlan? latestPlan;
  final DailyPlanFailure? reloadFailure;
}

/// The caller supplies the same owned Auth lease/delegate and retains storage
/// through shutdown. Recovery never dispatches or grants local progress.
final class DurableStudySessionRepository {
  DurableStudySessionRepository({
    required this.auth,
    required this.delegate,
    required this.store,
    this.operations,
  }) : _captured = _readStudySession(auth) {
    if ((operations?.isClosing ?? false) || !delegate.isCurrent) {
      throw const DailyPlanFailure(DailyPlanErrorCode.unauthorized);
    }
  }
  final ReviewAuth auth;
  final DailyPlanRepository delegate;
  final StudySessionStore store;
  final StudySessionOperationDrain? operations;
  final ReviewSession _captured;
  bool _revoked = false;
  final _active = <String, _StudyDispatch>{};

  bool _current(ReviewSession session) {
    if (_revoked ||
        (operations?.isClosing ?? false) ||
        !identical(session, _captured)) {
      return false;
    }
    try {
      if (identical(auth.currentSession, _captured) && delegate.isCurrent) {
        return true;
      }
    } on Object {
      // Failed readiness/identity is permanent for this borrowed lease.
    }
    _revoked = true;
    return false;
  }

  void _requireCurrent(ReviewSession session) {
    if (!_current(session)) {
      throw const DailyPlanFailure(DailyPlanErrorCode.unauthorized);
    }
  }

  ReviewSession _capture() {
    if (_current(_captured)) return _captured;
    throw const DailyPlanFailure(DailyPlanErrorCode.unauthorized);
  }

  Future<T> _track<T>(Future<T> operation) =>
      operations?.track(operation) ?? operation;

  Future<List<CompletedStudySession>> recoverPending() =>
      _track(_recoverPending());

  Future<List<CompletedStudySession>> _recoverPending() async {
    final session = _capture();
    try {
      final records = await store.list(session.userId);
      _requireCurrent(session);
      if (records.any((record) => record.userId != session.userId)) {
        throw const StudySessionStorageFailure();
      }
      return List.unmodifiable([
        for (final record in records)
          if (record.isPending) record.event,
      ]);
    } on DailyPlanFailure {
      rethrow;
    } on Object {
      _requireCurrent(session);
      throw const StudySessionStorageFailure();
    }
  }

  Future<StudySessionAcknowledgment> submit(CompletedStudySession event) {
    final ReviewSession session;
    try {
      session = _capture();
    } on DailyPlanFailure catch (failure) {
      return Future.error(failure);
    }
    final key = '${session.userId}/${event.clientEventId}';
    final active = _active[key];
    if (active != null) {
      if (!identical(active.session, session) ||
          !sameStudyEvent(active.event, event)) {
        return Future.error(
          const DailyPlanFailure(DailyPlanErrorCode.syncConflict),
        );
      }
      return active.result;
    }
    final result = _track(_submit(session, event));
    final dispatch = _StudyDispatch(session, event, result);
    _active[key] = dispatch;
    void clear() {
      if (identical(_active[key], dispatch)) _active.remove(key);
    }

    result.then<void>(
      (_) => clear(),
      onError: (Object _, StackTrace __) => clear(),
    );
    return result;
  }

  Future<StudySessionAcknowledgment> _submit(
    ReviewSession session,
    CompletedStudySession event,
  ) async {
    try {
      StoredStudySession record;
      try {
        record = await store.stage(session.userId, event);
      } on DailyPlanFailure {
        rethrow;
      } on Object {
        throw const StudySessionStorageFailure();
      }
      _requireCurrent(session);
      if (record.userId != session.userId ||
          !sameStudyEvent(record.event, event)) {
        throw const StudySessionStorageFailure();
      }
      if (record.rejection != null) throw DailyPlanFailure(record.rejection!);
      if (!record.acknowledged) {
        try {
          // The original receipt can be older than current progress. It is
          // validated by the delegate but never published as the dashboard.
          await delegate.submit(record.event);
        } on DailyPlanFailure catch (failure) {
          _requireCurrent(session);
          if (isDefinitiveStudyRejection(failure)) {
            await _storeWrite(
              () => store.reject(
                record.userId,
                record.event.clientEventId,
                failure.code,
              ),
            );
          }
          rethrow;
        }
        _requireCurrent(session);
        await _storeWrite(
          () => store.acknowledge(record.userId, record.event.clientEventId),
        );
      }
      _requireCurrent(session);
      try {
        final latest = await delegate.load(record.event.date);
        _requireCurrent(session);
        return StudySessionAcknowledgment._(
          event: record.event,
          latestPlan: latest,
        );
      } on DailyPlanFailure catch (failure) {
        _requireCurrent(session);
        return StudySessionAcknowledgment._(
          event: record.event,
          reloadFailure: failure,
        );
      }
    } on DailyPlanFailure {
      _requireCurrent(session);
      rethrow;
    } on StudySessionStorageFailure {
      _requireCurrent(session);
      rethrow;
    } on Object {
      _requireCurrent(session);
      throw const DailyPlanFailure(DailyPlanErrorCode.internalError);
    }
  }

  Future<void> _storeWrite(Future<void> Function() write) async {
    try {
      await write();
    } on Object {
      throw const StudySessionStorageFailure();
    }
  }
}

ReviewSession _readStudySession(ReviewAuth auth) {
  try {
    final session = auth.currentSession;
    if (session != null) return session;
  } on Object {
    // Never expose raw Auth errors or credentials through construction.
  }
  throw const DailyPlanFailure(DailyPlanErrorCode.unauthorized);
}

final class _StudyDispatch {
  const _StudyDispatch(this.session, this.event, this.result);
  final ReviewSession session;
  final CompletedStudySession event;
  final Future<StudySessionAcknowledgment> result;
}
