/// Frozen v0.1 square-canvas coordinates and per-stroke elapsed milliseconds.
class StrokePoint {
  StrokePoint(this.x, this.y, this.t) {
    if (!x.isFinite ||
        !y.isFinite ||
        x < 0 ||
        x > 1 ||
        y < 0 ||
        y > 1 ||
        t < 0 ||
        t > 3600000) {
      throw ArgumentError('Invalid normalized point');
    }
  }

  final double x;
  final double y;
  final int t;
  Map<String, Object> toJson() => {'x': x, 'y': y, 't': t};
}

class Stroke {
  Stroke(this.index, Iterable<StrokePoint> points)
    : points = List.unmodifiable(points) {
    if (index < 0 ||
        index > 63 ||
        this.points.length < 2 ||
        this.points.length > 4096 ||
        this.points.first.t != 0) {
      throw ArgumentError('Invalid stroke');
    }
    for (var i = 1; i < this.points.length; i++) {
      if (this.points[i].t < this.points[i - 1].t) {
        throw ArgumentError('Stroke time must be monotonic');
      }
    }
  }

  final int index;
  final List<StrokePoint> points;
  Map<String, Object> toJson() => {
    'index': index,
    'points': points.map((p) => p.toJson()).toList(),
  };
}

class KanjiAttempt {
  KanjiAttempt(this.kanjiId, Iterable<Stroke> strokes)
    : strokes = List.unmodifiable(strokes) {
    if (!RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(kanjiId) ||
        this.strokes.isEmpty ||
        this.strokes.length > 64) {
      throw ArgumentError('Invalid attempt');
    }
    for (var i = 0; i < this.strokes.length; i++) {
      if (this.strokes[i].index != i) {
        throw ArgumentError('Stroke indices must be consecutive');
      }
    }
  }

  final String kanjiId;
  final List<Stroke> strokes;
  Map<String, Object> toJson() => {
    'kanji_id': kanjiId,
    'strokes': strokes.map((s) => s.toJson()).toList(),
  };
}

/// Experimental scores are deliberately not a deployed evaluate_kanji response.
class SyntheticScores {
  const SyntheticScores({
    required this.shape,
    required this.order,
    required this.direction,
    required this.balance,
  });
  final double shape;
  final double order;
  final double direction;
  final double balance;
  double get total => (shape + order + direction + balance) / 4;
}

class ReferenceUnavailable implements Exception {
  const ReferenceUnavailable();
}
