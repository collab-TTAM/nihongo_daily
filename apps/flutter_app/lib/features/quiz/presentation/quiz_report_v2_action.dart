import 'package:flutter/material.dart';

import '../data/quiz_report_v2_adapter.dart';
import '../data/quiz_report_v2_transport.dart';

/// An explicit server-report action. Local device history is a separate action.
class QuizReportV2Action extends StatefulWidget {
  const QuizReportV2Action({
    super.key,
    required this.request,
    required this.submitter,
    required this.isCurrent,
  });

  final QuizReportV2Request request;
  final QuizReportV2Submitter submitter;
  final bool Function() isCurrent;

  @override
  State<QuizReportV2Action> createState() => _QuizReportV2ActionState();
}

class _QuizReportV2ActionState extends State<QuizReportV2Action> {
  late final _request = widget.request;
  late final _submitter = widget.submitter;

  bool _submitting = false;
  bool _lookingUp = false;
  bool _confirmed = false;
  bool _uncertain = false;
  bool _unresolved = false;
  bool _retryRateLimited = false;
  QuizReportV2TransportFailure? _submitFailure;
  QuizReportV2TransportFailure? _lookupFailure;
  QuizReportV2Response? _response;

  bool _current() {
    if (!mounted ||
        !identical(widget.request, _request) ||
        !identical(widget.submitter, _submitter)) {
      return false;
    }
    try {
      return widget.isCurrent();
    } on Object {
      return false;
    }
  }

  bool _isUncertain(QuizReportV2TransportCode code) =>
      code == QuizReportV2TransportCode.networkUnavailable ||
      code == QuizReportV2TransportCode.providerUnavailable ||
      code == QuizReportV2TransportCode.internalError;

  Future<void> _submit() async {
    if (!_current() ||
        _submitting ||
        _lookingUp ||
        _confirmed ||
        _uncertain ||
        (_submitFailure != null && !_retryRateLimited)) {
      return;
    }
    setState(() {
      _submitting = true;
      _submitFailure = null;
      _retryRateLimited = false;
    });
    try {
      final response = await _submitter.submit(_request);
      if (_current()) {
        setState(() {
          _response = response;
          _confirmed = true;
          _uncertain = false;
          _unresolved = false;
        });
      }
    } on QuizReportV2TransportFailure catch (error) {
      if (_current()) {
        setState(() {
          _submitFailure = error;
          _uncertain = _isUncertain(error.code);
          _retryRateLimited =
              error.code == QuizReportV2TransportCode.rateLimited;
        });
      }
    } on Object {
      if (_current()) {
        setState(() {
          _submitFailure = const QuizReportV2TransportFailure(
            QuizReportV2TransportCode.internalError,
          );
          _uncertain = true;
          _retryRateLimited = false;
        });
      }
    } finally {
      if (_current()) setState(() => _submitting = false);
    }
  }

  Future<void> _lookup() async {
    if (!_current() || !_uncertain || _lookingUp || _confirmed) return;
    setState(() {
      _lookingUp = true;
      _lookupFailure = null;
      _unresolved = false;
    });
    try {
      final result = await _submitter.lookupReceipt(_request);
      if (!_current()) return;
      if (result.clientEventId != _request.clientEventId) {
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.internalError,
        );
      }
      setState(() {
        if (result.hasReceipt && result.response != null) {
          _response = result.response;
          _confirmed = true;
          _uncertain = false;
          _unresolved = false;
          _submitFailure = null;
          _lookupFailure = null;
          _retryRateLimited = false;
        } else if (result.isUnresolved) {
          _unresolved = true;
        } else {
          _lookupFailure = const QuizReportV2TransportFailure(
            QuizReportV2TransportCode.internalError,
          );
        }
      });
    } on QuizReportV2TransportFailure catch (error) {
      if (_current()) {
        setState(() {
          _lookupFailure = error;
          _unresolved = false;
        });
      }
    } on Object {
      if (_current()) {
        setState(() {
          _lookupFailure = const QuizReportV2TransportFailure(
            QuizReportV2TransportCode.internalError,
          );
          _unresolved = false;
        });
      }
    } finally {
      if (_current()) setState(() => _lookingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_current()) return const SizedBox.shrink();
    final retrying = _retryRateLimited;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_confirmed && !_uncertain)
          FilledButton(
            key: Key(retrying ? 'quiz-report-retry' : 'quiz-report-submit'),
            onPressed: _submitting || _lookingUp ? null : () => _submit(),
            child: Text(
              _submitting
                  ? 'Đang gửi báo cáo…'
                  : retrying
                  ? 'Gửi lại cùng mã lượt'
                  : 'Gửi báo cáo kết quả lên máy chủ',
            ),
          ),
        if (_submitting || _lookingUp) const LinearProgressIndicator(),
        if (_submitFailure != null)
          Text(
            _submitFailure!.messageVi,
            key: const Key('quiz-report-submit-error'),
          ),
        if (_uncertain && !_confirmed) ...[
          const Text(
            'Phản hồi chưa xác định. Không gửi lại tự động; hãy kiểm tra biên nhận.',
          ),
          OutlinedButton(
            key: const Key('quiz-report-lookup'),
            onPressed: _lookingUp ? null : () => _lookup(),
            child: Text(
              _lookingUp ? 'Đang kiểm tra…' : 'Kiểm tra biên nhận máy chủ',
            ),
          ),
          if (_unresolved)
            const Text(
              'Chưa tìm thấy biên nhận. Kết quả vẫn chưa xác định; chỉ có thể kiểm tra lại.',
              key: Key('quiz-report-unresolved'),
            ),
          if (_lookupFailure != null)
            Text(
              _lookupFailure!.messageVi,
              key: const Key('quiz-report-lookup-error'),
            ),
        ],
        if (_confirmed && _response != null) ...[
          Text(
            'Máy chủ đã xác nhận báo cáo: ${_response!.correctCount}/${_response!.answerCount} câu đúng.',
            key: const Key('quiz-report-confirmed'),
          ),
          const Text(
            'Báo cáo này không tự xác định mức ghi nhớ hoặc cộng thời gian học.',
          ),
        ],
      ],
    );
  }
}
