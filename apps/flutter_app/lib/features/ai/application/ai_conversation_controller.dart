import 'dart:async';

import '../data/captured_ai_text_repository.dart';
import '../data/captured_conversation_session.dart';
import '../domain/ai_text_models.dart';
import '../domain/conversation_requests.dart';

enum AiConversationPhase { unavailable, ready, loading, error, pending }

enum AiConversationOperation { start, turn, finish }

/// Ephemeral view projection only. Scores/references never authorize writes.
final class AiConversationState {
  const AiConversationState._(
    this.phase, {
    this.conversation,
    this.operation,
    this.failure,
    this.hasUnresolvedMutation = false,
  });
  final AiConversationPhase phase;
  final ConversationSessionSnapshot? conversation;
  final AiConversationOperation? operation;
  final AiTextFailure? failure;
  final bool hasUnresolvedMutation;
}

/// Borrows one retained ready-generation flow. Only explicit commands dispatch;
/// neither construction, recheck, remount nor disposal resets its receipt lane.
final class AiConversationController {
  AiConversationController({
    CapturedConversationSession? session,
    Stream<void>? availabilityChanges,
  }) : _session = session {
    checkAvailability();
    if (!_revoked) {
      if (_session!.hasUnresolvedMutation) _phase = AiConversationPhase.pending;
      try {
        _subscription = availabilityChanges?.listen(
          (_) => recheck(),
          onError: (Object _, StackTrace _) => invalidate(),
          onDone: invalidate,
        );
      } on Object {
        invalidate();
      }
    }
  }

  final CapturedConversationSession? _session;
  final _changes = StreamController<void>.broadcast();
  late final Stream<void> changes = _changes.stream;
  StreamSubscription<void>? _subscription;
  ConversationSessionSnapshot? _projection;
  _Command? _pending;
  AiTextFailure? _failure;
  AiConversationPhase _phase = AiConversationPhase.ready;
  bool _checking = false;
  bool _submitting = false;
  bool _revoked = false;
  bool _disposed = false;
  int _epoch = 0;

  AiConversationState get state {
    // A supplied readiness getter may synchronously reenter a view read. Never
    // publish a retained projection before the outer check establishes authority.
    if (_checking || _session?.isCheckingAvailability == true) {
      return const AiConversationState._(AiConversationPhase.unavailable);
    }
    checkAvailability();
    if (_revoked) {
      return const AiConversationState._(AiConversationPhase.unavailable);
    }
    return AiConversationState._(
      _phase,
      conversation: _projection,
      operation: _pending?.operation,
      failure: _failure,
      hasUnresolvedMutation: _session!.hasUnresolvedMutation,
    );
  }

  bool get canStart => _canNew(ConversationSessionPhase.notStarted);
  bool get canTurn => _canNew(ConversationSessionPhase.active);
  bool get canFinish => _canNew(ConversationSessionPhase.active);
  bool get canRetry {
    if (_checking ||
        _submitting ||
        _revoked ||
        _session?.isCheckingAvailability == true) {
      return false;
    }
    checkAvailability();
    return !_revoked &&
        _pending != null &&
        _retryAllowed &&
        _session!.hasUnresolvedMutation &&
        !_session.isBusy;
  }

  /// Separate explicit host action after a view discarded its local DTO.
  /// Does not reconstruct a command or change legacy canRetry semantics.
  bool get canRecoverRetained {
    if (_checking ||
        _submitting ||
        _revoked ||
        _session?.isCheckingAvailability == true) {
      return false;
    }
    checkAvailability();
    if (_revoked || _pending != null) return false;
    final allowed = _session!.canRetryRetained;
    checkAvailability();
    return allowed && !_revoked && _pending == null;
  }

  Future<void> recoverRetained() async {
    if (!canRecoverRetained) return;
    _submitting = true;
    final epoch = _epoch;
    bool current() {
      checkAvailability();
      return !_revoked && epoch == _epoch;
    }

    try {
      if (!current()) return;
      _failure = null;
      _phase = AiConversationPhase.loading;
      _notify();
      await _session!.retryRetained();
      if (current()) {
        _phase = _session.hasUnresolvedMutation
            ? AiConversationPhase.pending
            : AiConversationPhase.ready;
      }
    } on AiTextRequestPending {
      if (current()) _phase = AiConversationPhase.pending;
    } on AiTextFailure catch (failure) {
      if (failure.code == AiTextErrorCode.unauthorized) invalidate();
      if (current()) _error(failure);
    } on Object {
      if (current()) _error(const AiTextFailure(AiTextErrorCode.internalError));
    } finally {
      _submitting = false;
      if (!_revoked) checkAvailability();
      _notify();
    }
  }

  bool get _retryAllowed =>
      _failure?.retryable == true ||
      (_failure == null && _phase == AiConversationPhase.pending);

  bool _canNew(ConversationSessionPhase phase) {
    if (_checking ||
        _submitting ||
        _revoked ||
        _session?.isCheckingAvailability == true) {
      return false;
    }
    checkAvailability();
    return !_revoked &&
        _projection!.phase == phase &&
        _pending == null &&
        !_session!.hasUnresolvedMutation &&
        !_session.isBusy;
  }

  void checkAvailability() {
    if (_revoked || _checking || _session?.isCheckingAvailability == true) {
      return;
    }
    _checking = true;
    try {
      if (_session?.isCurrent != true) {
        invalidate();
        return;
      }
      final projection = _session!.snapshot;
      if (projection.phase == ConversationSessionPhase.revoked) {
        invalidate();
      } else if (!_revoked) {
        _projection = projection;
      }
    } on Object {
      invalidate();
    } finally {
      _checking = false;
    }
  }

