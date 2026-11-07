import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/captured_conversation_session.dart';
import '../data/ai_conversation_source.dart';
import '../../auth/application/account_provider.dart';

/// Trusted host input for one captured ready generation. Acquisition itself must
/// issue no request. Replace this object after every readiness barrier; never
/// mutate it to point at a new account. The runtime still owns transport cleanup.
final class AiConversationViewBinding {
  const AiConversationViewBinding({
    required this.session,
    this.availabilityChanges,
  });
  final CapturedConversationSession session;
  final Stream<void>? availabilityChanges;
}

/// No default service/provider/SDK activation. A reviewed host may supply a
/// binding from its owned ready factory; account and owner events refresh it.
final aiConversationSourceProvider = Provider<AiConversationSource?>(
  (ref) => null,
);

final aiConversationViewBindingProvider = Provider<AiConversationViewBinding?>(
  (ref) => ref.watch(_aiConversationBindingStateProvider),
);

final _aiConversationBindingStateProvider =
    StateNotifierProvider<
      AiConversationBindingNotifier,
      AiConversationViewBinding?
    >((ref) {
      // The runtime may become ready before it has ever allocated an AI lease;
      // account readiness must therefore trigger acquisition independently of AI events.
      ref.watch(accountStateProvider);
      return AiConversationBindingNotifier(
        ref.watch(aiConversationSourceProvider),
      );
    });

final class AiConversationBindingNotifier
    extends StateNotifier<AiConversationViewBinding?> {
  AiConversationBindingNotifier(this._source) : super(null) {
    try {
      _availability = _source?.aiConversationChanges;
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
  final AiConversationSource? _source;
  StreamSubscription<void>? _subscription;
  Stream<void>? _availability;
  bool _closed = false;
  bool _failed = false;
  bool _syncing = false;

  void _sync() {
    if (_closed || _failed || _syncing) return;
    _syncing = true;
    try {
      final session = _source?.createAiConversationSession();
      final current = session?.isCurrent == true;
      if (_closed || _failed) return;
      if (session == null || !current) {
        state = null;
      } else if (!identical(state?.session, session)) {
        state = AiConversationViewBinding(
          session: session,
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
    super.dispose(); // Source/session/runtime remain borrowed.
  }
}
