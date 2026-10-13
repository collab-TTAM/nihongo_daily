import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_body.dart';
import '../../settings/application/preview_preferences.dart';
import '../application/study_preview_provider.dart';
import '../domain/study_preview.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(studyPreviewProvider)
        .when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Đang tải bản xem trước',
            ),
          ),
          error: (error, stackTrace) => PageBody(
            children: [
              const PageHeading(
                title: 'Không tải được bản xem trước',
                subtitle: 'Bạn có thể thử lại. Tiến độ học chưa được ghi nhận.',
              ),
              FilledButton.icon(
                onPressed: () => ref.invalidate(studyPreviewProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
          data: (preview) => _PreviewBody(preview: preview),
        );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.preview});

  final StudyPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageBody(
      children: [
        const PageHeading(
          title: 'Một chút tiếng Nhật, mỗi ngày',
          subtitle: 'Xây dựng thói quen học bằng những bước nhỏ và đều đặn.',
        ),
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LỘ TRÌNH MẪU · ${preview.level.label}',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  '${preview.totalMinutes} phút mỗi ngày',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Phân bổ thời gian tham khảo. Các buổi học và tiến độ '
                  'thực tế sẽ có sau khi kết nối nội dung và tài khoản.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.go('/study'),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Khám phá các phần học'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Phân bổ thời gian', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (preview.blocks.isEmpty)
          const Text('Chưa có phần học trong bản xem trước này.')
        else
          ...preview.blocks.map(
            (block) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                title: Text(block.area.label),
                subtitle: Text('${block.minutes} phút · Chưa khả dụng'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => context.go(block.area.path),
              ),
            ),
          ),
      ],
    );
  }
}
