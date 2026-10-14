import 'package:flutter_test/flutter_test.dart';
import '../../../tool/verify_transactional_review.dart' as verifier;

void main() {
  for (final scenario in verifier.scenarios) {
    test(
      'transactional ledger $scenario',
      () => verifier.verifyTransactional(scenario),
    );
  }
}
