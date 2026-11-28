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

  /// Restore only our canonical immutable storage encoding, never raw UI input.
  factory CompletedStudySession.fromJson(Object? raw) {
    if (raw is! Map<String, Object?> ||
        raw.length != 5 ||
        !const {
          'client_event_id',
          'plan_date',
          'session_type',
          'started_at',
          'ended_at',
        }.every((key) => raw[key] is String)) {
      throw const FormatException('Invalid stored study event');
    }
    try {
      final area = DailyPlanArea.values.singleWhere(
        (area) => area.wireName == raw['session_type'],
      );
      final event = CompletedStudySession(
        clientEventId: raw['client_event_id']! as String,
        date: DailyPlanDate(raw['plan_date']! as String),
        area: area,
        startedAt: DateTime.parse(raw['started_at']! as String),
        endedAt: DateTime.parse(raw['ended_at']! as String),
      );
      if (!event.toJson().entries.every(
        (entry) => raw[entry.key] == entry.value,
      )) {
        throw const FormatException();
      }
      return event;
    } on Object {
      throw const FormatException('Invalid stored study event');
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
