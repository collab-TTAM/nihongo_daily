import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/preview_level.dart';
import '../data/review_repository.dart';
import '../domain/srs_models.dart';
import 'srs_study_controller.dart';

/// No default fixture/demo runtime. Future #20/#22 binding must supply real
/// authenticated queue/review ports and immediate lifecycle notifications.
final class SrsStudyRuntime {
  const SrsStudyRuntime({
    required this.auth,
    required this.reviews,
    required this.queue,
    required this.sessionChanges,
  });
  final ReviewAuth auth;
  final ReviewRepository reviews;
  final SrsStudyQueue queue;
  final Stream<void> sessionChanges;
}

final srsStudyRuntimeProvider = Provider<SrsStudyRuntime?>((ref) => null);

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
