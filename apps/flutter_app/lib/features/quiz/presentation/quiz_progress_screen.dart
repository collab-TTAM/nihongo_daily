import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/preview_level.dart';
import '../../../shared/widgets/page_body.dart';
import '../../auth/application/account_provider.dart';
import '../../curriculum/application/curriculum_provider.dart';
import '../../curriculum/domain/curriculum.dart';
import '../application/quiz_history_provider.dart';
import '../data/vocabulary_quiz_history_repository.dart';
import '../domain/vocabulary_quiz_progress.dart';

class QuizProgressScreen extends ConsumerStatefulWidget {
  const QuizProgressScreen({super.key});

  @override
  ConsumerState<QuizProgressScreen> createState() => _QuizProgressScreenState();
}

class _QuizProgressScreenState extends ConsumerState<QuizProgressScreen> {
  PreviewLevel _level = PreviewLevel.n5;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(quizHistoryRepositoryProvider);
    final owner = ref.watch(accountStateProvider).profile?.id;
    final source = ref.watch(curriculumRepositoryProvider);
    return PageBody(
      children: [
        const PageHeading(
          title: 'Tiến độ luyện quiz trên thiết bị',
          subtitle:
              'Thống kê từ kết quả đã lưu của tài khoản hiện tại. '
              'Chưa đồng bộ, xác định mức ghi nhớ hoặc cộng thời gian học.',
        ),
        if (repository == null || owner == null) ...[
          const Text('Tiến độ chưa khả dụng. Hãy mở tài khoản đã cấu hình.'),
          OutlinedButton(
            onPressed: () => context.go('/auth'),
            child: const Text('Mở tài khoản'),
          ),
        ] else ...[
          DropdownButton<PreviewLevel>(
            key: const Key('quiz-progress-level'),
            value: _level,
            isExpanded: true,
            items: [
              for (final level in PreviewLevel.values)
                DropdownMenuItem(value: level, child: Text(level.label)),
            ],
            onChanged: (level) {
              if (level != null) setState(() => _level = level);
            },
          ),
          _ProgressPanel(
            key: ValueKey((repository, source, owner, _level)),
            repository: repository,
            source: source,
            owner: owner,
            level: _level,
          ),
        ],
        TextButton(
          onPressed: () => context.go('/quiz/history'),
          child: const Text('Xem lịch sử đã lưu'),
        ),
      ],
    );
  }
}

class _ProgressPanel extends StatefulWidget {
  const _ProgressPanel({
    super.key,
    required this.repository,
    required this.source,
    required this.owner,
    required this.level,
  });
  final VocabularyQuizHistoryRepository repository;
  final CurriculumRepository source;
  final String owner;
  final PreviewLevel level;

  @override
  State<_ProgressPanel> createState() => _ProgressPanelState();
}

class _ProgressPanelState extends State<_ProgressPanel> {
  VocabularyQuizProgress? _progress;
  bool _loading = false;
  bool _failed = false;

  Future<void> _load() async {
    if (!mounted || _loading) return;
    setState(() {
      _loading = true;
      _failed = false;
      _progress = null;
    });
    try {
      final entries = await widget.source.load(
        CurriculumKind.vocabulary,
        widget.level,
      );
      if (!mounted) return;
      // Read owner-bound history last so its session fence also follows the
      // public curriculum await. Replaced/closed panels cannot publish results.
      final records = await widget.repository.load();
      if (!mounted) return;
      final progress = deriveVocabularyQuizProgress(
        ownerId: widget.owner,
        level: widget.level,
        source: entries,
        history: records,
      );
      setState(() => _progress = progress);
    } on Object {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: const Key('quiz-progress-load'),
          onPressed: _loading ? null : () => unawaited(_load()),
          child: const Text('Tải thống kê quiz'),
        ),
        if (_loading) ...[
          const LinearProgressIndicator(),
          const Text('Đang tải thống kê…'),
        ],
        if (_failed)
          const Text(
            'Không thể đọc thống kê. Bạn có thể thử tải lại.',
            key: Key('quiz-progress-error'),
          ),
        if (progress != null) ...[
          Text(
            '${widget.level.label} · ${progress.attemptCount} bộ đã lưu',
            key: const Key('quiz-progress-summary'),
          ),
          Text(
            'Câu đúng theo bài gốc: ${progress.correctCount} / '
            '${progress.answerCount}',
          ),
          Text('Từ hiện tại đã luyện: ${progress.practicedCurrentItemCount}'),
          Text('Từ cần ôn: ${progress.needsReview.length}'),
          if (progress.attemptCount == 0)
            const Text('Chưa có kết quả quiz đã lưu cho cấp độ này.'),
          if (progress.needsReview.isEmpty)
            const Text('Chưa có từ cần ôn khớp nội dung hiện tại.'),
          if (progress.needsReview.length > 20)
            const Text('Hiển thị tối đa 20 từ cần ôn.'),
          for (final item in progress.needsReview.take(20))
            ListTile(
              key: ValueKey('quiz-progress-item-${item.entry.id}'),
              title: Text(item.entry.heading),
              subtitle: Text(
                '${item.entry.reading} · ${item.entry.meaningVi}\n'
                'Sai ${item.incorrectCount} lần; câu trả lời gần nhất chưa đúng.',
              ),
            ),
        ],
      ],
    );
  }
}
