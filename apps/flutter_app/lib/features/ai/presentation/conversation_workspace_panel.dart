import 'dart:async';
import 'package:flutter/material.dart';
import 'conversation_summary.dart';
import '../application/conversation_workspace_binding.dart';
import '../application/conversation_workspace_controller.dart';
import '../application/conversation_scenario_controller.dart';
import '../application/ai_conversation_controller.dart';
import '../data/captured_conversation_session.dart';
import '../domain/ai_text_models.dart';
import '../domain/conversation_responses.dart'
    show ConversationAssistantMessage;

/// Reusable opt-in commands. No route/default activation, durable drafts, voice,
/// new-round reset or client receipt reconstruction is installed here.
class ConversationWorkspacePanel extends StatefulWidget {
  const ConversationWorkspacePanel({super.key, this.binding});
  final ConversationWorkspaceBinding? binding;
  @override
  State<ConversationWorkspacePanel> createState() => _WorkspacePanelState();
}

class _WorkspacePanelState extends State<ConversationWorkspacePanel> {
  late ConversationWorkspaceController _controller;
  late TextEditingController _editor;
  StreamSubscription<void>? _subscription;
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    final b = widget.binding;
    final c = _controller = ConversationWorkspaceController(
      reader: b?.reader,
      session: b?.session,
      availabilityChanges: b?.availabilityChanges,
      createEventId: b?.createEventId,
    );
    final editor = _editor = TextEditingController();
    _subscription = c.changes.listen((_) {
      if (!_current(c)) return;
      _redact(c.state, editor);
      setState(() {});
    });
  }

  bool _current(ConversationWorkspaceController c) =>
      mounted && identical(c, _controller);
  void _redact(ConversationWorkspaceState state, TextEditingController editor) {
    if (!state.isAvailable ||
        state.conversation?.hasUnresolvedMutation == true ||
        state.conversation?.conversation?.phase ==
            ConversationSessionPhase.finished) {
      if (editor.text.isNotEmpty) editor.clear();
    }
  }

  void _detach() {
    unawaited(_cancel(_subscription));
    _subscription = null;
    _controller.dispose();
    _editor.dispose();
  }

  Future<void> _cancel(StreamSubscription<void>? subscription) async {
    try {
      await subscription?.cancel();
    } on Object {
      /* No raw cleanup detail. */
    }
  }

  @override
  void didUpdateWidget(covariant ConversationWorkspacePanel oldWidget) {
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

  Future<void> _turn(
    ConversationWorkspaceController c,
    TextEditingController editor,
  ) async {
    if (!_current(c) || !c.state.canTurn) return;
    final text = editor.text;
    await c.turn(text);
    if (!_current(c)) return;
    final state = c.state;
    _redact(state, editor);
    if (state.canTurn &&
        state.failure == null &&
        state.conversation?.failure == null) {
      editor.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final editor =
        _editor; // Retained callbacks never read a replacement editor.
    final state = c.state;
    _redact(state, editor);
    final scenarios = state.scenarios;
    final conversation = state.conversation;
    final snapshot = conversation?.conversation;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Luyện hội thoại bằng văn bản',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Giọng nói chưa khả dụng. Kết quả chưa lưu vào tiến độ hoặc SRS.',
          ),
          if (!state.isAvailable)
            const Text(
              'Hội thoại chưa khả dụng cho phiên hiện tại.',
              key: Key('workspace-unavailable'),
            )
          else ...[
            if (widget.binding?.createEventId == null)
              const Text('Gửi hội thoại chưa khả dụng.'),
            DropdownButtonFormField<AiTextLevel>(
              key: const Key('workspace-level'),
              initialValue: scenarios!.level,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Trình độ'),
              items: [
                for (final l in [AiTextLevel.n5, AiTextLevel.n4])
                  DropdownMenuItem(value: l, child: Text(l.wireName)),
              ],
              onChanged: state.canChoose
                  ? (v) {
                      if (_current(c) && v != null) c.chooseLevel(v);
                    }
                  : null,
            ),
            FilledButton(
              key: const Key('workspace-load'),
              onPressed: state.canLoad
                  ? () {
                      unawaited(c.loadScenarios());
                    }
                  : null,
              child: const Text('Tải tình huống'),
            ),
            if (scenarios.phase == ScenarioLoadPhase.idle &&
                snapshot?.phase == ConversationSessionPhase.notStarted)
              const Text('Tải và chọn một tình huống để bắt đầu.'),
            if (scenarios.phase == ScenarioLoadPhase.loading)
              const Text('Đang tải tình huống…'),
            if (scenarios.phase == ScenarioLoadPhase.error)
              const Text(
                'Chưa thể tải tình huống. Hãy thử tải lại khi kết nối ổn định.',
              ),
            if (scenarios.phase == ScenarioLoadPhase.ready &&
                scenarios.rows.isEmpty)
              const Text('Chưa có tình huống phù hợp.'),
            for (final row in scenarios.rows) ...[
              Text(row.titleJa),
              Text(row.titleVi),
              Text(row.descriptionVi),
              OutlinedButton(
                key: ValueKey('workspace-scenario-${row.id}'),
                onPressed: state.canChoose
                    ? () {
                        c.select(row);
                      }
                    : null,
                child: Text(
                  identical(scenarios.selected, row) ? 'Đã chọn' : 'Chọn',
                ),
              ),
            ],
            FilledButton(
              key: const Key('workspace-start'),
              onPressed: state.canStart
                  ? () {
                      unawaited(c.startSelected());
                    }
                  : null,
              child: const Text('Bắt đầu hội thoại'),
            ),
            if (conversation!.phase == AiConversationPhase.loading)
              const Text('Đang chờ phản hồi…'),
            if (state.failure ?? conversation.failure case final failure?)
              Text(failure.messageVi, key: const Key('workspace-error')),
            if (conversation.hasUnresolvedMutation)
              const Text(
                'Yêu cầu trước chưa rõ kết quả. Chỉ thử lại yêu cầu gốc khi nút được bật. Không tạo hội thoại mới.',
                key: Key('workspace-pending'),
              ),
            TextButton(
              key: const Key('workspace-recheck'),
              onPressed: c.recheck,
              child: const Text('Kiểm tra trạng thái'),
            ),
            OutlinedButton(
              key: const Key('workspace-retry'),
              onPressed: state.canRetry
                  ? () {
                      unawaited(c.retryPending());
                    }
                  : null,
              child: const Text('Thử lại yêu cầu gốc'),
            ),
            if (snapshot?.phase == ConversationSessionPhase.active) ...[
              TextField(
                key: const Key('workspace-editor'),
                controller: editor,
                enabled: state.canTurn,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Câu tiếng Nhật',
                  helperText: 'Tối đa 5.000 ký tự. Chỉ gửi khi nhấn nút.',
                ),
              ),
              FilledButton(
                key: const Key('workspace-send'),
                onPressed: state.canTurn
                    ? () {
                        unawaited(_turn(c, editor));
                      }
                    : null,
                child: const Text('Gửi câu'),
              ),
              OutlinedButton(
                key: const Key('workspace-finish'),
                onPressed: state.canFinish
                    ? () {
                        unawaited(c.finish());
                      }
                    : null,
                child: const Text('Kết thúc hội thoại'),
              ),
            ],
            for (final message
                in snapshot?.messages ??
                    const <ConversationAssistantMessage>[]) ...[
              Text(message.textJa),
              Text(message.textVi ?? 'Chưa có bản dịch.'),
            ],
            if (snapshot?.summary case final summary?) ...[
              const SizedBox(height: 20),
              ConversationSummary(summary: summary),
            ],
            if (snapshot?.phase == ConversationSessionPhase.finished)
              const Text(
                'Hội thoại đã kết thúc. Chưa mở lượt mới.',
                key: Key('workspace-finished'),
              ),
          ],
        ],
      ),
    );
  }
}
