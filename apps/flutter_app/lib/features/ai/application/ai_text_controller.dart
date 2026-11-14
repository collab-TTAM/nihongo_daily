import 'dart:async';

import '../data/captured_ai_text_repository.dart';
import '../domain/ai_text_models.dart';

enum AiTextPhase { unavailable, idle, loading, success, error, pending }

enum AiTextOperation { explain, correct }

/// Ephemeral view data only. A result never implies saved progress or mastery.
final class AiTextState {
  const AiTextState._(
    this.phase, {
    this.operation,
    this.level,
    this.submittedText,
    this.explanation,
    this.correction,
    this.failure,
  });

  final AiTextPhase phase;
  final AiTextOperation? operation;
  final AiTextLevel? level;
  final String? submittedText;
  final TutorExplanation? explanation;
  final SentenceCorrection? correction;
  final AiTextFailure? failure;
}

/// One view borrows one captured ready-generation capability. Never retarget a
/// mounted controller to another account/repository. The host must invalidate it
/// synchronously on readiness loss, then create a fresh view/controller when ready.
/// No SDK, resource ownership, persistence, timers or automatic resubmission.
final class AiTextController {
  AiTextController({
    CapturedAiTextRepository? repository,
    Stream<void>? availabilityChanges,
  }) : _repository = repository {
    checkAvailability();
    if (!_revoked) {
      _subscription = availabilityChanges?.listen(
        (_) => checkAvailability(),
        onError: (Object _, StackTrace _) => invalidate(),
        onDone: invalidate,
      );
    }
  }

  final CapturedAiTextRepository? _repository;
  final _changes = StreamController<void>.broadcast();
  late final Stream<void> changes = _changes.stream;
  StreamSubscription<void>? _subscription;
  AiTextState _state = const AiTextState._(AiTextPhase.idle);
  bool _revoked = false;
  bool _disposed = false;
  bool _submitting = false;
  int _epoch = 0;

  /// Check the lease on every view read, not just an asynchronous notification.
  AiTextState get state {
    checkAvailability();
    return _state;
  }

  bool get canSubmit {
    checkAvailability();
    return !_revoked && !_submitting && !_repository!.isBusy;
  }

  void checkAvailability() {
    if (_revoked) return;
    if (_repository?.isCurrent != true) invalidate();
  }

  /// Explicit UI recheck after an uncertain request; no polling or redispatch.
  /// The borrowed repository may finish draining without publishing a UI event.
  void recheck() {
    checkAvailability();
    _notify();
  }

  /// Clear private text/results immediately. Does not revoke or close a borrowed
  /// repository; the runtime owner independently revokes/drains its HTTP work.
  void invalidate() {
    if (_revoked) return;
    _revoked = true;
    _epoch++;
    _publish(const AiTextState._(AiTextPhase.unavailable));
  }

  /// Forget a settled result. Never treats clearing a view as request cancellation.
  bool clearResult() {
    if (!canSubmit) return false;
    _publish(const AiTextState._(AiTextPhase.idle));
    return true;
  }

  Future<void> explain({
    required AiTextLevel level,
    required String questionVi,
  }) => _submit(AiTextOperation.explain, level, questionVi, () {
    _requireLevel(level);
    return _repository!.explain(
      TutorExplainRequest(level: level, questionVi: questionVi),
    );
  });

  Future<void> correct({
    required AiTextLevel level,
    required String sentenceJa,
  }) => _submit(AiTextOperation.correct, level, sentenceJa, () {
    _requireLevel(level);
    return _repository!.correct(
      CorrectSentenceRequest(level: level, sentenceJa: sentenceJa),
    );
  });

  Future<void> _submit(
    AiTextOperation operation,
    AiTextLevel level,
    String text,
    Future<Object> Function() dispatch,
  ) async {
    // Register before any supplied readiness getter/transport can reenter.
    if (_submitting || _revoked) return;
    _submitting = true;
    final epoch = _epoch;
    bool current() {
      checkAvailability();
      return !_revoked && epoch == _epoch;
    }

    try {
      if (!current()) return;
      if (_repository!.isBusy) {
        _publish(const AiTextState._(AiTextPhase.pending));
        return;
      }
      _publish(
        AiTextState._(AiTextPhase.loading, operation: operation, level: level),
      );
      final result = await Future<Object>.sync(() {
        if (!current()) {
          throw const AiTextFailure(AiTextErrorCode.unauthorized);
        }
        return dispatch();
      });
      if (!current()) return;
      _publish(
        AiTextState._(
          AiTextPhase.success,
          operation: operation,
          level: level,
          submittedText: text,
          explanation: result is TutorExplanation ? result : null,
          correction: result is SentenceCorrection ? result : null,
        ),
      );
    } on AiTextRequestPending {
      if (current()) _publish(const AiTextState._(AiTextPhase.pending));
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
      _submitting = false;
      _notify(); // Availability only; never dispatch or replay a request.
    }
  }

  void _error(AiTextFailure failure) {
    _publish(AiTextState._(AiTextPhase.error, failure: failure));
  }

  void _publish(AiTextState value) {
    _state = value;
    _notify();
  }

  void _notify() {
    // Listeners receive no text snapshot: read current state after revocation.
    if (!_disposed && !_changes.isClosed) _changes.add(null);
  }

  void dispose() {
    if (_disposed) return;
    invalidate();
    _disposed = true;
    unawaited(_subscription?.cancel());
    // Paused view listeners cannot hold resource/SDK shutdown open.
    unawaited(_changes.close());
  }
}

void _requireLevel(AiTextLevel level) {
  if (level != AiTextLevel.n5 && level != AiTextLevel.n4) {
    throw const FormatException('Expected N5 or N4');
  }
}
