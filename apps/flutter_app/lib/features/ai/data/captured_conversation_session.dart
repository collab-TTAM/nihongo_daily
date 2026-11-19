import 'dart:convert';
import '../../srs/data/review_repository.dart';
import '../domain/conversation_requests.dart';
import '../domain/conversation_responses.dart';
import '../domain/retained_conversation_command.dart';
import 'captured_ai_text_repository.dart';
import 'captured_conversation_mutation.dart';
import 'captured_conversation_receipt_lookup.dart';
import '../domain/conversation_receipt_snapshot.dart';
import 'conversation_mutation_lane.dart';
import 'conversation_receipt_store.dart';

enum ConversationSessionPhase { notStarted, active, finished, revoked }

/// Ephemeral immutable projection. Model scores/references authorize no writes.
final class ConversationSessionSnapshot {
  ConversationSessionSnapshot._(
    this.phase, {
    this.sessionId,
    Iterable<ConversationAssistantMessage> messages = const [],
    this.summary,
  }) : messages = List.unmodifiable(messages);
  final ConversationSessionPhase phase;
  final String? sessionId;
  final List<ConversationAssistantMessage> messages;
  final FinishConversationResponse? summary;
}

/// One conversation in one ready-owner generation. Creates/owns a private lane;
/// borrows the trusted port/Auth. Host must revoke on every lifecycle barrier.
/// No dispatch at construction, reset, generated event IDs or automatic retry.
final class CapturedConversationSession {
  CapturedConversationSession({
    required ReviewAuth auth,
    required ConversationMutationTransport transport,
    required bool Function() isReady,
    Duration timeout = const Duration(seconds: 15),
    int maxMutations = 100,
  }) : _auth = auth,
       _lane = ConversationMutationLane(
         auth: auth,
         transport: transport,
         isReady: isReady,
         timeout: timeout,
         maxMutations: maxMutations,
       );
  final ReviewAuth _auth;
  final ConversationMutationLane _lane;
  final _turns = <String>{};
  String? _startEvent;
  String? _finishEvent;
  var _snapshot = ConversationSessionSnapshot._(
    ConversationSessionPhase.notStarted,
  );
  // One immutable command in this captured generation only. No disk/token data.
  Future<void> Function()? _retainedRetry;
  RetainedConversationCommand? _retainedCommand;
  String? _retainedFingerprint;
  bool _retainedRetryable = false;

  /// Original input for an idle, unresolved command in this ready generation.
  /// Never reconstructed from receipt metadata. Reading grants no retry/clear
  /// authority, performs no I/O and does not change the existing pending slot.
  /// In-flight/reentrant/stale reads are redacted, including after a timeout
  /// until the actual wire request drains. The caller must not persist this data.
  RetainedConversationCommand? get retainedCommand {
    if (_executing || _checking || !isCurrent || isBusy) return null;
    return _lane.hasUnresolvedMutation ? _retainedCommand : null;
  }

  /// Inspect a completion only for this idle session's exact retained command.
  /// This never applies a result, clears pending metadata or permits a new event.
  ConversationReceiptSnapshot? inspectRetainedCompletion(
    CapturedConversationCompletion completion,
  ) {
    if (_revoked || _executing || isCheckingAvailability) return null;
    _checking = true;
    try {
      if (!_lane.isCurrent) {
        revoke();
        return null;
      }
      if (_lane.isBusy || !_lane.hasUnresolvedMutation) return null;
      final original = _retainedCommand;
      final fingerprint = _retainedFingerprint;
      if (original == null || fingerprint == null) return null;
      final pair = completion.captureForAuth(_auth);
      if (pair == null) return null;
      final command = pair.command;
      final body =
          command.start?.toJson() ??
          command.turn?.toJson() ??
          command.finish!.toJson();
      if ('${command.reference.operation.wireName}:${jsonEncode(body)}' !=
          fingerprint) {
        return null;
      }
      if (!completion.isCurrent) return null;
      if (!_lane.isCurrent) {
        revoke();
        return null;
      }
      if (_revoked ||
          _lane.isBusy ||
          !_lane.hasUnresolvedMutation ||
          !identical(original, _retainedCommand) ||
          fingerprint != _retainedFingerprint) {
        return null;
      }
      return pair.receipt;
    } finally {
      _checking = false;
    }
  }

