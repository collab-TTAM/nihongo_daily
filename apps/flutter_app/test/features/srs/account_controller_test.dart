import 'package:flutter_test/flutter_test.dart';
import 'account_fixtures.dart' as fixture;

void main() {
  for (final scenario in fixture.scenarios) {
    test('account readiness $scenario', () => fixture.verifyAccount(scenario));
  }
}
