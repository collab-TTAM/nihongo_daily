// Pure-Dart entry point also runs when the local Flutter package is unavailable.
import 'dart:convert';
import 'dart:io';

import 'package:nihongo_daily/features/kanji/domain/kanji_models.dart';
import 'package:nihongo_daily/features/kanji/domain/stroke_capture.dart';
import 'package:nihongo_daily/features/kanji/domain/synthetic_scorer.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) throw ArgumentError('Expected output path');
  const id = '00000000-0000-4000-8000-000000000006';
  final capture = StrokeCapture();
  capture.begin(1, 20, 50, 100, 1000);
  capture.move(1, 50, 50, 100, 1010);
  capture.end(1, 80, 50, 100, 1020);
  capture.begin(2, 50, 20, 100, 2000);
  capture.end(2, 50, 80, 100, 2020);
  final a = KanjiAttempt(id, capture.strokes);
  final scores = const SyntheticScorer().scoreSynthetic(a, a);
  if ((scores.total - 100).abs() > 1e-8) {
    throw StateError('Identical synthetic geometry must score 100');
  }
  final reversed = KanjiAttempt(id, [
    for (final s in a.strokes)
      Stroke(s.index, [
        for (var i = 0; i < s.points.length; i++)
          StrokePoint(
            s.points[s.points.length - 1 - i].x,
            s.points[s.points.length - 1 - i].y,
            i,
          ),
      ]),
  ]);
  final reverseScores = const SyntheticScorer().scoreSynthetic(reversed, a);
  if (reverseScores.direction > 1e-8 ||
      (reverseScores.shape - 100).abs() > 1e-8) {
    throw StateError('Reversing synthetic lines must lower direction only');
  }
  final output = File(arguments.single)..parent.createSync(recursive: true);
  output.writeAsStringSync(
    jsonEncode({
      'algorithm': SyntheticScorer.version,
      'requests': [a.toJson(), reversed.toJson()],
    }),
  );
  stdout.writeln(
    'Emitted 2 actual Dart Kanji requests; synthetic identity/reversal checks passed',
  );
}
