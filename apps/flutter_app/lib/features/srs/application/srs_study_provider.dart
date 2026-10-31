import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/preview_level.dart';
import '../../auth/application/account_provider.dart';
import '../domain/srs_models.dart';
import 'srs_study_controller.dart';
import 'srs_study_runtime.dart';
export 'srs_study_runtime.dart';

final srsStudyRuntimeProvider = Provider<SrsStudyRuntime?>((ref) {
  ref.watch(accountStateProvider);
  return ref.watch(accountRuntimeProvider)?.readyRuntime;
});

// Not autoDispose: uncertain same-event retries survive navigation, not restart.
// Runtime replacement invalidates the old provider/session; #15 owns durability.
final srsStudyProvider = StateNotifierProvider<SrsStudyNotifier, SrsStudyState>(
  (ref) => SrsStudyNotifier(ref.watch(srsStudyRuntimeProvider)),
);

final class SrsStudyNotifier extends StateNotifier<SrsStudyState> {
  SrsStudyNotifier(SrsStudyRuntime? runtime)
    : super(
        SrsStudyState(
          phase: runtime == null
              ? SrsStudyPhase.unavailable
              : SrsStudyPhase.idle,
        ),
      ) {
    if (runtime == null) return;
    _controller = SrsStudyController(
      auth: runtime.auth,
      reviews: runtime.reviews,
      queue: runtime.queue,
    );
    _stateChanges = _controller!.changes.listen((value) => state = value);
    _sessionChanges = runtime.sessionChanges.listen(
      (_) => _controller?.sessionChanged(),
      onError: (Object _, StackTrace __) => _controller?.sessionChanged(),
      onDone: () {
        _controller?.dispose();
        _controller = null;
        state = const SrsStudyState(phase: SrsStudyPhase.unavailable);
      },
    );
  }
  SrsStudyController? _controller;
  StreamSubscription<SrsStudyState>? _stateChanges;
  StreamSubscription<void>? _sessionChanges;
  PreviewLevel? get selectedLevel => _controller?.selectedLevel;
  Future<void> changeLevel(PreviewLevel level) async =>
      _controller?.changeLevel(level);
  Future<void> load(PreviewLevel level) async => _controller?.load(level);
  void reveal() => _controller?.reveal();
  Future<void> rate(ReviewRating rating) async => _controller?.rate(rating);
  Future<void> retry() async => _controller?.retry();
  @override
  void dispose() {
    unawaited(_stateChanges?.cancel());
    unawaited(_sessionChanges?.cancel());
    _controller?.dispose();
    super.dispose();
  }
}
