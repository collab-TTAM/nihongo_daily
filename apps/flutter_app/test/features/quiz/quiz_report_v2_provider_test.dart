import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/application/quiz_report_v2_provider.dart';

void main() {
  test('preview exposes no quiz report transport by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(quizReportV2TransportSourceProvider), isNull);
    expect(container.read(quizReportV2TransportProvider), isNull);
  });
}
