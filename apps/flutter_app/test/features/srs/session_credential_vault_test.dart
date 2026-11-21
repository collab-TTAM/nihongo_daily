import 'package:flutter_test/flutter_test.dart';
import 'session_vault_fixtures.dart';

void main() {
  for (final scenario in vaultScenarios) {
    test('credential vault $scenario', () => verifyVault(scenario));
  }
}
