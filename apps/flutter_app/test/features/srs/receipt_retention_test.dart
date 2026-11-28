import 'package:flutter_test/flutter_test.dart';
import 'receipt_retention_fixtures.dart' as fixture;

void main() {
  for (final scenario in fixture.scenarios) {
    test(
      'receipt retention $scenario',
      () => fixture.verifyTransactionalRetention(scenario),
    );
  }
}
