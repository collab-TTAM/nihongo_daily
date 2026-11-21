import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/preview_level.dart';
import '../../../shared/widgets/page_body.dart';
import '../application/grammar_quiz_history_provider.dart';
import '../data/grammar_quiz_history_repository.dart';
import '../domain/grammar_quiz_attempt.dart';

class GrammarQuizHistoryScreen extends ConsumerStatefulWidget {
  const GrammarQuizHistoryScreen({super.key});

  @override
  ConsumerState<GrammarQuizHistoryScreen> createState() =>
      _GrammarQuizHistoryScreenState();
}

class _GrammarQuizHistoryScreenState
    extends ConsumerState<GrammarQuizHistoryScreen> {
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      grammarQuizHistoryRepositoryProvider,
      (_, _) => _generation++,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(grammarQuizHistoryRepositoryProvider);
    final generation = _generation;
    return PageBody(
      children: [
        const PageHeading(
          title: 'Lịch sử quiz ngữ pháp trên thiết bị',
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
            key: ValueKey((repository, generation)),
            repository: repository,
            isCurrent: () =>
                mounted &&
                generation == _generation &&
                identical(
                  ref.read(grammarQuizHistoryRepositoryProvider),
                  repository,
                ),
          ),
        TextButton(
          onPressed: () => context.go('/quiz/grammar'),
          child: const Text('Về quiz ngữ pháp'),
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
  final GrammarQuizHistoryRepository repository;
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
  List<OwnedGrammarQuizAttempt>? _records;
  _HistoryLevel _level = _HistoryLevel.all;
  GrammarQuizAttemptKind _kind = GrammarQuizAttemptKind.primary;
  bool _errorsOnly = false;
  bool _oldestFirst = false;
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
          final attempt = record.attempt;
          final levelMatches =
              _level.level == null || attempt.level == _level.level;
          return attempt.kind == _kind &&
              levelMatches &&
              (!_errorsOnly || attempt.score < attempt.answers.length);
        })
        .toList(growable: false);
    final kindLabel = _kind == GrammarQuizAttemptKind.primary
        ? 'Vòng gốc'
        : 'Vòng luyện sai';
    final ordered = _oldestFirst ? records : records?.reversed;
    final visible = ordered
        ?.skip(_pageStart)
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
        DropdownButton<GrammarQuizAttemptKind>(
          key: const Key('grammar-history-kind'),
          value: _kind,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: GrammarQuizAttemptKind.primary,
              child: Text('Vòng gốc'),
            ),
            DropdownMenuItem(
              value: GrammarQuizAttemptKind.correction,
              child: Text('Vòng luyện sai'),
            ),
          ],
          onChanged: (kind) {
            if (!mounted ||
                !widget.isCurrent() ||
                _loading ||
                pageRevision != _pageRevision ||
                kind == null) {
              return;
            }
            setState(() {
              _kind = kind;
              _pageStart = 0;
              _pageRevision++;
            });
          },
        ),
        const Text(
          'Hai loại vòng được xem riêng; điểm luyện sai không cộng vào vòng gốc.',
        ),
        DropdownButton<_HistoryLevel>(
          key: const Key('grammar-history-level'),
          value: _level,
          isExpanded: true,
          items: [
            for (final level in _HistoryLevel.values)
              DropdownMenuItem(value: level, child: Text(level.label)),
          ],
          onChanged: (level) {
            if (!mounted ||
                !widget.isCurrent() ||
                _loading ||
                pageRevision != _pageRevision ||
                level == null) {
              return;
            }
            setState(() {
              _level = level;
              _pageStart = 0;
              _pageRevision++;
            });
          },
        ),
        CheckboxListTile(
          key: const Key('grammar-history-errors-only'),
          value: _errorsOnly,
          title: const Text('Chỉ bộ có câu sai'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            if (!mounted ||
                !widget.isCurrent() ||
                _loading ||
                pageRevision != _pageRevision ||
                value == null) {
              return;
            }
            setState(() {
              _errorsOnly = value;
              _pageStart = 0;
              _pageRevision++;
            });
          },
        ),
        CheckboxListTile(
          key: const Key('grammar-history-oldest-first'),
          value: _oldestFirst,
          title: const Text('Cũ nhất trước'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            if (!mounted ||
                !widget.isCurrent() ||
                _loading ||
                pageRevision != _pageRevision ||
                value == null) {
              return;
            }
            setState(() {
              _oldestFirst = value;
              _pageStart = 0;
              _pageRevision++;
            });
          },
        ),
        OutlinedButton(
          key: const Key('grammar-history-load'),
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
            key: Key('grammar-history-error'),
          ),
        if (records != null) ...[
          Text(
            '$kindLabel: ${records.length} bộ đã lưu',
            key: const Key('grammar-history-summary'),
          ),
          Text('$kindLabel · Câu đúng theo bài gốc: $correct / $answers'),
        ],
        if (records != null && records.isEmpty)
          Text(
            _errorsOnly
                ? 'Không có bộ quiz có câu sai trong bộ lọc này.'
                : _level == _HistoryLevel.all
                ? 'Chưa có kết quả quiz được lưu trên thiết bị này.'
                : 'Chưa có kết quả quiz đã lưu cho cấp độ này.',
          ),
        if (records != null && visible != null && visible.isNotEmpty) ...[
          Text(
            'Hiển thị ${pageStart + 1}–${pageStart + visible.length} / '
            '${records.length} bộ '
            '(${_oldestFirst ? 'cũ nhất trước' : 'mới nhất trước'})',
            key: const Key('grammar-history-range'),
          ),
          if (records.length > _pageSize) ...[
            OutlinedButton(
              key: const Key('grammar-history-newer'),
              onPressed: pageStart == 0
                  ? null
                  : () => _movePage(pageRevision, pageStart - _pageSize),
              child: Text(_oldestFirst ? 'Kết quả cũ hơn' : 'Kết quả mới hơn'),
            ),
            OutlinedButton(
              key: const Key('grammar-history-older'),
              onPressed: pageStart + visible.length >= records.length
                  ? null
                  : () => _movePage(pageRevision, pageStart + _pageSize),
              child: Text(_oldestFirst ? 'Kết quả mới hơn' : 'Kết quả cũ hơn'),
            ),
          ],
          for (final record in visible)
            ListTile(
              key: ValueKey('grammar-history-${record.attempt.eventId}'),
              title: Text(
                '$kindLabel · ${record.attempt.level.label} · ${record.attempt.score} / '
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
