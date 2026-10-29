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

enum _HistoryLevel {
  all('Tất cả cấp độ', null),
  n5('N5', PreviewLevel.n5),
  n4('N4', PreviewLevel.n4);

  const _HistoryLevel(this.label, this.level);
  final String label;
  final PreviewLevel? level;
}

class _HistoryPanelState extends State<_HistoryPanel> {
  static const _pageSize = 20;
  List<OwnedVocabularyQuizAttempt>? _records;
  _HistoryLevel _level = _HistoryLevel.all;
  int _pageStart = 0;
  int _pageRevision = 0;
  bool _loading = false;
  bool _failed = false;

  Future<void> _load() async {
    if (!mounted || !widget.isCurrent() || _loading) return;
    setState(() {
      _loading = true;
      _failed = false;
      _records = null;
      _pageStart = 0;
      _pageRevision++;
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

  void _movePage(int revision, int start) {
    if (!mounted ||
        !widget.isCurrent() ||
        _loading ||
        _records == null ||
        revision != _pageRevision) {
      return;
    }
    setState(() {
      _pageStart = start;
      _pageRevision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final records = _records
        ?.where((record) {
          return _level.level == null || record.attempt.level == _level.level;
        })
        .toList(growable: false);
    final visible = records?.reversed
        .skip(_pageStart)
        .take(_pageSize)
        .toList(growable: false);
    final pageRevision = _pageRevision;
    final pageStart = _pageStart;
    var correct = 0;
    var answers = 0;
    if (records != null) {
      for (final record in records) {
        correct += record.attempt.score;
        answers += record.attempt.answers.length;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButton<_HistoryLevel>(
          key: const Key('quiz-history-level'),
          value: _level,
          isExpanded: true,
          items: [
            for (final level in _HistoryLevel.values)
              DropdownMenuItem(value: level, child: Text(level.label)),
          ],
          onChanged: (level) {
            if (!mounted || !widget.isCurrent() || level == null) return;
            setState(() {
              _level = level;
              _pageStart = 0;
              _pageRevision++;
            });
          },
        ),
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
        if (records != null) ...[
          Text(
            '${records.length} bộ đã lưu',
            key: const Key('quiz-history-summary'),
          ),
          Text('Câu đúng theo bài gốc: $correct / $answers'),
        ],
        if (records != null && records.isEmpty)
          Text(
            _level == _HistoryLevel.all
                ? 'Chưa có kết quả quiz được lưu trên thiết bị này.'
                : 'Chưa có kết quả quiz đã lưu cho cấp độ này.',
          ),
        if (records != null && visible != null && visible.isNotEmpty) ...[
          Text(
            'Hiển thị ${pageStart + 1}–${pageStart + visible.length} / '
            '${records.length} bộ (mới nhất trước)',
            key: const Key('quiz-history-range'),
          ),
          if (records.length > _pageSize) ...[
            OutlinedButton(
              key: const Key('quiz-history-newer'),
              onPressed: pageStart == 0
                  ? null
                  : () => _movePage(pageRevision, pageStart - _pageSize),
              child: const Text('Kết quả mới hơn'),
            ),
            OutlinedButton(
              key: const Key('quiz-history-older'),
              onPressed: pageStart + visible.length >= records.length
                  ? null
                  : () => _movePage(pageRevision, pageStart + _pageSize),
              child: const Text('Kết quả cũ hơn'),
            ),
          ],
          for (final record in visible)
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
      ],
    );
  }
}