  /// Validate a prospective transcript without installing it or releasing pending.
  /// A non-null preview is not authority to apply, clear, retry or send again.
  ConversationSessionSnapshot? previewRetainedCompletion(
    CapturedConversationCompletion completion,
  ) {
    final receipt = inspectRetainedCompletion(completion);
    if (receipt == null) return null;
    _checking = true;
    try {
      final before = _snapshot;
      final original = _retainedCommand;
      final ConversationSessionSnapshot candidate;
      switch (original) {
        case RetainedConversationStart():
          final result = receipt.start;
          if (before.phase != ConversationSessionPhase.notStarted ||
              _startEvent != null ||
              result == null ||
              result.assistantMessage.sequenceNo != 0) {
            return null;
          }
          candidate = ConversationSessionSnapshot._(
            ConversationSessionPhase.active,
            sessionId: result.sessionId,
            messages: [result.assistantMessage],
          );
        case RetainedConversationTurn(:final request):
          final result = receipt.turn;
          if (before.phase != ConversationSessionPhase.active ||
              !_sameSession(request.sessionId) ||
              before.messages.isEmpty ||
              result == null) {
            return null;
          }
          final message = result.assistantMessage;
          if (message.sequenceNo <= before.messages.last.sequenceNo ||
              before.messages.any(
                (m) => m.id.toLowerCase() == message.id.toLowerCase(),
              )) {
            return null;
          }
          candidate = ConversationSessionSnapshot._(
            ConversationSessionPhase.active,
            sessionId: before.sessionId,
            messages: [...before.messages, message],
          );
        case RetainedConversationFinish(:final request):
          if (before.phase != ConversationSessionPhase.active ||
              !_sameSession(request.sessionId) ||
              receipt.finish == null) {
            return null;
          }
          candidate = ConversationSessionSnapshot._(
            ConversationSessionPhase.finished,
            sessionId: before.sessionId,
            messages: before.messages,
            summary: receipt.finish,
          );
        case null:
          return null;
      }
      if (!completion.isCurrent) return null;
      if (!_lane.isCurrent) {
        revoke();
        return null;
      }
      if (_revoked ||
          _lane.isBusy ||
          !_lane.hasUnresolvedMutation ||
          !identical(before, _snapshot) ||
          !identical(original, _retainedCommand)) {
        return null;
      }
      return candidate;
    } finally {
      _checking = false;
    }
  }

  /// Explicit trusted-host application; no default UI/controller binding.
  /// Validate a prospective transcript before any storage effect. Keep all
  /// session commands fenced until confirmed lane settlement and publication.
  Future<bool> applyRetainedCompletion(
    CapturedConversationCompletion completion, {
    required ConversationReceiptStore store,
  }) async {
    if (_revoked || _executing || isCheckingAvailability) return false;
    final candidate = previewRetainedCompletion(completion);
    if (candidate == null) return false;
    final before = _snapshot;
    final original = _retainedCommand;
    final fingerprint = _retainedFingerprint;
    if (original == null || fingerprint == null) return false;
    _executing = true;
    try {
      if (!await _lane.reconcileCompleted(completion, store: store)) {
        if (!_lane.isCurrent) revoke();
        return false;
      }
      if (!completion.isCurrent || !isCurrent) {
        revoke();
        return false;
      }
      if (_revoked ||
          _checking ||
          _lane.isBusy ||
          _lane.hasUnresolvedMutation ||
          !identical(before, _snapshot) ||
          !identical(original, _retainedCommand) ||
          fingerprint != _retainedFingerprint) {
        revoke();
        return false;
      }
      // No external callbacks or await between event bookkeeping and snapshot
      // publication. Replay must not append twice or reset later progress.
      switch (original) {
        case RetainedConversationStart(:final request):
          _startEvent = request.clientEventId.toLowerCase();
        case RetainedConversationTurn(:final request):
          _turns.add(request.clientEventId.toLowerCase());
        case RetainedConversationFinish(:final request):
          _finishEvent = request.clientEventId.toLowerCase();
      }
      _snapshot = candidate;
      _clearRetained();
      return true;
    } on Object {
      revoke();
      rethrow;
    } finally {
      _executing = false;
    }
  }

  /// Explicit host capability; legacy view remount policy stays unchanged.
  bool get canRetryRetained {
    if (_executing || _checking || !isCurrent) return false;
    return _retainedRetry != null &&
        _retainedRetryable &&
        _lane.hasUnresolvedMutation &&
        !isBusy;
  }

  /// No caller payload/event and no automatic replay. Existing lane still checks
  /// captured identity, phase, original fingerprint and actual wire drain.
  Future<void> retryRetained() async {
    if (!canRetryRetained) return;
    final retry = _retainedRetry;
    if (retry != null) await retry();
  }

  Future<T> _remember<T>(
    String operation,
    Map<String, Object> body,
    RetainedConversationCommand command,
    Future<void> Function() retry,
    Future<T> Function() dispatch,
  ) async {
    final fingerprint = '$operation:${jsonEncode(body)}';
    if (_retainedRetry == null) {
      _retainedRetry = retry;
      _retainedCommand = command;
      _retainedFingerprint = fingerprint;
    }
    final original = fingerprint == _retainedFingerprint;
    try {
      return await dispatch();
    } on AiTextFailure catch (failure) {
      if (original) _retainedRetryable = failure.retryable;
      rethrow;
    } finally {
      if (!_lane.hasUnresolvedMutation || _revoked) _clearRetained();
    }
  }

  void _clearRetained() {
    _retainedRetry = null;
    _retainedCommand = null;
    _retainedFingerprint = null;
    _retainedRetryable = false;
  }

  bool _executing = false;
  bool _checking = false;
  bool _revoked = false;

