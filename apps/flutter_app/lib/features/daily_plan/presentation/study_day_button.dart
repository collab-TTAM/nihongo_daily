import 'dart:async';
import 'package:flutter/material.dart';
import '../data/daily_plan_repository.dart';
import '../domain/daily_plan.dart';

/// An explicit server lookup fills a date; it never starts study or writes.
class StudyDayButton extends StatefulWidget {
  const StudyDayButton({
    super.key,
    required this.repository,
    required this.timezone,
    required this.enabled,
    required this.currentDate,
    required this.onDate,
  });
  final DailyPlanRepository? repository;
  final String? timezone;
  final bool enabled;
  final ValueChanged<DailyPlanDate> onDate;
  final String Function() currentDate;
  @override
  State<StudyDayButton> createState() => _StudyDayButtonState();
}

class _StudyDayButtonState extends State<StudyDayButton> {
  bool _busy = false;
  String? _error;
  int _generation = 0;
  @override
  void didUpdateWidget(covariant StudyDayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.timezone != widget.timezone ||
        !widget.enabled) {
      _generation++;
      _busy = false;
      _error = null;
    }
  }

  Future<void> _choose() async {
    final repository = widget.repository;
    final zone = widget.timezone;
    if (_busy || !widget.enabled || repository == null || zone == null) return;
    final initialDate = widget.currentDate();
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    DailyPlanDate? date;
    String? error;
    try {
      date = (await repository.loadStudyDay(zone)).date;
    } on DailyPlanFailure catch (failure) {
      error = failure.code == DailyPlanErrorCode.syncConflict
          ? 'Múi giờ hồ sơ đã thay đổi. Hãy làm mới phiên tại Tài khoản.'
          : failure.messageVi;
    } on Object {
      error = 'Chưa thể tải ngày học. Vui lòng thử lại.';
    }
    if (!mounted ||
        generation != _generation ||
        !widget.enabled ||
        !identical(widget.repository, repository) ||
        widget.timezone != zone) {
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
    if (date != null) {
      if (widget.currentDate() == initialDate) {
        widget.onDate(date);
      } else {
        setState(
          () => _error = 'Ngày nhập đã thay đổi. Vui lòng chọn lại nếu cần.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!(widget.repository?.supportsStudyDay ?? false)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: widget.enabled && !_busy
              ? () => unawaited(_choose())
              : null,
          child: Text(
            _busy ? 'Đang lấy ngày theo hồ sơ…' : 'Chọn hôm nay theo hồ sơ',
          ),
        ),
        if (_error != null) Text(_error!),
      ],
    );
  }
}
