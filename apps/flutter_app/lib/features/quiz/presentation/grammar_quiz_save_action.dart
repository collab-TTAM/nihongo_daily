import 'dart:async';
import 'package:flutter/material.dart';
import '../application/grammar_quiz_attempt_factory.dart';
import '../data/grammar_quiz_history_repository.dart';
import '../domain/grammar_quiz.dart';
import '../domain/grammar_quiz_attempt.dart';

/// Parent keys this to a completed round and retires it on owner/source change.
class GrammarQuizSaveAction extends StatefulWidget {
  const GrammarQuizSaveAction({
    super.key,
    required this.round,
    required this.kind,
    required this.history,
    required this.capture,
    required this.isCurrent,
  });
  final GrammarQuizRound round;
  final GrammarQuizAttemptKind kind;
  final GrammarQuizHistoryRepository? history;
  final GrammarQuizAttemptFactory capture;
  final bool Function() isCurrent;
  @override
  State<GrammarQuizSaveAction> createState() => _GrammarQuizSaveActionState();
}

class _GrammarQuizSaveActionState extends State<GrammarQuizSaveAction> {
  late final _round = widget.round;
  late final _kind = widget.kind;
  late final _history = widget.history;
  late final _capture = widget.capture;
  GrammarQuizAttempt? _attempt;
  bool _saving = false;
  bool _saved = false;
  bool _failed = false;
  bool get _current =>
      mounted &&
      widget.isCurrent() &&
      identical(widget.round, _round) &&
      widget.kind == _kind &&
      identical(widget.history, _history) &&
      identical(widget.capture, _capture);

  @override
  void initState() {
    super.initState();
    if (_history != null && _round.isComplete && _current) {
      try {
        _attempt = _capture(_round, _kind);
      } on Object {
        // Capture failure cannot turn into an apparent saved result.
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
    if (_history == null) {
      return const Text(
        'Bộ này chưa có kho lưu theo tài khoản. Kết quả chỉ ở phiên này.',
      );
    }
    if (!_current) {
      return const Text('Phiên đã thay đổi. Hãy bắt đầu lại bộ mới.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_attempt == null)
          const Text('Chưa thể chuẩn bị kết quả để lưu. Hãy làm lại bộ.'),
        FilledButton(
          key: const Key('grammar-quiz-save'),
          onPressed: _attempt == null || _saving || _saved
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
    );
  }
}
