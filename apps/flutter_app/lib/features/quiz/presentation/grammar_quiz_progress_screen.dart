import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/preview_level.dart';
import '../../../shared/widgets/page_body.dart';
import '../../auth/application/account_provider.dart';
import '../../curriculum/application/curriculum_provider.dart';
import '../../curriculum/domain/curriculum.dart';
import '../application/grammar_quiz_history_provider.dart';
import '../data/grammar_quiz_history_repository.dart';
import '../domain/grammar_quiz_attempt.dart';
import '../domain/grammar_quiz_progress.dart';
import '../domain/grammar_quiz.dart';
import '../domain/grammar_review_quiz.dart';
import '../application/grammar_quiz_attempt_factory.dart';
import 'grammar_quiz_panel.dart';
import 'quiz_progress_navigation.dart';

class GrammarQuizProgressScreen extends ConsumerStatefulWidget {
  const GrammarQuizProgressScreen({super.key});
  @override
  ConsumerState<GrammarQuizProgressScreen> createState() =>
      _GrammarQuizProgressScreenState();
}

class _GrammarQuizProgressScreenState
    extends ConsumerState<GrammarQuizProgressScreen> {
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      grammarQuizHistoryRepositoryProvider,
      (_, _) => _generation++,
    );
    ref.listenManual(curriculumRepositoryProvider, (_, _) => _generation++);
    ref.listenManual(accountStateProvider, (_, _) => _generation++);
    ref.listenManual(
      grammarQuizAttemptFactoryProvider,
      (_, _) => _generation++,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(grammarQuizHistoryRepositoryProvider);
    final source = ref.watch(curriculumRepositoryProvider);
    final owner = ref.watch(accountStateProvider).profile?.id;
    final capture = ref.watch(grammarQuizAttemptFactoryProvider);
    final generation = _generation;
    return PageBody(
      children: [
        const PageHeading(
          title: 'Tiến độ quiz ngữ pháp trên thiết bị',
          subtitle:
              'Kết quả tài khoản hiện tại, chỉ trên thiết bị này. Chưa đồng bộ, xác định mức ghi nhớ hoặc cộng thời gian học.',
        ),
        const QuizProgressNavigation(grammar: true),
        if (repository == null || owner == null) ...[
          const Text('Tiến độ chưa khả dụng. Hãy mở tài khoản đã cấu hình.'),
          OutlinedButton(
            onPressed: () => context.go('/auth'),
            child: const Text('Mở tài khoản'),
          ),
        ] else
          _GrammarProgressPanel(
            key: ValueKey((repository, source, owner, capture, generation)),
            repository: repository,
            source: source,
            owner: owner,
            capture: capture,
            isCurrent: () =>
                mounted &&
                generation == _generation &&
                identical(
                  ref.read(grammarQuizAttemptFactoryProvider),
                  capture,
                ) &&
                ref.read(accountStateProvider).profile?.id == owner &&
                identical(
                  ref.read(grammarQuizHistoryRepositoryProvider),
                  repository,
                ) &&
                identical(ref.read(curriculumRepositoryProvider), source),
          ),
        TextButton(
          onPressed: () => context.go('/quiz/grammar/history'),
          child: const Text('Xem lịch sử ngữ pháp'),
        ),
        TextButton(
          onPressed: () => context.go('/quiz/grammar'),
          child: const Text('Về quiz ngữ pháp'),
        ),
      ],
    );
  }
}

class _GrammarProgressPanel extends StatefulWidget {
  const _GrammarProgressPanel({
    super.key,
    required this.repository,
    required this.source,
    required this.owner,
    required this.capture,
    required this.isCurrent,
  });
  final GrammarQuizHistoryRepository repository;
  final CurriculumRepository source;
  final String owner;
  final GrammarQuizAttemptFactory capture;
  final bool Function() isCurrent;
  @override
  State<_GrammarProgressPanel> createState() => _GrammarProgressPanelState();
}

