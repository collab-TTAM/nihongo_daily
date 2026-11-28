import 'package:flutter_test/flutter_test.dart';
import 'session_lifecycle_fixtures.dart' as fixture;

void main() {
  for (final scenario in fixture.scenarios) {
    test(
      'persistent session lifecycle: $scenario',
      () => fixture.verifyLifecycle(scenario),
    );
  }
}
