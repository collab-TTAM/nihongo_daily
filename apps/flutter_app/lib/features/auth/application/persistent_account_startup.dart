import 'dart:async';
import '../../srs/application/srs_study_runtime.dart';
import '../data/persistent_account_access.dart';
import 'account_controller.dart';
import 'account_startup_controller.dart';
import 'persistent_supabase_runtime.dart';
import 'account_session_notice.dart';

/// Transfer exclusive ownership of a newly constructed persistent runtime.
final class PersistentAccountStartup
    implements
        AccountStartupRuntime<AccountController<SrsStudyRuntime>>,
        ResumableAccountStartup,
        AccountSessionNoticeSource {
  PersistentAccountStartup(this.runtime);
  final PersistentSupabaseRuntime runtime;
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
  Future<void> start() => runtime.start();
  @override
  Future<void> close() => runtime.close();
}
