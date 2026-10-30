import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_body.dart';
import '../../curriculum/application/curriculum_provider.dart';
import '../../settings/application/preview_preferences.dart';
import '../application/grammar_quiz_provider.dart';
import '../application/grammar_quiz_history_provider.dart';
import '../application/grammar_quiz_attempt_factory.dart';
import '../data/grammar_quiz_history_repository.dart';
import '../domain/grammar_quiz_attempt.dart';
import 'grammar_quiz_save_action.dart';
import '../domain/grammar_quiz.dart';

class GrammarQuizScreen extends ConsumerStatefulWidget {
  const GrammarQuizScreen({super.key});

  @override
  ConsumerState<GrammarQuizScreen> createState() => _GrammarQuizScreenState();
}

class _GrammarQuizScreenState extends ConsumerState<GrammarQuizScreen> {
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    // Retire callbacks immediately, including level/source ABA before a frame.
    ref.listenManual(previewLevelProvider, (_, _) => _generation++);
    ref.listenManual(curriculumRepositoryProvider, (_, _) => _generation++);
    ref.listenManual(
      grammarQuizHistoryRepositoryProvider,
      (_, _) => _generation++,
    );
    ref.listenManual(
      grammarQuizAttemptFactoryProvider,
      (_, _) => _generation++,
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(grammarQuizHistoryRepositoryProvider);
    final capture = ref.watch(grammarQuizAttemptFactoryProvider);
    final level = ref.watch(previewLevelProvider);
    final source = ref.watch(curriculumRepositoryProvider);
    final content = ref.watch(grammarQuizProvider(level));
    final generation = _generation;
    bool current() =>
        mounted &&
        generation == _generation &&
        identical(ref.read(grammarQuizHistoryRepositoryProvider), history) &&
        identical(ref.read(grammarQuizAttemptFactoryProvider), capture) &&
        ref.read(previewLevelProvider) == level &&
        identical(ref.read(curriculumRepositoryProvider), source) &&
        identical(ref.read(grammarQuizProvider(level)), content);
    return PageBody(
      children: [
        const PageHeading(
          title: 'Quiz ngữ pháp',
          subtitle: 'Chọn nghĩa tiếng Việt theo bài gốc.',
        ),
        const Text(
          'Chỉ lưu trên thiết bị khi bạn chọn lưu và tài khoản có kho lưu. '
          'Kết quả không cộng thời gian học hoặc xác định mức ghi nhớ.',
        ),
        TextButton(
          key: const Key('grammar-quiz-history-link'),
          onPressed: () => context.go('/quiz/grammar/history'),
          child: const Text('Xem lịch sử ngữ pháp trên thiết bị'),
        ),
        DropdownButton<PreviewLevel>(
          key: const Key('grammar-quiz-level'),
          value: level,
          isExpanded: true,
          items: [
            for (final option in PreviewLevel.values)
              DropdownMenuItem(value: option, child: Text(option.label)),
          ],
          onChanged: (value) {
            if (value != null && current()) {
              ref.read(previewLevelProvider.notifier).state = value;
            }
          },
        ),
        ...content.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => [
            const LinearProgressIndicator(),
            const Text('Đang tải ngữ pháp…'),
          ],
          error: (_, _) => [
            const Text('Không tải được ngữ pháp. Vui lòng thử lại.'),
          ],
          data: (questions) => [
            if (questions.isEmpty)
              const Text('Chưa đủ mẫu có nghĩa khác nhau để tạo bộ câu hỏi.')
            else
              _GrammarRoundPanel(
                key: ValueKey((content, generation, history, capture)),
                history: history,
                capture: capture,
                questions: questions,
                isCurrent: current,
              ),
          ],
        ),
        OutlinedButton(
          key: const Key('grammar-quiz-reload'),
          onPressed: current()
              ? () {
                  if (current()) {
                    ref.invalidate(grammarQuizProvider(level));
                  }
                }
              : null,
          child: const Text('Tải lại ngữ pháp'),
        ),
      ],
    );
  }
}

class _GrammarRoundPanel extends StatefulWidget {
  const _GrammarRoundPanel({
    super.key,
    required this.questions,
    required this.isCurrent,
    required this.history,
    required this.capture,
  });

  final List<GrammarQuizQuestion> questions;
  final bool Function() isCurrent;
  final GrammarQuizHistoryRepository? history;
  final GrammarQuizAttemptFactory capture;

  @override
  State<_GrammarRoundPanel> createState() => _GrammarRoundPanelState();
}

class _GrammarRoundPanelState extends State<_GrammarRoundPanel> {
  int _offset = 0;
  late GrammarQuizRound _round;
  late List<GrammarQuizQuestion> _batch;
  int? _originalScore;

  @override
  void initState() {
    super.initState();
    _replace();
  }

  void _replace() {
    _batch = widget.questions.skip(_offset).take(10).toList(growable: false);
    _originalScore = null;
    _round = GrammarQuizRound(_batch);
  }

