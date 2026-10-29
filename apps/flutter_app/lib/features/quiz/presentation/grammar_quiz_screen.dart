import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/page_body.dart';
import '../../curriculum/application/curriculum_provider.dart';
import '../../settings/application/preview_preferences.dart';
import '../application/grammar_quiz_provider.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(previewLevelProvider);
    final source = ref.watch(curriculumRepositoryProvider);
    final content = ref.watch(grammarQuizProvider(level));
    final generation = _generation;
    bool current() =>
        mounted &&
        generation == _generation &&
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
          'Luyện trong phiên này. Chưa lưu kết quả, cộng thời gian học '
          'hoặc xác định mức ghi nhớ.',
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
                key: ValueKey((content, generation)),
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
  });

  final List<GrammarQuizQuestion> questions;
  final bool Function() isCurrent;

  @override
  State<_GrammarRoundPanel> createState() => _GrammarRoundPanelState();
}

class _GrammarRoundPanelState extends State<_GrammarRoundPanel> {
  int _offset = 0;
  late GrammarQuizRound _round;

  @override
  void initState() {
    super.initState();
    _replace();
  }

  void _replace() {
    _round = GrammarQuizRound(widget.questions.skip(_offset).take(10).toList());
  }

  bool _current(GrammarQuizRound round) =>
      mounted && identical(round, _round) && widget.isCurrent();

  @override
  Widget build(BuildContext context) {
    final round = _round;
    final question = round.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          Text(
            'Kết quả theo bài gốc: ${round.score} / ${round.questions.length}',
          ),
          for (final entry in round.incorrect) ...[
            Text(entry.heading),
            Text('Ôn lại theo bài gốc: ${entry.meaningVi}'),
          ],
          OutlinedButton(
            key: const Key('grammar-quiz-restart'),
            onPressed: () {
              if (_current(round)) {
                setState(_replace);
              }
            },
            child: const Text('Làm lại bộ này'),
          ),
          if (_offset + round.questions.length < widget.questions.length)
            OutlinedButton(
              key: const Key('grammar-quiz-batch'),
              onPressed: () {
                if (_current(round)) {
                  setState(() {
                    _offset += round.questions.length;
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
