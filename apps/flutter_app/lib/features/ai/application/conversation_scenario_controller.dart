import 'dart:async';
import '../data/captured_conversation_scenarios.dart';
import '../data/captured_ai_text_repository.dart';
import '../domain/ai_text_models.dart';

enum ScenarioLoadPhase { unavailable, idle, loading, ready, error }

final class ConversationScenarioState {
  const ConversationScenarioState._(
    this.phase,
    this.level,
    this.rows,
    this.selected,
    this.failure,
    this.canLoad,
  );
  final ScenarioLoadPhase phase;
  final AiTextLevel level;
  final List<ConversationScenario> rows;
  final ConversationScenario? selected;
  final AiTextFailure? failure;
  final bool canLoad;
}

/// Ephemeral read-only selection, not authority to start a conversation.
/// Owns view state/subscription only; never revokes/closes the borrowed reader.
final class ConversationScenarioController {
  ConversationScenarioController({
    CapturedConversationScenarios? reader,
    Stream<void>? availabilityChanges,
  }) : _reader = reader {
    _check();
    if (!_revoked) {
      try {
        _subscription = availabilityChanges?.listen(
          (_) => recheck(),
          onError: (Object _, StackTrace _) => invalidate(),
          onDone: invalidate,
        );
      } on Object {
        invalidate();
      }
    }
  }
  final CapturedConversationScenarios? _reader;
  final _changes = StreamController<void>.broadcast();
  late final Stream<void> changes = _changes.stream;
  StreamSubscription<void>? _subscription;
  var _level = AiTextLevel.n5;
  var _rows = const <ConversationScenario>[];
  ConversationScenario? _selected;
  AiTextFailure? _failure;
  var _phase = ScenarioLoadPhase.idle;
  bool _checking = false, _revoked = false, _loading = false, _disposed = false;
  int _epoch = 0;

  bool _check() {
    if (_checking || _revoked) return false;
    _checking = true;
    try {
      if (_reader?.isCurrent != true) invalidate();
    } on Object {
      invalidate();
    } finally {
      _checking = false;
    }
    return !_revoked;
  }

  ConversationScenarioState get state {
    if (!_check()) {
      return ConversationScenarioState._(
        ScenarioLoadPhase.unavailable,
        _level,
        const [],
        null,
        null,
        false,
      );
    }
    return ConversationScenarioState._(
      _phase,
      _level,
      _rows,
      _selected,
      _failure,
      !_loading && !_reader!.isBusy,
    );
  }

  bool chooseLevel(AiTextLevel level) {
    if (!_check() ||
        _loading ||
        _reader!.isBusy ||
        (level != AiTextLevel.n5 && level != AiTextLevel.n4)) {
      return false;
    }
    if (level != _level) {
      _level = level;
      _epoch++;
      _clear();
      _phase = ScenarioLoadPhase.idle;
      _notify();
    }
    return true;
  }

  bool select(ConversationScenario row) {
    if (!_check() ||
        _loading ||
        _reader!.isBusy ||
        _phase != ScenarioLoadPhase.ready ||
        !_rows.any((item) => identical(item, row))) {
      return false;
    }
    _selected = row;
    _notify();
    return true;
  }

  Future<void> load() async {
    if (!_check() || _loading || _reader!.isBusy) return;
    _loading = true;
    final epoch = ++_epoch;
    final level = _level;
    _clear();
    _phase = ScenarioLoadPhase.loading;
    _notify();
    bool current() => _check() && epoch == _epoch;
    try {
      final result = await _reader.load(level);
      if (!current()) return;
      _rows = result;
      _phase = ScenarioLoadPhase.ready;
    } on AiTextRequestPending {
      if (current()) {
        _phase = ScenarioLoadPhase.idle;
      }
    } on AiTextFailure catch (e) {
      if (e.code == AiTextErrorCode.unauthorized) invalidate();
      if (current()) {
        _failure = e;
        _phase = ScenarioLoadPhase.error;
      }
    } on Object {
      if (current()) {
        _failure = const AiTextFailure(AiTextErrorCode.internalError);
        _phase = ScenarioLoadPhase.error;
      }
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _clear() {
    _rows = const [];
    _selected = null;
    _failure = null;
  }

  void recheck() {
    _check();
    _notify();
  }

  void invalidate() {
    if (_revoked) return;
    _revoked = true;
    _epoch++;
    _clear();
    _phase = ScenarioLoadPhase.unavailable;
    _notify();
  }

  void _notify() {
    if (!_disposed && !_changes.isClosed) _changes.add(null);
  }

  void dispose() {
    if (_disposed) return;
    invalidate();
    _disposed = true;
    unawaited(_cancel());
    unawaited(_changes.close());
  }

  Future<void> _cancel() async {
    try {
      await _subscription?.cancel();
    } on Object {
      /* Safe view cleanup only. */
    }
  }
}
