import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/page_body.dart';
import '../application/daily_plan_provider.dart';
import '../data/daily_plan_repository.dart';
import '../data/durable_study_session_repository.dart';
import '../domain/completed_study_session.dart';
import 'daily_plan_labels.dart';

class StudyRecoveryScreen extends ConsumerStatefulWidget {
  const StudyRecoveryScreen({super.key});
  @override
  ConsumerState<StudyRecoveryScreen> createState() =>
      _StudyRecoveryScreenState();
}

class _StudyRecoveryScreenState extends ConsumerState<StudyRecoveryScreen> {
  List<CompletedStudySession>? _pending;
  StudySessionAcknowledgment? _ack;
  String? _error;
  bool _busy = false;

  bool _current(DurableStudySessionRepository service) =>
      mounted && identical(ref.read(durableStudyRepositoryProvider), service);

  Future<void> _check() async {
    final service = ref.read(durableStudyRepositoryProvider);
    if (_busy || service == null) return;
    setState(() {
      _busy = true;
      _pending = null;
      _ack = null;
      _error = null;
    });
    List<CompletedStudySession>? pending;
    String? error;
    try {
      pending = await service.recoverPending();
    } on DailyPlanFailure catch (failure) {
      error = failure.messageVi;
    } on StudySessionStorageFailure catch (failure) {
      error = failure.toString();
    } on Object {
      error = 'Chưa thể kiểm tra buổi học trên thiết bị. Vui lòng thử lại.';
    }
    if (!_current(service)) return;
    setState(() {
      _busy = false;
      _pending = pending;
      _error = error;
    });
  }

  Future<void> _send(CompletedStudySession event) async {
    final service = ref.read(durableStudyRepositoryProvider);
    if (_busy || service == null || !(_pending?.contains(event) ?? false)) {
      return;
    }
    setState(() {
      _busy = true;
      _ack = null;
      _error = null;
    });
    StudySessionAcknowledgment? acknowledgment;
    String? error;
    try {
      acknowledgment = await service.submit(event);
    } on DailyPlanFailure catch (failure) {
      error = isDefinitiveStudyRejection(failure)
          ? 'Buổi học không được chấp nhận. ${failure.messageVi} Bạn có thể kiểm tra lại danh sách.'
          : 'Chưa xác nhận được kết quả đồng bộ. ${failure.messageVi}';
    } on StudySessionStorageFailure catch (failure) {
      error = failure.toString();
    } on Object {
      error = 'Chưa xác nhận được kết quả đồng bộ. Vui lòng thử lại.';
    }
    if (!_current(service)) return;
    setState(() {
      _busy = false;
      _ack = acknowledgment;
      _error = error;
      if (acknowledgment != null) {
        _pending = _pending
            ?.where((e) => e.clientEventId != event.clientEventId)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(durableStudyRepositoryProvider);
    ref.listen(durableStudyRepositoryProvider, (_, next) {
      _pending = null;
      _ack = null;
      _error = null;
      _busy = false;
    });
    final ack = service == null ? null : _ack;
    final latest = ack?.latestPlan;
    return PageBody(
      children: [
        const PageHeading(
          title: 'Buổi học chờ đồng bộ',
          subtitle:
              'Kiểm tra buổi học đã lưu trên thiết bị và chọn từng buổi để đồng bộ.',
        ),
        if (service == null)
          FilledButton(
            onPressed: () => context.go('/auth'),
            child: const Text('Mở tài khoản'),
          )
        else ...[
          const Text(
            'Không tự động gửi lại. Ngày học được giữ nguyên; thời gian bên dưới hiển thị theo UTC.',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('study-recovery-check'),
            onPressed: _busy ? null : () => unawaited(_check()),
            child: const Text('Kiểm tra buổi học trên thiết bị'),
          ),
          if (_busy) ...[
            const LinearProgressIndicator(),
            const Text('Đang xử lý buổi học…'),
          ],
          if (_error != null)
            Text(_error!, key: const Key('study-recovery-error')),
          if (ack != null)
            Text(
              ack.reloadFailure == null
                  ? 'Buổi học đã được ghi nhận.'
                  : 'Buổi học đã được ghi nhận. Chưa tải được tiến độ mới.',
              key: const Key('study-recovery-confirmed'),
            ),
          if (latest != null)
            Text(
              'Ngày ${latest.date.value}: ${latest.completedMinutes}/${latest.targetMinutes} phút',
              key: const Key('study-recovery-progress'),
            ),
          if (_pending?.isEmpty ?? false)
            const Text('Không có buổi học chờ đồng bộ.'),
          for (final event in _pending ?? <CompletedStudySession>[])
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dailyPlanAreaLabel(event.area)} · ${event.date.value}',
                    ),
                    const SizedBox(height: 8),
                    Text('Bắt đầu: ${_utc(event.startedAt)}'),
                    Text('Kết thúc: ${_utc(event.endedAt)}'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: Key('study-recovery-send-${event.clientEventId}'),
                      onPressed: _busy ? null : () => unawaited(_send(event)),
                      child: const Text('Đồng bộ buổi học'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/plan'),
            child: const Text('Xem kế hoạch học'),
          ),
        ],
      ],
    );
  }
}

String _utc(DateTime time) =>
    '${time.toUtc().toIso8601String().substring(0, 19).replaceFirst('T', ' ')} UTC';
