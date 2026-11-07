import 'package:flutter/material.dart';
import '../domain/conversation_responses.dart';

/// Pure rendering only. The host supplies a freshly guarded accepted summary;
/// this widget grants no authority and owns no flow, requests or persistence.
class ConversationSummary extends StatelessWidget {
  const ConversationSummary({super.key, required this.summary});
  final FinishConversationResponse summary;
  @override
  Widget build(BuildContext context) => Column(
    key: const Key('conversation-summary'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Tổng kết tham khảo', style: Theme.of(context).textTheme.titleLarge),
      const Text('Chưa lưu vào tiến độ hoặc SRS.'),
      Text('Ngữ pháp: ${summary.scores.grammar}/100'),
      Text('Từ vựng: ${summary.scores.vocabulary}/100'),
      Text('Lưu loát: ${summary.scores.fluency}/100'),
      const SizedBox(height: 12),
      const Text('Gợi ý sửa câu'),
      if (summary.errors.isEmpty)
        const Text('Không có gợi ý sửa câu trong phản hồi này.')
      else
        for (final error in summary.errors) ...[
          Text(error.originalText),
          Text(error.correctedText),
          Text(error.explanationVi),
        ],
      const SizedBox(height: 12),
      const Text('Điểm mạnh'),
      if (summary.strengthsVi.isEmpty)
        const Text('Chưa có nhận xét điểm mạnh.')
      else
        for (final text in summary.strengthsVi) Text(text),
      const SizedBox(height: 12),
      const Text('Nội dung nên luyện tiếp'),
      if (summary.focusNextVi.isEmpty)
        const Text('Chưa có gợi ý luyện tiếp.')
      else
        for (final text in summary.focusNextVi) Text(text),
      Text('Gợi ý SRS: ${summary.srsRecommendations.length}. Chưa lưu.'),
    ],
  );
}
