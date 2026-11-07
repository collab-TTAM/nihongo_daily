import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_body.dart';
import '../../curriculum/application/curriculum_provider.dart';
import '../../settings/application/preview_preferences.dart';
import '../application/grammar_quiz_provider.dart';
import '../application/grammar_quiz_history_provider.dart';
import '../application/grammar_quiz_attempt_factory.dart';
import 'grammar_quiz_panel.dart';

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
          key: const Key('grammar-quiz-progress-link'),
          onPressed: () => context.go('/quiz/grammar/progress'),
          child: const Text('Xem tiến độ ngữ pháp trên thiết bị'),
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
              GrammarQuizPanel(
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
