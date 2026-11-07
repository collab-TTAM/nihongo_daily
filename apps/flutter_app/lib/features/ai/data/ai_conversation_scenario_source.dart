import 'captured_conversation_scenarios.dart';

/// Optional borrowed reader for one owned ready generation. Factory sends nothing;
/// callers discard old projections on owner hints and never close SDK resources.
abstract interface class AiConversationScenarioSource {
  CapturedConversationScenarios? createAiConversationScenarios();
  Stream<void> get aiConversationScenarioChanges;
}
