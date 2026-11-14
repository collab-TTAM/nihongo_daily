import 'durable_study_session_repository.dart';

/// Browser-only storage capability. Native callers use NativeStudySessionJournal.
abstract interface class BrowserStudySessionStore implements StudySessionStore {
  Future<void> close();
}

/// No in-memory persistence fallback on native or unsupported platforms.
Future<BrowserStudySessionStore> openBrowserStudySessionStore({
  String databaseName = 'nihongo-daily-study-sessions-v1',
}) => Future.error(const StudySessionStorageFailure());