  bool _current(GrammarQuizRound round) =>
      mounted && identical(round, _round) && widget.isCurrent();

  @override
  Widget build(BuildContext context) {
    final round = _round;
    final question = round.current;
    final originalScore = _originalScore;
    final answers = round.acceptedAnswers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (originalScore != null) ...[
          const Text('Ôn riêng câu sai — kết quả riêng với bộ gốc'),
          Text('Bộ gốc: $originalScore / ${_batch.length}'),
          OutlinedButton(
            key: const Key('grammar-review-original'),
            onPressed: () {
              if (_current(round)) {
                setState(_replace);
              }
            },
            child: const Text('Làm lại bộ gốc'),
          ),
        ],
        if (question != null) ...[
          Text(
            'Câu ${round.answeredCount + (round.answered ? 0 : 1)} / ${round.questions.length}',
          ),
          Text(
            question.target.heading,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final choice in question.choices)
            OutlinedButton(
              key: ValueKey('grammar-choice-${choice.id}'),
              onPressed: round.answered
                  ? null
                  : () {
                      if (_current(round) &&
                          round.answer(question.id, choice.id)) {
                        setState(() {});
                      }
                    },
              child: Text(choice.meaningVi),
            ),
          if (round.answered) ...[
            Text(
              round.selectedChoice == question.target.id
                  ? 'Đúng theo bài gốc.'
                  : 'Chưa đúng theo bài gốc.',
            ),
            Text('Nghĩa theo bài gốc: ${question.target.meaningVi}'),
            Text(question.target.explanationVi),
            ExpansionTile(
              key: ValueKey('grammar-source-${question.id}'),
              title: const Text('Cách dùng và ví dụ theo bài gốc'),
              childrenPadding: const EdgeInsets.all(12),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (question.target.notes.isNotEmpty) ...[
                  const Text('Cách dùng'),
                  for (final note in question.target.notes) Text(note),
                ],
                if (question.target.mistakes.isNotEmpty) ...[
                  const Text('Lỗi thường gặp'),
                  for (final mistake in question.target.mistakes) Text(mistake),
                ],
                const Text('Ví dụ theo bài gốc'),
                if (question.target.examples.isEmpty)
                  const Text('Bài gốc chưa có ví dụ.'),
                for (final example in question.target.examples) ...[
                  const SizedBox(height: 8),
                  Text(example.japanese),
                  Text(example.reading),
                  Text(example.vietnamese),
                ],
              ],
            ),
          ],
          FilledButton(
            key: const Key('grammar-quiz-next'),
            onPressed: !round.answered
                ? null
                : () {
                    if (_current(round) && round.advance(question.id)) {
                      setState(() {});
                    }
                  },
            child: Text(
              round.answeredCount == round.questions.length
                  ? 'Xem kết quả'
                  : 'Câu tiếp theo',
            ),
          ),
        ] else ...[
          GrammarQuizSaveAction(
            key: ValueKey(round),
            round: round,
            kind: originalScore == null
                ? GrammarQuizAttemptKind.primary
                : GrammarQuizAttemptKind.correction,
            history: widget.history,
            capture: widget.capture,
            isCurrent: () => _current(round),
          ),
          Text(
            'Kết quả theo bài gốc: ${round.score} / ${round.questions.length}',
          ),
          for (final item in round.questions)
            if (answers[item.id] != item.target.id) ...[
              Text(item.target.heading),
              Text(
                'Bạn đã chọn: ${item.choices.singleWhere((choice) => choice.id == answers[item.id]).meaningVi}',
              ),
              Text('Ôn lại theo bài gốc: ${item.target.meaningVi}'),
              Text(item.target.explanationVi),
            ],
          if (originalScore == null && round.incorrect.isNotEmpty)
            OutlinedButton(
              key: const Key('grammar-review-errors'),
              onPressed: () {
                if (_current(round)) {
                  final ids = round.incorrect.map((entry) => entry.id).toSet();
                  final questions = round.questions
                      .where((question) => ids.contains(question.target.id))
                      .toList(growable: false);
                  setState(() {
                    _originalScore = round.score;
                    _round = GrammarQuizRound(questions);
                  });
                }
              },
              child: const Text('Luyện riêng câu sai'),
            ),
          OutlinedButton(
            key: const Key('grammar-quiz-restart'),
            onPressed: () {
              if (_current(round)) {
                setState(() {
                  _round = GrammarQuizRound(round.questions);
                });
              }
            },
            child: Text(
              originalScore == null ? 'Làm lại bộ này' : 'Làm lại câu sai',
            ),
          ),
          if (_offset + _batch.length < widget.questions.length)
            OutlinedButton(
              key: const Key('grammar-quiz-batch'),
              onPressed: () {
                if (_current(round)) {
                  setState(() {
                    _offset += _batch.length;
                    _replace();
                  });
                }
              },
              child: const Text('Bộ câu hỏi tiếp theo'),
            ),
        ],
      ],
    );
  }
}
