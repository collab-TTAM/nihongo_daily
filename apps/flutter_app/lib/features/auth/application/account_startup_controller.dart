import 'dart:async';
import '../../daily_plan/data/daily_plan_repository.dart';
import '../../daily_plan/data/durable_study_session_repository.dart';
import '../../quiz/data/vocabulary_quiz_history_repository.dart';
import 'account_session_notice.dart';
import 'account_session_refresh.dart';

enum AccountStartupPhase {
  idle,
  loading,
  active,
  restoreError,
  openError,
  cleanupError,
  closed,
}

/// Owned startup port. Failed start must fence Auth/study before offering login.
abstract interface class AccountStartupRuntime<T> {
  T get account;
  bool get canOfferLogin;
  Future<void> start();
  Future<void> close();
}

abstract interface class ResumableAccountStartup {
  void resume();
}

final class AccountStartupCleanupFailure implements Exception {
  const AccountStartupCleanupFailure();
  @override
  String toString() => 'Account startup cleanup unavailable';
}

/// One factory/owner, explicit retry only. Public state contains no credentials.
final class AccountStartupController<T> {
  AccountStartupController(this.open);
  final Future<AccountStartupRuntime<T>> Function() open;
  final _events = StreamController<AccountStartupPhase>.broadcast();
  late final Stream<AccountStartupPhase> changes = _events.stream;
  AccountStartupPhase _phase = AccountStartupPhase.idle;
  AccountStartupPhase get phase => _phase;
  AccountStartupRuntime<T>? _runtime;
  Future<void>? _operation;
  Future<void>? _closing;
  bool _closed = false;
  T? get account =>
      _phase == AccountStartupPhase.active ? _runtime?.account : null;
  DailyPlanRepositorySource? get dailyPlanSource {
    final runtime = _runtime;
    if (!_closed &&
        _phase == AccountStartupPhase.active &&
        runtime is DailyPlanRepositorySource) {
      return runtime as DailyPlanRepositorySource;
    }
    return null;
  }

  DurableStudySessionSource? get durableStudySource {
    final runtime = _runtime;
    if (!_closed &&
        _phase == AccountStartupPhase.active &&
        runtime is DurableStudySessionSource) {
      return runtime as DurableStudySessionSource;
    }
    return null;
  }

  VocabularyQuizHistorySource? get quizHistorySource {
    final runtime = _runtime;
    if (!_closed &&
        _phase == AccountStartupPhase.active &&
        runtime is VocabularyQuizHistorySource) {
      return runtime as VocabularyQuizHistorySource;
    }
    return null;
  }

  AccountSessionNoticeSource? get noticeSource {
    final runtime = _runtime;
    if (!_closed &&
        _phase == AccountStartupPhase.active &&
        runtime is AccountSessionNoticeSource) {
      return runtime as AccountSessionNoticeSource;
    }
    return null;
  }

  bool get canOfferLogin =>
      !_closed &&
      _phase == AccountStartupPhase.restoreError &&
      (_runtime?.canOfferLogin ?? false);

  AccountSessionRefreshAction? get refreshAction {
    final runtime = _runtime;
    if (!_closed &&
        _phase == AccountStartupPhase.active &&
        runtime is AccountSessionRefreshAction) {
      return runtime as AccountSessionRefreshAction;
    }
    return null;
  }

  void _set(AccountStartupPhase phase) {
    if (_closed) return;
    _phase = phase;
    _events.add(phase);
  }

  Future<void> _cleanup() async {
    final runtime = _runtime;
    if (runtime == null) return;
    try {
      await runtime.close();
      _runtime = null;
    } on Object {
      throw const AccountStartupCleanupFailure();
    }
  }

  Future<void> start() {
    if (_closed || _phase != AccountStartupPhase.idle) return Future.value();
    return _begin();
  }

  Future<void> retry() {
    if (_closed ||
        !const {
          AccountStartupPhase.openError,
          AccountStartupPhase.restoreError,
          AccountStartupPhase.cleanupError,
        }.contains(_phase)) {
      return Future.value();
    }
    return _begin();
  }

  Future<void> _begin() {
    if (_operation != null) return _operation!;
    _set(AccountStartupPhase.loading);
    final operation = _run();
    _operation = operation;
    return operation;
  }

  Future<void> _run() async {
    try {
      try {
        await _cleanup();
      } on Object {
        _set(AccountStartupPhase.cleanupError);
        return;
      }
      if (_closed) return;
      try {
        _runtime = await open();
      } on Object {
        _set(AccountStartupPhase.openError);
        return;
      }
      if (_closed) return;
      try {
        await _runtime!.start();
        _set(AccountStartupPhase.active);
      } on Object {
        _set(AccountStartupPhase.restoreError);
      }
    } finally {
      _operation = null;
    }
  }

  void resume() {
    final runtime = _runtime;
    if (!_closed &&
        _phase == AccountStartupPhase.active &&
        runtime != null &&
        runtime is ResumableAccountStartup) {
      (runtime as ResumableAccountStartup).resume();
    }
  }

  /// Explicitly expose the fenced account form. Its login operation owns cleanup.
  void offerLogin() {
    if (canOfferLogin) _set(AccountStartupPhase.active);
  }

  /// Revoke publication immediately; drain late factory/start before cleanup.
  /// Failed cleanup remains retryable by calling close again, never opening anew.
  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    _phase = AccountStartupPhase.closed;
    if (!_events.isClosed) _events.add(_phase);
    final operation = _finishClose();
    _closing = operation;
    return operation;
  }

  Future<void> _finishClose() async {
    try {
      await _operation;
      await _cleanup();
      if (!_events.isClosed) await _events.close();
    } finally {
      _closing = null;
    }
  }
}
