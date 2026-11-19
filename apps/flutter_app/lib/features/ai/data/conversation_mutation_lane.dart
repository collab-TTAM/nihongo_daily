import 'dart:convert';
import '../../srs/data/review_repository.dart';
import '../domain/conversation_requests.dart';
import '../domain/conversation_responses.dart';
import '../domain/conversation_receipt_snapshot.dart';
import 'captured_ai_text_repository.dart';
import 'captured_conversation_mutation.dart';
import 'captured_conversation_receipt_lookup.dart';
import 'conversation_receipt_store.dart';

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
  bool _checking = false;

  /// Exposes the temporary readiness fence to captured consumers. Reentrant
  /// readers must redact without interpreting this state as permanent revocation.
  bool get isCheckingAvailability => _checking;
  bool get hasUnresolvedMutation => _pendingKey != null;
  int get retainedMutationCount => _slots.length;
  bool get isBusy {
    if (!_executing && _held?.isBusy() == false) {
      _held = null;
    }
    return _executing || (_held?.isBusy() ?? false);
  }

  bool get isCurrent {
    // Supplied readiness/Auth getters cannot establish nested currentness.
    if (_revoked || _checking) return false;
    _checking = true;
    try {
      if (_ready() &&
          identical(_auth.currentSession, _session) &&
          _ready() &&
          identical(_auth.currentSession, _session) &&
          !_revoked) {
        return true;
      }
    } on Object {
      /* Fixed unavailable below. */
    } finally {
      _checking = false;
    }
    revoke();
    return false;
  }

  void revoke() {
    _revoked = true;
    for (final slot in _slots.values) {
      slot.accepted = null;
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

  /// Read-only comparison with an already accepted lane result. This is not
  /// transcript applicability, storage confirmation, proof or dispatch authority.
  /// The host must supply its existing owned store; no store I/O/ownership here.
  ConversationReceiptSnapshot? inspectAcceptedCompletion(
    CapturedConversationCompletion completion, {
    required ConversationReceiptStore store,
  }) {
    if (_revoked || _executing || _checking) return null;
    _executing = true; // Before supplied reader/Auth/readiness can reenter.
    try {
      if (!isCurrent) return null;
      final pair = completion.captureForAuth(_auth);
      if (pair == null || _pendingKey != null || _held?.isBusy() == true) {
        return null;
      }
      final command = pair.command;
      final key =
          '${command.reference.operation.wireName}:${command.reference.clientEventId.toLowerCase()}';
      final body =
          command.start?.toJson() ??
          command.turn?.toJson() ??
          command.finish!.toJson();
      final slot = _slots[key];
      final accepted = slot?.accepted;
      if (slot == null ||
          !slot.recordsMutationSuccess ||
          accepted == null ||
          slot.isBusy() ||
          slot.fingerprint != jsonEncode(body) ||
          store.phase != ConversationReceiptStorePhase.open ||
          !store.scope.contains(command.reference)) {
        return null;
      }
      final remote =
          pair.receipt.start ?? pair.receipt.turn ?? pair.receipt.finish;
      final encoded = _encodedResult(accepted);
      if (encoded == null || encoded != _encodedResult(remote)) return null;
      if (!completion.isCurrent || !isCurrent) return null;
      // Only local checks after the final external currentness callback.
      if (_revoked ||
          _checking ||
          completion.isRevoked ||
          _pendingKey != null ||
          _held?.isBusy() == true ||
          !identical(_slots[key], slot) ||
          !identical(slot.accepted, accepted) ||
          slot.isBusy() ||
          store.phase != ConversationReceiptStorePhase.open) {
        return null;
      }
      return pair.receipt;
    } on Object {
      revoke();
      return null;
    } finally {
      _executing = false;
    }
  }

  String? _encodedResult(Object? result) => switch (result) {
    StartConversationResponse value => jsonEncode(value.toJson()),
    ConversationTurnResponse value => jsonEncode(value.toJson()),
    FinishConversationResponse value => jsonEncode(value.toJson()),
    _ => null,
  };

  /// Explicit trusted-host reconciliation, never inferred from metadata/absence.
  /// Caller supplies the same owned project's secure store and must validate its
  /// prospective transcript before invoking. No default/session/UI caller exists.
  /// Cache the authenticated exact original result only after confirmed clear;
  /// an ambiguous attempted clear permanently retires this generation.
  Future<bool> reconcileCompleted(
    CapturedConversationCompletion completion, {
    required ConversationReceiptStore store,
  }) async {
    if (_executing || _checking) throw const AiTextRequestPending();
    _executing = true;
    var attemptedClear = false;
    try {
      _requireCurrent();
      final pair = completion.captureForAuth(_auth);
      if (pair == null) return false;
      final command = pair.command;
      final body =
          command.start?.toJson() ??
          command.turn?.toJson() ??
          command.finish!.toJson();
      final key =
          '${command.reference.operation.wireName}:${command.reference.clientEventId.toLowerCase()}';
      final fingerprint = jsonEncode(body);
      final slot = _slots[key];
      if (_pendingKey != key ||
          slot == null ||
          slot.fingerprint != fingerprint ||
          slot.isBusy() ||
          !store.scope.contains(command.reference)) {
        return false;
      }
      final result =
          pair.receipt.start ?? pair.receipt.turn ?? pair.receipt.finish;
      if (result == null) return false;
      bool current() {
        if (!completion.isCurrent || !isCurrent) return false;
        return !_revoked &&
            !_checking &&
            store.phase == ConversationReceiptStorePhase.open &&
            _pendingKey == key &&
            identical(_slots[key], slot) &&
            !slot.isBusy();
      }

      if (!current()) return false;
      attemptedClear = true;
      if (!await store.clearMatching(command.reference, isCurrent: current) ||
          !current()) {
        revoke();
        return false;
      }
      // No external callbacks or await between replacing the exact slot and
      // releasing pending. Future exact replay returns the typed result locally.
      slot.revoke();
      _slots[key] = _Slot(
        fingerprint,
        () async => result,
        () => false,
        () {},
        recordsMutationSuccess: false,
      );
      _pendingKey = null;
      _held = null;
      return true;
    } on Object {
      if (attemptedClear) revoke();
      rethrow;
    } finally {
      _executing = false;
    }
  }

  Future<T> _submit<T extends Object>(
    String operation,
    String eventId,
    Map<String, Object> body,
    _Slot Function() create,
  ) async {
    // Reserve before supplied readiness/Auth getters or factories can reenter.
    if (_executing || _checking) throw const AiTextRequestPending();
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
      if (slot.recordsMutationSuccess) slot.accepted = result;
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
  _Slot(
    this.fingerprint,
    this.submit,
    this.isBusy,
    this.revoke, {
    this.recordsMutationSuccess = true,
  });
  final bool recordsMutationSuccess;
  Object? accepted;
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
