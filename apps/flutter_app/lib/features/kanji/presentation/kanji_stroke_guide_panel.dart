import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/kanji_stroke_guide_provider.dart';
import '../domain/kanji_catalog.dart';
import '../domain/kanji_stroke_guide.dart';

class KanjiStrokeGuidePanel extends ConsumerStatefulWidget {
  const KanjiStrokeGuidePanel({
    super.key,
    required this.entry,
    this.trace,
    this.onTraceChanged,
  });
  final KanjiCatalogEntry entry;
  final KanjiGuideTrace? trace;
  final ValueChanged<KanjiGuideTrace?>? onTraceChanged;
  @override
  ConsumerState<KanjiStrokeGuidePanel> createState() =>
      _KanjiStrokeGuidePanelState();
}

class _KanjiStrokeGuidePanelState extends ConsumerState<KanjiStrokeGuidePanel> {
  bool _expanded = false;
  int _stroke = 0;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: const Key('kanji-guide-toggle'),
          onPressed: () {
            widget.onTraceChanged?.call(null);
            setState(() {
              _expanded = !_expanded;
              _stroke = 0;
            });
          },
          child: Text(_expanded ? 'Ẩn nét mẫu' : 'Xem nét mẫu'),
        ),
        if (_expanded) _content(),
      ],
    );
  }

  void _selectStroke(KanjiStrokeGuide guide, int index) {
    setState(() => _stroke = index);
    if (widget.trace != null) {
      widget.onTraceChanged?.call(KanjiGuideTrace(guide, index));
    }
  }

  Widget _content() {
    return ref
        .watch(kanjiStrokeGuideProvider(widget.entry))
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Column(
            children: [
              const Text('Không tải được nét mẫu. Vui lòng thử lại.'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(kanjiStrokeGuideProvider(widget.entry)),
                child: const Text('Thử tải nét mẫu'),
              ),
            ],
          ),
          data: (guide) {
            if (guide == null || !guide.matches(widget.entry)) {
              return const Text(
                'Chưa có nét mẫu phù hợp cho chữ này.',
                key: Key('kanji-guide-missing'),
              );
            }
            final stroke = math.min(_stroke, guide.strokes.length - 1);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nét ${stroke + 1} / ${guide.strokes.length}',
                      key: const Key('kanji-guide-step'),
                    ),
                    const Text(
                      'Theo số thứ tự; chấm tròn là đầu nét, mũi tên chỉ hướng cuối nét.',
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: CustomPaint(
                            key: const Key('kanji-guide-picture'),
                            painter: _GuidePainter(
                              guide,
                              stroke,
                              Theme.of(context).colorScheme,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.onTraceChanged != null)
                      SwitchListTile.adaptive(
                        key: const Key('kanji-trace-toggle'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Hiện nét mẫu trong ô viết'),
                        subtitle: const Text(
                          'Tô theo mẫu mờ; chưa chấm điểm chữ viết.',
                        ),
                        value: identical(widget.trace?.guide, guide),
                        onChanged: (enabled) => widget.onTraceChanged!(
                          enabled ? KanjiGuideTrace(guide, stroke) : null,
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          key: const Key('kanji-guide-previous'),
                          onPressed: stroke > 0
                              ? () => _selectStroke(guide, stroke - 1)
                              : null,
                          child: const Text('Nét trước'),
                        ),
                        TextButton(
                          key: const Key('kanji-guide-next'),
                          onPressed: stroke + 1 < guide.strokes.length
                              ? () => _selectStroke(guide, stroke + 1)
                              : null,
                          child: const Text('Nét tiếp'),
                        ),
                        TextButton(
                          onPressed: () =>
                              _selectStroke(guide, guide.strokes.length - 1),
                          child: const Text('Xem toàn bộ'),
                        ),
                      ],
                    ),
                    const SelectableText(
                      'Nguồn: KanjiVG — Ulrich Apel và cộng tác viên.\nhttps://kanjivg.tagaini.net/\nCC BY-SA 3.0 · https://creativecommons.org/licenses/by-sa/3.0/\nĐã chuẩn hóa đường cong và tọa độ. Chưa chấm điểm chữ viết.',
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.guide, this.stroke, this.colors);
  final KanjiStrokeGuide guide;
  final int stroke;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colors.surfaceContainerLow,
    );
    Offset project(GuidePoint p) => Offset(p.x * size.width, p.y * size.height);
    for (var i = 0; i <= stroke; i++) {
      final points = guide.strokes[i];
      final ink = i == stroke ? colors.primary : colors.outline;
      final path = Path()
        ..moveTo(project(points.first).dx, project(points.first).dy);
      for (final point in points.skip(1)) {
        final p = project(point);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = ink
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      final start = project(points.first);
      canvas.drawCircle(start, 3.5, Paint()..color = ink);
      final end = project(points.last),
          previous = project(points[points.length - 2]);
      final angle = math.atan2(end.dy - previous.dy, end.dx - previous.dx);
      final arrow = Path()
        ..moveTo(
          end.dx - 9 * math.cos(angle - .5),
          end.dy - 9 * math.sin(angle - .5),
        )
        ..lineTo(end.dx, end.dy)
        ..lineTo(
          end.dx - 9 * math.cos(angle + .5),
          end.dy - 9 * math.sin(angle + .5),
        );
      canvas.drawPath(
        arrow,
        Paint()
          ..color = ink
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          (start.dx + 5)
              .clamp(0, math.max(0, size.width - text.width))
              .toDouble(),
          (start.dy - 18)
              .clamp(0, math.max(0, size.height - text.height))
              .toDouble(),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) =>
      guide != oldDelegate.guide ||
      stroke != oldDelegate.stroke ||
      colors != oldDelegate.colors;
}
