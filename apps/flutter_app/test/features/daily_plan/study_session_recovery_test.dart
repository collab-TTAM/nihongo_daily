import 'package:flutter_test/flutter_test.dart';
import 'study_session_recovery_fixtures.dart';

void main() {
  for (final scenario in studyRecoveryScenarios) {
    test(
      scenario == 'twoClients'
          ? 'two independent native clients replay immutable study events exactly once'
          : 'durable completed-study $scenario',
      () => verifyStudyRecovery(scenario),
    );
  }
}
