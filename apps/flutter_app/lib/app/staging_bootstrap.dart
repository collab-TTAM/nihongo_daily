import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/application/account_controller.dart';
import '../features/auth/application/account_startup_controller.dart';
import '../features/auth/application/account_session_notice.dart';
import '../features/auth/application/account_session_refresh.dart';
import '../features/auth/application/persistent_account_startup.dart';
import '../features/auth/application/persistent_supabase_runtime.dart';
import '../features/auth/data/windows_review_directory.dart';
import '../features/auth/data/windows_session_credential_vault.dart';
import '../features/auth/presentation/account_startup_app.dart';
import '../features/daily_plan/data/daily_plan_repository.dart';
import '../features/srs/application/srs_study_runtime.dart';
import '../features/srs/data/native_review_journal.dart';
import '../features/srs/data/supabase_review_binding.dart';
import 'app.dart';

/// Trusted build values only. Public key/URL may ship; learner secrets never do.
final class StagingBuildSettings {
  const StagingBuildSettings({
    this.mode = '',
    this.projectUrl = '',
    this.publicKey = '',
    this.automaticRefresh = 'false',
  });
  static const compiled = StagingBuildSettings(
    mode: String.fromEnvironment('ND_MODE'),
    projectUrl: String.fromEnvironment('ND_SUPABASE_URL'),
    publicKey: String.fromEnvironment('ND_SUPABASE_PUBLIC_KEY'),
    automaticRefresh: String.fromEnvironment(
      'ND_AUTOMATIC_REFRESH',
      defaultValue: 'false',
    ),
  );
  final String mode;
  final String projectUrl;
  final String publicKey;
  final String automaticRefresh;
  bool get isPreview => mode.isEmpty || mode == 'preview';
  StagingConfiguration configuration() {
    if (mode != 'staging' ||
        !const {'true', 'false'}.contains(automaticRefresh)) {
      throw const FormatException('Build configuration unavailable');
    }
    return StagingConfiguration(
      SupabaseReviewBinding.validateProjectUrl(projectUrl),
      SupabaseReviewBinding.validatePublicKey(publicKey),
      automaticRefresh == 'true',
    );
  }
}

final class StagingConfiguration {
  const StagingConfiguration(
    this.projectUrl,
    this.publicKey,
    this.automaticRefresh,
  );
  final String projectUrl;
  final String publicKey;
  final bool automaticRefresh;
}

typedef StagingOwner =
    AccountStartupRuntime<AccountController<SrsStudyRuntime>>;

/// No configuration activates preview Auth. Invalid selected staging fails before
/// opening disk/SDK, and never falls back to a different project or demo success.
Widget selectBootstrapApp(
  StagingBuildSettings settings, {
  Future<StagingOwner> Function(StagingConfiguration)? open,
}) {
  if (settings.isPreview) return const ProviderScope(child: NihongoDailyApp());
  try {
    final config = settings.configuration();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return const _ConfigurationUnavailable(
        'Chế độ tài khoản có cấu hình hiện chỉ hỗ trợ Windows.',
      );
    }
    final factory = open ?? openWindowsStagingOwner;
    final controller =
        AccountStartupController<AccountController<SrsStudyRuntime>>(
          () => factory(config),
        );
    return AccountStartupApp(controller: controller);
  } on Object {
    return const _ConfigurationUnavailable(
      'Chưa thể khởi động tài khoản. Hãy kiểm tra cấu hình ứng dụng.',
    );
  }
}

Future<StagingOwner> openWindowsStagingOwner(
  StagingConfiguration config,
) async {
  final directory = await resolveWindowsReviewDirectory(config.projectUrl);
  final journal = await NativeReviewJournal.open(directory);
  try {
    final runtime = PersistentSupabaseRuntime(
      projectUrl: config.projectUrl,
      publishableKey: config.publicKey,
      vault: createWindowsSessionCredentialVault(config.projectUrl),
      store: journal,
      automaticRefresh: config.automaticRefresh,
    );
    return WindowsStagingOwner(PersistentAccountStartup(runtime), journal);
  } on Object {
    await journal.close();
    rethrow; // Startup controller replaces raw details with its fixed UI state.
  }
}

/// The process journal lease is acquired before any SDK/token writer is created.
/// Transfer exclusive ownership of both lifetimes. Public assembly permits the
/// same production wrapper to be exercised with actual SDK/local-store fixtures.
/// No history is deleted by logout/shutdown.
final class WindowsStagingOwner
    implements
        StagingOwner,
        ResumableAccountStartup,
        AccountSessionNoticeSource,
        AccountSessionRefreshAction,
        DailyPlanRepositorySource {
  WindowsStagingOwner(this.session, this.journal);
  final PersistentAccountStartup session;
  final NativeReviewJournal journal;
  Future<void>? _closing;
  @override
  DailyPlanRepository? createDailyPlanRepository() =>
      _closing == null ? session.createDailyPlanRepository() : null;
  @override
  AccountController<SrsStudyRuntime> get account => session.account;
  @override
  bool get canOfferLogin => session.canOfferLogin;
  @override
  AccountSessionNotice get notice => session.notice;
  @override
  Stream<AccountSessionNotice> get noticeChanges => session.noticeChanges;
  @override
  void resume() => session.resume();
  @override
  Future<void> refresh() => session.refresh();
  @override
  Future<void> start() => session.start();
  @override
  Future<void> close() => _closing ??= () async {
    await session.close();
    await journal.close();
  }();
}

class _ConfigurationUnavailable extends StatelessWidget {
  const _ConfigurationUnavailable(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nihongo Daily',
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(message),
          ),
        ),
      ),
    ),
  );
}
