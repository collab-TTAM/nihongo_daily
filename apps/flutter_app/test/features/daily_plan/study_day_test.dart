import 'package:flutter_test/flutter_test.dart';
import 'study_day_fixtures.dart';

void main() {
  for (final scenario in studyDayScenarios) {
    test('server study day $scenario', () => verifyStudyDay(scenario));
  }
}
