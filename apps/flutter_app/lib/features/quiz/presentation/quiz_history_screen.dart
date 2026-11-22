import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/preview_level.dart';
import '../../../shared/widgets/page_body.dart';
import '../application/quiz_history_provider.dart';
import '../application/quiz_report_v2_provider.dart';
import '../data/quiz_report_v2_adapter.dart';
import '../data/quiz_report_v2_transport.dart';
import '../data/vocabulary_quiz_history_repository.dart';
import '../domain/vocabulary_quiz_attempt.dart';

class QuizHistoryScreen extends ConsumerWidget {
  const QuizHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(quizHistoryRepositoryProvider);
    final serverReader = ref.watch(quizReportV2HistoryReaderProvider);
    return PageBody(
      children: [
        const PageHeading(
          title: 'Lịch sử quiz trên thiết bị',
          subtitle:
              'Kết quả đã lưu của tài khoản hiện tại trên thiết bị này. '
              'Chưa đồng bộ hoặc xác định mức ghi nhớ.',
        ),
        if (serverReader != null) ...[
          _ServerHistoryPanel(
            key: ObjectKey(serverReader),
            reader: serverReader,
            isCurrent: () => identical(
              ref.read(quizReportV2HistoryReaderProvider),
              serverReader,
            ),
          ),
          const Divider(),
        ],
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
          return levelMatches &&
              (!_errorsOnly || attempt.score < attempt.answers.length);
        })
        .toList(growable: false);
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
        CheckboxListTile(
          key: const Key('quiz-history-errors-only'),
          value: _errorsOnly,
          title: const Text('Chỉ bộ có câu sai'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            if (!mounted || !widget.isCurrent() || value == null) return;
            setState(() {
              _errorsOnly = value;
              _pageStart = 0;
              _pageRevision++;
            });
          },
        ),
        CheckboxListTile(
          key: const Key('quiz-history-oldest-first'),
          value: _oldestFirst,
          title: const Text('Cũ nhất trước'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            if (!mounted || !widget.isCurrent() || value == null) return;
            setState(() {
              _oldestFirst = value;
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
            key: const Key('quiz-history-range'),
          ),
          if (records.length > _pageSize) ...[
            OutlinedButton(
              key: const Key('quiz-history-newer'),
              onPressed: pageStart == 0
                  ? null
                  : () => _movePage(pageRevision, pageStart - _pageSize),
              child: Text(_oldestFirst ? 'Kết quả cũ hơn' : 'Kết quả mới hơn'),
            ),
            OutlinedButton(
              key: const Key('quiz-history-older'),
              onPressed: pageStart + visible.length >= records.length
                  ? null
                  : () => _movePage(pageRevision, pageStart + _pageSize),
              child: Text(_oldestFirst ? 'Kết quả mới hơn' : 'Kết quả cũ hơn'),
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

class _ServerHistoryPanel extends StatefulWidget {
  const _ServerHistoryPanel({
    super.key,
    required this.reader,
    required this.isCurrent,
  });

  final QuizReportV2HistoryReader reader;
  final bool Function() isCurrent;

  @override
  State<_ServerHistoryPanel> createState() => _ServerHistoryPanelState();
}

enum _ServerHistoryLevel {
  all('Tất cả cấp độ', null),
  n5('N5', 'N5'),
  n4('N4', 'N4');

  const _ServerHistoryLevel(this.label, this.value);
  final String label;
  final String? value;
}

enum _ServerHistoryType {
  all('Tất cả dạng quiz', null),
  vocabulary('Từ vựng · đọc', 'vocabulary_reading'),
  grammar('Ngữ pháp', 'grammar_meaning');

  const _ServerHistoryType(this.label, this.value);
  final String label;
  final String? value;
}

class _ServerHistoryPanelState extends State<_ServerHistoryPanel> {
  static const _pageSize = 20;

  _ServerHistoryLevel _level = _ServerHistoryLevel.all;
  _ServerHistoryType _type = _ServerHistoryType.all;
  QuizReportV2HistoryPage? _page;
  List<QuizReportV2HistoryCursor?> _cursorHistory = [null];
  int _pageIndex = 0;
  int _requestRevision = 0;
  bool _requested = false;
  bool _loading = false;
  bool _failed = false;
  QuizReportV2HistoryCursor? _retryCursor;
  int? _retryPageIndex;

  Future<void> _load({
    QuizReportV2HistoryCursor? cursor,
    bool reset = false,
    int? targetPageIndex,
  }) async {
    if (!mounted || !widget.isCurrent()) return;
    if (reset) {
      _cursorHistory = [null];
      _pageIndex = 0;
      _retryCursor = null;
      _retryPageIndex = null;
      cursor = null;
      targetPageIndex = null;
    } else if (targetPageIndex != null) {
      // Keep the current page visible until the requested page is validated.
      _retryCursor = cursor;
      _retryPageIndex = targetPageIndex;
    }
    final revision = ++_requestRevision;
    setState(() {
      _requested = true;
      _loading = true;
      _failed = false;
      if (reset) _page = null;
    });
    try {
      final page = await widget.reader.readHistory(
        QuizReportV2HistoryQuery(
          jlptLevel: _level.value,
          quizType: _type.value,
          limit: _pageSize,
          cursor: cursor,
        ),
      );
      if (!mounted || !widget.isCurrent() || revision != _requestRevision) {
        return;
      }
      setState(() {
        if (targetPageIndex != null) {
          _cursorHistory = [
            ..._cursorHistory.take(targetPageIndex),
            cursor,
          ];
          _pageIndex = targetPageIndex;
        } else if (reset) {
          _cursorHistory = [null];
          _pageIndex = 0;
        }
        _page = page;
        _retryCursor = null;
        _retryPageIndex = null;
      });
    } on Object {
      if (!mounted || !widget.isCurrent() || revision != _requestRevision) {
        return;
      }
      setState(() => _failed = true);
    } finally {
      if (mounted && widget.isCurrent() && revision == _requestRevision) {
        setState(() => _loading = false);
      }
    }
  }

  void _retry() {
    final pageIndex = _retryPageIndex;
    if (pageIndex != null) {
      unawaited(
        _load(cursor: _retryCursor, targetPageIndex: pageIndex),
      );
      return;
    }
    unawaited(_load(reset: true));
  }

  void _changeLevel(_ServerHistoryLevel? value) {
    if (value == null || !mounted || !widget.isCurrent()) return;
    final reload = _requested;
    _requestRevision++;
    setState(() {
      _level = value;
      _page = null;
      _cursorHistory = [null];
      _pageIndex = 0;
      _retryCursor = null;
      _retryPageIndex = null;
      _loading = false;
      _failed = false;
    });
    if (reload) unawaited(_load());
  }

  void _changeType(_ServerHistoryType? value) {
    if (value == null || !mounted || !widget.isCurrent()) return;
    final reload = _requested;
    _requestRevision++;
    setState(() {
      _type = value;
      _page = null;
      _cursorHistory = [null];
      _pageIndex = 0;
      _retryCursor = null;
      _retryPageIndex = null;
      _loading = false;
      _failed = false;
    });
    if (reload) unawaited(_load());
  }

  void _loadOlder() {
    final cursor = _page?.nextCursor;
    if (cursor == null || _loading || !widget.isCurrent()) return;
    final nextIndex = _pageIndex + 1;
    unawaited(_load(cursor: cursor, targetPageIndex: nextIndex));
  }

  void _loadNewer() {
    if (_pageIndex == 0 || _loading || !widget.isCurrent()) return;
    final previousIndex = _pageIndex - 1;
    final cursor = _cursorHistory[previousIndex];
    unawaited(_load(cursor: cursor, targetPageIndex: previousIndex));
  }

  String _typeLabel(QuizReportV2HistoryEntry entry) {
    final request = entry.request;
    if (request.quizType == 'vocabulary_reading') {
      return 'Từ vựng · đọc';
    }
    return request.practiceKind == 'primary'
        ? 'Ngữ pháp · nghĩa chính'
        : 'Ngữ pháp · sửa lỗi';
  }

  @override
  void dispose() {
    _requestRevision++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeading(
          title: 'Lịch sử quiz trên máy chủ',
          subtitle:
              'Biên nhận chỉ đọc của tài khoản đã đăng nhập. Không cộng vào '
              'tiến độ, mức ghi nhớ hoặc thời gian học.',
        ),
        DropdownButton<_ServerHistoryLevel>(
          key: const Key('server-quiz-history-level'),
          value: _level,
          isExpanded: true,
          items: [
            for (final value in _ServerHistoryLevel.values)
              DropdownMenuItem(value: value, child: Text(value.label)),
          ],
          onChanged: _loading ? null : _changeLevel,
        ),
        DropdownButton<_ServerHistoryType>(
          key: const Key('server-quiz-history-type'),
          value: _type,
          isExpanded: true,
          items: [
            for (final value in _ServerHistoryType.values)
              DropdownMenuItem(value: value, child: Text(value.label)),
          ],
          onChanged: _loading ? null : _changeType,
        ),
        OutlinedButton(
          key: Key(
            _failed
                ? 'server-quiz-history-retry'
                : _requested
                ? 'server-quiz-history-refresh'
                : 'server-quiz-history-load',
          ),
          onPressed: _loading
              ? null
              : _failed
              ? _retry
              : () => unawaited(_load(reset: true)),
          child: Text(
            _failed
                ? _retryPageIndex == null
                      ? 'Thử tải lại lịch sử máy chủ'
                      : 'Thử tải lại trang này'
                : _requested
                ? 'Làm mới lịch sử máy chủ'
                : 'Tải lịch sử máy chủ',
          ),
        ),
        if (_loading) ...[
          const LinearProgressIndicator(),
          const Text('Đang đọc biên nhận…'),
        ],
        if (_failed)
          Text(
            _page == null
                ? 'Không thể đọc lịch sử máy chủ. Hãy thử lại khi kết nối ổn định.'
                : 'Không tải được trang lịch sử. Trang hiện tại vẫn được giữ; hãy thử lại.',
            key: const Key('server-quiz-history-error'),
          ),
        if (page != null) ...[
          Text(
            '${page.items.length} kết quả trên trang ${_pageIndex + 1}',
            key: const Key('server-quiz-history-summary'),
          ),
          if (page.items.isEmpty)
            const Text(
              'Chưa có biên nhận quiz trên máy chủ cho bộ lọc này.',
              key: Key('server-quiz-history-empty'),
            ),
          for (final entry in page.items)
            ListTile(
              key: ValueKey(
                'server-quiz-history-${entry.request.clientEventId}',
              ),
              title: Text(
                '${entry.request.jlptLevel} · ${_typeLabel(entry)} · '
                '${entry.response.correctCount} / '
                '${entry.response.answerCount}',
              ),
              subtitle: Text(
                'Hoàn thành (UTC): ${entry.request.completedAt}\n'
                'Máy chủ nhận (giờ địa phương): '
                '${DateTime.parse(entry.receivedAt).toLocal()}',
              ),
            ),
          if (page.items.isNotEmpty) ...[
            OutlinedButton(
              key: const Key('server-quiz-history-newer'),
              onPressed: _pageIndex == 0 || _loading ? null : _loadNewer,
              child: const Text('Kết quả mới hơn'),
            ),
            OutlinedButton(
              key: const Key('server-quiz-history-older'),
              onPressed: page.nextCursor == null || _loading
                  ? null
                  : _loadOlder,
              child: const Text('Kết quả cũ hơn'),
            ),
          ],
        ],
      ],
    );
  }
}
