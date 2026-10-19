import 'daily_plan.dart';

/// Immutable study-submit-v1 report. The server owns credit and validation;
/// this event carries no owner, score, planned/actual minutes or credentials.
final class CompletedStudySession {
  CompletedStudySession({
    required String clientEventId,
    required this.date,
    required this.area,
    required DateTime startedAt,
    required DateTime endedAt,
  }) : clientEventId = clientEventId.toLowerCase(),
       startedAt = startedAt.toUtc(),
       endedAt = endedAt.toUtc() {
    if (clientEventId.length != 36 ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(clientEventId)) {
      throw const FormatException('Invalid study event ID');
    }
    for (final instant in [this.startedAt, this.endedAt]) {
      if (instant.year < 1 || instant.year > 9999) {
        throw const FormatException('Invalid study instant');
      }
    }
    final elapsed = this.endedAt.difference(this.startedAt);
    if (elapsed < const Duration(minutes: 1) ||
        elapsed > const Duration(hours: 25)) {
      throw const FormatException('Invalid study interval');
    }
  }

  final String clientEventId;
  final DailyPlanDate date;
  final DailyPlanArea area;
  final DateTime startedAt;
  final DateTime endedAt;

  Map<String, Object> toJson() => {
    'client_event_id': clientEventId,
    'plan_date': date.value,
    'session_type': area.wireName,
    'started_at': startedAt.toIso8601String(),
    'ended_at': endedAt.toIso8601String(),
  };
}
