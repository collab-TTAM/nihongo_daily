import 'package:flutter_test/flutter_test.dart';
import 'srs_session_recorder_fixtures.dart';

void main() {
  for (final scenario in recorderScenarios) {
    test(
      'SRS elapsed-session recorder $scenario',
      () => verifyRecorder(scenario),
    );
  }
}
