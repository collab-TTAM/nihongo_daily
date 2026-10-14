import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/kanji_models.dart';
import '../domain/stroke_capture.dart';

class CaptureSnapshot {
  CaptureSnapshot(StrokeCapture capture)
    : strokes = capture.strokes,
      active = capture.active,
      messageVi = capture.messageVi;
  final List<Stroke> strokes;
  final List<StrokePoint> active;
  final String? messageVi;
}

class KanjiCaptureController extends StateNotifier<CaptureSnapshot> {
  KanjiCaptureController() : this._(StrokeCapture());
  KanjiCaptureController._(this._capture) : super(CaptureSnapshot(_capture));
  final StrokeCapture _capture;

  void begin(int id, double x, double y, double side, int ms) {
    _capture.begin(id, x, y, side, ms);
    state = CaptureSnapshot(_capture);
  }

  void move(int id, double x, double y, double side, int ms) {
    _capture.move(id, x, y, side, ms);
    state = CaptureSnapshot(_capture);
  }

  void end(int id, double x, double y, double side, int ms) {
    _capture.end(id, x, y, side, ms);
    state = CaptureSnapshot(_capture);
  }

  void cancel(int id) {
    _capture.cancel(id);
    state = CaptureSnapshot(_capture);
  }

  void undo() {
    _capture.undo();
    state = CaptureSnapshot(_capture);
  }

  void clear() {
    _capture.clear();
    state = CaptureSnapshot(_capture);
  }
}

final kanjiCaptureProvider =
    StateNotifierProvider.autoDispose<KanjiCaptureController, CaptureSnapshot>(
      (ref) => KanjiCaptureController(),
    );
