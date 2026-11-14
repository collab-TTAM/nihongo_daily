import 'dart:convert';
import '../../srs/data/review_repository.dart';
import '../domain/conversation_requests.dart';
import '../domain/conversation_responses.dart';
import 'captured_ai_text_repository.dart';
import 'captured_conversation_mutation.dart';

/// One trusted owner's serialization lane. Caller must reuse it for all events
/// in that ready generation and revoke on every readiness barrier.
final class ConversationMutationLane {
  ConversationMutationLane({
    required ReviewAuth auth,
    required ConversationMutationTransport transport,
    required bool Function() isReady,
    Duration timeout = const Duration(seconds: 15),
    int maxMutations = 100,
  }) : _auth = auth,
       _transport = transport,
       _ready = isReady,
       _timeout = timeout,
       _maxMutations = maxMutations,
       _session = _capture(auth) {
    if (timeout <= Duration.zero ||
        timeout > const Duration(seconds: 15) ||
        maxMutations < 1 ||
        maxMutations > 1000) {
      throw ArgumentError('Invalid conversation lane limits');
    }
    _requireCurrent();
  }
  final ReviewAuth _auth;
  final ConversationMutationTransport _transport;
  final bool Function() _ready;
  final Duration _timeout;
  final int _maxMutations;
  final ReviewSession _session;
  final _slots = <String, _Slot>{};
  String? _pendingKey;
  _Slot? _held;
  bool _executing = false;
  bool _revoked = false;
  bool get hasUnresolvedMutation => _pendingKey != null;
  int get retainedMutationCount => _slots.length;
  bool get isBusy {
    if (!_executing && _held?.isBusy() == false) {
      _held = null;
    }
    return _executing || (_held?.isBusy() ?? false);
  }

  bool get isCurrent {
    if (_revoked) return false;
    try {
      if (_ready() && identical(_auth.currentSession, _session) && _ready()) {
        return true;
      }
    } on Object {
      /* Fixed unavailable below. */
    }
    revoke();
    return false;
  }

  void revoke() {
    _revoked = true;
    for (final slot in _slots.values) {
      slot.revoke();
    }
    _slots.clear();
    _pendingKey = null;
    if (_held?.isBusy() == false) {
      _held = null;
    }
  }

  void _requireCurrent() {
    if (!isCurrent) {
      throw const AiTextFailure(AiTextErrorCode.unauthorized);
    }
  }

  Future<StartConversationResponse> start(StartConversationRequest request) =>
      _submit(
        'start_conversation',
        request.clientEventId,
        request.toJson(),
        () => _slot(
          CapturedConversationMutation.start(
            auth: _auth,
            transport: _transport,
            isReady: () => isCurrent,
            request: request,
            timeout: _timeout,
          ),
          jsonEncode(request.toJson()),
        ),
      );
  Future<ConversationTurnResponse> turn(ConversationTurnRequest request) =>
      _submit(
        'conversation_turn',
        request.clientEventId,
        request.toJson(),
        () => _slot(
          CapturedConversationMutation.turn(
            auth: _auth,
            transport: _transport,
            isReady: () => isCurrent,
            request: request,
            timeout: _timeout,
          ),
          jsonEncode(request.toJson()),
        ),
      );
  Future<FinishConversationResponse> finish(
    FinishConversationRequest request,
  ) => _submit(
    'finish_conversation',
    request.clientEventId,
    request.toJson(),
    () => _slot(
      CapturedConversationMutation.finish(
        auth: _auth,
        transport: _transport,
        isReady: () => isCurrent,
        request: request,
        timeout: _timeout,
      ),
      jsonEncode(request.toJson()),
    ),
  );

  Future<T> _submit<T extends Object>(
    String operation,
    String eventId,
    Map<String, Object> body,
    _Slot Function() create,
  ) async {
    // Reserve before supplied readiness/Auth getters or factories can reenter.
    if (_executing) throw const AiTextRequestPending();
    _executing = true;
    try {
      _requireCurrent();
      final key = '$operation:${eventId.toLowerCase()}';
      final fingerprint = jsonEncode(body);
      var slot = _slots[key];
      if (slot != null && slot.fingerprint != fingerprint) {
        throw const AiTextFailure(AiTextErrorCode.syncConflict);
      }
      if (_pendingKey != null && _pendingKey != key) {
        throw const AiTextRequestPending();
      }
      if (slot == null) {
        if (_slots.length >= _maxMutations) {
          throw const AiTextFailure(AiTextErrorCode.rateLimited);
        }
        slot = create();
        _slots[key] = slot;
      }
      _pendingKey = key;
      _held = slot;
      final result = await slot.submit();
      _requireCurrent();
      _pendingKey = null;
      return result
          as T; // Private operation-scoped slot fixes its response type.
    } on AiTextFailure catch (error) {
      if (error.code == AiTextErrorCode.unauthorized) {
        revoke();
      }
      rethrow;
    } finally {
      _executing = false;
    }
  }
}

final class _Slot {
  const _Slot(this.fingerprint, this.submit, this.isBusy, this.revoke);
  final String fingerprint;
  final Future<Object> Function() submit;
  final bool Function() isBusy;
  final void Function() revoke;
}

_Slot _slot<T extends Object>(
  CapturedConversationMutation<T> mutation,
  String fingerprint,
) => _Slot(
  fingerprint,
  () async => await mutation.submit(),
  () => mutation.isBusy,
  mutation.revoke,
);
ReviewSession _capture(ReviewAuth auth) {
  try {
    final session = auth.currentSession;
    if (session != null) return session;
  } on Object {
    /* Do not expose SDK errors. */
  }
  throw const AiTextFailure(AiTextErrorCode.unauthorized);
}
