import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/daily_plan/data/browser_study_session_store.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart';

void main() {
  test('native platform never substitutes an in-memory study store', () async {
    await expectLater(
      openBrowserStudySessionStore(databaseName: 'nd-study-native-test'),
      throwsA(isA<StudySessionStorageFailure>()),
    );
  });
}
