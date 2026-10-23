import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/page_body.dart';
import '../../settings/application/preview_preferences.dart';
import '../application/reading_provider.dart';
import '../domain/reading_material.dart';
import '../domain/reading_repository.dart';

class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  final _scroll = ScrollController(keepScrollOffset: false);
  int _revision = 0;

  bool _scope(PreviewLevel level, ReadingRepository? repository) =>
      mounted &&
      ref.read(previewLevelProvider) == level &&
      identical(ref.read(readingRepositoryProvider), repository);

  void _reload(PreviewLevel level, ReadingRepository repository) {
    if (!_scope(level, repository)) return;
    setState(() => _revision++);
    ref.invalidate(readingCatalogProvider(level));
    _top();
  }

  void _top() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(previewLevelProvider);
    final repository = ref.watch(readingRepositoryProvider);
    return PageBody(
      scrollController: _scroll,
      children: [
        const PageHeading(
          title: 'Nghe và đọc',
          subtitle: 'Đọc bài và trả lời câu hỏi theo nội dung đang mở.',
        ),
        DropdownButton<PreviewLevel>(
          key: const Key('reading-level'),
          value: level,
          isExpanded: true,
          items: [
            for (final option in PreviewLevel.values)
              DropdownMenuItem(value: option, child: Text(option.label)),
          ],
          onChanged: (value) {
            if (!_scope(level, repository) || value == null || value == level) {
              return;
            }
            ref.read(previewLevelProvider.notifier).state = value;
            _top();
          },
        ),
        const SizedBox(height: 16),
        const FilledButton(
          key: Key('reading-audio-unavailable'),
          onPressed: null,
          child: Text('Nghe: chưa khả dụng'),
        ),
        const Text('Chưa có âm thanh được duyệt để luyện nghe.'),
        const SizedBox(height: 16),
        if (repository == null)
          const Text(
            'Chưa có nguồn bài đọc được cấu hình. '
            'Bài đọc N5/N4 sẽ xuất hiện khi có nội dung được duyệt.',
            key: Key('reading-unavailable'),
          )
        else ...[
          OutlinedButton(
            key: const Key('reading-reload'),
            onPressed: () => _reload(level, repository),
            child: const Text('Tải lại danh sách bài'),
          ),
          ...ref
              .watch(readingCatalogProvider(level))
              .when(
                skipLoadingOnRefresh: false,
                skipLoadingOnReload: false,
                loading: () => [
                  const LinearProgressIndicator(),
                  const Text('Đang tải bài đọc…', key: Key('reading-loading')),
                ],
                error: (_, _) => [
                  const Text(
                    'Không tải được bài đọc. Chưa có bản sao ngoại tuyến để mở. '
                    'Hãy thử lại khi nguồn sẵn sàng.',
                    key: Key('reading-error'),
                  ),
                  OutlinedButton(
                    key: const Key('reading-retry'),
                    onPressed: () => _reload(level, repository),
                    child: const Text('Thử tải bài đọc'),
                  ),
                ],
                data: (passages) => [
                  if (passages.isEmpty)
                    Text(
                      'Chưa có bài đọc ${level.label} trong nguồn hiện tại.',
                      key: const Key('reading-empty'),
                    )
                  else
                    _ReadingPanel(
                      key: ValueKey((repository, level, _revision, passages)),
                      passages: passages,
                      onNavigate: _top,
                    ),
                ],
              ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Kết quả chỉ giữ khi bạn đang mở bài; '
          'chưa lưu tiến độ hoặc cộng thời gian học.',
        ),
      ],
    );
  }
}

class _ReadingPanel extends StatefulWidget {
  const _ReadingPanel({
    super.key,
    required this.passages,
    required this.onNavigate,
  });
  final List<ReadingPassage> passages;
  final VoidCallback onNavigate;

  @override
  State<_ReadingPanel> createState() => _ReadingPanelState();
}

