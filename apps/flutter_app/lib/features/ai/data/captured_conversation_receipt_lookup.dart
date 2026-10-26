import '../../srs/data/review_repository.dart';
import '../domain/conversation_receipt_reference.dart';
import '../domain/conversation_receipt_snapshot.dart';
import 'captured_ai_text_repository.dart';

abstract interface class ConversationReceiptReadPort {
  Future<ConversationReceiptSnapshot> lookupReceipt(
    ConversationReceiptReference reference,
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
  bool get isCurrent {
    if (_revoked) return false;
    try {
      if (_ready() && identical(_auth.currentSession, _session) && _ready()) {
        return true;
      }
    } on Object {
      /* Fixed failure below. */
    }
    revoke();
    return false;
  }

  void revoke() => _revoked = true;
  void _check() {
    if (!isCurrent) throw const AiTextFailure(AiTextErrorCode.unauthorized);
  }

  Future<ConversationReceiptSnapshot> lookup(
    ConversationReceiptReference reference,
  ) async {
    _check();
    if (reference.ownerId.toLowerCase() != _session.userId.toLowerCase()) {
      throw const AiTextFailure(AiTextErrorCode.unauthorized);
    }
    try {
      final result = await _port.lookupReceipt(reference);
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
