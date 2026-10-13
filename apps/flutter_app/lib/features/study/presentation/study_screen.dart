import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_body.dart';
import '../../home/domain/study_preview.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        const PageHeading(
          title: 'Không gian học tập',
          subtitle:
              'Khám phá các phần của Nihongo Daily. Nội dung đang được xây dựng.',
        ),
        ...StudyArea.values.map(
          (area) => Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(area.label),
              subtitle: const Text('Xem thông tin · Chưa có buổi học thực tế'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(area.path),
            ),
          ),
        ),
      ],
    );
  }
}
