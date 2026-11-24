import 'package:flutter/material.dart';

import '../data/quiz_report_v2_adapter.dart';
import '../data/quiz_report_v2_transport.dart';
import 'quiz_report_v2_action.dart';

typedef SavedQuizReportRequestBuilder = QuizReportV2Request Function();

/// A manual, lookup-first server replay of an immutable local quiz attempt.
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
  QuizReportV2Response? _response;
  QuizReportV2TransportFailure? _lookupFailure;
  bool _checking = false;
  bool _allowSubmit = false;
  bool _confirmed = false;

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

  Future<void> _lookup() async {
    final request = _request;
    if (!_current() ||
        request == null ||
        _checking ||
        _allowSubmit ||
        _confirmed) {
      return;
    }
    setState(() {
      _checking = true;
      _lookupFailure = null;
    });
    try {
      final result = await _submitter.lookupReceipt(request);
      if (!_current()) return;
      if (result.clientEventId != request.clientEventId) {
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.internalError,
        );
      }
      if (result.hasReceipt && result.response != null) {
        setState(() {
          _response = result.response;
          _confirmed = true;
          _allowSubmit = false;
        });
      } else if (result.isUnresolved) {
        setState(() => _allowSubmit = true);
      } else {
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.internalError,
        );
      }
    } on QuizReportV2TransportFailure catch (error) {
      if (_current()) setState(() => _lookupFailure = error);
    } on Object {
      if (_current()) {
        setState(
          () => _lookupFailure = const QuizReportV2TransportFailure(
            QuizReportV2TransportCode.internalError,
          ),
        );
      }
    } finally {
      if (_current()) setState(() => _checking = false);
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
    if (_confirmed && _response != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Máy chủ đã xác nhận báo cáo: ${_response!.correctCount}/'
            '${_response!.answerCount} câu đúng.',
            key: const Key('quiz-report-confirmed'),
          ),
          const Text(
            'Báo cáo này không tự xác định mức ghi nhớ hoặc cộng thời gian học.',
          ),
        ],
      );
    }
    if (_allowSubmit) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Chưa tìm thấy biên nhận. Nếu tiếp tục, ứng dụng sẽ gửi lại đúng '
            'mã lượt và nội dung đã lưu.',
            key: Key('quiz-report-history-unresolved'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Kiểm tra biên nhận máy chủ trước khi gửi lại kết quả đã lưu. '
          'Không tự gửi khi mở lịch sử.',
        ),
        OutlinedButton(
          key: const Key('quiz-report-history-lookup'),
          onPressed: _checking ? null : () => _lookup(),
          child: Text(
            _checking ? 'Đang kiểm tra…' : 'Kiểm tra biên nhận máy chủ',
          ),
        ),
        if (_checking) const LinearProgressIndicator(),
        if (_lookupFailure != null)
          Text(
            _lookupFailure!.messageVi,
            key: const Key('quiz-report-history-lookup-error'),
          ),
      ],
    );
  }
}
