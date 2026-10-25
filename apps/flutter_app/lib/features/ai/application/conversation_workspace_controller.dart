import 'dart:async';

import '../data/captured_ai_text_repository.dart';
import '../data/captured_conversation_scenarios.dart';
import '../data/captured_conversation_session.dart';
import '../domain/ai_text_models.dart';
import '../domain/conversation_requests.dart';
import 'ai_conversation_controller.dart';
import 'conversation_scenario_controller.dart';

/// Ephemeral UI composition, never receipt recovery or permission for a new round.
final class ConversationWorkspaceState {
  const ConversationWorkspaceState._({
    this.scenarios,
    this.conversation,
    this.failure,
    this.canChoose = false,
    this.canLoad = false,
    this.canStart = false,
    this.canTurn = false,
    this.canFinish = false,
    this.canRetry = false,
  });
  final ConversationScenarioState? scenarios;
  final AiConversationState? conversation;
  final AiTextFailure? failure;
  final bool canChoose, canLoad, canStart, canTurn, canFinish, canRetry;
  bool get isAvailable => scenarios != null && conversation != null;
}

/// Trusted host must supply the reader and retained flow from the SAME ready
/// runtime generation. Owns only two view controllers and their subscriptions.
/// Event factory is host configuration, not learner input; absent disables writes.
/// Neither remount nor disposal resets the borrowed flow's receipts/projection.
final class ConversationWorkspaceController {
  ConversationWorkspaceController({
    CapturedConversationScenarios? reader,
    CapturedConversationSession? session,
    Stream<void>? availabilityChanges,
    String Function()? createEventId,
  }) : _scenarios = ConversationScenarioController(
         reader: reader,
         availabilityChanges: availabilityChanges,
       ),
       _conversation = AiConversationController(
         session: session,
         availabilityChanges: availabilityChanges,
       ),
       _createEventId = createEventId,
       _reader = reader,
       _session = session {
    _subscriptions.add(_scenarios.changes.listen((_) => _changed()));
    _subscriptions.add(_conversation.changes.listen((_) => _changed()));
    _read();
  }
  final CapturedConversationScenarios? _reader;
  final CapturedConversationSession? _session;
  final ConversationScenarioController _scenarios;
  final AiConversationController _conversation;
  final String Function()? _createEventId;
  final _changes = StreamController<void>.broadcast();
  late final Stream<void> changes = _changes.stream;
  final _subscriptions = <StreamSubscription<void>>[];
  bool _reading = false, _acting = false, _revoked = false, _disposed = false;
  AiTextFailure? _failure;

  _View? _read() {
    if (_reading ||
        _revoked ||
        _reader?.isCheckingAvailability == true ||
        _session?.isCheckingAvailability == true) {
      return null;
    }
    _reading = true; // Before borrowed readiness getters can reenter commands.
    try {
      final scenarios = _scenarios.state;
      final conversation = _conversation.state;
      if (scenarios.phase == ScenarioLoadPhase.unavailable ||
          conversation.phase == AiConversationPhase.unavailable) {
        invalidate();
        return null;
      }
      final canStart = _conversation.canStart;
      final canTurn = _conversation.canTurn;
      final canFinish = _conversation.canFinish;
      final canRetry = _conversation.canRetry;
      // Capability getters themselves call supplied readiness code. Re-read
      // projections afterward so a loss discovered there cannot publish old text.
      final latestScenarios = _scenarios.state;
      final latestConversation = _conversation.state;
      if (_revoked ||
          latestScenarios.phase == ScenarioLoadPhase.unavailable ||
          latestConversation.phase == AiConversationPhase.unavailable) {
        invalidate();
        return null;
      }
      return _View(
        latestScenarios,
        latestConversation,
        canStart,
        canTurn,
        canFinish,
        canRetry,
      );
    } on Object {
      invalidate();
      return null;
    } finally {
      _reading = false;
    }
  }

  ConversationWorkspaceState get state {
    final view = _read();
    if (view == null) return const ConversationWorkspaceState._();
    final idle = !_acting;
    final writable = idle && _createEventId != null;
    final choose = idle && view.canStart && view.scenarios.canLoad;
    return ConversationWorkspaceState._(
      scenarios: view.scenarios,
      conversation: view.conversation,
      failure: _failure,
      canChoose: choose,
      canLoad: choose,
      canStart: writable && choose && view.scenarios.selected != null,
      canTurn: writable && view.canTurn && view.scenarios.canLoad,
      canFinish: writable && view.canFinish && view.scenarios.canLoad,
      // Original pending DTO already has an event; factory is not required.
      canRetry: idle && view.canRetry && view.scenarios.canLoad,
    );
  }

