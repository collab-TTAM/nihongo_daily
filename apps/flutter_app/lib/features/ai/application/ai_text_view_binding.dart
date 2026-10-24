import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/captured_ai_text_repository.dart';
import '../data/ai_text_repository_source.dart';
import '../../auth/application/account_provider.dart';

/// Trusted host input for one captured ready generation. Acquisition itself must
/// issue no request. Replace this object after every readiness barrier; never
/// mutate it to point at a new account. The runtime still owns transport cleanup.
final class AiTextViewBinding {
  const AiTextViewBinding({required this.repository, this.availabilityChanges});
  final CapturedAiTextRepository repository;
  final Stream<void>? availabilityChanges;
}

/// No default service/provider/SDK activation. A reviewed host may supply a
/// binding from its owned ready factory; account and owner events refresh it.
final aiTextRepositorySourceProvider = Provider<AiTextRepositorySource?>(
  (ref) => null,
);

final aiTextViewBindingProvider = Provider<AiTextViewBinding?>(
  (ref) => ref.watch(_aiTextBindingStateProvider),
);

final _aiTextBindingStateProvider =
    StateNotifierProvider<AiTextBindingNotifier, AiTextViewBinding?>((ref) {
      // The runtime may become ready before it has ever allocated an AI lease;
      // account readiness must therefore trigger acquisition independently of AI events.
      ref.watch(accountStateProvider);
      return AiTextBindingNotifier(ref.watch(aiTextRepositorySourceProvider));
    });

final class AiTextBindingNotifier extends StateNotifier<AiTextViewBinding?> {
  AiTextBindingNotifier(this._source) : super(null) {
    try {
      _availability = _source?.aiTextChanges;
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
  final AiTextRepositorySource? _source;
  StreamSubscription<void>? _subscription;
  Stream<void>? _availability;
  bool _closed = false;
  bool _failed = false;
  bool _syncing = false;

  void _sync() {
    if (_closed || _failed || _syncing) return;
    _syncing = true;
    try {
      final repository = _source?.createAiTextRepository();
      final current = repository?.isCurrent == true;
      if (_closed || _failed) return;
      if (repository == null || !current) {
        state = null;
      } else if (!identical(state?.repository, repository)) {
        state = AiTextViewBinding(
          repository: repository,
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

  @override
  void dispose() {
    _closed = true;
    unawaited(_subscription?.cancel());
    super.dispose(); // Source/repository/runtime remain borrowed.
  }
}
