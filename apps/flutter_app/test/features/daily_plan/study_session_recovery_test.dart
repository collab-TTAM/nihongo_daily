import 'package:flutter_test/flutter_test.dart';
import 'study_session_recovery_fixtures.dart';

void main() {
  for (final scenario in studyRecoveryScenarios) {
    test(
      'durable completed-study $scenario',
      () => verifyStudyRecovery(scenario),
    );
  }
}
