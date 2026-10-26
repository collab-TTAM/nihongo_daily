import '../application/ai_text_runtime_owner.dart';
import '../../srs/data/review_repository.dart';
import '../domain/ai_text_models.dart';
import '../domain/conversation_requests.dart';
import '../domain/conversation_receipt_reference.dart';
import 'captured_ai_text_repository.dart';
import 'captured_conversation_mutation.dart';
import 'captured_conversation_scenarios.dart';
import 'conversation_receipt_dispatch.dart';
import 'conversation_receipt_store.dart';

/// Transfers transport ownership; borrows the secure store. Explicit factory
/// composition only, never a default. One mutation until future reconciliation.
final class ReceiptGuardedAiTransport
    implements
        OwnedAiTextTransport,
        ConversationMutationTransport,
        ConversationScenarioReadPort {
  ReceiptGuardedAiTransport({
    required OwnedAiTextTransport inner,
    required ConversationReceiptStore store,
    required ReviewAuth auth,
    required ReviewSession capturedSession,
    required bool Function() isReady,
  }) : _inner = inner,
       _store = store,
       _auth = auth,
       _session = capturedSession,
       _ready = isReady {
    if (inner is! ConversationMutationTransport ||
        inner is! ConversationScenarioReadPort ||
        store.scope.ownerId != capturedSession.userId) {
      throw const AiTextFailure(AiTextErrorCode.unauthorized);
    }
  }
  final OwnedAiTextTransport _inner;
  final ConversationReceiptStore _store;
  final ReviewAuth _auth;
  final ReviewSession _session;
  final bool Function() _ready;
  ConversationReceiptDispatch<Object?>? _gate;
  bool _attempted = false;
  bool _revoked = false;
  bool _cleanupFailed = false;
  Future<void>? _closing;

  @override
  bool get isCurrent {
    if (_revoked) return false;
    try {
      if (_ready() &&
          identical(_auth.currentSession, _session) &&
          _inner.isCurrent &&
          _ready() &&
          identical(_auth.currentSession, _session) &&
          !_revoked) {
        return true;
      }
    } on Object {
      /* Fixed failure below. */
    }
    revoke();
    return false;
  }

  void _check(ReviewSession session) {
    if (!identical(session, _session) || !isCurrent) {
      throw const AiTextFailure(AiTextErrorCode.unauthorized);
    }
  }

  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  }) async {
    // Claim before external getters and immutable decoding can reenter.
    if (_attempted) throw const AiTextFailure(AiTextErrorCode.syncConflict);
    _attempted = true;
    _check(capturedSession);
    final ConversationReceiptReference reference;
    final Map<String, Object> original;
    final project = _store.scope.projectOrigin;
    try {
      switch (operation) {
        case 'start_conversation':
          final request = StartConversationRequest.fromJson(body);
          original = request.toJson();
          reference = ConversationReceiptReference.fromStart(
            projectUrl: project,
            ownerId: _session.userId,
            request: request,
          );
        case 'conversation_turn':
          final request = ConversationTurnRequest.fromJson(body);
          original = request.toJson();
          reference = ConversationReceiptReference.fromTurn(
            projectUrl: project,
            ownerId: _session.userId,
            request: request,
          );
        case 'finish_conversation':
          final request = FinishConversationRequest.fromJson(body);
          original = request.toJson();
          reference = ConversationReceiptReference.fromFinish(
            projectUrl: project,
            ownerId: _session.userId,
            request: request,
          );
        default:
          throw const FormatException();
      }
    } on Object {
      throw const AiTextFailure(AiTextErrorCode.validationFailure);
    }
    _check(capturedSession);
    final frozen = Map<String, Object>.unmodifiable(original);
    final gate = ConversationReceiptDispatch<Object?>(
      store: _store,
      reference: reference,
      auth: _auth,
      capturedSession: _session,
      isReady: () => isCurrent,
      dispatch: (session) {
        _check(session);
        return (_inner as ConversationMutationTransport).invoke(
          capturedSession: session,
          operation: operation,
          body: frozen,
        );
      },
    );
    _gate = gate;
    try {
      return await gate.submit();
    } on ReceiptDispatchFailure catch (error) {
      throw AiTextFailure(switch (error.code) {
        ReceiptDispatchError.unauthorized => AiTextErrorCode.unauthorized,
        ReceiptDispatchError.conflict => AiTextErrorCode.syncConflict,
        ReceiptDispatchError.unavailable => AiTextErrorCode.internalError,
      });
    }
  }

  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) {
    _check(capturedSession);
    return _inner.tutorExplain(capturedSession: capturedSession, body: body);
  }

  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) {
    _check(capturedSession);
    return _inner.correctSentence(capturedSession: capturedSession, body: body);
  }

  @override
  Future<Object?> read({
    required ReviewSession capturedSession,
    required AiTextLevel level,
  }) {
    _check(capturedSession);
    return (_inner as ConversationScenarioReadPort).read(
      capturedSession: capturedSession,
      level: level,
    );
  }

  @override
  void revoke() {
    if (_revoked) return;
    _revoked = true;
    _gate?.revoke();
    try {
      _inner.revoke();
    } on Object {
      _cleanupFailed = true;
    }
  }

  @override
  Future<void> close() {
    revoke();
    return _closing ??= () async {
      try {
        await _gate?.close();
      } finally {
        try {
          await _inner.close();
        } on Object {
          _cleanupFailed = true;
        }
      }
      if (_cleanupFailed) {
        throw const AiTextFailure(AiTextErrorCode.internalError);
      }
    }();
  }
}
