import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/page_body.dart';
import '../../settings/application/preview_preferences.dart';
import '../application/vocabulary_quiz_provider.dart';
import '../domain/vocabulary_quiz.dart';

class VocabularyQuizScreen extends ConsumerWidget {
  const VocabularyQuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(previewLevelProvider);
    final content = ref.watch(vocabularyQuizProvider(level));
    return PageBody(
      children: [
        const PageHeading(
          title: 'Kiểm tra nhanh',
          subtitle: 'Chọn cách đọc theo bài gốc. Kết quả chỉ giữ trong bộ này.',
        ),
        DropdownButton<PreviewLevel>(
          key: const Key('quiz-level'),
          value: level,
          isExpanded: true,
          items: [
            for (final option in PreviewLevel.values)
              DropdownMenuItem(value: option, child: Text(option.label)),
          ],
          onChanged: (value) {
            if (value != null) {
              ref.read(previewLevelProvider.notifier).state = value;
            }
          },
        ),
        ...content.when(
          skipLoadingOnRefresh: false,
          loading: () => [
            const LinearProgressIndicator(),
            const Text('Đang tải câu hỏi…'),
          ],
          error: (_, _) => [
            const Text('Không tải được câu hỏi. Vui lòng thử lại.'),
            OutlinedButton(
              onPressed: () => ref.invalidate(vocabularyQuizProvider(level)),
              child: const Text('Thử tải câu hỏi'),
            ),
          ],
          data: (questions) => [
            if (questions.isEmpty)
              const Text('Chưa đủ từ có cách đọc khác nhau để tạo bộ câu hỏi.')
            else
              _QuizPanel(key: ObjectKey(questions), questions: questions),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Mỗi câu chỉ nhận câu trả lời đầu tiên. Chưa lưu tiến độ, '
          'xác định mức ghi nhớ hoặc cộng thời gian học.',
        ),
      ],
    );
  }
}

class _QuizPanel extends StatefulWidget {
  const _QuizPanel({super.key, required this.questions});
  final List<QuizQuestion> questions;

  @override
  State<_QuizPanel> createState() => _QuizPanelState();
}

class _QuizPanelState extends State<_QuizPanel> {
  int _offset = 0;
  late QuizRound _round;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  void _startRound() {
    _round = QuizRound(widget.questions.skip(_offset).take(10).toList());
  }

  void _restart(QuizRound expected, {bool next = false}) {
    if (!mounted || !identical(_round, expected)) return;
    setState(() {
      if (next) _offset += expected.questions.length;
      _startRound();
    });
  }

  void _answer(QuizRound expected, String questionId, String choiceId) {
    if (!mounted || !identical(_round, expected)) return;
    if (expected.answer(questionId, choiceId)) setState(() {});
  }

  void _advance(QuizRound expected, String questionId) {
    if (!mounted || !identical(_round, expected)) return;
    if (expected.advance(questionId)) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    final question = round.current;
    if (question == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kết quả bộ này: ${round.score} / ${round.questions.length}',
            key: const Key('quiz-result'),
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
            onPressed: () => _restart(round),
            child: const Text('Làm lại bộ này'),
          ),
          if (_offset + round.questions.length < widget.questions.length)
            OutlinedButton(
              onPressed: () => _restart(round, next: true),
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
