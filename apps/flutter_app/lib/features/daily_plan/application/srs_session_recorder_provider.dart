import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/account_provider.dart';
import '../../curriculum/application/curriculum_provider.dart';
import '../../curriculum/domain/curriculum.dart';
import '../../settings/application/preview_preferences.dart';
import '../../reading/application/reading_provider.dart';
import '../../srs/application/srs_study_controller.dart';
import '../../srs/application/srs_study_provider.dart';
import '../domain/daily_plan.dart';
import '../domain/completed_study_session.dart';
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

// Only settled, real loaded content at the own profile's level can start.
// Loading/error values must not reuse a stale successful projection.
final canStartStudyRecorderProvider = Provider.autoDispose
    .family<bool, DailyPlanArea>((ref, area) {
      if (area == DailyPlanArea.srs) {
        return ref.watch(canStartSrsRecorderProvider);
      }
      if (area == DailyPlanArea.listeningReading) {
        final profile = ref.watch(accountStateProvider).profile;
        final level = ref.watch(previewLevelProvider);
        final selected = ref.watch(readingSelectedPassageProvider);
        if (profile == null ||
            profile.level != level.label ||
            selected == null) {
          return false;
        }
        final content = ref.watch(readingCatalogProvider(level));
        if (content.isLoading || content.hasError) return false;
        final passages = content.asData?.value;
        return passages != null &&
            passages.any((p) => identical(p, selected)) &&
            passages.every((p) => p.level == level && p.contentVersion > 0);
      }
      final kind = switch (area) {
        DailyPlanArea.vocabulary => CurriculumKind.vocabulary,
        DailyPlanArea.grammar => CurriculumKind.grammar,
        _ => null,
      };
      if (kind == null) {
        return false;
      }
      final profile = ref.watch(accountStateProvider).profile;
      final level = ref.watch(previewLevelProvider);
      if (profile == null || profile.level != level.label) {
        return false;
      }
      final content = ref.watch(curriculumProvider(kind));
      if (content.isLoading || content.hasError) {
        return false;
      }
      final entries = content.asData?.value;
      return entries != null &&
          entries.isNotEmpty &&
          entries.every(
            (entry) =>
                entry.kind == kind &&
                entry.level == level &&
                entry.contentVersion > 0,
          );
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
                canStudyArea: (area) =>
                    ref.read(canStartStudyRecorderProvider(area)),
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
  CompletedStudySession? get pendingEvent => controller?.pendingEvent;
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
