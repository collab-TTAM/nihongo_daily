import 'daily_plan.dart';

/// profile-study-day-v1: server date at lookup, never a device-date calculation.
final class StudyDay {
  const StudyDay._(this.date, this.timezone);
  final DailyPlanDate date;
  final String timezone;
  static bool validZone(String value) {
    if (value.isEmpty || value.length > 100) return false;
    return RegExp(
          r'[A-Za-z0-9_+-]+(?:/[A-Za-z0-9_+-]+)*',
        ).matchAsPrefix(value)?.group(0) ==
        value;
  }

  factory StudyDay.fromJson(Object? raw) {
    if (raw is! Map<String, Object?> ||
        raw.length != 2 ||
        raw['date'] is! String ||
        raw['timezone'] is! String ||
        !validZone(raw['timezone']! as String)) {
      throw const FormatException('Invalid study day');
    }
    return StudyDay._(
      DailyPlanDate(raw['date']! as String),
      raw['timezone']! as String,
    );
  }
}
