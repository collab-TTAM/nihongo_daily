import 'dart:async';

import '../../srs/data/review_repository.dart';
import '../domain/vocabulary_quiz_attempt.dart';
import '../domain/vocabulary_quiz_progress.dart';
import 'vocabulary_quiz_attempt_store.dart';

/// Borrowed capability; storage remains owned through runtime shutdown.
abstract interface class VocabularyQuizHistorySource {
  VocabularyQuizHistoryRepository? createVocabularyQuizHistoryRepository();
}

final class VocabularyQuizSessionChanged implements Exception {
  const VocabularyQuizSessionChanged();

  @override
  String toString() => 'Phiên đăng nhập đã thay đổi. Vui lòng mở lại lịch sử.';
}

/// Borrowed operations must settle before the owner releases the store.
final class VocabularyQuizOperationDrain {
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
    await Future<void>.value();
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }
}

/// Local reports only. A trusted owner supplies ready Auth and runtime fences;
/// these ports do not establish JWT validity or authorize a hosted endpoint.
/// The caller owns storage and must revoke/drain before closing it.
final class VocabularyQuizHistoryRepository {
  factory VocabularyQuizHistoryRepository({
    required ReviewAuth auth,
    required VocabularyQuizAttemptStore store,
    required bool Function() isReady,
    required VocabularyQuizOperationDrain operations,
  }) {
    try {
      if (operations.isClosing || !isReady()) {
        throw const VocabularyQuizSessionChanged();
      }
      final session = auth.currentSession;
      if (session == null) throw const VocabularyQuizSessionChanged();
      quizHistoryUuid(session.userId);
      final result = VocabularyQuizHistoryRepository._(
        auth,
        store,
        isReady,
        operations,
        session,
      );
      result._requireCurrent();
      return result;
    } on Object {
      throw const VocabularyQuizSessionChanged();
    }
  }

  VocabularyQuizHistoryRepository._(
    this._auth,
    this._store,
    this._isReady,
    this._operations,
    this._captured,
  );

  final ReviewAuth _auth;
  final VocabularyQuizAttemptStore _store;
  final bool Function() _isReady;
  final VocabularyQuizOperationDrain _operations;
  final ReviewSession _captured;
  final _active = <String, _QuizSave>{};
  bool _revoked = false;
  bool _checking = false;

  void _requireCurrent() {
    if (_checking) throw const VocabularyQuizSessionChanged();
    _checking = true;
    try {
      if (!_revoked && !_operations.isClosing) {
        try {
          if (_isReady() &&
              identical(_auth.currentSession, _captured) &&
              _isReady() &&
              identical(_auth.currentSession, _captured) &&
              !_operations.isClosing &&
              !_revoked) {
            return;
          }
        } on Object {
          // Raw Auth/readiness errors never cross this boundary.
        }
      }
      _revoked = true;
      throw const VocabularyQuizSessionChanged();
    } finally {
      _checking = false;
    }
  }

  Future<T> _storage<T>(Future<T> Function() operation) async {
    _requireCurrent();
    try {
      final result = await operation();
      _requireCurrent();
      return result;
    } on Object catch (error) {
      _requireCurrent();
      if (error is VocabularyQuizHistoryConflict ||
          error is VocabularyQuizStorageFailure) {
        rethrow;
      }
      throw const VocabularyQuizStorageFailure();
    }
  }

  Future<OwnedVocabularyQuizAttempt> save(VocabularyQuizAttempt attempt) {
    try {
      _requireCurrent();
    } on VocabularyQuizSessionChanged catch (failure) {
      return Future.error(failure);
    }
    final active = _active[attempt.eventId];
    if (active != null) {
      if (!sameVocabularyQuizAttempt(active.attempt, attempt)) {
        return Future.error(const VocabularyQuizHistoryConflict());
      }
      return active.result;
    }
    // Register before dispatch, even if a supplied port reenters save().
    final result = _operations.track(
      Future<OwnedVocabularyQuizAttempt>.microtask(() => _save(attempt)),
    );
    final dispatch = _QuizSave(attempt, result);
    _active[attempt.eventId] = dispatch;
    void clear() {
      if (identical(_active[attempt.eventId], dispatch)) {
        _active.remove(attempt.eventId);
      }
    }

    unawaited(
      result.then<void>(
        (_) => clear(),
        onError: (Object _, StackTrace __) => clear(),
      ),
    );
    return result;
  }

  Future<OwnedVocabularyQuizAttempt> _save(
    VocabularyQuizAttempt attempt,
  ) async {
    final record = await _storage(
      () => _store.append(_captured.userId, attempt),
    );
    _requireCurrent();
    if (record.ownerId != _captured.userId ||
        !sameVocabularyQuizAttempt(record.attempt, attempt)) {
      throw const VocabularyQuizStorageFailure();
    }
    return record;
  }

  Future<List<OwnedVocabularyQuizAttempt>> load() {
    try {
      _requireCurrent();
    } on VocabularyQuizSessionChanged catch (failure) {
      return Future.error(failure);
    }
    return _operations.track(
      Future<List<OwnedVocabularyQuizAttempt>>.microtask(_load),
    );
  }

  Future<List<OwnedVocabularyQuizAttempt>> _load() async {
    final records = await _storage(() => _store.list(_captured.userId));
    _requireCurrent();
    if (records.length > 10000 ||
        records.any((record) => record.ownerId != _captured.userId)) {
      throw const VocabularyQuizStorageFailure();
    }
    final unique = <String, OwnedVocabularyQuizAttempt>{};
    for (final record in records) {
      final previous = unique[record.attempt.eventId];
      if (previous != null &&
          !sameVocabularyQuizAttempt(previous.attempt, record.attempt)) {
        throw const VocabularyQuizHistoryConflict();
      }
      unique[record.attempt.eventId] = record;
    }
    final result = unique.values.toList();
    result.sort((left, right) {
      final instant = left.attempt.completedAt;
      final time = instant.compareTo(right.attempt.completedAt);
      return time == 0
          ? left.attempt.eventId.compareTo(right.attempt.eventId)
          : time;
    });
    return List.unmodifiable(result);
  }
}

final class _QuizSave {
  const _QuizSave(this.attempt, this.result);
  final VocabularyQuizAttempt attempt;
  final Future<OwnedVocabularyQuizAttempt> result;
}
