import 'dart:math' as math;

import 'kanji_models.dart';

typedef _Point = ({double x, double y});
typedef _Box = ({double minX, double minY, double width, double height});

/// nd-kanji-synthetic-1: bounded geometric feedback for tests only.
/// No canonical Kanji lookup or recognition is inferred from a drawing.
class SyntheticScorer {
  const SyntheticScorer();
  static const version = 'nd-kanji-synthetic-1';

  SyntheticScores scoreSynthetic(KanjiAttempt attempt, KanjiAttempt reference) {
    if (attempt.kanjiId != reference.kanjiId) {
      throw ArgumentError('Synthetic identities must match');
    }
    final aBox = _box(attempt.strokes);
    final rBox = _box(reference.strokes);
    final a = attempt.strokes.map((s) => _resample(s.points, aBox)).toList();
    final r = reference.strokes.map((s) => _resample(s.points, rBox)).toList();
    final remainingA = List.generate(a.length, (i) => i);
    final remainingR = List.generate(r.length, (i) => i);
    var shape = 0.0;
    var direction = 0.0;
    var order = 0.0;
    // Greedy unique shape matching separates order/direction from geometry.
    // This is not an optimal assignment algorithm or a recognition classifier.
    while (remainingA.isNotEmpty && remainingR.isNotEmpty) {
      var best = double.infinity;
      var ai = remainingA.first;
      var ri = remainingR.first;
      for (final i in remainingA) {
        for (final j in remainingR) {
          final distance = math.min(
            _distance(a[i], r[j]),
            _distance(a[i], r[j].reversed.toList()),
          );
          if (distance < best) {
            best = distance;
            ai = i;
            ri = j;
          }
        }
      }
      shape += _score(best / 0.25);
      direction += _direction(a[ai], r[ri]);
      if (ai == ri) order += 100;
      remainingA.remove(ai);
      remainingR.remove(ri);
    }
    final count = math.max(a.length, r.length);
    final balanceError =
        (((aBox.minX + aBox.width / 2) - (rBox.minX + rBox.width / 2)).abs() +
            ((aBox.minY + aBox.height / 2) - (rBox.minY + rBox.height / 2))
                .abs() +
            (aBox.width - rBox.width).abs() +
            (aBox.height - rBox.height).abs()) /
        2;
    return SyntheticScores(
      shape: shape / count,
      order: order / count,
      direction: direction / count,
      balance: _score(balanceError),
    );
  }

  /// #16 must supply vetted, versioned assets before a real evaluator exists.
  Never evaluateReal(KanjiAttempt attempt) =>
      throw const ReferenceUnavailable();
}

double _score(double error) => (100 * (1 - error)).clamp(0.0, 100.0);

_Box _box(List<Stroke> strokes) {
  final points = strokes.expand((s) => s.points).toList();
  final minX = points.map((p) => p.x).reduce(math.min);
  final minY = points.map((p) => p.y).reduce(math.min);
  final maxX = points.map((p) => p.x).reduce(math.max);
  final maxY = points.map((p) => p.y).reduce(math.max);
  return (minX: minX, minY: minY, width: maxX - minX, height: maxY - minY);
}

List<_Point> _resample(List<StrokePoint> points, _Box box) {
  final side = math.max(box.width, box.height);
  if (side <= 1e-9) throw ArgumentError('Degenerate synthetic geometry');
  final source = points
      .map(
        (p) => (
          x: (p.x - box.minX - box.width / 2) / side,
          y: (p.y - box.minY - box.height / 2) / side,
        ),
      )
      .toList();
  final lengths = <double>[0];
  for (var i = 1; i < source.length; i++) {
    lengths.add(lengths.last + _length(source[i - 1], source[i]));
  }
  if (lengths.last <= 1e-9) throw ArgumentError('Degenerate synthetic stroke');
  var segment = 1;
  return List.generate(32, (i) {
    final target = lengths.last * i / 31;
    while (segment < lengths.length - 1 && lengths[segment] < target) {
      segment++;
    }
    final span = lengths[segment] - lengths[segment - 1];
    final ratio = span <= 1e-9 ? 0.0 : (target - lengths[segment - 1]) / span;
    final start = source[segment - 1];
    final end = source[segment];
    return (
      x: start.x + ratio * (end.x - start.x),
      y: start.y + ratio * (end.y - start.y),
    );
  });
}

double _length(_Point a, _Point b) =>
    math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

double _distance(List<_Point> a, List<_Point> b) {
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    sum += _length(a[i], b[i]);
  }
  return sum / a.length;
}

double _direction(List<_Point> a, List<_Point> b) {
  var sum = 0.0;
  for (var i = 1; i < a.length; i++) {
    final ax = a[i].x - a[i - 1].x;
    final ay = a[i].y - a[i - 1].y;
    final bx = b[i].x - b[i - 1].x;
    final by = b[i].y - b[i - 1].y;
    final denom = math.sqrt((ax * ax + ay * ay) * (bx * bx + by * by));
    sum += denom <= 1e-12
        ? 0
        : 50 * (1 + ((ax * bx + ay * by) / denom).clamp(-1.0, 1.0));
  }
  return sum / (a.length - 1);
}