  /// Reentrant reads must redact while either the captured session or its
  /// underlying mutation lane is evaluating an external readiness callback.
  /// This hint grants no authority; callers still check isCurrent afterward.
  bool get isCheckingAvailability => _checking || _lane.isCheckingAvailability;
  bool get isBusy => _executing || isCheckingAvailability || _lane.isBusy;
  bool get hasUnresolvedMutation => _lane.hasUnresolvedMutation;

  bool get isCurrent {
    // Supplied getters may synchronously reenter a read. Do not expose retained
    // results while the outer availability check has not established readiness.
    if (_revoked || _checking || _lane.isCheckingAvailability) return false;
    _checking = true;
    try {
      if (!_lane.isCurrent) revoke();
      return !_revoked;
    } finally {
      _checking = false;
    }
  }

  ConversationSessionSnapshot get snapshot => isCurrent
      ? _snapshot
      : ConversationSessionSnapshot._(ConversationSessionPhase.revoked);

  void revoke() {
    _revoked = true;
    _lane.revoke();
    _clearRetained();
    _turns.clear();
    _startEvent = null;
    _finishEvent = null;
    _snapshot = ConversationSessionSnapshot._(ConversationSessionPhase.revoked);
  }

  Future<StartConversationResponse> start(
    StartConversationRequest request,
  ) => _run(() async {
    final event = request.clientEventId.toLowerCase();
    if (_snapshot.phase == ConversationSessionPhase.finished ||
        (_startEvent != null && _startEvent != event)) {
      throw const AiTextFailure(AiTextErrorCode.syncConflict);
    }
    final response = await _remember(
      'start_conversation',
      request.toJson(),
      RetainedConversationStart(request),
      () async {
        await start(request);
      },
      () => _lane.start(request),
    );
    _requireCurrent();
    if (_startEvent == null) {
      _startEvent = event;
      _snapshot = ConversationSessionSnapshot._(
        ConversationSessionPhase.active,
        sessionId: response.sessionId,
        messages: [response.assistantMessage],
      );
    }
    return response; // An accepted start replay never resets later messages.
  });

  Future<ConversationTurnResponse> turn(ConversationTurnRequest request) =>
      _run(() async {
        _requireActive(request.sessionId);
        final response = await _remember(
          'conversation_turn',
          request.toJson(),
          RetainedConversationTurn(request),
          () async {
            await turn(request);
          },
          () => _lane.turn(request),
        );
        _requireCurrent();
        final event = request.clientEventId.toLowerCase();
        if (!_turns.contains(event)) {
          final message = response.assistantMessage;
          if (message.sequenceNo <= _snapshot.messages.last.sequenceNo ||
              _snapshot.messages.any(
                (m) => m.id.toLowerCase() == message.id.toLowerCase(),
              )) {
            // The lane may already have accepted this response/receipt. It must
            // never be retried under a new event or used to advance the view.
            revoke();
            throw const AiTextFailure(AiTextErrorCode.syncConflict);
          }
          _turns.add(event);
          _snapshot = ConversationSessionSnapshot._(
            ConversationSessionPhase.active,
            sessionId: _snapshot.sessionId,
            messages: [..._snapshot.messages, message],
          );
        }
        return response;
      });

  Future<FinishConversationResponse> finish(
    FinishConversationRequest request,
  ) => _run(() async {
    final event = request.clientEventId.toLowerCase();
    if (_snapshot.phase == ConversationSessionPhase.finished) {
      if (_finishEvent != event || !_sameSession(request.sessionId)) {
        throw const AiTextFailure(AiTextErrorCode.syncConflict);
      }
    } else {
      _requireActive(request.sessionId);
    }
    final response = await _remember(
      'finish_conversation',
      request.toJson(),
      RetainedConversationFinish(request),
      () async {
        await finish(request);
      },
      () => _lane.finish(request),
    );
    _requireCurrent();
    if (_finishEvent == null) {
      _finishEvent = event;
      _snapshot = ConversationSessionSnapshot._(
        ConversationSessionPhase.finished,
        sessionId: _snapshot.sessionId,
        messages: _snapshot.messages,
        summary: response,
      );
    }
    return response;
  });

  bool _sameSession(String id) =>
      _snapshot.sessionId?.toLowerCase() == id.toLowerCase();
  void _requireActive(String sessionId) {
    if (_snapshot.phase != ConversationSessionPhase.active ||
        !_sameSession(sessionId)) {
      throw const AiTextFailure(AiTextErrorCode.syncConflict);
    }
  }

  void _requireCurrent() {
    if (!isCurrent) {
      throw const AiTextFailure(AiTextErrorCode.unauthorized);
    }
  }

  Future<T> _run<T>(Future<T> Function() operation) async {
    // Reserve before supplied readiness/Auth/port code can synchronously reenter.
    if (_executing || _checking || _lane.isCheckingAvailability) {
      throw const AiTextRequestPending();
    }
    _executing = true;
    try {
      _requireCurrent();
      return await operation();
    } on AiTextFailure catch (error) {
      if (error.code == AiTextErrorCode.unauthorized) revoke();
      rethrow;
    } finally {
      _executing = false;
    }
  }
}
