import 'package:flutter/material.dart';
import '../domain/kanji_stroke_guide.dart';

/// A faint original-canvas prefix painted below, never into, learner ink.
class KanjiTracePainter extends CustomPainter {
  KanjiTracePainter(this.trace, this.color);
  final KanjiGuideTrace trace;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    var index = 0;
    for (final stroke in trace.strokes) {
      final current = index++ == trace.strokeIndex;
      final pen = Paint()
        ..color = color.withValues(alpha: current ? .30 : .16)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(stroke.first.x * size.width, stroke.first.y * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.x * size.width, point.y * size.height);
      }
      canvas.drawPath(path, pen);
      if (current) {
        canvas.drawCircle(
          Offset(stroke.first.x * size.width, stroke.first.y * size.height),
          4.5,
          Paint()..color = color.withValues(alpha: .40),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(KanjiTracePainter oldDelegate) =>
      trace.guide != oldDelegate.trace.guide ||
      trace.strokeIndex != oldDelegate.trace.strokeIndex ||
      color != oldDelegate.color;
}