  bool chooseLevel(AiTextLevel level) =>
      _choose(() => _scenarios.chooseLevel(level));

  bool select(ConversationScenario row) =>
      _choose(() => _scenarios.select(row));

  bool _choose(bool Function() change) {
    if (_acting || _reading || _revoked) return false;
    _acting = true;
    try {
      final view = _read();
      if (view == null || !view.canStart || !view.scenarios.canLoad) {
        return false;
      }
      _reading = true;
      final accepted = change();
      return !_revoked && accepted;
    } finally {
      _reading = false;
      _acting = false;
      _notify();
    }
  }

  Future<void> loadScenarios() =>
      _run((v) => v.canStart && v.scenarios.canLoad, (_) => _scenarios.load());

  Future<void> startSelected() => _run(
    (v) =>
        _createEventId != null &&
        v.canStart &&
        v.scenarios.canLoad &&
        v.scenarios.selected != null,
    (before) async {
      final selected = before.scenarios.selected!;
      final event =
          _createEventId!(); // Once, after reserving the command slot.
      final current = _read();
      if (current == null ||
          !current.canStart ||
          !current.scenarios.canLoad ||
          !identical(current.scenarios.selected, selected)) {
        return;
      }
      await _conversation.start(
        scenarioId: selected.id,
        level: selected.level,
        clientEventId: event,
      );
    },
  );

  Future<void> turn(
    String textJa,
  ) => _run((v) => _createEventId != null && v.canTurn && v.scenarios.canLoad, (
    before,
  ) async {
    final sessionId = before.conversation.conversation!.sessionId!;
    // Validate text before requesting an ID. Preserve exact Unicode/whitespace.
    ConversationTurnRequest(
      sessionId: sessionId,
      clientEventId: '00000000-0000-0000-0000-000000000000',
      textJa: textJa,
    );
    final event = _createEventId!();
    final current = _read();
    if (current == null ||
        !current.canTurn ||
        !current.scenarios.canLoad ||
        current.conversation.conversation!.sessionId != sessionId) {
      return;
    }
    await _conversation.turn(textJa: textJa, clientEventId: event);
  });

  Future<void> finish() => _run(
    (v) => _createEventId != null && v.canFinish && v.scenarios.canLoad,
    (before) async {
      final sessionId = before.conversation.conversation!.sessionId!;
      final event = _createEventId!();
      final current = _read();
      if (current == null ||
          !current.canFinish ||
          !current.scenarios.canLoad ||
          current.conversation.conversation!.sessionId != sessionId) {
        return;
      }
      await _conversation.finish(clientEventId: event);
    },
  );

  /// Manual original-command replay only, never generates a replacement event.
  Future<void> retryPending() => _run(
    (v) => v.canRetry && v.scenarios.canLoad,
    (_) => _conversation.retryPending(),
  );

  Future<void> _run(
    bool Function(_View) allowed,
    Future<void> Function(_View) command,
  ) async {
    if (_acting || _reading || _revoked) return;
    _acting = true;
    try {
      final view = _read();
      if (view == null || !allowed(view)) return;
      _failure = null;
      _notify();
      await command(view);
    } on FormatException {
      if (_read() != null) {
        _failure = const AiTextFailure(AiTextErrorCode.validationFailure);
      }
    } on Object {
      if (_read() != null) {
        _failure = const AiTextFailure(AiTextErrorCode.internalError);
      }
    } finally {
      _acting = false;
      _read();
      _notify();
    }
  }

  /// Only a hint/repaint; no polling, event generation, retry or reset.
  void recheck() {
    _read();
    _notify();
  }

  void _changed() {
    _read();
    _notify();
  }

  void invalidate() {
    if (_revoked) return;
    _revoked = true;
    _failure = null;
    _scenarios.invalidate();
    _conversation.invalidate();
    _notify();
  }

  void _notify() {
    if (!_disposed && !_changes.isClosed) _changes.add(null);
  }

  void dispose() {
    if (_disposed) return;
    invalidate();
    _disposed = true;
    _scenarios.dispose();
    _conversation.dispose();
    for (final subscription in _subscriptions) {
      unawaited(_cancel(subscription));
    }
    unawaited(_changes.close());
  }

  Future<void> _cancel(StreamSubscription<void> subscription) async {
    try {
      await subscription.cancel();
    } on Object {
      // Cancellation detail is never learner data.
    }
  }
}

final class _View {
  const _View(
    this.scenarios,
    this.conversation,
    this.canStart,
    this.canTurn,
    this.canFinish,
    this.canRetry,
  );
  final ConversationScenarioState scenarios;
  final AiConversationState conversation;
  final bool canStart, canTurn, canFinish, canRetry;
}
