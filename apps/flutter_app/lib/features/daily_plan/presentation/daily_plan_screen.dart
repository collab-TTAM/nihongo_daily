import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/page_body.dart';
import '../../auth/application/account_provider.dart';
import '../application/daily_plan_provider.dart';
import '../data/daily_plan_repository.dart';
import '../domain/daily_plan.dart';
import 'daily_plan_labels.dart';
import 'study_day_button.dart';

class DailyPlanScreen extends ConsumerStatefulWidget {
  const DailyPlanScreen({super.key});
  @override
  ConsumerState<DailyPlanScreen> createState() => _DailyPlanScreenState();
}

class _DailyPlanScreenState extends ConsumerState<DailyPlanScreen> {
  final _date = TextEditingController();
  DailyPlan? _plan;
  String? _message;
  bool _loading = false;

  Future<void> _load() async {
    if (_loading) return;
    DailyPlanDate date;
    try {
      date = DailyPlanDate(_date.text.trim());
    } on FormatException {
      setState(() {
        _plan = null;
        _message = 'Nhập ngày hợp lệ theo dạng YYYY-MM-DD.';
      });
      return;
    }
    final repository = ref.read(dailyPlanRepositoryProvider);
    if (repository == null) return;
    setState(() {
      _loading = true;
      _plan = null;
      _message = null;
    });
    DailyPlan? plan;
    String? message;
    try {
      plan = await repository.load(date);
    } on DailyPlanFailure catch (failure) {
      message = failure.messageVi;
    } on Object {
      message = 'Chưa thể tải kế hoạch học. Vui lòng thử lại.';
    }
    if (!mounted ||
        !identical(ref.read(dailyPlanRepositoryProvider), repository)) {
      return;
    }
    setState(() {
      _loading = false;
      _plan = plan;
      _message = message;
    });
  }

  @override
  void dispose() {
    _date.clear();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(dailyPlanRepositoryProvider);
    final study = ref.watch(durableStudyRepositoryProvider);
    final profile = ref.watch(accountStateProvider).profile;
    final ready = repository != null && profile != null;
    ref.listen(dailyPlanRepositoryProvider, (_, next) {
      _date.clear();
      _plan = null;
      _message = null;
      _loading = false;
    });
    final plan = ready ? _plan : null;
    return PageBody(
      children: [
        PageHeading(
          title: 'Kế hoạch học',
          subtitle: ready
              ? 'Chọn ngày theo múi giờ hồ sơ: ${profile.timezone}.'
              : 'Cần phiên đăng nhập và hồ sơ học tập đã sẵn sàng.',
        ),
        if (!ready)
          FilledButton(
            onPressed: () => context.go('/auth'),
            child: const Text('Mở tài khoản'),
          ),
        // Keep EditableText's lifecycle observer mounted during the OS exit
        // snapshot. Revocation clears/disables/hides it, as in AccountScreen.
        Offstage(
          key: const Key('plan-form'),
          offstage: !ready,
          child: ExcludeFocus(
            excluding: !ready,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Kế hoạch và tiến độ được tải từ máy chủ.'),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('plan-date'),
                  controller: _date,
                  enabled: ready && !_loading,
                  maxLength: 10,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Ngày học (YYYY-MM-DD)',
                    hintText: '2026-10-20',
                  ),
                  onSubmitted: ready && !_loading
                      ? (_) => unawaited(_load())
                      : null,
                ),
                StudyDayButton(
                  key: const Key('plan-today'),
                  currentDate: () => _date.text,
                  repository: repository,
                  timezone: profile?.timezone,
                  enabled: ready && !_loading,
                  onDate: (date) {
                    if (ready && !_loading) _date.text = date.value;
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('plan-load'),
                  onPressed: ready && !_loading
                      ? () => unawaited(_load())
                      : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tải kế hoạch'),
                ),
              ],
            ),
          ),
        ),
        if (ready && study != null)
          OutlinedButton(
            onPressed: () => context.go('/study-recovery'),
            child: const Text('Buổi học chờ đồng bộ'),
          ),
        const SizedBox(height: 20),
        if (ready && _loading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          const Text('Đang tải kế hoạch…'),
        ],
        if (ready && _message != null)
          Text(_message!, key: const Key('plan-error')),
        if (plan != null) ...[
          Text(
            'Ngày ${plan.date.value}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            '${plan.completedMinutes}/${plan.targetMinutes} phút',
            key: const Key('plan-progress'),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (plan.completedMinutes / plan.targetMinutes).clamp(0.0, 1.0),
            semanticsLabel: 'Tiến độ theo máy chủ',
          ),
          const SizedBox(height: 16),
          if (plan.blocks.every((b) => b.status == DailyPlanStatus.blocked))
            const Text('Chưa có phần học khả dụng cho ngày này.'),
          for (final block in plan.blocks)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dailyPlanAreaLabel(block.area)),
                    const SizedBox(height: 8),
                    Text(
                      '${block.plannedMinutes} phút · ${dailyPlanStatusLabel(block.status)}',
                    ),
                    Text('${block.itemCount} mục trong kế hoạch'),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