class _GrammarProgressPanelState extends State<_GrammarProgressPanel> {
  PreviewLevel _level = PreviewLevel.n5;
  GrammarQuizAttemptKind _kind = GrammarQuizAttemptKind.primary;
  int _revision = 0;
  bool _loading = false;
  bool _failed = false;
  GrammarQuizProgress? _progress;
  List<GrammarQuizQuestion> _review = const [];
  List<GrammarQuizQuestion>? _practice;
  bool _current(int revision) =>
      mounted && widget.isCurrent() && revision == _revision;
  void _select(
    int revision, {
    PreviewLevel? level,
    GrammarQuizAttemptKind? kind,
  }) {
    if (!_current(revision)) return;
    setState(() {
      if (level != null) _level = level;
      if (kind != null) _kind = kind;
      _revision++;
      _progress = null;
      _review = const [];
      _practice = null;
      _failed = false;
      _loading = false;
    });
  }

  Future<void> _load(int revision) async {
    if (!_current(revision) || _loading) return;
    final level = _level;
    final kind = _kind;
    setState(() {
      _loading = true;
      _failed = false;
      _progress = null;
      _review = const [];
      _practice = null;
    });
    try {
      final entries = await widget.source.load(CurriculumKind.grammar, level);
      if (!_current(revision)) return;
      // Read captured owner history last: content completion cannot bypass Auth.
      final records = await widget.repository.load();
      if (!_current(revision)) return;
      final progress = deriveGrammarQuizProgress(
        ownerId: widget.owner,
        level: level,
        kind: kind,
        source: entries,
        history: records,
      );
      final review = kind == GrammarQuizAttemptKind.primary
          ? selectGrammarReviewQuestions(
              buildGrammarQuiz(entries, level),
              progress,
            )
          : const <GrammarQuizQuestion>[];
      setState(() {
        _progress = progress;
        _review = review;
      });
    } on Object {
      if (_current(revision)) setState(() => _failed = true);
    } finally {
      if (_current(revision)) setState(() => _loading = false);
    }
  }

