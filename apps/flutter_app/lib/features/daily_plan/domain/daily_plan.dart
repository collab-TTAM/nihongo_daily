/// Strict, immutable projections of the frozen v0.1 Daily Plan wire contract.
library;

enum DailyPlanArea {
  srs('SRS'),
  vocabulary('VOCABULARY'),
  kanji('KANJI'),
  grammar('GRAMMAR'),
  listeningReading('LISTENING_READING'),
  aiConversation('AI_CONVERSATION'),
  quizReview('QUIZ_REVIEW');

  const DailyPlanArea(this.wireName);
  final String wireName;
}

enum DailyPlanStatus { ready, inProgress, done, blocked }

/// A profile-local calendar date, never inferred from this device's timezone.
final class DailyPlanDate {
  factory DailyPlanDate(String value) {
    if (!RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value) ||
        value.length != 10) {
      throw const FormatException('Invalid plan date');
    }
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final day = int.parse(value.substring(8, 10));
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      throw const FormatException('Invalid plan date');
    }
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw const FormatException('Invalid plan date');
    }
    return DailyPlanDate._(value);
  }

  const DailyPlanDate._(this.value);
  final String value;

  Map<String, Object> toRequestJson() => {'date': value};
}

final class DailyPlanBlock {
  const DailyPlanBlock._({
    required this.area,
    required this.plannedMinutes,
    required this.status,
    required this.itemCount,
  });

  final DailyPlanArea area;
  final int plannedMinutes;
  final DailyPlanStatus status;
  final int itemCount;

  static DailyPlanBlock _decode(Object? value) {
    final map = _object(value, {
      'type',
      'planned_minutes',
      'status',
      'item_count',
    });
    final area = DailyPlanArea.values.where(
      (area) => area.wireName == map['type'],
    );
    const statuses = {
      'READY': DailyPlanStatus.ready,
      'IN_PROGRESS': DailyPlanStatus.inProgress,
      'DONE': DailyPlanStatus.done,
      'BLOCKED': DailyPlanStatus.blocked,
    };
    final status = statuses[map['status']];
    if (area.length != 1 || status == null) {
      throw const FormatException('Invalid plan block');
    }
    return DailyPlanBlock._(
      area: area.single,
      plannedMinutes: _integer(map['planned_minutes'], 1, 1440),
      status: status,
      itemCount: _integer(map['item_count'], 0),
    );
  }
}

final class DailyPlan {
  const DailyPlan._({
    required this.date,
    required this.targetMinutes,
    required this.completedMinutes,
    required this.blocks,
  });

  factory DailyPlan.fromJson(Object? value) {
    final map = _object(value, {
      'plan_date',
      'target_minutes',
      'completed_minutes',
      'blocks',
    });
    final date = map['plan_date'];
    final rawBlocks = map['blocks'];
    if (date is! String ||
        rawBlocks is! List<Object?> ||
        rawBlocks.length != 7) {
      throw const FormatException('Invalid plan');
    }
    final target = _integer(map['target_minutes'], 7, 1440);
    final blocks = rawBlocks.map(DailyPlanBlock._decode).toList();
    if (blocks.map((block) => block.area).toSet().length != 7 ||
        blocks.fold(0, (sum, block) => sum + block.plannedMinutes) != target) {
      throw const FormatException('Invalid plan allocation');
    }
    return DailyPlan._(
      date: DailyPlanDate(date),
      targetMinutes: target,
      completedMinutes: _integer(map['completed_minutes'], 0),
      blocks: List.unmodifiable(blocks),
    );
  }

  final DailyPlanDate date;
  final int targetMinutes;
  // Server progress is preserved even when it exceeds the daily target.
  final int completedMinutes;
  final List<DailyPlanBlock> blocks;
}

Map<String, Object?> _object(Object? value, Set<String> fields) {
  if (value is! Map<String, Object?> ||
      value.length != fields.length ||
      !fields.every(value.containsKey)) {
    throw const FormatException('Invalid plan fields');
  }
  return value;
}

// Reject numbers that cannot be represented exactly on both Dart VM and web.
int _integer(Object? value, int minimum, [int maximum = 9007199254740991]) {
  if (value is! num ||
      !value.isFinite ||
      value < minimum ||
      value > maximum ||
      value != value.truncateToDouble()) {
    throw const FormatException('Invalid plan number');
  }
  return value.toInt();
}
