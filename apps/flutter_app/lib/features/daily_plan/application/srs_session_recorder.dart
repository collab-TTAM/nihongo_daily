import 'dart:async';
import 'dart:math';
import '../data/daily_plan_repository.dart';
import '../data/durable_study_session_repository.dart';
import '../domain/completed_study_session.dart';
import '../domain/daily_plan.dart';

abstract interface class StudyRecorderClock {
  DateTime now();
  int get elapsedMs;
  String eventId();
}

final class SystemStudyRecorderClock implements StudyRecorderClock {
  final _watch = Stopwatch()..start();
  @override
  DateTime now() => DateTime.now().toUtc();
  @override
  int get elapsedMs => _watch.elapsedMilliseconds;
  @override
  String eventId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

enum StudyRecorderPhase {
  idle,
  checking,
  running,
  saving,
  uncertain,
  confirmed,
  rejected,
  recoveryRequired,
  canceled,
  unavailable,
}

final class StudyRecorderState {
  const StudyRecorderState(this.phase, {this.message, this.acknowledgment});
  final StudyRecorderPhase phase;
  final String? message;
  final StudySessionAcknowledgment? acknowledgment;
  bool get busy =>
      phase == StudyRecorderPhase.checking ||
      phase == StudyRecorderPhase.saving;
  bool get canStart => const {
    StudyRecorderPhase.idle,
    StudyRecorderPhase.canceled,
    StudyRecorderPhase.confirmed,
    StudyRecorderPhase.rejected,
    StudyRecorderPhase.recoveryRequired,
  }.contains(phase);
}

/// A foreground SRS interval, not evidence of attention/mastery. Only explicit
/// finish dispatches. Owner replacement disposes this captured controller;
/// unfinished timing is canceled on route/background loss by the host widget.
final class SrsSessionRecorder {
  SrsSessionRecorder({
    required this.service,
    required this.clock,
    required this.canStudy,
  });
  final DurableStudySessionRepository service;
  final StudyRecorderClock clock;
  final bool Function() canStudy;
  final _changes = StreamController<StudyRecorderState>.broadcast();
  Stream<StudyRecorderState> get changes => _changes.stream;
  StudyRecorderState _state = const StudyRecorderState(StudyRecorderPhase.idle);
  StudyRecorderState get state => _state;
  int _generation = 0;
  bool _disposed = false;
  DateTime? _startedAt;
  int? _startedTick;
  DailyPlanDate? _date;
  CompletedStudySession? _event;
  Future<void>? _saving;
  Duration get elapsed {
    try {
      final tick = _startedTick;
      return Duration(
        milliseconds: tick == null ? 0 : max(0, clock.elapsedMs - tick),
      );
    } on Object {
      return Duration.zero;
    }
  }

  bool _current(int generation) =>
      !_disposed && generation == _generation && service.delegate.isCurrent;
  bool _ready() {
    try {
      return canStudy();
    } on Object {
      return false;
    }
  }

  void _publish(StudyRecorderState value) {
    if (_disposed) return;
    _state = value;
    _changes.add(value);
  }

  void _revoke(int generation) {
    if (_disposed || generation != _generation) return;
    _generation++;
    _clearTiming();
    _event = null;
    _publish(const StudyRecorderState(StudyRecorderPhase.unavailable));
  }

  void _clearTiming() {
    _startedAt = null;
    _startedTick = null;
    _date = null;
  }

  Future<void> start(DailyPlanDate date) async {
    if (_disposed || !_state.canStart) return;
    final generation = ++_generation;
    if (!_current(generation)) {
      _revoke(generation);
      return;
    }
    if (!_ready()) {
      _publish(
        const StudyRecorderState(
          StudyRecorderPhase.canceled,
          message: 'Cần thẻ ôn sẵn sàng đúng trình độ hồ sơ để bắt đầu.',
        ),
      );
      return;
    }
    _event = null;
    _publish(const StudyRecorderState(StudyRecorderPhase.checking));
    try {
      final pending = await service.recoverPending();
      if (!_current(generation)) {
        _revoke(generation);
        return;
      }
      if (pending.isNotEmpty) {
        _publish(
          const StudyRecorderState(
            StudyRecorderPhase.recoveryRequired,
            message: 'Hãy xử lý buổi học còn chờ trước khi bắt đầu buổi mới.',
          ),
        );
        return;
      }
      final plan = await service.delegate.load(date);
      if (!_current(generation)) {
        _revoke(generation);
        return;
      }
      if (!_ready()) {
        _publish(
          const StudyRecorderState(
            StudyRecorderPhase.canceled,
            message:
                'Danh sách ôn đã thay đổi. Hãy kiểm tra lại trước khi bắt đầu.',
          ),
        );
        return;
      }
      final block = plan.blocks.singleWhere((b) => b.area == DailyPlanArea.srs);
      if (block.status == DailyPlanStatus.blocked || block.itemCount == 0) {
        _publish(
          const StudyRecorderState(
            StudyRecorderPhase.canceled,
            message: 'Kế hoạch ngày này chưa có phần ôn SRS khả dụng.',
          ),
        );
        return;
      }
      final instant = clock.now().toUtc();
      if (instant.year < 1 || instant.year > 9999) {
        throw const FormatException();
      }
      final tick = clock.elapsedMs;
      if (tick < 0) throw const FormatException();
      _startedAt = instant;
      _startedTick = tick;
      _date = date;
      _publish(const StudyRecorderState(StudyRecorderPhase.running));
    } on DailyPlanFailure catch (failure) {
      if (!_current(generation)) {
        _revoke(generation);
        return;
      }
      _publish(
        StudyRecorderState(
          StudyRecorderPhase.canceled,
          message: failure.messageVi,
        ),
      );
    } on StudySessionStorageFailure catch (failure) {
      if (!_current(generation)) {
        _revoke(generation);
        return;
      }
      _publish(
        StudyRecorderState(
          StudyRecorderPhase.canceled,
          message: failure.toString(),
        ),
      );
    } on Object {
      if (!_current(generation)) {
        _revoke(generation);
        return;
      }
      _publish(
        const StudyRecorderState(
          StudyRecorderPhase.canceled,
          message: 'Chưa thể bắt đầu bộ đếm. Vui lòng thử lại.',
        ),
      );
    }
  }

