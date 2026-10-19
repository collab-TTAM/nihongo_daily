import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_body.dart';
import '../../settings/application/preview_preferences.dart';
import '../application/curriculum_provider.dart';
import '../domain/curriculum.dart';

class CurriculumScreen extends ConsumerStatefulWidget {
  const CurriculumScreen({super.key, required this.kind});
  final CurriculumKind kind;

  @override
  ConsumerState<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends ConsumerState<CurriculumScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(previewLevelProvider);
    final content = ref.watch(curriculumProvider(widget.kind));
    return PageBody(
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
            setState(() => _selectedId = null);
            ref.read(previewLevelProvider.notifier).state = value;
          },
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
          data: (entries) {
            final selected = [
              for (final entry in entries)
                if (entry.id == _selectedId) entry,
            ];
            if (selected.isNotEmpty) {
              return [
                OutlinedButton(
                  onPressed: () => setState(() => _selectedId = null),
                  child: const Text('Về danh sách'),
                ),
                ..._details(selected.single),
              ];
            }
            if (entries.isEmpty) {
              return [Text('Chưa có nội dung ${level.label} trong bản này.')];
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
                    onTap: () => setState(() => _selectedId = entry.id),
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
