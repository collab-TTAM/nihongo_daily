import 'captured_conversation_session.dart';

/// Borrowed owner capability. Construction sends nothing. The owner retains one
/// session per ready generation, revokes synchronously and drains accepted I/O.
/// Consumers must not reset/rebuild uncertain work or close borrowed resources.
abstract interface class AiConversationSource {
  CapturedConversationSession? createAiConversationSession();
  Stream<void> get aiConversationChanges;
}
