import '../domain/daily_plan.dart';
import 'study_session_recorder.dart';

export 'study_session_recorder.dart';

/// Compatibility constructor for existing SRS callers and retained regressions.
/// The configured app owns the single shared recorder through its provider.
final class SrsSessionRecorder extends StudySessionRecorder {
  SrsSessionRecorder({
    required super.service,
    required super.clock,
    required this.canStudy,
  }) : super(canStudyArea: (area) => area == DailyPlanArea.srs && canStudy());
  final bool Function() canStudy;
}
