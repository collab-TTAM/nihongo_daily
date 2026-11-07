import 'package:flutter/material.dart';

/// Display only: caller supplies an already-loaded, owner-bound projection.
final class QuizRecallSummary extends StatelessWidget {
  const QuizRecallSummary({
    required this.scope,
    required this.itemLabel,
    required this.count,
    super.key,
  });

  final String scope;
  final String itemLabel;
  final int count;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$scope · $itemLabel đạt mốc ôn cách ngày: $count'),
      const Text(
        'Với từng từ hoặc mẫu, mốc ôn là 3 lần đúng, mỗi lần cách lần được tính trước ít nhất 24 giờ. '
        'Nếu trả lời sai mục đó khớp nội dung hiện tại thì tính lại từ đầu.',
      ),
      const Text(
        'Chỉ dựa trên báo cáo quiz đã lưu. Mốc này không xác nhận đã thuộc bài '
        'hay còn nhớ ở hiện tại, không cộng thời gian học.',
      ),
    ],
  );
}
