import 'dart:async';
import '../../ai/data/ai_text_repository_source.dart';
import '../../ai/data/captured_ai_text_repository.dart';
import '../../daily_plan/data/daily_plan_repository.dart';
import '../../daily_plan/data/durable_study_session_repository.dart';
import '../../quiz/data/vocabulary_quiz_history_repository.dart';
import '../../srs/application/srs_study_runtime.dart';
import '../data/persistent_account_access.dart';
import 'account_controller.dart';
import 'account_startup_controller.dart';
import 'persistent_supabase_runtime.dart';
import 'account_session_notice.dart';
import 'account_session_refresh.dart';

/// Transfer exclusive ownership of a newly constructed persistent runtime.
final class PersistentAccountStartup
    implements
        AccountStartupRuntime<AccountController<SrsStudyRuntime>>,
        ResumableAccountStartup,
        AccountSessionNoticeSource,
        AccountSessionRefreshAction,
        DailyPlanRepositorySource,
        DurableStudySessionSource,
        VocabularyQuizHistorySource,
        AiTextRepositorySource {
  PersistentAccountStartup(this.runtime);
  final PersistentSupabaseRuntime runtime;
  @override
  CapturedAiTextRepository? createAiTextRepository() =>
      runtime.createAiTextRepository();
  @override
  Stream<void> get aiTextChanges => runtime.aiTextChanges;
  @override
  VocabularyQuizHistoryRepository? createVocabularyQuizHistoryRepository() =>
      runtime.createVocabularyQuizHistoryRepository();
  @override
  DailyPlanRepository? createDailyPlanRepository() =>
      runtime.createDailyPlanRepository();
  @override
  DurableStudySessionRepository? createDurableStudySessionRepository() =>
      runtime.createDurableStudySessionRepository();
  @override
  AccountSessionNotice get notice => runtime.notice;
  @override
  Stream<AccountSessionNotice> get noticeChanges => runtime.noticeChanges;
  @override
  AccountController<SrsStudyRuntime> get account => runtime.account;
  @override
  bool get canOfferLogin =>
      runtime.persistence.phase == SessionPersistencePhase.failed &&
      runtime.persistence.currentSession == null &&
      runtime.account.readyRuntime == null;
  @override
  void resume() => runtime.resume();
  @override
  Future<void> refresh() => runtime.refresh();
  @override
  Future<void> start() => runtime.start();
  @override
  Future<void> close() => runtime.close();
}
