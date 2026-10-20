import 'package:flutter/material.dart';
import '../domain/daily_plan.dart';
import 'study_session_timer_panel.dart';

/// Preserve the existing SRS host and its keyed retained date field.
class SrsSessionTimerPanel extends StatelessWidget {
  const SrsSessionTimerPanel({super.key});
  @override
  Widget build(BuildContext context) =>
      const StudySessionTimerPanel(area: DailyPlanArea.srs);
}
