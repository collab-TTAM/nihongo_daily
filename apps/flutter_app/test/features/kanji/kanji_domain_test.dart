import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/kanji/domain/kanji_models.dart';
import 'package:nihongo_daily/features/kanji/domain/stroke_capture.dart';
import 'package:nihongo_daily/features/kanji/domain/synthetic_scorer.dart';

const id = '00000000-0000-4000-8000-000000000006';
Stroke line(int index, double x, double y, double xx, double yy) =>
    Stroke(index, [StrokePoint(x, y, 0), StrokePoint(xx, yy, 10)]);
KanjiAttempt cross() =>
    KanjiAttempt(id, [line(0, .2, .5, .8, .5), line(1, .5, .2, .5, .8)]);
void draw(StrokeCapture c, {int pointer = 1, int start = 100}) {
  expect(c.begin(pointer, 20, 50, 100, start), isTrue);
  expect(c.end(pointer, 80, 50, 100, start + 20), isTrue);
}

void main() {
  group('frozen models', () {
    test('bounds and finite coordinates', () {
      for (final x in [-.1, 1.1, double.nan, double.infinity]) {
        expect(() => StrokePoint(x, .5, 0), throwsArgumentError);
      }
      expect(() => StrokePoint(0, 0, -1), throwsArgumentError);
      expect(() => StrokePoint(0, 0, 3600001), throwsArgumentError);
      expect(StrokePoint(0, 1, 3600000).toJson()['t'], 3600000);
    });
    test('timing begins zero, monotonic and bounded', () {
      expect(
        () => Stroke(0, [StrokePoint(0, 0, 1), StrokePoint(1, 1, 2)]),
        throwsArgumentError,
      );
      expect(
        () => Stroke(0, [
          StrokePoint(0, 0, 0),
          StrokePoint(.5, .5, 10),
          StrokePoint(1, 1, 9),
        ]),
        throwsArgumentError,
      );
      expect(
        () => Stroke(64, [StrokePoint(0, 0, 0), StrokePoint(1, 1, 1)]),
        throwsArgumentError,
      );
      expect(() => Stroke(0, [StrokePoint(0, 0, 0)]), throwsArgumentError);
      expect(
        () => Stroke(0, List.generate(4097, (i) => StrokePoint(0, 0, i))),
        throwsArgumentError,
      );
    });
    test('attempt identity/count/index boundaries', () {
      expect(
        () => KanjiAttempt('invalid', cross().strokes),
        throwsArgumentError,
      );
      expect(() => KanjiAttempt(id, []), throwsArgumentError);
      expect(
        () => KanjiAttempt(id, [line(1, 0, 0, 1, 1)]),
        throwsArgumentError,
      );
      expect(
        () => KanjiAttempt(id, [line(0, 0, 0, 1, 1), line(0, 0, 0, 1, 1)]),
        throwsArgumentError,
      );
    });
    test('collections are defensive snapshots and immutable', () {
      final points = [StrokePoint(0, 0, 0), StrokePoint(1, 1, 1)];
      final stroke = Stroke(0, points);
      points.clear();
      final strokes = [stroke];
      final attempt = KanjiAttempt(id, strokes);
      strokes.clear();
      expect(attempt.strokes.single.points.length, 2);
      expect(() => stroke.points.clear(), throwsUnsupportedError);
      expect(() => attempt.strokes.clear(), throwsUnsupportedError);
    });
  });
  group('capture', () {
    test('square normalization, boundary clamp and relative time', () {
      final c = StrokeCapture();
      c.begin(1, 20, 50, 100, 1000);
      c.move(1, -10, 110, 100, 1010);
      c.end(1, 80, 50, 100, 1030);
      expect(c.strokes.single.points.map((p) => p.t), [0, 10, 30]);
      expect(c.strokes.single.points[1].toJson(), {
        'x': 0.0,
        'y': 1.0,
        't': 10,
      });
    });
    test('secondary pointer events cannot mutate primary stroke', () {
      final c = StrokeCapture();
      c.begin(1, 20, 50, 100, 0);
      expect(c.begin(2, 40, 40, 100, 0), isFalse);
      expect(c.move(2, 80, 50, 100, 10), isFalse);
      expect(c.end(2, 80, 50, 100, 10), isFalse);
      c.cancel(2);
      expect(c.isDrawing, isTrue);
      c.end(1, 80, 50, 100, 20);
      expect(c.strokes.length, 1);
    });
    test('tap/cancel do not invent duplicate endpoints', () {
      final c = StrokeCapture();
      c.begin(1, 20, 50, 100, 0);
      expect(c.end(1, 20, 50, 100, 1), isFalse);
      expect(c.strokes, isEmpty);
      c.begin(2, 20, 50, 100, 5);
      c.move(2, 80, 50, 100, 6);
      c.cancel(2);
      expect(c.strokes, isEmpty);
      expect(c.active, isEmpty);
    });
    test('undo/clear cancel in-flight stroke and reindex next capture', () {
      final c = StrokeCapture();
      draw(c);
      draw(c);
      c.undo();
      draw(c);
      expect(c.strokes.map((s) => s.index), [0, 1]);
      c.begin(9, 10, 10, 100, 500);
      c.clear();
      expect(c.end(9, 30, 30, 100, 510), isFalse);
      draw(c);
      expect(c.strokes.single.index, 0);
    });
    test(
      'resize, clock reversal and duration overflow abort active stroke',
      () {
        for (final args in [
          (side: 99.0, t: 110),
          (side: 100.0, t: 99),
          (side: 100.0, t: 3600101),
        ]) {
          final c = StrokeCapture();
          c.begin(1, 20, 50, 100, 100);
          expect(c.end(1, 80, 50, args.side, args.t), isFalse);
          expect(c.strokes, isEmpty);
          expect(c.isDrawing, isFalse);
          expect(c.messageVi, isNotNull);
        }
      },
    );
    test('invalid start and nonfinite moves', () {
      final c = StrokeCapture();
      expect(c.begin(1, -1, 50, 100, 0), isFalse);
      expect(c.begin(1, 0, 0, 0, 0), isFalse);
      c.begin(1, 0, 0, 100, 0);
      c.move(1, double.nan, 0, 100, 10);
      expect(c.isDrawing, isFalse);
    });
    test('4096-point overflow aborts rather than silently truncates', () {
      final c = StrokeCapture();
      c.begin(1, 0, 0, 100, 0);
      for (var i = 1; i < 4096; i++) {
        expect(c.move(1, i.isOdd ? 50 : 0, 0, 100, i), isTrue);
      }
      expect(c.active.length, 4096);
      expect(c.move(1, 0, 50, 100, 4096), isFalse);
      expect(c.strokes, isEmpty);
      expect(c.active, isEmpty);
    });
    test('64 stroke limit and undo recovery', () {
      final c = StrokeCapture();
      for (var i = 0; i < 64; i++) {
        draw(c);
      }
      expect(c.begin(1, 20, 50, 100, 0), isFalse);
      expect(c.strokes.length, 64);
      c.undo();
      draw(c);
      expect(c.strokes.last.index, 63);
    });
    test('previous snapshots and JSON remain unchanged after later events', () {
      final c = StrokeCapture();
      draw(c);
      final snapshot = c.strokes;
      final json = KanjiAttempt(id, snapshot).toJson();
      c.clear();
      expect(snapshot.length, 1);
      expect((json['strokes']! as List).length, 1);
    });
  });
  group('synthetic-only scoring', () {
    const scorer = SyntheticScorer();
    test('identical geometry scores 100, deterministic', () {
      final a = cross();
      final scores = scorer.scoreSynthetic(a, cross());
      expect(scores.total, closeTo(100, 1e-8));
      expect(scorer.scoreSynthetic(a, cross()).total, scores.total);
    });
    test('reverse keeps shape but lowers direction', () {
      final a = KanjiAttempt(id, [
        line(0, .8, .5, .2, .5),
        line(1, .5, .8, .5, .2),
      ]);
      final s = scorer.scoreSynthetic(a, cross());
      expect(s.shape, closeTo(100, 1e-8));
      expect(s.order, 100);
      expect(s.direction, closeTo(0, 1e-8));
    });
    test('swapping distinct strokes keeps geometry but lowers order', () {
      final s = scorer.scoreSynthetic(
        KanjiAttempt(id, [line(0, .5, .2, .5, .8), line(1, .2, .5, .8, .5)]),
        cross(),
      );
      expect(s.shape, closeTo(100, 1e-8));
      expect(s.direction, closeTo(100, 1e-8));
      expect(s.order, 0);
    });
    test('translation/scale preserve shape but lower canvas balance', () {
      final s = scorer.scoreSynthetic(
        KanjiAttempt(id, [line(0, .1, .3, .5, .3), line(1, .3, .1, .3, .5)]),
        cross(),
      );
      expect(s.shape, closeTo(100, 1e-8));
      expect(s.balance, lessThan(100));
    });
    test('sampling density and stationary duplicate points preserve shape', () {
      final a = KanjiAttempt(id, [
        Stroke(0, [
          StrokePoint(.2, .5, 0),
          StrokePoint(.2, .5, 1),
          StrokePoint(.3, .5, 2),
          StrokePoint(.8, .5, 10),
        ]),
        cross().strokes[1],
      ]);
      expect(scorer.scoreSynthetic(a, cross()).total, closeTo(100, 1e-8));
    });
    test('missing/extra strokes lower scores and remain finite/bounded', () {
      for (final a in [
        KanjiAttempt(id, [cross().strokes.first]),
        KanjiAttempt(id, [...cross().strokes, line(2, .1, .1, .9, .9)]),
      ]) {
        final s = scorer.scoreSynthetic(a, cross());
        expect(s.total, lessThan(100));
        for (final v in [s.total, s.shape, s.order, s.direction, s.balance]) {
          expect(v.isFinite, isTrue);
          expect(v, inInclusiveRange(0, 100));
        }
      }
    });
    test('degenerate/foreign identity rejected and real grade unavailable', () {
      expect(
        () => scorer.scoreSynthetic(
          KanjiAttempt(id, [line(0, .5, .5, .5, .5)]),
          cross(),
        ),
        throwsArgumentError,
      );
      expect(
        () => scorer.scoreSynthetic(
          KanjiAttempt('00000000-0000-4000-8000-000000000007', cross().strokes),
          cross(),
        ),
        throwsArgumentError,
      );
      expect(
        () => scorer.evaluateReal(cross()),
        throwsA(isA<ReferenceUnavailable>()),
      );
    });
  });
}
