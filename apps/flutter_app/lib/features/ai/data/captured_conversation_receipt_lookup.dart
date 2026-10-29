import '../../srs/data/review_repository.dart';
import '../domain/conversation_receipt_reference.dart';
import '../domain/conversation_receipt_snapshot.dart';
import '../domain/conversation_requests.dart';
import '../domain/pending_conversation_command_envelope.dart';
import 'captured_ai_text_repository.dart';

abstract interface class ConversationReceiptReadPort {
  Future<ConversationReceiptSnapshot> lookupReceipt(
    ConversationReceiptReference reference,
  );
}

/// Optional original-command read capability; legacy readers need not supply it.
abstract interface class ConversationOriginalReceiptReadPort {
  Future<ConversationReceiptSnapshot> lookupStartReceipt(
    ConversationReceiptReference reference,
    StartConversationRequest original,
  );
  Future<ConversationReceiptSnapshot> lookupTurnReceipt(
    ConversationReceiptReference reference,
    ConversationTurnRequest original,
  );
  Future<ConversationReceiptSnapshot> lookupFinishReceipt(
    ConversationReceiptReference reference,
    FinishConversationRequest original,
  );
}

/// Borrowed read capability on an existing owner/transport lease. No I/O at
/// acquisition, independent SDK/storage owner, replay or receipt-clear authority.
final class CapturedConversationReceiptLookup {
  CapturedConversationReceiptLookup({
    required ReviewAuth auth,
    required ConversationReceiptReadPort port,
    required bool Function() isReady,
  }) : _auth = auth,
       _port = port,
       _ready = isReady {
    try {
      _session = auth.currentSession!;
      _check();
    } on Object {
      throw const AiTextFailure(AiTextErrorCode.unauthorized);
    }
  }
  final ReviewAuth _auth;
  final ConversationReceiptReadPort _port;
  final bool Function() _ready;
  late final ReviewSession _session;
  bool _revoked = false;
  bool _checking = false;
  bool get isCurrent {
    // External readiness/Auth getters can synchronously reenter or retire us.
    // Nested reads cannot establish readiness while the outer check is pending.
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
      /* Fixed failure below. */
    } finally {
      _checking = false;
    }
    revoke();
    return false;
  }

  void revoke() => _revoked = true;
  void _check() {
    if (!isCurrent) throw const AiTextFailure(AiTextErrorCode.unauthorized);
  }

  ConversationOriginalReceiptReadPort get _originalPort {
    final port = _port;
    if (port is! ConversationOriginalReceiptReadPort) {
      throw const AiTextFailure(AiTextErrorCode.internalError);
    }
    return port as ConversationOriginalReceiptReadPort;
  }

  /// Read-only correlation of a fully decoded original command. Never falls back
  /// to metadata-only lookup and never authorizes replay, deletion or application.
  Future<ConversationReceiptSnapshot> lookupCommand(
    PendingConversationCommandEnvelope command,
  ) => switch (command.reference.operation) {
    ConversationReceiptOperation.start => lookupStart(
      command.reference,
      command.start!,
    ),
    ConversationReceiptOperation.turn => lookupTurn(
      command.reference,
      command.turn!,
    ),
    ConversationReceiptOperation.finish => lookupFinish(
      command.reference,
      command.finish!,
    ),
  };

  Future<ConversationReceiptSnapshot> lookupStart(
    ConversationReceiptReference reference,
    StartConversationRequest original,
  ) => _lookup(
    reference,
    () => _originalPort.lookupStartReceipt(reference, original),
  );

  Future<ConversationReceiptSnapshot> lookupTurn(
    ConversationReceiptReference reference,
    ConversationTurnRequest original,
  ) => _lookup(
    reference,
    () => _originalPort.lookupTurnReceipt(reference, original),
  );

  Future<ConversationReceiptSnapshot> lookupFinish(
    ConversationReceiptReference reference,
    FinishConversationRequest original,
  ) => _lookup(
    reference,
    () => _originalPort.lookupFinishReceipt(reference, original),
  );

  Future<ConversationReceiptSnapshot> lookup(
    ConversationReceiptReference reference,
  ) => _lookup(reference, () => _port.lookupReceipt(reference));

  Future<ConversationReceiptSnapshot> _lookup(
    ConversationReceiptReference reference,
    Future<ConversationReceiptSnapshot> Function() read,
  ) async {
    _check();
    if (reference.ownerId.toLowerCase() != _session.userId.toLowerCase()) {
      throw const AiTextFailure(AiTextErrorCode.unauthorized);
    }
    try {
      final result = await read();
      _check();
      return result;
    } on AiTextRequestPending {
      _check();
      rethrow;
    } on AiTextFailure catch (error) {
      _check();
      if (error.code == AiTextErrorCode.unauthorized) revoke();
      throw AiTextFailure(error.code); // Never supplied private error text.
    } on Object {
      _check();
      throw const AiTextFailure(AiTextErrorCode.internalError);
    }
  }
}
