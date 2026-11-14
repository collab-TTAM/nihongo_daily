import 'package:flutter_test/flutter_test.dart';
import 'own_profile_fixtures.dart' as fixture;

void main() {
  for (final scenario in fixture.scenarios) {
    test('own profile $scenario', () => fixture.verifyProfile(scenario));
  }
}
