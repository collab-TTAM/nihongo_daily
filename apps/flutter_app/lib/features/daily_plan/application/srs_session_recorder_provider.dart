import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/preview_level.dart';
import '../../auth/application/account_provider.dart';
import '../../srs/application/srs_study_controller.dart';
import '../../srs/application/srs_study_provider.dart';
import '../domain/daily_plan.dart';
import 'daily_plan_provider.dart';
import 'study_session_recorder.dart';

final studyRecorderClockProvider = Provider<StudyRecorderClock>(
  (ref) => SystemStudyRecorderClock(),
);

final canStartSrsRecorderProvider = Provider<bool>((ref) {
  final study = ref.watch(srsStudyProvider);
  final profile = ref.watch(accountStateProvider).profile;
  return study.phase == SrsStudyPhase.ready &&
      study.item != null &&
      !study.hasPendingEvent &&
      profile != null &&
      ref.read(srsStudyProvider.notifier).selectedLevel?.label == profile.level;
});

// Retain a frozen uncertain report when navigating away. Only unfinished timing
// is canceled by the panel. Account/ready-service replacement disposes the lease.
final studySessionRecorderProvider =
    StateNotifierProvider<StudyRecorderNotifier, StudyRecorderState>((ref) {
      final service = ref.watch(durableStudyRepositoryProvider);
      final clock = ref.watch(studyRecorderClockProvider);
      return StudyRecorderNotifier(
        service == null
            ? null
            : StudySessionRecorder(
                service: service,
                clock: clock,
                // Reader controls are not installed yet. Fail closed for other areas.
                canStudyArea: (area) =>
                    area == DailyPlanArea.srs &&
                    ref.read(canStartSrsRecorderProvider),
              ),
      );
    });

// Compatibility names resolve to the exact same provider/controller, never a
// second activity recorder. New reader hosts will use the shared name.
final srsSessionRecorderProvider = studySessionRecorderProvider;
typedef SrsRecorderNotifier = StudyRecorderNotifier;

final class StudyRecorderNotifier extends StateNotifier<StudyRecorderState> {
  StudyRecorderNotifier(this.controller)
    : super(
        controller?.state ??
            const StudyRecorderState(StudyRecorderPhase.unavailable),
      ) {
    _subscription = controller?.changes.listen((_) {
      state = controller!.state;
    });
  }
  final StudySessionRecorder? controller;
  StreamSubscription<StudyRecorderState>? _subscription;
  Duration get elapsed => controller?.elapsed ?? Duration.zero;
  Future<void> start(
    DailyPlanDate date, {
    DailyPlanArea area = DailyPlanArea.srs,
  }) async => controller?.start(date, area: area);
  Future<void> finish() async => controller?.finish();
  Future<void> retry() async => controller?.retry();
  void interrupt({DailyPlanArea area = DailyPlanArea.srs}) =>
      controller?.interrupt(area: area);
  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    controller?.dispose();
    super.dispose();
  }
}
