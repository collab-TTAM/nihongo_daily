import 'package:flutter/material.dart';

import '../data/quiz_report_v2_adapter.dart';
import '../data/quiz_report_v2_transport.dart';
import 'quiz_report_v2_action.dart';

typedef SavedQuizReportRequestBuilder = QuizReportV2Request Function();

/// A manual server replay of an immutable attempt already stored on this device.
class SavedQuizReportReplayAction extends StatefulWidget {
  const SavedQuizReportReplayAction({
    super.key,
    required this.buildRequest,
    required this.submitter,
    required this.isCurrent,
  });

  final SavedQuizReportRequestBuilder buildRequest;
  final QuizReportV2Submitter submitter;
  final bool Function() isCurrent;

  @override
  State<SavedQuizReportReplayAction> createState() =>
      _SavedQuizReportReplayActionState();
}

class _SavedQuizReportReplayActionState
    extends State<SavedQuizReportReplayAction> {
  late final QuizReportV2Submitter _submitter;
  QuizReportV2Request? _request;

  @override
  void initState() {
    super.initState();
    _submitter = widget.submitter;
    try {
      _request = widget.buildRequest();
    } on FormatException {
      // Legacy attempts without displayed choice provenance remain local-only.
    }
  }

  bool _current() {
    if (!mounted || !identical(widget.submitter, _submitter)) return false;
    try {
      return widget.isCurrent();
    } on Object {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_current()) return const SizedBox.shrink();
    final request = _request;
    if (request == null) {
      return const Text(
        'Bản ghi cũ thiếu phiên bản lựa chọn đã hiển thị nên chưa thể gửi báo cáo máy chủ.',
        key: Key('quiz-report-legacy-unavailable'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Gửi thủ công từ kết quả đã lưu, dùng cùng mã lượt. Không tự gửi hoặc cộng tiến độ.',
        ),
        QuizReportV2Action(
          key: ValueKey(request.clientEventId),
          request: request,
          submitter: _submitter,
          isCurrent: _current,
        ),
      ],
    );
  }
}
