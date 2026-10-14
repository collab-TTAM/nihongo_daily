import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_body.dart';
import '../../settings/application/preview_preferences.dart';
import '../application/srs_study_controller.dart';
import '../application/srs_study_provider.dart';
import '../domain/srs_models.dart';

class SrsStudyScreen extends ConsumerStatefulWidget {
  const SrsStudyScreen({super.key});
  @override
  ConsumerState<SrsStudyScreen> createState() => _SrsStudyScreenState();
}

class _SrsStudyScreenState extends ConsumerState<SrsStudyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(srsStudyProvider).phase == SrsStudyPhase.idle) {
        ref
            .read(srsStudyProvider.notifier)
            .load(ref.read(previewLevelProvider));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(srsStudyProvider);
    final controller = ref.read(srsStudyProvider.notifier);
    final item = state.item;
    void reload() => controller.load(ref.read(previewLevelProvider));
    return PageBody(
      children: [
        const PageHeading(
          title: 'Ôn tập SRS',
          subtitle:
              'Luồng giao diện đang phát triển · Chưa kiểm chứng với Supabase thật.',
        ),
        if (state.phase == SrsStudyPhase.unavailable) ...[
          const Text(
            'Chưa kết nối Supabase. Chưa có danh sách ôn tập hoặc kết quả lưu thật.',
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.go('/auth'),
            child: const Text('Xem trạng thái tài khoản'),
          ),
        ] else if (state.phase == SrsStudyPhase.signedOut) ...[
          const Text(
            'Phiên tài khoản đã thay đổi hoặc chưa đăng nhập. Danh sách cũ đã được ẩn.',
          ),
          OutlinedButton(
            onPressed: reload,
            child: const Text('Tải danh sách cho phiên hiện tại'),
          ),
        ] else if (state.phase == SrsStudyPhase.loading) ...[
          const Center(child: CircularProgressIndicator()),
          const Text('Đang tải danh sách ôn tập…'),
        ] else ...[
          if (state.total > 0)
            Text(
              'Đã xác nhận ${state.confirmed} / ${state.total} lượt trong phiên này.',
            ),
          if (item != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Danh sách ${item.level.label} • ${_itemLabel(item.type)}',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item.prompt,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    if (state.answerVisible) ...[
                      const SizedBox(height: 16),
                      Text(
                        item.reading.trim().isEmpty
                            ? 'Chưa có cách đọc trong dữ liệu của mục này.'
                            : item.reading,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(item.answerVi),
                    ] else ...[
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: controller.reveal,
                        child: const Text('Xem đáp án'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (state.canRate)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final rating in ReviewRating.values)
                  FilledButton.tonal(
                    onPressed: () => controller.rate(rating),
                    child: Text(_ratingLabel(rating)),
                  ),
              ],
            ),
          if (state.phase == SrsStudyPhase.saving) ...[
            const Center(child: CircularProgressIndicator()),
            const Text('Đang chờ phản hồi lưu. Không gửi lượt mới.'),
          ],
          if (state.failure != null) ...[
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: Text(state.failure!.messageVi)),
            if (state.hasPendingEvent)
              const Text(
                'Chưa xác nhận lượt này đã lưu. Không đổi đánh giá hay tạo mã lượt mới.',
              ),
            if (state.canRetry)
              FilledButton(
                onPressed: controller.retry,
                child: const Text('Thử lại cùng lượt ôn'),
              ),
            if (state.canReload)
              OutlinedButton(
                onPressed: reload,
                child: Text(
                  state.hasPendingEvent
                      ? 'Bỏ lượt bị từ chối và tải lại'
                      : 'Tải lại danh sách',
                ),
              ),
          ],
          if (state.receipt != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: const Text('Đã nhận phản hồi xác nhận lượt ôn.'),
            ),
            Text(
              'Lịch từ phản hồi (UTC): ${state.receipt!.nextReviewAt.toIso8601String()}',
            ),
          ],
          if (state.phase == SrsStudyPhase.empty)
            const Text('Không có mục đến hạn trong danh sách đã tải.'),
          if (state.phase == SrsStudyPhase.complete)
            const Text('Đã xử lý hết danh sách của phiên này.'),
          if (state.phase == SrsStudyPhase.empty ||
              state.phase == SrsStudyPhase.complete)
            OutlinedButton(
              onPressed: reload,
              child: const Text('Tải lại danh sách'),
            ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Lượt chưa xác nhận chỉ được giữ trong bộ nhớ khi đổi trang. '
          'Lưu hàng đợi qua khởi động lại và đồng bộ thiết bị chưa được tích hợp.',
        ),
      ],
    );
  }
}

String _ratingLabel(ReviewRating rating) => switch (rating) {
  ReviewRating.again => 'Quên',
  ReviewRating.hard => 'Khó',
  ReviewRating.good => 'Tốt',
  ReviewRating.easy => 'Dễ',
};
String _itemLabel(LearningItemType type) => switch (type) {
  LearningItemType.vocabulary => 'Từ vựng',
  LearningItemType.kanji => 'Kanji',
  LearningItemType.grammar => 'Ngữ pháp',
};
