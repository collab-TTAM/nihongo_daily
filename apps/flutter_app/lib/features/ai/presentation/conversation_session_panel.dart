import 'dart:async';
import 'package:flutter/material.dart';

import '../application/ai_conversation_controller.dart';
import '../application/ai_conversation_view_binding.dart';
import '../data/captured_conversation_session.dart';
import '../domain/conversation_responses.dart';

/// Read-only view of one borrowed retained flow. No scenario/event generation,
/// dispatch, retry, audio playback, persistence or new-round/reset controls.
class ConversationSessionPanel extends StatefulWidget {
  const ConversationSessionPanel({super.key, this.binding});
  final AiConversationViewBinding? binding;
  @override
  State<ConversationSessionPanel> createState() =>
      _ConversationSessionPanelState();
}

class _ConversationSessionPanelState extends State<ConversationSessionPanel> {
  late AiConversationController _controller;
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    final binding = widget.binding;
    _controller = AiConversationController(
      session: binding?.session,
      availabilityChanges: binding?.availabilityChanges,
    );
    _subscription = _controller.changes.listen((_) {
      if (mounted) {
        setState(() {}); // Read fresh guarded state, never queued text.
      }
    });
  }

  void _detach() {
    final subscription = _subscription;
    _subscription = null;
    unawaited(_cancel(subscription));
    _controller.dispose(); // View-owned only; the borrowed flow survives.
  }

  Future<void> _cancel(StreamSubscription<void>? subscription) async {
    try {
      await subscription?.cancel();
    } on Object {
      // No raw stream error is learner-facing data.
    }
  }

  @override
  void didUpdateWidget(covariant ConversationSessionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.binding, widget.binding)) {
      _detach();
      _attach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final snapshot = state.conversation;
    return SingleChildScrollView(
      key: const Key('conversation-panel'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hội thoại', style: Theme.of(context).textTheme.headlineSmall),
          const Text('Luyện giọng nói và phát âm thanh chưa khả dụng.'),
          if (state.phase == AiConversationPhase.unavailable ||
              snapshot == null)
            const Text(
              'Hội thoại chưa khả dụng cho phiên hiện tại.',
              key: Key('conversation-unavailable'),
            )
          else ...[
            Text(switch (snapshot.phase) {
              ConversationSessionPhase.notStarted => 'Chưa bắt đầu hội thoại.',
              ConversationSessionPhase.active => 'Hội thoại đang mở.',
              ConversationSessionPhase.finished => 'Hội thoại đã kết thúc.',
              ConversationSessionPhase.revoked =>
                'Hội thoại chưa khả dụng cho phiên hiện tại.',
            }),
            if (widget.binding!.session.isBusy)
              const Text('Đang chờ yêu cầu trước kết thúc.'),
            if (state.hasUnresolvedMutation)
              const Text(
                'Kết quả yêu cầu trước chưa xác định. Chưa thể bắt đầu lượt mới.',
                key: Key('conversation-uncertain'),
              ),
            if (snapshot.messages.isEmpty)
              const Text('Chưa có phản hồi từ trợ lý.')
            else ...[
              const SizedBox(height: 12),
              const Text('Phản hồi từ trợ lý'),
              for (final message in snapshot.messages) ...[
                const SizedBox(height: 12),
                Text(message.textJa, key: ValueKey('assistant-${message.id}')),
                Text(message.textVi ?? 'Chưa có bản dịch.'),
              ],
            ],
            if (snapshot.summary case final summary?) ...[
              const SizedBox(height: 20),
              _Summary(summary: summary),
            ],
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});
  final FinishConversationResponse summary;
  @override
  Widget build(BuildContext context) => Column(
    key: const Key('conversation-summary'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Tổng kết tham khảo', style: Theme.of(context).textTheme.titleLarge),
      const Text('Chưa lưu vào tiến độ hoặc SRS.'),
      Text('Ngữ pháp: ${summary.scores.grammar}/100'),
      Text('Từ vựng: ${summary.scores.vocabulary}/100'),
      Text('Lưu loát: ${summary.scores.fluency}/100'),
      const SizedBox(height: 12),
      const Text('Gợi ý sửa câu'),
      if (summary.errors.isEmpty)
        const Text('Không có gợi ý sửa câu trong phản hồi này.')
      else
        for (final error in summary.errors) ...[
          Text(error.originalText),
          Text(error.correctedText),
          Text(error.explanationVi),
        ],
      const SizedBox(height: 12),
      const Text('Điểm mạnh'),
      if (summary.strengthsVi.isEmpty)
        const Text('Chưa có nhận xét điểm mạnh.')
      else
        for (final text in summary.strengthsVi) Text(text),
      const SizedBox(height: 12),
      const Text('Nội dung nên luyện tiếp'),
      if (summary.focusNextVi.isEmpty)
        const Text('Chưa có gợi ý luyện tiếp.')
      else
        for (final text in summary.focusNextVi) Text(text),
      Text('Gợi ý SRS: ${summary.srsRecommendations.length}. Chưa lưu.'),
    ],
  );
}