  Future<void> finish() {
    if (_disposed || _state.phase != StudyRecorderPhase.running) {
      return _saving ?? Future.value();
    }
    final generation = _generation;
    if (!_current(generation)) {
      _revoke(generation);
      return Future.value();
    }
    try {
      final duration = Duration(milliseconds: clock.elapsedMs - _startedTick!);
      if (duration < const Duration(minutes: 1) ||
          duration > const Duration(hours: 25)) {
        _clearTiming();
        _publish(
          const StudyRecorderState(
            StudyRecorderPhase.canceled,
            message:
                'Chỉ lưu buổi học từ 1 phút đến 25 giờ. Buổi này chưa được lưu.',
          ),
        );
        return Future.value();
      }
      final end = _startedAt!.add(duration);
      if (clock.now().toUtc().difference(end).abs() >
          const Duration(seconds: 5)) {
        _clearTiming();
        _publish(
          const StudyRecorderState(
            StudyRecorderPhase.canceled,
            message: 'Đồng hồ thiết bị đã thay đổi. Buổi này chưa được lưu.',
          ),
        );
        return Future.value();
      }
      _event = CompletedStudySession(
        clientEventId: clock.eventId(),
        date: _date!,
        area: DailyPlanArea.srs,
        startedAt: _startedAt!,
        endedAt: end,
      );
      _clearTiming();
      return _save();
    } on Object {
      _clearTiming();
      _publish(
        const StudyRecorderState(
          StudyRecorderPhase.canceled,
          message: 'Chưa thể tạo buổi học. Buổi này chưa được lưu.',
        ),
      );
      return Future.value();
    }
  }

  Future<void> retry() =>
      !_disposed && _state.phase == StudyRecorderPhase.uncertain
      ? _save()
      : (_saving ?? Future.value());
  Future<void> _save() {
    if (_saving != null) return _saving!;
    final operation = _runSave();
    _saving = operation;
    operation.then<void>((_) {
      if (identical(_saving, operation)) _saving = null;
    });
    return operation;
  }

  Future<void> _runSave() async {
    final generation = _generation;
    final event = _event;
    if (event == null) return;
    if (!_current(generation)) {
      _revoke(generation);
      return;
    }
    _publish(const StudyRecorderState(StudyRecorderPhase.saving));
    try {
      final ack = await service.submit(event);
      if (!_current(generation)) {
        _revoke(generation);
        return;
      }
      _event = null;
      _publish(
        StudyRecorderState(StudyRecorderPhase.confirmed, acknowledgment: ack),
      );
    } on DailyPlanFailure catch (failure) {
      if (!_current(generation)) {
        _revoke(generation);
        return;
      }
      final definitive = isDefinitiveStudyRejection(failure);
      if (definitive) _event = null;
      _publish(
        StudyRecorderState(
          definitive
              ? StudyRecorderPhase.rejected
              : StudyRecorderPhase.uncertain,
          message: definitive
              ? 'Buổi học không được chấp nhận. ${failure.messageVi}'
              : 'Chưa xác nhận được kết quả đồng bộ. ${failure.messageVi}',
        ),
      );
    } on StudySessionStorageFailure catch (failure) {
      if (!_current(generation)) {
        _revoke(generation);
        return;
      }
      _publish(
        StudyRecorderState(
          StudyRecorderPhase.uncertain,
          message:
              '${failure.toString()} Hãy thử lại cùng buổi học trước khi rời ứng dụng.',
        ),
      );
    } on Object {
      if (!_current(generation)) {
        _revoke(generation);
        return;
      }
      _publish(
        const StudyRecorderState(
          StudyRecorderPhase.uncertain,
          message:
              'Chưa xác nhận được kết quả đồng bộ. Hãy thử lại cùng buổi học.',
        ),
      );
    }
  }

  void interrupt() {
    if (_disposed ||
        !const {
          StudyRecorderPhase.running,
          StudyRecorderPhase.checking,
        }.contains(_state.phase)) {
      return;
    }
    _generation++;
    _clearTiming();
    _publish(
      const StudyRecorderState(
        StudyRecorderPhase.canceled,
        message: 'Bộ đếm đã hủy khi rời phần học. Chưa tạo buổi học để lưu.',
      ),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _clearTiming();
    _event = null;
    unawaited(_changes.close());
  }
}
