import 'package:flutter_test/flutter_test.dart';
import 'transactional_review_fixtures.dart' as verifier;

void main() {
  for (final scenario in verifier.scenarios) {
    test(
      'transactional ledger $scenario',
      () => verifier.verifyTransactional(scenario),
    );
  }
}
