import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/page_body.dart';
import '../../settings/application/preview_preferences.dart';
import '../application/vocabulary_quiz_provider.dart';
import '../data/vocabulary_quiz_repository.dart';
import '../domain/vocabulary_quiz.dart';

class VocabularyQuizScreen extends ConsumerWidget {
  const VocabularyQuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(previewLevelProvider);
    return PageBody(
      children: [
        const PageHeading(
          title: 'Kiểm tra nhanh',
          subtitle:
              'Chọn cách đọc theo dữ liệu gốc. Kết quả chỉ tồn tại trong lượt hiện tại.',
        ),
        DropdownButton<PreviewLevel>(
          key: const Key('quiz-level'),
          value: level,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: PreviewLevel.n5, child: Text('N5')),
            DropdownMenuItem(
              value: PreviewLevel.n4,
              child: Text('N4 · chưa tích hợp'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              ref.read(previewLevelProvider.notifier).state = value;
            }
          },
        ),
        const SizedBox(height: 16),
        _VocabularyQuizRound(
          key: ValueKey(level),
          level: level.name.toUpperCase(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Chưa lưu lịch sử, mastery, tiến độ hoặc thời gian học. '
          'Rời trang sẽ bỏ lượt trả lời này.',
        ),
      ],
    );
  }
}

class _VocabularyQuizRound extends ConsumerStatefulWidget {
  const _VocabularyQuizRound({super.key, required this.level});

  final String level;

  @override
  ConsumerState<_VocabularyQuizRound> createState() =>
      _VocabularyQuizRoundState();
}

class _VocabularyQuizRoundState extends ConsumerState<_VocabularyQuizRound> {
  int _batchIndex = 0;
  VocabularyQuizSession? _session;

  @override
  Widget build(BuildContext context) {
    final request = (level: widget.level, batchIndex: _batchIndex);
    final provider = vocabularyQuizRoundProvider(request);
    ref.listen(provider, (_, next) {
      next.whenData((round) {
        if (mounted && !identical(_session?.round, round)) {
          setState(() => _session = VocabularyQuizSession(round));
        }
      });
    });
    final content = ref.watch(provider);

    return content.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(),
          SizedBox(height: 12),
          Text('Đang tải câu hỏi…'),
        ],
      ),
      error: (error, _) => _error(error, () {
        ref.invalidate(provider);
      }),
      data: (round) {
        if (!identical(_session?.round, round)) {
          _session = VocabularyQuizSession(round);
        }
        return _buildRound(context, round, _session!);
      },
    );
  }

  Widget _error(Object error, VoidCallback retry) {
    if (error is QuizContentUnavailable) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${error.level} chưa được tích hợp. Không thay thế bằng N5; '
            'nội dung đang chờ được rà soát.',
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Không tải được câu hỏi. Dữ liệu không thay đổi; hãy thử lại.',
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('quiz-retry'),
          onPressed: retry,
          child: const Text('Thử lại'),
        ),
      ],
    );
  }

  Widget _buildRound(
    BuildContext context,
    VocabularyQuizRound round,
    VocabularyQuizSession session,
  ) {
    if (round.status == VocabularyQuizBuildStatus.empty) {
      return const Text(
        'Chưa có từ vựng Kanji phù hợp để tạo câu hỏi.',
        key: Key('quiz-empty'),
      );
    }
    if (round.status == VocabularyQuizBuildStatus.insufficientContent) {
      return const Text(
        'Chưa đủ bốn cách đọc khác nhau trong nội dung cấp độ này.',
        key: Key('quiz-insufficient'),
      );
    }
    if (session.isComplete) return _buildResult(round, session);

    final question = session.currentQuestion;
    if (question == null) {
      return const Text('Không có câu hỏi hiện tại.');
    }
    final answer = session.answers[question.questionId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lượt ${round.batchIndex + 1} · Câu ${session.currentIndex + 1}/${round.questions.length}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (session.currentIndex + 1) / round.questions.length,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.expression,
                  key: const Key('quiz-question-expression'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(question.meaningVi),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final option in question.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: Key('quiz-option-${option.id}'),
                onPressed: answer == null
                    ? () => setState(() {
                        _session = session.answer(
                          questionId: question.questionId,
                          optionId: option.id,
                        );
                      })
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                child: Text(option.label, textAlign: TextAlign.start),
              ),
            ),
          ),
        if (answer != null) ...[
          Card(
            key: const Key('quiz-answer-feedback'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(answer.isCorrect ? 'Chính xác!' : 'Chưa chính xác.'),
                  const SizedBox(height: 4),
                  Text('Cách đọc theo bài gốc: ${question.reading}'),
                  Text('Nghĩa: ${question.meaningVi}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('quiz-next'),
            onPressed: () => setState(() {
              _session = session.next(question.questionId);
            }),
            child: const Text('Câu tiếp theo'),
          ),
        ],
      ],
    );
  }

  Widget _buildResult(
    VocabularyQuizRound round,
    VocabularyQuizSession session,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Hoàn thành lượt ôn'),
        const SizedBox(height: 8),
        Text(
          'Kết quả: ${session.scoreLabel}',
          key: const Key('quiz-score'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (session.incorrectQuestions.isEmpty)
          const Text('Bạn đã trả lời đúng tất cả câu hỏi.'),
        if (session.incorrectQuestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Cần ôn lại'),
          for (final question in session.incorrectQuestions)
            Card(
              child: ListTile(
                title: Text(question.expression),
                subtitle: Text('${question.reading} · ${question.meaningVi}'),
              ),
            ),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('quiz-restart'),
          onPressed: () => setState(() => _session = session.restart()),
          child: const Text('Làm lại lượt này'),
        ),
        if (round.hasNextBatch) ...[
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('quiz-next-batch'),
            onPressed: () => setState(() {
              _batchIndex++;
              _session = null;
            }),
            child: const Text('Làm tiếp lượt kế tiếp'),
          ),
        ],
      ],
    );
  }
}
