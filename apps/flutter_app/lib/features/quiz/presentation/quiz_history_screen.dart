import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/preview_level.dart';
import '../../../shared/widgets/page_body.dart';
import '../application/quiz_history_provider.dart';
import '../data/vocabulary_quiz_history_repository.dart';
import '../domain/vocabulary_quiz_attempt.dart';

class QuizHistoryScreen extends ConsumerWidget {
  const QuizHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(quizHistoryRepositoryProvider);
    return PageBody(
      children: [
        const PageHeading(
          title: 'Lịch sử quiz trên thiết bị',
          subtitle:
              'Kết quả đã lưu của tài khoản hiện tại trên thiết bị này. '
              'Chưa đồng bộ hoặc xác định mức ghi nhớ.',
        ),
        if (repository == null) ...[
          const Text('Lịch sử chưa khả dụng. Hãy mở tài khoản đã cấu hình.'),
          OutlinedButton(
            onPressed: () => context.go('/auth'),
            child: const Text('Mở tài khoản'),
          ),
        ] else
          _HistoryPanel(
            key: ObjectKey(repository),
            repository: repository,
            isCurrent: () =>
                identical(ref.read(quizHistoryRepositoryProvider), repository),
          ),
        TextButton(
          onPressed: () => context.go('/quiz'),
          child: const Text('Về kiểm tra nhanh'),
        ),
      ],
    );
  }
}

class _HistoryPanel extends StatefulWidget {
  const _HistoryPanel({
    super.key,
    required this.repository,
    required this.isCurrent,
  });
  final VocabularyQuizHistoryRepository repository;
  final bool Function() isCurrent;

  @override
  State<_HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<_HistoryPanel> {
  List<OwnedVocabularyQuizAttempt>? _records;
  bool _loading = false;
  bool _failed = false;

  Future<void> _load() async {
    if (!mounted || !widget.isCurrent() || _loading) return;
    setState(() {
      _loading = true;
      _failed = false;
      _records = null;
    });
    try {
      final records = await widget.repository.load();
      if (!mounted || !widget.isCurrent()) return;
      setState(() => _records = records);
    } on Object {
      if (!mounted || !widget.isCurrent()) return;
      setState(() => _failed = true);
    } finally {
      if (mounted && widget.isCurrent()) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: const Key('quiz-history-load'),
          onPressed: _loading ? null : () => unawaited(_load()),
          child: const Text('Tải lịch sử'),
        ),
        if (_loading) ...[
          const LinearProgressIndicator(),
          const Text('Đang tải lịch sử…'),
        ],
        if (_failed)
          const Text(
            'Không thể đọc lịch sử. Bạn có thể thử tải lại.',
            key: Key('quiz-history-error'),
          ),
        if (records != null && records.isEmpty)
          const Text('Chưa có kết quả quiz được lưu trên thiết bị này.'),
        if (records != null)
          for (final record in records.reversed)
            ListTile(
              key: ValueKey('quiz-history-${record.attempt.eventId}'),
              title: Text(
                '${record.attempt.level.label} · ${record.attempt.score} / '
                '${record.attempt.answers.length}',
              ),
              subtitle: Text(
                'Hoàn thành (UTC): '
                '${record.attempt.completedAt.toIso8601String()}',
              ),
            ),
      ],
    );
  }
}
