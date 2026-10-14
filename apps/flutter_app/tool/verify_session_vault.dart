import '../test/features/srs/session_vault_fixtures.dart';

Future<void> main() async {
  for (final scenario in vaultScenarios) {
    await verifyVault(scenario);
  }
  print(
    'PASS: twelve scoped credential-vault validation/serialization/redaction '
    'fixture scenarios. Not Windows OS storage or hosted Auth restoration proof.',
  );
}
