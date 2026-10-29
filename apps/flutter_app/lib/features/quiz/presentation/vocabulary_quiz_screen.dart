import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_body.dart';
import '../../settings/application/preview_preferences.dart';
import '../application/vocabulary_quiz_provider.dart';
import '../application/quiz_history_provider.dart';
import '../application/quiz_attempt_factory.dart';
import 'vocabulary_quiz_panel.dart';

class VocabularyQuizScreen extends ConsumerWidget {
  const VocabularyQuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(previewLevelProvider);
    final content = ref.watch(vocabularyQuizProvider(level));
    final history = ref.watch(quizHistoryRepositoryProvider);
    final capture = ref.watch(quizAttemptFactoryProvider);
    return PageBody(
      children: [
        const PageHeading(
          title: 'Kiểm tra nhanh',
          subtitle:
              'Chọn cách đọc theo bài gốc. Bạn có thể lưu kết quả trên '
              'thiết bị nếu đã mở tài khoản trước khi bắt đầu bộ.',
        ),
        OutlinedButton(
          onPressed: () => context.go('/quiz/history'),
          child: const Text('Xem lịch sử đã lưu'),
        ),
        OutlinedButton(
          onPressed: () => context.go('/quiz/grammar'),
          child: const Text('Luyện quiz ngữ pháp'),
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
          skipLoadingOnReload: false,
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
              VocabularyQuizPanel(
                key: ObjectKey(questions),
                questions: questions,
                history: history,
                capture: capture,
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Mỗi câu chỉ nhận câu trả lời đầu tiên. Chưa lưu tiến độ, '
          'xác định mức ghi nhớ hoặc tự cộng thời gian học.',
        ),
      ],
    );
  }
}
