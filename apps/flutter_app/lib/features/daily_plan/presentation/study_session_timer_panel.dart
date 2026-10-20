import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/application/account_provider.dart';
import '../../srs/application/srs_study_controller.dart';
import '../../srs/application/srs_study_provider.dart';
import '../application/study_session_recorder.dart';
import 'daily_plan_labels.dart';
import '../application/daily_plan_provider.dart';
import 'study_day_button.dart';
import '../application/srs_session_recorder_provider.dart';
import '../domain/daily_plan.dart';

class StudySessionTimerPanel extends ConsumerStatefulWidget {
  const StudySessionTimerPanel({
    super.key,
    required this.area,
    this.contentVisible = true,
  });
  final DailyPlanArea area;
  final bool contentVisible;
  @override
  ConsumerState<StudySessionTimerPanel> createState() =>
      _StudySessionTimerPanelState();
}

class _StudySessionTimerPanelState extends ConsumerState<StudySessionTimerPanel>
    with WidgetsBindingObserver {
  final _date = TextEditingController();
  Timer? _ticker;
  StudyRecorderNotifier? _owner;
  Key _key(String suffix) =>
      Key('${widget.area.wireName.toLowerCase()}-timer-$suffix');
  String? _validation;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant StudySessionTimerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.area != widget.area) {
      _owner?.interrupt(area: oldWidget.area);
      _date.clear();
      _validation = null;
    } else if (oldWidget.contentVisible && !widget.contentVisible) {
      _owner?.interrupt(area: widget.area);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _owner?.interrupt(area: widget.area);
    }
  }

  void _start() {
    if (!widget.contentVisible ||
        !ref.read(canStartStudyRecorderProvider(widget.area))) {
      return;
    }
    try {
      final date = DailyPlanDate(_date.text.trim());
      setState(() => _validation = null);
      unawaited(
        ref
            .read(studySessionRecorderProvider.notifier)
            .start(date, area: widget.area),
      );
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
    _owner?.interrupt(area: widget.area);
    _date.clear();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studySessionRecorderProvider);
    final owner = ref.read(studySessionRecorderProvider.notifier);
    _owner = owner;
    final canStudy =
        widget.contentVisible &&
        ref.watch(canStartStudyRecorderProvider(widget.area));
    final profile = ref.watch(accountStateProvider).profile;
    final visible =
        state.phase != StudyRecorderPhase.unavailable && profile != null;
    final ownsInterval = state.area == widget.area;
    final running =
        visible && ownsInterval && state.phase == StudyRecorderPhase.running;
    _refreshTicker(running);
    ref.listen(srsStudyRuntimeProvider, (_, next) {
      _date.clear();
      _validation = null;
    });
    ref.listen(durableStudyRepositoryProvider, (_, _) {
      _date.clear();
      _validation = null;
    });
    if (widget.area == DailyPlanArea.srs) {
      ref.listen(srsStudyProvider, (_, next) {
        if (const {
          SrsStudyPhase.loading,
          SrsStudyPhase.recovering,
          SrsStudyPhase.failed,
          SrsStudyPhase.unavailable,
          SrsStudyPhase.signedOut,
        }.contains(next.phase)) {
          owner.interrupt(area: widget.area);
        }
      });
    } else {
      ref.listen(canStartStudyRecorderProvider(widget.area), (_, next) {
        if (!next) {
          owner.interrupt(area: widget.area);
        }
      });
    }
    final report = owner.pendingEvent;
    final ack = state.acknowledgment;
    final latest = ack?.latestPlan;
    final elapsed = owner.elapsed;
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    // Retain EditableText through the binding's awaited OS-exit snapshot.
    // Revocation clears, disables, hides and excludes focus instead of disposing.
    return Offstage(
      key: _key('panel'),
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
                  widget.area == DailyPlanArea.srs
                      ? 'Thời gian ôn SRS'
                      : 'Thời gian học ${dailyPlanAreaLabel(widget.area).toLowerCase()}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.area == DailyPlanArea.srs
                      ? 'Thời gian tự ghi nhận, tách biệt kết quả từng thẻ. Chỉ lưu khi bạn kết thúc buổi học.'
                      : 'Thời gian tự ghi nhận, không phải điểm số hoặc mức ghi nhớ. Chỉ lưu khi bạn kết thúc buổi học.',
                ),
                const Text(
                  'Rời trang hoặc đưa ứng dụng xuống nền sẽ hủy bộ đếm đang chạy.',
                ),
                if (widget.area != DailyPlanArea.srs)
                  const Text(
                    'Đổi cấp độ hoặc tìm kiếm không có kết quả cũng hủy bộ đếm.',
                  ),
                const SizedBox(height: 12),
                Text(
                  'Ngày học theo múi giờ hồ sơ: ${profile?.timezone ?? ''}.',
                ),
                TextField(
                  key: _key('date'),
                  controller: _date,
                  enabled: visible && state.canStart,
                  maxLength: 10,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Ngày học (YYYY-MM-DD)',
                  ),
                ),
                StudyDayButton(
                  key: _key('today'),
                  currentDate: () => _date.text,
                  repository: ref
                      .watch(durableStudyRepositoryProvider)
                      ?.delegate,
                  timezone: profile?.timezone,
                  enabled: visible && state.canStart,
                  onDate: (date) {
                    if (ref.read(studySessionRecorderProvider).canStart) {
                      _date.text = date.value;
                    }
                  },
                ),
                if (_validation != null)
                  Text(_validation!, key: _key('validation')),
                if (state.canStart) ...[
                  if (!canStudy)
                    Text(
                      widget.area == DailyPlanArea.srs
                          ? 'Cần thẻ ôn sẵn sàng và trình độ ôn trùng với hồ sơ.'
                          : 'Cần bài học khả dụng và trình độ đang đọc trùng với hồ sơ.',
                    ),
                  FilledButton(
                    key: _key('start'),
                    onPressed: visible && canStudy ? _start : null,
                    child: const Text('Bắt đầu tính giờ'),
                  ),
                ],
                if (state.area != null && state.area != widget.area)
                  Text(
                    'Buổi hiện tại thuộc phần: ${dailyPlanAreaLabel(state.area!)}.',
                    key: _key('report-area'),
                  ),
                if (report != null)
                  Text(
                    '${dailyPlanAreaLabel(report.area)} · Ngày ${report.date.value}\n'
                    'UTC ${report.startedAt.toIso8601String()} → ${report.endedAt.toIso8601String()}',
                    key: _key('frozen-report'),
                  ),
                if (visible &&
                    state.phase == StudyRecorderPhase.running &&
                    !ownsInterval)
                  const Text('Một bộ đếm ở phần học khác đang chạy.'),
                if (state.busy) ...[
                  const LinearProgressIndicator(),
                  Text(
                    state.phase == StudyRecorderPhase.checking
                        ? 'Đang kiểm tra buổi còn chờ và kế hoạch…'
                        : 'Đang xác nhận buổi học…',
                  ),
                ],
                if (running) ...[
                  Text('$minutes:$seconds', key: _key('elapsed')),
                  FilledButton(
                    key: _key('finish'),
                    onPressed: () {
                      final current = ref.read(studySessionRecorderProvider);
                      if (current.area == widget.area &&
                          current.phase == StudyRecorderPhase.running) {
                        unawaited(owner.finish());
                      }
                    },
                    child: const Text('Kết thúc và lưu buổi học'),
                  ),
                  TextButton(
                    onPressed: () => owner.interrupt(area: widget.area),
                    child: const Text('Hủy bộ đếm, không lưu'),
                  ),
                ],
                if (state.message != null)
                  Text(state.message!, key: _key('message')),
                if (state.phase == StudyRecorderPhase.uncertain)
                  FilledButton(
                    key: _key('retry'),
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
                    key: _key('confirmed'),
                  ),
                if (latest != null)
                  Text(
                    'Ngày ${latest.date.value}: ${latest.completedMinutes}/${latest.targetMinutes} phút',
                    key: _key('progress'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