class _ReadingPanelState extends State<_ReadingPanel> {
  ReadingRound? _round;
  bool _showReading = false;
  bool _showTranslation = false;

  bool _current(ReadingRound round) => mounted && identical(_round, round);

  void _open(ReadingPassage passage) {
    if (!mounted || _round != null) return;
    setState(() => _round = ReadingRound(passage));
    widget.onNavigate();
  }

  void _answer(ReadingRound round, String questionId, String choiceId) {
    if (!_current(round)) return;
    if (round.answer(round.passage.snapshotKey, questionId, choiceId)) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    if (round == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.passages.length} bài đọc · Chọn để mở'),
          for (final passage in widget.passages)
            Card(
              child: ListTile(
                key: ValueKey('reading-open-${passage.id}'),
                title: Text(passage.titleJa),
                subtitle: Text(passage.titleVi),
                onTap: () => _open(passage),
              ),
            ),
        ],
      );
    }
    final passage = round.passage;
    final answers = round.acceptedAnswers;
    return Column(
      key: const Key('reading-passage'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: const Key('reading-back'),
          onPressed: () {
            if (!_current(round)) return;
            setState(() => _round = null);
            widget.onNavigate();
          },
          child: const Text('Về danh sách bài đọc'),
        ),
        Semantics(
          header: true,
          child: Text(
            passage.titleJa,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Text(passage.titleVi),
        CheckboxListTile(
          key: const Key('reading-show-reading'),
          title: const Text('Hiện cách đọc'),
          value: _showReading,
          onChanged: (value) {
            if (_current(round)) setState(() => _showReading = value ?? false);
          },
        ),
        CheckboxListTile(
          key: const Key('reading-show-translation'),
          title: const Text('Hiện bản dịch'),
          value: _showTranslation,
          onChanged: (value) {
            if (_current(round)) {
              setState(() => _showTranslation = value ?? false);
            }
          },
        ),
        SelectableText(passage.japanese, key: const Key('reading-text')),
        if (_showReading)
          SelectableText(passage.reading, key: const Key('reading-kana')),
        if (_showTranslation)
          SelectableText(
            passage.vietnamese,
            key: const Key('reading-vietnamese'),
          ),
        const SizedBox(height: 16),
        Text('Nguồn: ${passage.sourceNoteVi}'),
        const SizedBox(height: 16),
        for (final question in passage.questions) ...[
          Semantics(header: true, child: Text(question.japanese)),
          if (_showReading) Text(question.reading),
          if (_showTranslation) Text(question.vietnamese),
          for (final choice in question.choices)
            OutlinedButton(
              key: ValueKey('reading-choice-${question.id}-${choice.id}'),
              onPressed: answers.containsKey(question.id)
                  ? null
                  : () => _answer(round, question.id, choice.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(choice.japanese),
                  if (_showReading) Text(choice.reading),
                  if (_showTranslation) Text(choice.vietnamese),
                ],
              ),
            ),
          if (answers.containsKey(question.id)) ...[
            Text(
              answers[question.id] == question.correctChoiceId
                  ? 'Đúng theo bài đọc.'
                  : 'Chưa đúng theo bài đọc.',
              key: ValueKey('reading-feedback-${question.id}'),
            ),
            Text(
              'Đáp án: ${question.choices.firstWhere((c) => c.id == question.correctChoiceId).japanese}',
            ),
            Text(question.explanationVi),
          ],
          const SizedBox(height: 16),
        ],
        if (round.isComplete)
          Text(
            'Kết quả: ${round.correctCount} / ${passage.questions.length}',
            key: const Key('reading-result'),
          )
        else
          Text('Đã trả lời ${answers.length} / ${passage.questions.length}'),
        OutlinedButton(
          key: const Key('reading-restart'),
          onPressed: () {
            if (!_current(round)) return;
            setState(() => _round = ReadingRound(passage));
            widget.onNavigate();
          },
          child: const Text('Làm lại bài đọc'),
        ),
      ],
    );
  }
}
