import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/ai/data/ai_text_repository_source.dart';
import '../features/ai/data/ai_conversation_source.dart';
import '../features/ai/data/ai_conversation_scenario_source.dart';
import '../features/ai/data/captured_conversation_scenarios.dart';
import '../features/ai/data/captured_ai_text_repository.dart';
import '../features/ai/data/captured_conversation_session.dart';
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
import '../features/daily_plan/data/durable_study_session_repository.dart';
import '../features/daily_plan/data/native_study_session_journal.dart';
import '../features/quiz/data/native_grammar_quiz_journal.dart';
import '../features/quiz/data/grammar_quiz_history_repository.dart';
import '../features/quiz/data/native_vocabulary_quiz_journal.dart';
import '../features/quiz/data/vocabulary_quiz_history_repository.dart';
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
    this.grammarHistory = 'false',
  });
  static const compiled = StagingBuildSettings(
    mode: String.fromEnvironment('ND_MODE'),
    projectUrl: String.fromEnvironment('ND_SUPABASE_URL'),
    publicKey: String.fromEnvironment('ND_SUPABASE_PUBLIC_KEY'),
    grammarHistory: String.fromEnvironment(
      'ND_GRAMMAR_HISTORY',
      defaultValue: 'false',
    ),
    automaticRefresh: String.fromEnvironment(
      'ND_AUTOMATIC_REFRESH',
      defaultValue: 'false',
    ),
  );
  final String mode;
  final String projectUrl;
  final String publicKey;
  final String automaticRefresh;
  final String grammarHistory;
  bool get isPreview => mode.isEmpty || mode == 'preview';
  StagingConfiguration configuration() {
    if (mode != 'staging' ||
        !const {'true', 'false'}.contains(automaticRefresh) ||
        !const {'true', 'false'}.contains(grammarHistory)) {
      throw const FormatException('Build configuration unavailable');
    }
    return StagingConfiguration(
      SupabaseReviewBinding.validateProjectUrl(projectUrl),
      SupabaseReviewBinding.validatePublicKey(publicKey),
      automaticRefresh == 'true',
      grammarHistoryEnabled: grammarHistory == 'true',
    );
  }
}

final class StagingConfiguration {
  const StagingConfiguration(
    this.projectUrl,
    this.publicKey,
    this.automaticRefresh, {
    this.grammarHistoryEnabled = false,
  });
  final String projectUrl;
  final String publicKey;
  final bool automaticRefresh;
  final bool grammarHistoryEnabled;
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
  NativeStudySessionJournal? studyJournal;
  NativeVocabularyQuizJournal? quizJournal;
  NativeGrammarQuizJournal? grammarJournal;
  try {
    studyJournal = await NativeStudySessionJournal.open(directory);
    quizJournal = await NativeVocabularyQuizJournal.open(directory);
    if (config.grammarHistoryEnabled) {
      grammarJournal = await NativeGrammarQuizJournal.open(directory);
    }
    final runtime = PersistentSupabaseRuntime(
      projectUrl: config.projectUrl,
      publishableKey: config.publicKey,
      vault: createWindowsSessionCredentialVault(config.projectUrl),
      store: journal,
      studyStore: studyJournal,
      quizStore: quizJournal,
      grammarStore: grammarJournal,
      automaticRefresh: config.automaticRefresh,
    );
    return WindowsStagingOwner(
      PersistentAccountStartup(runtime),
      journal,
      studyJournal: studyJournal,
      quizJournal: quizJournal,
      grammarJournal: grammarJournal,
    );
  } on Object {
    try {
      await grammarJournal?.close();
    } finally {
      try {
        await quizJournal?.close();
      } finally {
        try {
          await studyJournal?.close();
        } finally {
          await journal.close();
        }
      }
    }
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
        DailyPlanRepositorySource,
        DurableStudySessionSource,
        VocabularyQuizHistorySource,
        GrammarQuizHistorySource,
        AiTextRepositorySource,
        AiConversationSource,
        AiConversationScenarioSource {
  WindowsStagingOwner(
    this.session,
    this.journal, {
    this.studyJournal,
    this.quizJournal,
    this.grammarJournal,
  });

  /// Only explicit trusted grammar-history opt-in transfers this store.
  final NativeGrammarQuizJournal? grammarJournal;
  final NativeVocabularyQuizJournal? quizJournal;
  final NativeStudySessionJournal? studyJournal;
  final PersistentAccountStartup session;
  final NativeReviewJournal journal;
  Future<void>? _closing;
  @override
  CapturedAiTextRepository? createAiTextRepository() =>
      _closing == null ? session.createAiTextRepository() : null;
  @override
  Stream<void> get aiTextChanges => session.aiTextChanges;
  @override
  CapturedConversationScenarios? createAiConversationScenarios() =>
      _closing == null ? session.createAiConversationScenarios() : null;
  @override
  Stream<void> get aiConversationScenarioChanges =>
      session.aiConversationScenarioChanges;
  @override
  CapturedConversationSession? createAiConversationSession() =>
      _closing == null ? session.createAiConversationSession() : null;
  @override
  Stream<void> get aiConversationChanges => session.aiConversationChanges;
  @override
  VocabularyQuizHistoryRepository? createVocabularyQuizHistoryRepository() =>
      _closing == null ? session.createVocabularyQuizHistoryRepository() : null;
  @override
  GrammarQuizHistoryRepository? createGrammarQuizHistoryRepository() =>
      _closing == null ? session.createGrammarQuizHistoryRepository() : null;
  @override
  DailyPlanRepository? createDailyPlanRepository() =>
      _closing == null ? session.createDailyPlanRepository() : null;
  @override
  DurableStudySessionRepository? createDurableStudySessionRepository() =>
      _closing == null ? session.createDurableStudySessionRepository() : null;
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
    try {
      await grammarJournal?.close();
    } finally {
      try {
        await quizJournal?.close();
      } finally {
        try {
          await studyJournal?.close();
        } finally {
          await journal.close();
        }
      }
    }
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
