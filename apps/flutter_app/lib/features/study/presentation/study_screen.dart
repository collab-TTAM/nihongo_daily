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
              'Chọn phần học. Từ vựng và ngữ pháp có nội dung N5/N4 để đọc.',
        ),
        ...StudyArea.values.map(
          (area) => Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(area.label),
              subtitle: Text(switch (area) {
                StudyArea.vocabulary =>
                  'Đọc và tìm từ N5/N4 · Cách đọc, nghĩa Việt và ví dụ',
                StudyArea.grammar =>
                  'Đọc và tìm mẫu câu N5/N4 · Giải thích và ví dụ',
                StudyArea.srs => 'Ôn thẻ khi tài khoản học tập đã sẵn sàng',
                StudyArea.kanji => 'Viết trực tiếp · Chấm điểm chưa khả dụng',
                _ => 'Xem thông tin · Nội dung đang được xây dựng',
              }),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(area.path),
            ),
          ),
        ),
      ],
    );
  }
}
