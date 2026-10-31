import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/captured_conversation_scenarios.dart';
import '../data/ai_conversation_scenario_source.dart';
import '../../auth/application/account_provider.dart';

/// Trusted host input for one captured ready generation. Acquisition itself must
/// issue no request. Replace this object after every readiness barrier; never
/// mutate it to point at a new account. The runtime still owns transport cleanup.
final class AiConversationScenarioBinding {
  const AiConversationScenarioBinding({
    required this.reader,
    this.availabilityChanges,
  });
  final CapturedConversationScenarios reader;
  final Stream<void>? availabilityChanges;
}

/// No default service/provider/SDK activation. A reviewed host may supply a
/// binding from its owned ready factory; account and owner events refresh it.
final aiConversationScenarioSourceProvider =
    Provider<AiConversationScenarioSource?>((ref) => null);

final aiConversationScenarioBindingProvider =
    Provider<AiConversationScenarioBinding?>(
      (ref) => ref.watch(_aiConversationScenarioBindingStateProvider),
    );

final _aiConversationScenarioBindingStateProvider =
    StateNotifierProvider<
      AiConversationScenarioBindingNotifier,
      AiConversationScenarioBinding?
    >((ref) {
      // The runtime may become ready before it has ever allocated an AI lease;
      // account readiness must therefore trigger acquisition independently of AI events.
      ref.watch(accountStateProvider);
      return AiConversationScenarioBindingNotifier(
        ref.watch(aiConversationScenarioSourceProvider),
      );
    });

final class AiConversationScenarioBindingNotifier
    extends StateNotifier<AiConversationScenarioBinding?> {
  AiConversationScenarioBindingNotifier(this._source) : super(null) {
    try {
      _availability = _source?.aiConversationScenarioChanges;
      _subscription = _availability?.listen(
        (_) => _sync(),
        onError: (Object _, StackTrace _) => _disable(),
        onDone: _disable,
      );
      _sync();
    } on Object {
      _disable();
    }
  }
  final AiConversationScenarioSource? _source;
  StreamSubscription<void>? _subscription;
  Stream<void>? _availability;
  bool _closed = false;
  bool _failed = false;
  bool _syncing = false;

  void _sync() {
    if (_closed || _failed || _syncing) return;
    _syncing = true;
    try {
      final reader = _source?.createAiConversationScenarios();
      final current = reader?.isCurrent == true;
      if (_closed || _failed) return;
      if (reader == null || !current) {
        state = null;
      } else if (!identical(state?.reader, reader)) {
        state = AiConversationScenarioBinding(
          reader: reader,
          availabilityChanges: _availability,
        );
      }
    } on Object {
      if (!_closed) {
        state = null; // Fixed unavailable state, no raw source error.
      }
    } finally {
      _syncing = false;
    }
  }

  void _disable() {
    if (_closed) return;
    _failed = true;
    state = null;
  }

  Future<void> _cancelSubscription() async {
    try {
      await _subscription?.cancel();
    } on Object {
      // Cancellation is a borrowed stream hint, never a safe learner error.
    }
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_cancelSubscription());
    super.dispose(); // Source/reader/runtime remain borrowed.
  }
}
