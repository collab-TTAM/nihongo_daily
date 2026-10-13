import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_body.dart';
import '../application/preview_preferences.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageBody(
      children: [
        const PageHeading(
          title: 'Cài đặt bản xem trước',
          subtitle:
              'Lựa chọn chỉ có hiệu lực trong phiên này; chưa lưu vào tài khoản.',
        ),
        Text('Trình độ', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SegmentedButton<PreviewLevel>(
          segments: const [
            ButtonSegment(value: PreviewLevel.n5, label: Text('N5')),
            ButtonSegment(value: PreviewLevel.n4, label: Text('N4')),
          ],
          selected: {ref.watch(previewLevelProvider)},
          onSelectionChanged: (values) {
            ref.read(previewLevelProvider.notifier).state = values.single;
          },
        ),
        const SizedBox(height: 24),
        Text('Giao diện', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        DropdownButtonFormField<ThemeMode>(
          isExpanded: true,
          initialValue: ref.watch(previewThemeProvider),
          decoration: const InputDecoration(
            labelText: 'Chế độ hiển thị',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: ThemeMode.system,
              child: Text('Theo thiết bị', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: ThemeMode.light,
              child: Text('Sáng', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: ThemeMode.dark,
              child: Text('Tối', overflow: TextOverflow.ellipsis),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              ref.read(previewThemeProvider.notifier).state = value;
            }
          },
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.go('/auth'),
          icon: const Icon(Icons.person_outline),
          label: const Text('Thông tin tài khoản'),
        ),
      ],
    );
  }
}