  /// Availability hint only: never polls, retries, clears an event or creates IDs.
  void recheck() {
    checkAvailability();
    _notify();
  }

  /// Clears this view's retained request/projection synchronously. Runtime still
  /// owns revocation/drain; a replacement view must borrow its retained flow.
  void invalidate() {
    if (_revoked) return;
    _revoked = true;
    _epoch++;
    _projection = null;
    _pending = null;
    _failure = null;
    _phase = AiConversationPhase.unavailable;
    _notify();
  }

  Future<void> start({
    required String scenarioId,
    required AiTextLevel level,
    required String clientEventId,
  }) => _submit(false, () {
    _requirePhase(ConversationSessionPhase.notStarted);
    if (level != AiTextLevel.n5 && level != AiTextLevel.n4) {
      throw const FormatException('Expected N5 or N4');
    }
    return _Start(
      StartConversationRequest(
        scenarioId: scenarioId,
        level: level,
        clientEventId: clientEventId,
      ),
    );
  });

  Future<void> turn({required String textJa, required String clientEventId}) =>
      _submit(false, () {
        _requirePhase(ConversationSessionPhase.active);
        return _Turn(
          ConversationTurnRequest(
            sessionId: _projection!.sessionId!,
            clientEventId: clientEventId,
            textJa: textJa,
          ),
        );
      });

  Future<void> finish({required String clientEventId}) => _submit(false, () {
    _requirePhase(ConversationSessionPhase.active);
    return _Finish(
      FinishConversationRequest(
        sessionId: _projection!.sessionId!,
        clientEventId: clientEventId,
      ),
    );
  });

  /// Explicitly resubmits the original immutable DTO only after the old wire
  /// drains and a safe retryable failure. No caller edits or fresh event accepted.
  Future<void> retryPending() => _submit(true, () => _pending!);

  void _requirePhase(ConversationSessionPhase phase) {
    if (_projection?.phase != phase) {
      throw const AiTextFailure(AiTextErrorCode.syncConflict);
    }
  }

  Future<void> _submit(bool retry, _Command Function() create) async {
    if (_checking ||
        _submitting ||
        _revoked ||
        _session?.isCheckingAvailability == true) {
      return;
    }
    _submitting = true; // Before supplied readiness/port callbacks can reenter.
    final epoch = _epoch;
    bool current() {
      checkAvailability();
      return !_revoked && epoch == _epoch;
    }

    try {
      if (!current()) return;
      if (_session!.isBusy ||
          (!retry && (_pending != null || _session.hasUnresolvedMutation))) {
        _phase = AiConversationPhase.pending;
        _notify();
        return;
      }
      if (retry &&
          (_pending == null ||
              !_retryAllowed ||
              !_session.hasUnresolvedMutation)) {
        return;
      }
      final command = create(); // Validate locally before retaining any input.
      _pending = command;
      _failure = null;
      _phase = AiConversationPhase.loading;
      _notify();
      await Future<void>.sync(() {
        if (!current()) {
          throw const AiTextFailure(AiTextErrorCode.unauthorized);
        }
        return command.dispatch(_session);
      });
      if (!current()) return;
      _pending = null;
      _phase = AiConversationPhase.ready;
    } on AiTextRequestPending {
      if (current()) _phase = AiConversationPhase.pending;
    } on FormatException {
      if (current()) {
        _error(const AiTextFailure(AiTextErrorCode.validationFailure));
      }
    } on AiTextFailure catch (failure) {
      if (failure.code == AiTextErrorCode.unauthorized) invalidate();
      if (current()) _error(failure);
    } on Object {
      if (current()) {
        _error(const AiTextFailure(AiTextErrorCode.internalError));
      }
    } finally {
      if (!_revoked && !_session!.hasUnresolvedMutation) _pending = null;
      _submitting = false;
      _notify();
    }
  }

  void _error(AiTextFailure failure) {
    _failure = failure;
    _phase = AiConversationPhase.error;
  }

  void _notify() {
    // Never queue text/state snapshots that could outlive the captured account.
    if (!_disposed && !_changes.isClosed) _changes.add(null);
  }

  void dispose() {
    if (_disposed) return;
    invalidate();
    _disposed = true;
    unawaited(_cancelSubscription());
    unawaited(
      _changes.close(),
    ); // A paused view cannot hold owner shutdown open.
  }

  Future<void> _cancelSubscription() async {
    try {
      await _subscription?.cancel();
    } on Object {
      // A borrowed hint stream's cancellation error contains no safe UI data.
    }
  }
}

sealed class _Command {
  const _Command();
  AiConversationOperation get operation;
  Future<void> dispatch(CapturedConversationSession session);
}

final class _Start extends _Command {
  const _Start(this.request);
  final StartConversationRequest request;
  @override
  AiConversationOperation get operation => AiConversationOperation.start;
  @override
  Future<void> dispatch(CapturedConversationSession session) async {
    await session.start(request);
  }
}

final class _Turn extends _Command {
  const _Turn(this.request);
  final ConversationTurnRequest request;
  @override
  AiConversationOperation get operation => AiConversationOperation.turn;
  @override
  Future<void> dispatch(CapturedConversationSession session) async {
    await session.turn(request);
  }
}

final class _Finish extends _Command {
  const _Finish(this.request);
  final FinishConversationRequest request;
  @override
  AiConversationOperation get operation => AiConversationOperation.finish;
  @override
  Future<void> dispatch(CapturedConversationSession session) async {
    await session.finish(request);
  }
}
