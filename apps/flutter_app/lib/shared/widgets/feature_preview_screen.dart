import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'page_body.dart';

class FeaturePreviewScreen extends StatelessWidget {
  const FeaturePreviewScreen({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        PageHeading(title: title, subtitle: description),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.construction_outlined, size: 40),
                const SizedBox(height: 16),
                Text(
                  'Đang xây dựng',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chức năng này chưa khả dụng. Bản xem trước không ghi '
                  'tiến độ, chấm điểm hay gửi dữ liệu tới dịch vụ bên ngoài.',
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => context.go('/study'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Về các phần học'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
