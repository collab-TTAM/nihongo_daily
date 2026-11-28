import 'package:flutter_test/flutter_test.dart';

import '../../../tool/verify_journal_compaction.dart' as verifier;

void main() {
  for (final scenario in verifier.scenarios) {
    test('lossless journal compaction $scenario', () async {
      await verifier.verifyCompaction(scenario);
    });
  }
}