  void _startReview(int revision, GrammarQuizProgress expected) {
    if (!_current(revision) ||
        _loading ||
        _practice != null ||
        !identical(_progress, expected) ||
        expected.kind != GrammarQuizAttemptKind.primary ||
        _review.isEmpty) {
      return;
    }
    setState(() {
      _practice = List.unmodifiable(_review);
      _revision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final revision = _revision;
    final practice = _practice;
    if (practice != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Luyện lại ${practice.length} mẫu cần ôn'),
          const Text(
            'Dùng câu hỏi và lựa chọn theo nội dung hiện tại. Kết quả được lưu riêng là vòng luyện sai; không đổi điểm hoặc mục cần ôn của vòng gốc. Không cộng thời gian học.',
          ),
          OutlinedButton(
            key: const Key('grammar-focused-back'),
            onPressed: () {
              if (_current(revision) && identical(_practice, practice)) {
                setState(() {
                  _practice = null;
                  _revision++;
                });
              }
            },
            child: const Text('Về thống kê ngữ pháp'),
          ),
          GrammarQuizPanel(
            key: ObjectKey(practice),
            questions: practice,
            history: widget.repository,
            capture: widget.capture,
            baseKind: GrammarQuizAttemptKind.correction,
            isCurrent: () =>
                _current(revision) && identical(_practice, practice),
          ),
        ],
      );
    }
    final progress = _progress;
    final label = _kind == GrammarQuizAttemptKind.primary
        ? 'Vòng gốc'
        : 'Vòng luyện sai';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButton<PreviewLevel>(
          key: const Key('grammar-progress-level'),
          value: _level,
          isExpanded: true,
          items: [
            for (final level in PreviewLevel.values)
              DropdownMenuItem(value: level, child: Text(level.label)),
          ],
          onChanged: (level) {
            if (level != null) _select(revision, level: level);
          },
        ),
        DropdownButton<GrammarQuizAttemptKind>(
          key: const Key('grammar-progress-kind'),
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
            if (kind != null) _select(revision, kind: kind);
          },
        ),
        const Text(
          'Hai loại vòng được xem riêng; điểm luyện sai không cộng vào vòng gốc.',
        ),
        OutlinedButton(
          key: const Key('grammar-progress-load'),
          onPressed: _loading ? null : () => unawaited(_load(revision)),
          child: const Text('Tải thống kê ngữ pháp'),
        ),
        if (_loading) ...[
          const LinearProgressIndicator(),
          const Text('Đang tải thống kê…'),
        ],
        if (_failed)
          const Text(
            'Không thể đọc thống kê. Bạn có thể thử tải lại.',
            key: Key('grammar-progress-error'),
          ),
        if (progress != null) ...[
          Text(
            '$label · ${_level.label} · ${progress.attemptCount} bộ đã lưu',
            key: const Key('grammar-progress-summary'),
          ),
          Text(
            '$label · Câu đúng theo bài gốc: ${progress.correctCount} / ${progress.answerCount}',
          ),
          Text('Mẫu hiện tại đã luyện: ${progress.practicedCurrentItemCount}'),
          Text(
            'Mẫu có câu hỏi trong nội dung hiện tại: ${progress.eligibleCurrentItemCount}',
          ),
          Text(
            'Mẫu chưa có kết quả khớp: ${progress.unpracticedCurrentItemCount}',
          ),
          Text(
            'Mẫu có lần trả lời gần nhất đúng: ${progress.latestCorrectCurrentItemCount}',
          ),
          Text('Mẫu cần ôn: ${progress.needsReview.length}'),
          const Text(
            'Phạm vi: các câu hỏi tạo được từ nội dung hiện tại, theo loại vòng đang chọn.',
          ),
          if (_review.isNotEmpty)
            FilledButton(
              key: const Key('grammar-focused-start'),
              onPressed: () => _startReview(revision, progress),
              child: const Text('Luyện lại các mẫu này'),
            ),
          if (progress.attemptCount == 0)
            const Text(
              'Chưa có kết quả quiz đã lưu cho cấp độ và loại vòng này.',
            ),
          if (progress.needsReview.isEmpty)
            const Text('Chưa có mẫu cần ôn khớp nội dung hiện tại.'),
          if (progress.needsReview.length > 20)
            const Text('Hiển thị tối đa 20 mẫu cần ôn.'),
          for (final item in progress.needsReview.take(20))
            ExpansionTile(
              key: ValueKey('grammar-progress-item-${item.entry.id}'),
              title: Text(item.entry.heading),
              subtitle: Text(
                '${item.entry.meaningVi}\nSai ${item.incorrectCount} lần; câu trả lời gần nhất chưa đúng.\nMở để xem cách dùng và ví dụ gốc.',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Giải thích theo bài gốc'),
                SelectableText(item.entry.explanationVi),
                const Text('Lưu ý cách dùng'),
                if (item.entry.notes.isEmpty)
                  const Text('Bài gốc chưa có lưu ý cách dùng cho mẫu này.')
                else
                  for (final note in item.entry.notes) SelectableText(note),
                const Text('Lỗi thường gặp'),
                if (item.entry.mistakes.isEmpty)
                  const Text('Bài gốc chưa có lỗi thường gặp cho mẫu này.')
                else
                  for (final mistake in item.entry.mistakes)
                    SelectableText(mistake),
                if (item.entry.examples.isEmpty)
                  const Text('Bài gốc chưa có ví dụ cho mẫu này.')
                else ...[
                  const Text('Ví dụ gốc'),
                  for (final example in item.entry.examples)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(example.japanese),
                          SelectableText(example.reading),
                          SelectableText(example.vietnamese),
                        ],
                      ),
                    ),
                ],
                const Text('Âm thanh chưa khả dụng trong phần ôn này.'),
              ],
            ),
        ],
      ],
    );
  }
}
