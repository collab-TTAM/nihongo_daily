import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/preview_level.dart';
import '../../../shared/widgets/page_body.dart';
import '../application/kanji_capture_provider.dart';
import '../application/kanji_catalog_provider.dart';
import '../domain/kanji_catalog.dart';
import 'kanji_capture_screen.dart';

class KanjiCatalogScreen extends ConsumerStatefulWidget {
  const KanjiCatalogScreen({super.key, this.initialLevel = PreviewLevel.n5});
  final PreviewLevel initialLevel;

  @override
  ConsumerState<KanjiCatalogScreen> createState() => _KanjiCatalogScreenState();
}

class _KanjiCatalogScreenState extends ConsumerState<KanjiCatalogScreen> {
  late var _level = widget.initialLevel;
  final _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(kanjiCatalogProvider(_level));
    return PageBody(
      children: [
        const PageHeading(
          title: 'Chọn chữ Kanji',
          subtitle:
              'Nội dung gốc N5/N4 · Chọn chữ để xem cách đọc và tập viết.',
        ),
        DropdownButton<PreviewLevel>(
          key: const Key('kanji-catalog-level'),
          value: _level,
          isExpanded: true,
          items: [
            for (final level in PreviewLevel.values)
              DropdownMenuItem(value: level, child: Text(level.label)),
          ],
          onChanged: (value) {
            if (value == null || value == _level) {
              return;
            }
            setState(() {
              _level = value;
              _query.clear();
            });
          },
        ),
        TextField(
          key: const Key('kanji-catalog-search'),
          controller: _query,
          maxLength: 128,
          decoration: InputDecoration(
            labelText: 'Tìm Kanji, cách đọc hoặc nghĩa Việt',
            counterText: '',
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xóa tìm Kanji',
                    onPressed: () => setState(_query.clear),
                    icon: const Icon(Icons.clear),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        ...content.when(
          skipLoadingOnRefresh: false,
          loading: () => [
            const LinearProgressIndicator(),
            const Text('Đang tải Kanji…'),
          ],
          error: (_, _) => [
            const Text('Không tải được Kanji. Vui lòng thử lại.'),
            OutlinedButton(
              key: const Key('kanji-catalog-retry'),
              onPressed: () => ref.invalidate(kanjiCatalogProvider(_level)),
              child: const Text('Thử tải lại Kanji'),
            ),
          ],
          data: (entries) {
            final matches = searchKanjiCatalog(entries, _query.text);
            if (entries.isEmpty) {
              return [Text('Chưa có Kanji ${_level.label} trong bản này.')];
            }
            if (matches.isEmpty) {
              return [const Text('Không tìm thấy Kanji phù hợp.')];
            }
            return [
              Text('${matches.length} chữ ${_level.label}'),
              for (final entry in matches)
                Card(
                  child: ListTile(
                    key: ValueKey('kanji-${entry.id}'),
                    title: Text(entry.character),
                    subtitle: Text(entry.meaningVi),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(
                      '/kanji/practice/${entry.level.name}/${entry.id}',
                    ),
                  ),
                ),
            ];
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Nội dung chưa bao phủ toàn bộ JLPT và cần duyệt ngôn ngữ. '
          'Chưa hướng dẫn thứ tự nét, chấm điểm hoặc lưu tiến độ.',
        ),
        OutlinedButton(
          onPressed: () => context.go('/kanji'),
          child: const Text('Về ô tập vẽ tự do'),
        ),
      ],
    );
  }
}

class KanjiPracticeScreen extends ConsumerWidget {
  const KanjiPracticeScreen({
    super.key,
    required this.level,
    required this.entryId,
  });
  final PreviewLevel level;
  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(kanjiCatalogProvider(level));
    return content.when(
      skipLoadingOnRefresh: false,
      loading: () => const PageBody(
        children: [LinearProgressIndicator(), Text('Đang tải Kanji…')],
      ),
      error: (_, _) => PageBody(
        children: [
          const Text('Không tải được Kanji. Vui lòng thử lại.'),
          OutlinedButton(
            onPressed: () => ref.invalidate(kanjiCatalogProvider(level)),
            child: const Text('Thử tải lại Kanji'),
          ),
        ],
      ),
      data: (entries) {
        final index = entries.indexWhere(
          (entry) => entry.id == entryId && entry.level == level,
        );
        if (index < 0) {
          return PageBody(
            children: [
              const Text('Không tìm thấy chữ Kanji ở cấp độ này.'),
              OutlinedButton(
                onPressed: () =>
                    context.go('/kanji/characters?level=${level.name}'),
                child: const Text('Về danh sách Kanji'),
              ),
            ],
          );
        }
        final entry = entries[index];
        // A fresh local capture per identity/version/level. No previous character's
        // strokes survive a selection, source reload or route replacement.
        return ProviderScope(
          key: ValueKey('${level.name}/${entry.id}/${entry.contentVersion}'),
          overrides: [
            kanjiCaptureProvider.overrideWith(
              (ref) => KanjiCaptureController(),
            ),
          ],
          child: KanjiCaptureScreen(entry: entry),
        );
      },
    );
  }
}
