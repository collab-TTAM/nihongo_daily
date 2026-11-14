import 'dart:async';
import 'package:flutter/material.dart';
import '../application/grammar_quiz_attempt_factory.dart';
import '../data/quiz_report_v2_adapter.dart';
import '../data/quiz_report_v2_transport.dart';
import '../data/grammar_quiz_history_repository.dart';
import '../domain/grammar_quiz.dart';
import '../domain/grammar_quiz_attempt.dart';
import 'quiz_report_v2_action.dart';

/// Parent keys this to a completed round and retires it on owner/source change.
class GrammarQuizSaveAction extends StatefulWidget {
  const GrammarQuizSaveAction({
    super.key,
    required this.round,
    required this.kind,
    required this.history,
    required this.capture,
    required this.isCurrent,
    this.reportTransport,
  });
  final GrammarQuizRound round;
  final GrammarQuizAttemptKind kind;
  final GrammarQuizHistoryRepository? history;
  final GrammarQuizAttemptFactory capture;
  final bool Function() isCurrent;
  final QuizReportV2Submitter? reportTransport;
  @override
  State<GrammarQuizSaveAction> createState() => _GrammarQuizSaveActionState();
}

class _GrammarQuizSaveActionState extends State<GrammarQuizSaveAction> {
  late final _round = widget.round;
  late final _kind = widget.kind;
  late final _history = widget.history;
  late final _capture = widget.capture;
  late final _transport = widget.reportTransport;
  GrammarQuizAttempt? _attempt;
  QuizReportV2Request? _report;
  bool _saving = false;
  bool _saved = false;
  bool _failed = false;
  bool get _current =>
      mounted &&
      widget.isCurrent() &&
      identical(widget.round, _round) &&
      widget.kind == _kind &&
      identical(widget.history, _history) &&
      identical(widget.capture, _capture) &&
      identical(widget.reportTransport, _transport);

  @override
  void initState() {
    super.initState();
    if ((_history != null || _transport != null) &&
        _round.isComplete &&
        _current) {
      try {
        _attempt = _capture(_round, _kind);
        if (_transport != null) {
          _report = QuizReportV2Request.fromGrammarAttempt(_attempt!);
        }
      } on Object {
        // Capture failure cannot turn into an apparent saved or sent result.
      }
    }
  }

  Future<void> _save() async {
    final history = _history;
    final attempt = _attempt;
    if (!_current || _saving || _saved || history == null || attempt == null) {
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await history.save(attempt);
      if (_current) setState(() => _saved = true);
    } on Object {
      if (_current) setState(() => _failed = true);
    } finally {
      if (_current) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_current) {
      return const Text('Phiên đã thay đổi. Hãy bắt đầu lại bộ mới.');
    }
    if (_history == null && _transport == null) {
      return const Text(
        'Bộ này chưa có kho lưu theo tài khoản. Kết quả chỉ ở phiên này.',
      );
    }
    final attempt = _attempt;
    final report = _report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (attempt == null)
          const Text('Chưa thể chuẩn bị kết quả để lưu. Hãy làm lại bộ.'),
        if (_history != null) ...[
          FilledButton(
            key: const Key('grammar-quiz-save'),
            onPressed: attempt == null || _saving || _saved
                ? null
                : () => unawaited(_save()),
            child: Text(
              _saving ? 'Đang lưu…' : 'Lưu kết quả ngữ pháp trên thiết bị',
            ),
          ),
          if (_saved)
            const Text(
              'Đã lưu kết quả ngữ pháp trên thiết bị.',
              key: Key('grammar-quiz-saved'),
            ),
          if (_failed)
            const Text(
              'Chưa xác nhận đã lưu. Bạn có thể thử lưu lại đúng kết quả.',
              key: Key('grammar-quiz-save-error'),
            ),
        ],
        if (_transport != null) ...[
          if (attempt != null && report != null)
            QuizReportV2Action(
              key: ValueKey(report.clientEventId),
              request: report,
              submitter: _transport,
              isCurrent: () =>
                  _current &&
                  identical(_attempt, attempt) &&
                  identical(_report, report),
            )
          else
            const Text('Chưa thể chuẩn bị báo cáo máy chủ. Hãy làm lại bộ.'),
        ],
      ],
    );
  }
}
