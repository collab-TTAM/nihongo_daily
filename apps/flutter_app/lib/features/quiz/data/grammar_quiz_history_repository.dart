import 'dart:async';

import '../../srs/data/review_repository.dart';
import '../domain/grammar_quiz_attempt.dart';
import 'grammar_quiz_attempt_store.dart';

/// Borrowed capability; storage remains owned through runtime shutdown.
abstract interface class GrammarQuizHistorySource {
  GrammarQuizHistoryRepository? createGrammarQuizHistoryRepository();
}

final class GrammarQuizSessionChanged implements Exception {
  const GrammarQuizSessionChanged();

  @override
  String toString() => 'Phiên đăng nhập đã thay đổi. Vui lòng mở lại lịch sử.';
}

/// Borrowed operations must settle before the owner releases the store.
final class GrammarQuizOperationDrain {
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
final class GrammarQuizHistoryRepository {
  factory GrammarQuizHistoryRepository({
    required ReviewAuth auth,
    required GrammarQuizAttemptStore store,
    required bool Function() isReady,
    required GrammarQuizOperationDrain operations,
  }) {
    try {
      if (operations.isClosing || !isReady()) {
        throw const GrammarQuizSessionChanged();
      }
      final session = auth.currentSession;
      if (session == null) throw const GrammarQuizSessionChanged();
      grammarHistoryUuid(session.userId);
      final result = GrammarQuizHistoryRepository._(
        auth,
        store,
        isReady,
        operations,
        session,
      );
      result._requireCurrent();
      return result;
    } on Object {
      throw const GrammarQuizSessionChanged();
    }
  }

  GrammarQuizHistoryRepository._(
    this._auth,
    this._store,
    this._isReady,
    this._operations,
    this._captured,
  );

  final ReviewAuth _auth;
  final GrammarQuizAttemptStore _store;
  final bool Function() _isReady;
  final GrammarQuizOperationDrain _operations;
  final ReviewSession _captured;
  final _active = <String, _QuizSave>{};
  bool _revoked = false;
  bool _checking = false;

  void _requireCurrent() {
    if (_checking) throw const GrammarQuizSessionChanged();
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
      throw const GrammarQuizSessionChanged();
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
      if (error is GrammarQuizHistoryConflict ||
          error is GrammarQuizStorageFailure) {
        rethrow;
      }
      throw const GrammarQuizStorageFailure();
    }
  }

  Future<OwnedGrammarQuizAttempt> save(GrammarQuizAttempt attempt) {
    try {
      _requireCurrent();
    } on GrammarQuizSessionChanged catch (failure) {
      return Future.error(failure);
    }
    final active = _active[attempt.eventId];
    if (active != null) {
      if (!sameGrammarQuizAttempt(active.attempt, attempt)) {
        return Future.error(const GrammarQuizHistoryConflict());
      }
      return active.result;
    }
    // Register before dispatch, even if a supplied port reenters save().
    final result = _operations.track(
      Future<OwnedGrammarQuizAttempt>.microtask(() => _save(attempt)),
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

  Future<OwnedGrammarQuizAttempt> _save(GrammarQuizAttempt attempt) async {
    final record = await _storage(
      () => _store.append(_captured.userId, attempt),
    );
    _requireCurrent();
    if (record.ownerId != _captured.userId ||
        !sameGrammarQuizAttempt(record.attempt, attempt)) {
      throw const GrammarQuizStorageFailure();
    }
    return record;
  }

  Future<List<OwnedGrammarQuizAttempt>> load() {
    try {
      _requireCurrent();
    } on GrammarQuizSessionChanged catch (failure) {
      return Future.error(failure);
    }
    return _operations.track(
      Future<List<OwnedGrammarQuizAttempt>>.microtask(_load),
    );
  }

  Future<List<OwnedGrammarQuizAttempt>> _load() async {
    final records = await _storage(() => _store.list(_captured.userId));
    _requireCurrent();
    if (records.length > 10000 ||
        records.any((record) => record.ownerId != _captured.userId)) {
      throw const GrammarQuizStorageFailure();
    }
    final unique = <String, OwnedGrammarQuizAttempt>{};
    for (final record in records) {
      final previous = unique[record.attempt.eventId];
      if (previous != null &&
          !sameGrammarQuizAttempt(previous.attempt, record.attempt)) {
        throw const GrammarQuizHistoryConflict();
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
    final snapshot = List<OwnedGrammarQuizAttempt>.unmodifiable(result);
    _requireCurrent(); // Validation/snapshot callbacks cannot publish old data.
    return snapshot;
  }
}

final class _QuizSave {
  const _QuizSave(this.attempt, this.result);
  final GrammarQuizAttempt attempt;
  final Future<OwnedGrammarQuizAttempt> result;
}
