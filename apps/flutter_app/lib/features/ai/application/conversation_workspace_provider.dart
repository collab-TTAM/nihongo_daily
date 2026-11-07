import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_conversation_view_binding.dart';
import 'ai_conversation_scenario_binding.dart';
import 'conversation_workspace_binding.dart';

/// Does not create an ID while reading the provider. A failed secure entropy
/// source propagates to the existing controller's fixed safe error, never a
/// timestamp/counter/pseudorandom fallback. Retry reuses the captured DTO instead.
String createConversationEventId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Trusted host/test injection only; not a learner setting or service flag.
final conversationEventFactoryProvider = Provider<String Function()>(
  (ref) => createConversationEventId,
);

/// Existing AccountStartupApp already exposes both owned optional sources.
/// Require the SAME source object and owner hint stream; do not combine arbitrary
/// independent provider overrides. Actual runtime still owns generation pairing,
/// synchronous revocation/drain and borrowed retained receipts. Identity checks
/// are not authentication of an untrusted host implementation.
final conversationWorkspaceBindingProvider =
    Provider<ConversationWorkspaceBinding?>((ref) {
      final source = ref.watch(aiConversationSourceProvider);
      final scenariosSource = ref.watch(aiConversationScenarioSourceProvider);
      if (source == null || !identical(source, scenariosSource)) return null;
      final conversation = ref.watch(aiConversationViewBindingProvider);
      final scenarios = ref.watch(aiConversationScenarioBindingProvider);
      if (conversation == null ||
          scenarios == null ||
          conversation.availabilityChanges == null ||
          !identical(
            conversation.availabilityChanges,
            scenarios.availabilityChanges,
          )) {
        return null;
      }
      // Capture a function, never call it in build/availability/acquisition.
      final eventFactory = ref.watch(conversationEventFactoryProvider);
      try {
        if (!scenarios.reader.isCurrent ||
            !conversation.session.isCurrent ||
            !scenarios.reader.isCurrent) {
          return null;
        }
        return ConversationWorkspaceBinding(
          reader: scenarios.reader,
          session: conversation.session,
          availabilityChanges: conversation.availabilityChanges,
          createEventId: eventFactory,
        );
      } on Object {
        return null; // No raw trusted getter exception reaches the learner.
      }
    });
