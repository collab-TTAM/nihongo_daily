import 'dart:async';
import 'package:flutter/material.dart';
import '../application/ai_conversation_scenario_binding.dart';
import '../application/conversation_scenario_controller.dart';
import '../domain/ai_text_models.dart';

/// Explicit read/selection only. No conversation start, generated IDs or writes.
class ConversationScenarioPanel extends StatefulWidget {
  const ConversationScenarioPanel({super.key, this.binding});
  final AiConversationScenarioBinding? binding;
  @override
  State<ConversationScenarioPanel> createState() => _ScenarioPanelState();
}

class _ScenarioPanelState extends State<ConversationScenarioPanel> {
  late ConversationScenarioController _controller;
  StreamSubscription<void>? _subscription;
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _controller = ConversationScenarioController(
      reader: widget.binding?.reader,
      availabilityChanges: widget.binding?.availabilityChanges,
    );
    _subscription = _controller.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _cancel(StreamSubscription<void>? s) async {
    try {
      await s?.cancel();
    } on Object {
      /* No raw view cleanup error. */
    }
  }

  void _detach() {
    unawaited(_cancel(_subscription));
    _subscription = null;
    _controller.dispose();
  }

  @override
  void didUpdateWidget(covariant ConversationScenarioPanel oldWidget) {
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
    final controller = _controller; // Old callbacks stay bound to the old view.
    final state = controller.state;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chọn tình huống',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Chọn tình huống chưa bắt đầu hội thoại. Giọng nói chưa khả dụng.',
          ),
          if (state.phase == ScenarioLoadPhase.unavailable)
            const Text(
              'Danh sách tình huống chưa khả dụng cho phiên hiện tại.',
              key: Key('scenario-unavailable'),
            )
          else ...[
            DropdownButtonFormField<AiTextLevel>(
              key: const Key('scenario-level'),
              initialValue: state.level,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Trình độ'),
              items: [
                for (final level in [AiTextLevel.n5, AiTextLevel.n4])
                  DropdownMenuItem(value: level, child: Text(level.wireName)),
              ],
              onChanged: state.canLoad
                  ? (value) {
                      if (value != null && controller.chooseLevel(value)) {
                        setState(() {});
                      }
                    }
                  : null,
            ),
            FilledButton(
              key: const Key('scenario-load'),
              onPressed: state.canLoad
                  ? () {
                      unawaited(controller.load());
                    }
                  : null,
              child: const Text('Tải tình huống'),
            ),
            TextButton(
              key: const Key('scenario-recheck'),
              onPressed: controller.recheck,
              child: const Text('Kiểm tra trạng thái'),
            ),
            if (state.phase == ScenarioLoadPhase.idle)
              const Text('Nhấn tải để xem tình huống. Chưa gửi yêu cầu.'),
            if (state.phase == ScenarioLoadPhase.loading)
              const Text('Đang tải tình huống…', key: Key('scenario-loading')),
            if (state.phase == ScenarioLoadPhase.error)
              const Text(
                'Chưa thể tải danh sách tình huống. Hãy kiểm tra kết nối và thử lại.',
                key: Key('scenario-error'),
              ),
            if (!state.canLoad && state.phase != ScenarioLoadPhase.loading)
              const Text(
                'Yêu cầu trước chưa kết thúc. Kiểm tra trạng thái sau khi kết nối ổn định.',
              ),
            if (state.phase == ScenarioLoadPhase.ready && state.rows.isEmpty)
              const Text(
                'Chưa có tình huống phù hợp.',
                key: Key('scenario-empty'),
              ),
            for (final row in state.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(row.titleJa),
                    Text(row.titleVi),
                    Text(row.descriptionVi),
                    OutlinedButton(
                      key: ValueKey('scenario-${row.id}'),
                      onPressed: state.canLoad
                          ? () {
                              if (controller.select(row)) setState(() {});
                            }
                          : null,
                      child: Text(
                        identical(state.selected, row) ? 'Đã chọn' : 'Chọn',
                      ),
                    ),
                  ],
                ),
              ),
            if (state.selected != null)
              Text(
                'Đã chọn: ${state.selected!.titleVi}. Chưa bắt đầu.',
                key: const Key('scenario-selected'),
              ),
          ],
        ],
      ),
    );
  }
}
