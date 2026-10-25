import '../data/captured_conversation_scenarios.dart';
import '../data/captured_conversation_session.dart';

/// Trusted host input: both capabilities MUST belong to the same owned ready
/// generation. Replace this immutable binding at every lifecycle barrier.
/// This descriptor does not establish pairing or install a default ID generator.
final class ConversationWorkspaceBinding {
  const ConversationWorkspaceBinding({
    required this.reader,
    required this.session,
    this.availabilityChanges,
    this.createEventId,
  });
  final CapturedConversationScenarios reader;
  final CapturedConversationSession session;
  final Stream<void>? availabilityChanges;
  final String Function()? createEventId;
}
