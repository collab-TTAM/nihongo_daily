import 'package:flutter_test/flutter_test.dart';
import 'windows_exit_marker_fixtures.dart';

void main() {
  for (final name in exitMarkerScenarios.keys) {
    test(
      'exit fixture complete-marker publication $name',
      () => runExitMarkerScenario(name),
    );
  }
}
