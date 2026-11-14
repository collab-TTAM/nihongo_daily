import '../data/windows_conversation_receipt_store.dart';
import '../domain/conversation_receipt_reference.dart';
import 'receipt_ai_runtime_owner.dart';

/// Explicit Windows secure-store composition. No default activation, learner
/// endpoint input or fallback. Host binds factory to this same trusted scope.
ReceiptAiRuntimeOwner createWindowsReceiptAiRuntimeOwner({
  required ConversationReceiptScope scope,
  required ReceiptAiTransportFactory createTransport,
}) => ReceiptAiRuntimeOwner(
  store: createWindowsConversationReceiptStore(scope: scope),
  createTransport: createTransport,
);
