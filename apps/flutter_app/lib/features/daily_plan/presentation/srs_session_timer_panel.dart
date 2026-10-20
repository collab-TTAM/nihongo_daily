import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/application/account_provider.dart';
import '../../srs/application/srs_study_controller.dart';
import '../../srs/application/srs_study_provider.dart';
import '../application/srs_session_recorder.dart';
import '../application/srs_session_recorder_provider.dart';
import '../domain/daily_plan.dart';

class SrsSessionTimerPanel extends ConsumerStatefulWidget {
  const SrsSessionTimerPanel({super.key});
  @override
  ConsumerState<SrsSessionTimerPanel> createState() =>
      _SrsSessionTimerPanelState();
}

class _SrsSessionTimerPanelState extends ConsumerState<SrsSessionTimerPanel>
    with WidgetsBindingObserver {
  final _date = TextEditingController();
  Timer? _ticker;
  SrsRecorderNotifier? _owner;
  String? _validation;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _owner?.interrupt();
  }

  void _start() {
    try {
      final date = DailyPlanDate(_date.text.trim());
      setState(() => _validation = null);
      unawaited(ref.read(srsSessionRecorderProvider.notifier).start(date));
    } on FormatException {
      setState(() => _validation = 'Nhập ngày hợp lệ theo dạng YYYY-MM-DD.');
    }
  }

  void _refreshTicker(bool running) {
    if (!running) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _owner?.interrupt();
    _date.clear();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(srsSessionRecorderProvider);
    final owner = ref.read(srsSessionRecorderProvider.notifier);
    _owner = owner;
    final canStudy = ref.watch(canStartSrsRecorderProvider);
    final profile = ref.watch(accountStateProvider).profile;
    final visible =
        state.phase != StudyRecorderPhase.unavailable && profile != null;
    final running = visible && state.phase == StudyRecorderPhase.running;
    _refreshTicker(running);
    ref.listen(srsStudyRuntimeProvider, (_, next) {
      _date.clear();
      _validation = null;
    });
    ref.listen(srsStudyProvider, (_, next) {
      if (const {
        SrsStudyPhase.loading,
        SrsStudyPhase.recovering,
        SrsStudyPhase.failed,
        SrsStudyPhase.unavailable,
        SrsStudyPhase.signedOut,
      }.contains(next.phase)) {
        owner.interrupt();
      }
    });
    final ack = state.acknowledgment;
    final latest = ack?.latestPlan;
    final elapsed = owner.elapsed;
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    // Retain EditableText through the binding's awaited OS-exit snapshot.
    // Revocation clears, disables, hides and excludes focus instead of disposing.
    return Offstage(
      key: const Key('srs-timer-panel'),
      offstage: !visible,
      child: ExcludeFocus(
        excluding: !visible,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Thời gian ôn SRS',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thời gian tự ghi nhận, tách biệt kết quả từng thẻ. Chỉ lưu khi bạn kết thúc buổi học.',
                ),
                const Text(
                  'Rời trang hoặc đưa ứng dụng xuống nền sẽ hủy bộ đếm đang chạy.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Ngày học theo múi giờ hồ sơ: ${profile?.timezone ?? ''}.',
                ),
                TextField(
                  key: const Key('srs-timer-date'),
                  controller: _date,
                  enabled: visible && state.canStart,
                  maxLength: 10,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Ngày học (YYYY-MM-DD)',
                  ),
                ),
                if (_validation != null)
                  Text(_validation!, key: const Key('srs-timer-validation')),
                if (state.canStart) ...[
                  if (!canStudy)
                    const Text(
                      'Cần thẻ ôn sẵn sàng và trình độ ôn trùng với hồ sơ.',
                    ),
                  FilledButton(
                    key: const Key('srs-timer-start'),
                    onPressed: visible && canStudy ? _start : null,
                    child: const Text('Bắt đầu tính giờ'),
                  ),
                ],
                if (state.busy) ...[
                  const LinearProgressIndicator(),
                  Text(
                    state.phase == StudyRecorderPhase.checking
                        ? 'Đang kiểm tra buổi còn chờ và kế hoạch…'
                        : 'Đang xác nhận buổi học…',
                  ),
                ],
                if (running) ...[
                  Text(
                    '$minutes:$seconds',
                    key: const Key('srs-timer-elapsed'),
                  ),
                  FilledButton(
                    key: const Key('srs-timer-finish'),
                    onPressed: () => unawaited(owner.finish()),
                    child: const Text('Kết thúc và lưu buổi học'),
                  ),
                  TextButton(
                    onPressed: owner.interrupt,
                    child: const Text('Hủy bộ đếm, không lưu'),
                  ),
                ],
                if (state.message != null)
                  Text(state.message!, key: const Key('srs-timer-message')),
                if (state.phase == StudyRecorderPhase.uncertain)
                  FilledButton(
                    key: const Key('srs-timer-retry'),
                    onPressed: () => unawaited(owner.retry()),
                    child: const Text('Thử lại cùng buổi học'),
                  ),
                if (state.phase == StudyRecorderPhase.recoveryRequired ||
                    state.phase == StudyRecorderPhase.uncertain)
                  TextButton(
                    onPressed: () => context.go('/study-recovery'),
                    child: const Text('Mở buổi học chờ đồng bộ'),
                  ),
                if (ack != null)
                  Text(
                    ack.reloadFailure == null
                        ? 'Buổi học đã được ghi nhận.'
                        : 'Buổi học đã được ghi nhận. Chưa tải được tiến độ mới.',
                    key: const Key('srs-timer-confirmed'),
                  ),
                if (latest != null)
                  Text(
                    'Ngày ${latest.date.value}: ${latest.completedMinutes}/${latest.targetMinutes} phút',
                    key: const Key('srs-timer-progress'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
