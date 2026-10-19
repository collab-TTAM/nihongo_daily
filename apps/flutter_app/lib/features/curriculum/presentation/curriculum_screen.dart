import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_body.dart';
import '../../settings/application/preview_preferences.dart';
import '../application/curriculum_provider.dart';
import '../domain/curriculum.dart';
import '../domain/curriculum_search.dart';

class CurriculumScreen extends ConsumerStatefulWidget {
  const CurriculumScreen({super.key, required this.kind});
  final CurriculumKind kind;

  @override
  ConsumerState<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends ConsumerState<CurriculumScreen> {
  final _scrollController = ScrollController(keepScrollOffset: false);
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedId;
  double _listOffset = 0;
  int _scrollRevision = 0;

  void _navigateTo(String? id, {bool resetList = false}) {
    if (id != null) FocusScope.of(context).unfocus();
    if (_selectedId == null && id != null && _scrollController.hasClients) {
      _listOffset = _scrollController.offset;
    }
    if (resetList) _listOffset = 0;
    setState(() => _selectedId = id);
    final offset = id == null ? _listOffset : 0.0;
    final revision = ++_scrollRevision;
    // Layout must finish before restoring a list that is longer than details.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _scrollRevision ||
          !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      _scrollController.jumpTo(
        offset
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(previewLevelProvider);
    final content = ref.watch(curriculumProvider(widget.kind));
    return PageBody(
      scrollController: _scrollController,
      children: [
        PageHeading(
          title: widget.kind.label,
          subtitle: 'Nội dung gốc ban đầu · Chỉ đọc, chưa ghi tiến độ học tập.',
        ),
        DropdownButton<PreviewLevel>(
          key: const Key('curriculum-level'),
          value: level,
          isExpanded: true,
          items: [
            for (final option in PreviewLevel.values)
              DropdownMenuItem(value: option, child: Text(option.label)),
          ],
          onChanged: (value) {
            if (value == null || value == level) return;
            _navigateTo(null, resetList: true);
            ref.read(previewLevelProvider.notifier).state = value;
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('curriculum-search'),
          controller: _searchController,
          maxLength: 128,
          decoration: InputDecoration(
            labelText: 'Tìm bài',
            hintText: 'Chữ Nhật, cách đọc, nghĩa Việt',
            counterText: '',
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    onPressed: () {
                      _searchController.clear();
                      _changeQuery('');
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
          onChanged: _changeQuery,
        ),
        const SizedBox(height: 16),
        ...content.when(
          loading: () => [
            const Center(child: CircularProgressIndicator()),
            const Text('Đang tải nội dung…'),
          ],
          error: (_, _) => [
            const Text('Không tải được nội dung. Vui lòng thử lại.'),
            OutlinedButton(
              onPressed: () => ref.invalidate(curriculumProvider(widget.kind)),
              child: const Text('Thử tải lại'),
            ),
          ],
          data: (sourceEntries) {
            if (sourceEntries.isEmpty) {
              return [Text('Chưa có nội dung ${level.label} trong bản này.')];
            }
            final entries = searchCurriculum(sourceEntries, _query);
            final selectedIndex = entries.indexWhere(
              (entry) => entry.id == _selectedId,
            );
            if (selectedIndex >= 0) {
              return [
                OutlinedButton(
                  onPressed: () => _navigateTo(null),
                  child: const Text('Về danh sách'),
                ),
                Text('Mục ${selectedIndex + 1} / ${entries.length}'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('curriculum-previous'),
                      onPressed: selectedIndex > 0
                          ? () => _navigateTo(entries[selectedIndex - 1].id)
                          : null,
                      child: const Text('Bài trước'),
                    ),
                    OutlinedButton(
                      key: const Key('curriculum-next'),
                      onPressed: selectedIndex + 1 < entries.length
                          ? () => _navigateTo(entries[selectedIndex + 1].id)
                          : null,
                      child: const Text('Bài tiếp'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._details(entries[selectedIndex]),
              ];
            }
            if (entries.isEmpty) {
              return [
                const Text(
                  'Không tìm thấy bài phù hợp. Hãy đổi hoặc xóa tìm kiếm.',
                ),
              ];
            }
            return [
              Text('${entries.length} mục ${level.label} · Chọn để xem bài'),
              for (final entry in entries)
                Card(
                  child: ListTile(
                    key: ValueKey(entry.id),
                    title: Text(entry.heading),
                    subtitle: Text(entry.reading ?? entry.caption),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _navigateTo(entry.id),
                  ),
                ),
            ];
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Nội dung chưa bao phủ toàn bộ JLPT và cần duyệt ngôn ngữ. '
          'Chưa có buổi học, điểm số hoặc kết quả lưu vào tài khoản.',
        ),
        OutlinedButton(
          onPressed: () => context.go('/study'),
          child: const Text('Về các phần học'),
        ),
      ],
    );
  }

  void _changeQuery(String value) {
    if (value == _query) return;
    _query = value;
    _navigateTo(null, resetList: true);
  }

  List<Widget> _details(CurriculumEntry entry) => [
    Text(entry.heading, style: Theme.of(context).textTheme.headlineMedium),
    if (entry.reading != null)
      Text(entry.reading!, style: Theme.of(context).textTheme.titleLarge),
    Text(entry.caption),
    const SizedBox(height: 12),
    Text(entry.meaningVi),
    const SizedBox(height: 12),
    Text(entry.explanationVi),
    for (final note in entry.notes) Text('• $note'),
    if (entry.mistakes.isNotEmpty) ...[
      const SizedBox(height: 12),
      const Text('Lỗi thường gặp'),
      for (final mistake in entry.mistakes) Text('• $mistake'),
    ],
    const SizedBox(height: 16),
    Text(
      entry.hasAudioReference
          ? 'Phát âm thanh chưa được tích hợp.'
          : 'Chưa có âm thanh cho mục này.',
    ),
    const SizedBox(height: 16),
    const Text('Ví dụ'),
    for (final example in entry.examples)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(example.japanese),
              Text(example.reading),
              Text(example.vietnamese),
            ],
          ),
        ),
      ),
  ];
}
