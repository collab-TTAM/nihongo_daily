import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/feature_preview_screen.dart';
import '../application/conversation_workspace_provider.dart';
import 'conversation_workspace_panel.dart';

/// Route consumption does not enable a source or send a request. The owned
/// runtime must explicitly opt in and satisfy secure-storage/profile readiness.
class ConversationScreen extends ConsumerWidget {
  const ConversationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binding = ref.watch(conversationWorkspaceBindingProvider);
    return binding == null
        ? const FeaturePreviewScreen(
            title: 'Hội thoại AI',
            description: 'Luyện hội thoại theo tình huống.',
          )
        : ConversationWorkspacePanel(
            key: ObjectKey(binding),
            binding: binding,
            enableRetainedRecovery: true,
          );
  }
}
