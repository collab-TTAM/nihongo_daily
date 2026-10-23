import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../daily_plan/application/srs_session_recorder_provider.dart';
import '../../daily_plan/domain/daily_plan.dart';
import '../../daily_plan/presentation/study_session_timer_panel.dart';
import '../application/quiz_attempt_factory.dart';
import '../data/vocabulary_quiz_history_repository.dart';
import '../domain/vocabulary_quiz.dart';
import '../domain/vocabulary_quiz_attempt.dart';

class VocabularyQuizPanel extends ConsumerStatefulWidget {
  const VocabularyQuizPanel({
    super.key,
    required this.questions,
    required this.history,
    required this.capture,
    this.enableStudyTimer = true,
  });
  final List<QuizQuestion> questions;
  final VocabularyQuizHistoryRepository? history;
  final QuizAttemptFactory capture;
  final bool enableStudyTimer;

  @override
  ConsumerState<VocabularyQuizPanel> createState() =>
      _VocabularyQuizPanelState();
}

class _VocabularyQuizPanelState extends ConsumerState<VocabularyQuizPanel> {
  int _offset = 0;
  late QuizRound _round;
  VocabularyQuizHistoryRepository? _roundHistory;
  VocabularyQuizAttempt? _attempt;
  bool _saving = false;
  bool _saved = false;
  bool _saveFailed = false;
  bool _captureFailed = false;
  bool get _eligible =>
      _roundHistory != null && identical(widget.history, _roundHistory);

  @override
  void didUpdateWidget(covariant VocabularyQuizPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.history, widget.history)) {
      _saving = false;
      _saved = false;
      _saveFailed = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  void _startRound() {
    _round = QuizRound(widget.questions.skip(_offset).take(10).toList());
    _roundHistory = widget.history;
    _attempt = null;
    _saving = false;
    _saved = false;
    _saveFailed = false;
    _captureFailed = false;
  }

  void _restart(QuizRound expected, {bool next = false}) {
    if (!mounted || !identical(_round, expected) || _saving) return;
    if (widget.enableStudyTimer) {
      ref
          .read(studySessionRecorderProvider.notifier)
          .interrupt(area: DailyPlanArea.quizReview);
    }
    setState(() {
      if (next) _offset += expected.questions.length;
      _startRound();
    });
  }

  void _answer(QuizRound expected, String questionId, String choiceId) {
    if (!mounted || !identical(_round, expected)) return;
    if (_roundHistory != null && !_eligible) return;
    if (expected.answer(questionId, choiceId)) setState(() {});
  }

  void _advance(QuizRound expected, String questionId) {
    if (!mounted || !identical(_round, expected)) return;
    if (_roundHistory != null && !_eligible) return;
    if (expected.advance(questionId)) {
      if (expected.isComplete && _eligible) {
        try {
          _attempt = widget.capture(expected);
        } on Object {
          _captureFailed = true;
        }
      }
      setState(() {});
    }
  }

  Future<void> _save(QuizRound expected) async {
    final repository = _roundHistory;
    final attempt = _attempt;
    if (!_eligible ||
        _saving ||
        _saved ||
        repository == null ||
        attempt == null ||
        !identical(_round, expected)) {
      return;
    }
    bool current() =>
        mounted &&
        identical(_round, expected) &&
        identical(_attempt, attempt) &&
        _eligible;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await repository.save(attempt);
      if (current()) setState(() => _saved = true);
    } on Object {
      if (current()) setState(() => _saveFailed = true);
    } finally {
      if (current()) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    final current = _roundHistory == null || _eligible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Keep the editor mounted even when the captured history owner changes.
        if (widget.enableStudyTimer)
          StudySessionTimerPanel(
            area: DailyPlanArea.quizReview,
            contentVisible: current,
            isContentCurrent: () =>
                mounted &&
                identical(_round, round) &&
                (_roundHistory == null || _eligible),
          ),
        _quizBody(context, round),
      ],
    );
  }

  Widget _quizBody(BuildContext context, QuizRound round) {
    if (_roundHistory != null && !_eligible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Phiên tài khoản đã thay đổi. Hãy bắt đầu lại bộ mới.'),
          OutlinedButton(
            onPressed: () => _restart(round),
            child: const Text('Làm lại bộ này'),
          ),
        ],
      );
    }
    final question = round.current;
    if (question == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kết quả bộ này: ${round.score} / ${round.questions.length}',
            key: const Key('quiz-result'),
          ),
          if (_eligible) ...[
            if (_captureFailed)
              const Text('Chưa thể chuẩn bị kết quả để lưu. Hãy làm lại bộ.'),
            FilledButton(
              key: const Key('quiz-save'),
              onPressed: _saving || _saved || _attempt == null
                  ? null
                  : () => unawaited(_save(round)),
              child: Text(_saving ? 'Đang lưu…' : 'Lưu kết quả trên thiết bị'),
            ),
            if (_saved)
              const Text(
                'Đã lưu kết quả trên thiết bị.',
                key: Key('quiz-saved'),
              ),
            if (_saveFailed)
              const Text(
                'Chưa xác nhận đã lưu. Bạn có thể thử lưu lại đúng kết quả '
                'hoặc xem lịch sử.',
                key: Key('quiz-save-error'),
              ),
          ] else
            const Text(
              'Bộ này chưa gắn với tài khoản có kho lưu. '
              'Hãy mở tài khoản rồi bắt đầu lại bộ mới để lưu.',
            ),
          if (round.incorrect.isNotEmpty) ...[
            const Text('Xem lại các từ trả lời sai'),
            for (final entry in round.incorrect)
              ListTile(
                title: Text(entry.heading),
                subtitle: Text('${entry.reading} · ${entry.meaningVi}'),
              ),
          ],
          OutlinedButton(
            onPressed: _saving ? null : () => _restart(round),
            child: const Text('Làm lại bộ này'),
          ),
          if (_offset + round.questions.length < widget.questions.length)
            OutlinedButton(
              onPressed: _saving ? null : () => _restart(round, next: true),
              child: const Text('Bộ tiếp'),
            ),
        ],
      );
    }
    final target = question.target;
    final selected = round.selectedChoice;
    final number = round.answeredCount + (round.answered ? 0 : 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Câu $number / ${round.questions.length}'),
        Text(
          target.heading,
          key: const Key('quiz-prompt'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const Text('Chọn cách đọc theo bài gốc:'),
        for (final choice in question.choices)
          OutlinedButton(
            key: ValueKey('quiz-choice-${choice.id}'),
            onPressed: round.answered
                ? null
                : () => _answer(round, question.id, choice.id),
            child: Text(choice.reading!.trim()),
          ),
        if (round.answered) ...[
          Text(
            selected == target.id
                ? 'Đúng theo bài gốc.'
                : 'Chưa đúng theo bài gốc.',
            key: const Key('quiz-feedback'),
          ),
          Text('Đáp án: ${target.heading} · ${target.reading}'),
          Text(target.meaningVi),
          if (target.examples.isNotEmpty) ...[
            Text(target.examples.first.japanese),
            Text(target.examples.first.vietnamese),
          ],
        ],
        FilledButton(
          key: const Key('quiz-next'),
          onPressed: !round.answered
              ? null
              : () => _advance(round, question.id),
          child: Text(
            round.answeredCount == round.questions.length
                ? 'Xem kết quả'
                : 'Câu tiếp',
          ),
        ),
      ],
    );
  }
}
