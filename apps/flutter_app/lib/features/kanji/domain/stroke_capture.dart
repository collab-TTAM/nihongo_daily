import 'kanji_models.dart';

/// Pure single-pointer state machine. The caller supplies monotonic milliseconds.
/// No wall clock, platform, persistence or Flutter dependency.
class StrokeCapture {
  final List<Stroke> _strokes = [];
  List<StrokePoint> _active = [];
  int? _pointer;
  int _startedAt = 0;
  int _lastEventAt = 0;
  double _side = 0;
  String? messageVi;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  List<StrokePoint> get active => List.unmodifiable(_active);
  bool get isDrawing => _pointer != null;

  bool begin(int pointer, double x, double y, double side, int timestampMs) {
    if (isDrawing) return false;
    messageVi = null;
    if (_strokes.length >= 64) {
      messageVi = 'Đã đạt giới hạn 64 nét. Hãy hoàn tác hoặc xóa.';
      return false;
    }
    if (!side.isFinite ||
        side <= 0 ||
        timestampMs < 0 ||
        !x.isFinite ||
        !y.isFinite ||
        x < 0 ||
        y < 0 ||
        x > side ||
        y > side) {
      return false;
    }
    _pointer = pointer;
    _startedAt = timestampMs;
    _lastEventAt = timestampMs;
    _side = side;
    _active = [StrokePoint(x / side, y / side, 0)];
    return true;
  }

  bool move(int pointer, double x, double y, double side, int timestampMs) {
    if (_pointer != pointer) return false;
    final elapsed = timestampMs - _startedAt;
    if (side != _side ||
        !x.isFinite ||
        !y.isFinite ||
        timestampMs < _lastEventAt ||
        elapsed > 3600000) {
      cancel(pointer);
      messageVi = 'Nét bị hủy do kích thước hoặc thời gian không hợp lệ.';
      return false;
    }
    final px = (x / side).clamp(0.0, 1.0);
    final py = (y / side).clamp(0.0, 1.0);
    _lastEventAt = timestampMs;
    // Stationary events add no geometry; retain the final elapsed time on end.
    if (_active.last.x == px && _active.last.y == py) return true;
    if (_active.length >= 4096) {
      cancel(pointer);
      messageVi = 'Nét vượt giới hạn 4096 điểm và đã bị hủy.';
      return false;
    }
    _active.add(StrokePoint(px, py, elapsed));
    return true;
  }

  bool end(int pointer, double x, double y, double side, int timestampMs) {
    if (_pointer != pointer || !move(pointer, x, y, side, timestampMs)) {
      return false;
    }
    if (_active.length < 2) {
      cancel(pointer);
      messageVi = 'Hãy kéo để tạo một nét; chạm một điểm chưa tạo nét.';
      return false;
    }
    final last = _active.last;
    _active[_active.length - 1] = StrokePoint(
      last.x,
      last.y,
      timestampMs - _startedAt,
    );
    _strokes.add(Stroke(_strokes.length, _active));
    _active = [];
    _pointer = null;
    return true;
  }

  void cancel(int pointer) {
    if (_pointer != pointer) return;
    _active = [];
    _pointer = null;
  }

  void undo() {
    _active = [];
    _pointer = null;
    if (_strokes.isNotEmpty) _strokes.removeLast();
    messageVi = null;
  }

  void clear() {
    _strokes.clear();
    _active = [];
    _pointer = null;
    messageVi = null;
  }
}
