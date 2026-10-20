import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page_body.dart';
import '../application/kanji_capture_provider.dart';
import '../domain/kanji_models.dart';
import '../domain/kanji_catalog.dart';
import 'kanji_stroke_guide_panel.dart';
import '../../../shared/models/preview_level.dart';

class KanjiCaptureScreen extends ConsumerWidget {
  const KanjiCaptureScreen({super.key, this.entry});
  final KanjiCatalogEntry? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kanjiCaptureProvider);
    final controller = ref.read(kanjiCaptureProvider.notifier);
    return PageBody(
      children: [
        Text(
          entry == null ? 'Luyện Kanji' : 'Luyện viết ${entry!.character}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (entry case final selected?) ...[
          Text(
            selected.character,
            key: ValueKey('kanji-selected-${selected.id}'),
            style: Theme.of(context).textTheme.displayLarge,
          ),
          Text(selected.meaningVi),
          Text(
            'Âm On: ${selected.onyomi.isEmpty ? 'Chưa có' : selected.onyomi.join('、')}',
          ),
          Text(
            'Âm Kun: ${selected.kunyomi.isEmpty ? 'Chưa có' : selected.kunyomi.join('、')}',
          ),
          Text(
            '${selected.level.label} · Số nét theo nội dung: ${selected.strokeCount}',
          ),
          Text('Bộ thủ: ${selected.radical ?? 'Chưa có thông tin'}'),
        ],
        const SizedBox(height: 8),
        const Text('BẢN XEM TRƯỚC · NHẬP NÉT THỬ NGHIỆM'),
        const SizedBox(height: 12),
        const Text(
          'Dùng chuột, bút hoặc ngón tay để vẽ trong ô vuông. '
          'Nét chỉ giữ trong màn này; chưa lưu tiến độ.',
        ),
        const SizedBox(height: 8),
        Text(
          entry != null
              ? 'Có thể xem từng nét mẫu ${entry!.level.label}. Bộ đánh giá chữ viết chưa được kiểm chứng.'
              : 'Chưa có nét mẫu đã kiểm chứng để chấm Kanji thật. '
                    'Ô này là vùng tập vẽ, chưa hướng dẫn thứ tự nét.',
        ),
        if (entry case final selected?) KanjiStrokeGuidePanel(entry: selected),
        OutlinedButton(
          key: const Key('kanji-open-catalog'),
          onPressed: () => context.go(
            entry == null
                ? '/kanji/characters'
                : '/kanji/characters?level=${entry!.level.name}',
          ),
          child: Text(entry == null ? 'Chọn chữ N5/N4' : 'Về danh sách Kanji'),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = constraints.maxWidth;
                  final color = Theme.of(context).colorScheme;
                  return Semantics(
                    label: 'Ô nhập nét viết',
                    child: RawGestureDetector(
                      gestures: {
                        EagerGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                              EagerGestureRecognizer
                            >(EagerGestureRecognizer.new, (instance) {}),
                      },
                      child: Listener(
                        key: const Key('kanji-canvas'),
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) {
                          if (e.buttons == kPrimaryButton) {
                            controller.begin(
                              e.pointer,
                              e.localPosition.dx,
                              e.localPosition.dy,
                              side,
                              e.timeStamp.inMilliseconds,
                            );
                          }
                        },
                        onPointerMove: (e) => controller.move(
                          e.pointer,
                          e.localPosition.dx,
                          e.localPosition.dy,
                          side,
                          e.timeStamp.inMilliseconds,
                        ),
                        onPointerUp: (e) => controller.end(
                          e.pointer,
                          e.localPosition.dx,
                          e.localPosition.dy,
                          side,
                          e.timeStamp.inMilliseconds,
                        ),
                        onPointerCancel: (e) => controller.cancel(e.pointer),
                        child: ColoredBox(
                          color: color.surfaceContainerLow,
                          child: CustomPaint(
                            painter: _StrokePainter(
                              state,
                              color.primary,
                              color.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Đã nhập ${state.strokes.length} nét / 64',
          key: const Key('kanji-count'),
          semanticsLabel: 'Số nét đã nhập: ${state.strokes.length}',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: state.strokes.isEmpty && state.active.isEmpty
                  ? null
                  : controller.undo,
              icon: const Icon(Icons.undo),
              label: const Text('Hoàn tác nét'),
            ),
            OutlinedButton.icon(
              onPressed: state.strokes.isEmpty && state.active.isEmpty
                  ? null
                  : controller.clear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xóa tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.messageVi != null)
          Text(
            state.messageVi!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Text(
          entry != null
              ? 'Chấm điểm: chưa khả dụng — bộ đánh giá chữ viết chưa được kiểm chứng. Không có điểm số hoặc kết quả học được lưu.'
              : 'Chấm điểm: chưa khả dụng — thiếu dữ liệu nét mẫu. '
                    'Không có điểm số hoặc kết quả học được lưu.',
        ),
      ],
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.snapshot, this.ink, this.grid);
  final CaptureSnapshot snapshot;
  final Color ink;
  final Color grid;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final guide = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawRect(Offset.zero & size, guide..style = PaintingStyle.stroke);
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      guide,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      guide,
    );
    final pen = Paint()
      ..color = ink
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    void draw(List<StrokePoint> points) {
      if (points.isEmpty) return;
      final path = Path()
        ..moveTo(points.first.x * size.width, points.first.y * size.height);
      for (final p in points.skip(1)) {
        path.lineTo(p.x * size.width, p.y * size.height);
      }
      canvas.drawPath(path, pen);
    }

    for (final stroke in snapshot.strokes) {
      draw(stroke.points);
    }
    draw(snapshot.active);
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) =>
      snapshot != oldDelegate.snapshot ||
      ink != oldDelegate.ink ||
      grid != oldDelegate.grid;
}
