import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:supabase/supabase.dart';
import '../../ai/application/ai_text_runtime_owner.dart';
import '../../ai/data/ai_text_repository_source.dart';
import '../../ai/data/ai_conversation_source.dart';
import '../../ai/data/ai_conversation_scenario_source.dart';
import '../../ai/data/captured_conversation_scenarios.dart';
import '../../ai/data/captured_ai_text_repository.dart';
import '../../ai/data/captured_conversation_session.dart';
import '../../ai/data/supabase_ai_text_transport.dart';
import '../../daily_plan/data/captured_daily_plan_gateway.dart';
import '../../quiz/data/vocabulary_quiz_attempt_store.dart';
import '../../quiz/data/vocabulary_quiz_history_repository.dart';
import '../../daily_plan/data/daily_plan_repository.dart';
import '../../daily_plan/data/durable_study_session_repository.dart';
import '../../srs/application/srs_study_runtime.dart';
import '../../srs/data/durable_review_repository.dart';
import '../../srs/data/review_repository.dart';
import '../../srs/data/supabase_review_binding.dart';
import '../data/persistent_account_access.dart';
import '../data/session_credential_vault.dart';
import '../data/supabase_account_access.dart';
import 'account_controller.dart';
import 'account_provider.dart';
import 'session_refresh_scheduler.dart';
import 'account_session_notice.dart';
import 'account_session_refresh.dart';

/// Exclusively owns an SDK client with auto-refresh disabled and no Session JSON
/// persistence. Caller installs [account] only after [start] settles. The default
/// application never invokes this assembly or supplies project configuration.
final class PersistentSupabaseRuntime
    implements
        AccountSessionNoticeSource,
        AccountSessionRefreshAction,
        AiTextRepositorySource,
        AiConversationSource,
        AiConversationScenarioSource {
  PersistentSupabaseRuntime({
    required String projectUrl,
    required String publishableKey,
    required SessionCredentialVault vault,
    required DurableReviewStore store,
    StudySessionStore? studyStore,
    VocabularyQuizAttemptStore? quizStore,
    http.Client? httpClient,
    http.Client? aiHttpClient,
    DateTime Function()? now,
    bool automaticRefresh = false,
    bool aiTextEnabled = false,
    bool aiConversationEnabled = false,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _studyStore = studyStore,
       _quizStore = quizStore,
       _aiTextEnabled = aiTextEnabled,
       _aiConversationEnabled = aiConversationEnabled {
    if (kIsWeb) {
      // The pinned SDK broadcasts Auth session objects between browser tabs.
      // No browser token persistence/restore is authorized by this assembly.
      throw const SessionVaultFailure(SessionVaultError.unavailable);
    }
    final url = SupabaseReviewBinding.validateProjectUrl(projectUrl);
    final key = SupabaseReviewBinding.validatePublicKey(publishableKey);
    if (vault.target !=
        '${SessionCredentialVault.targetPrefix}${Uri.parse(url).origin.toLowerCase()}') {
      throw const SessionVaultFailure(SessionVaultError.invalidInput);
    }
    if (requestTimeout <= Duration.zero ||
        requestTimeout > const Duration(seconds: 15)) {
      throw const SessionVaultFailure(SessionVaultError.invalidInput);
    }
    if (PersistentAccountAccess.isTargetOwned(vault.target)) {
      throw const SessionVaultFailure(SessionVaultError.unavailable);
    }
    _network = _BoundedSessionHttp(
      httpClient ?? http.Client(),
      httpClient == null,
      Uri.parse(url),
      requestTimeout,
    );
    hierarchicalLoggingEnabled = true;
    Logger('supabase').level = Level.OFF;
    Logger('supabase.auth').level = Level.OFF;
    Logger('supabase.postgrest').level = Level.OFF;
    _client = SupabaseClient(
      url,
      key,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: _network,
    );
    _binding = SupabaseReviewBinding(
      client: _client,
      projectUrl: url,
      publishableKey: key,
      httpClient: _network,
      now: now,
    );
    _port = _OwnedSdkAccess(_client, _binding);
    persistence = PersistentAccountAccess(sdk: _port, vault: vault);
    account = createSupabaseAccountRuntime(
      _binding,
      store: store,
      access: persistence,
    );
    _aiOwner = AiTextRuntimeOwner(
      createTransport: ({required auth, required isReady}) =>
          SupabaseAiTextTransport(
            client: _client,
            auth: auth,
            isReady: isReady,
            projectUrl: url,
            publishableKey: key,
            httpClient: aiHttpClient,
            now: now,
            timeout: requestTimeout,
          ),
    );
    _aiSubscription = account.changes.listen(
      (_) => _syncAiReadiness(),
      onError: (Object _, StackTrace _) => _aiOwner.invalidate(),
      onDone: _aiOwner.invalidate,
    );
    _noticeSubscription = persistence.sessionChanges.listen(
      (_) => _publishNotice(),
      onError: (Object _, StackTrace __) =>
          _setNotice(AccountSessionNotice.needsLogin),
    );
    if (automaticRefresh) {
      _refreshScheduler = SessionRefreshScheduler(
        current: () {
          final session = persistence.currentSession;
          final expiry = _binding.currentExpiresAt;
          return session == null || expiry == null
              ? null
              : RefreshLease(session, expiry);
        },
        refresh: refresh,
        now: now,
      );
      _refreshSubscription = persistence.sessionChanges.listen(
        (_) => _refreshScheduler?.update(),
        onError: (Object _, StackTrace __) => _refreshScheduler?.dispose(),
        onDone: () => _refreshScheduler?.dispose(),
      );
    }
  }
  final StudySessionStore? _studyStore;
  final VocabularyQuizAttemptStore? _quizStore;
  final bool _aiTextEnabled;
  final bool _aiConversationEnabled;
  late final AiTextRuntimeOwner _aiOwner;
  StreamSubscription<AccountState>? _aiSubscription;
  SrsStudyRuntime? _aiReadyRuntime;
  AiTextGeneration? _aiGeneration;
  final _quizOperations = VocabularyQuizOperationDrain();
  final _studyOperations = StudySessionOperationDrain();
  late final SupabaseClient _client;
  late final _BoundedSessionHttp _network;
  late final SupabaseReviewBinding _binding;
  late final _OwnedSdkAccess _port;
  late final PersistentAccountAccess persistence;
  late final AccountController<SrsStudyRuntime> account;
  Future<void>? _closing;
  final _noticeEvents = StreamController<AccountSessionNotice>.broadcast();
  StreamSubscription<void>? _noticeSubscription;
  AccountSessionNotice _notice = AccountSessionNotice.none;
  @override
  AccountSessionNotice get notice => _notice;
  @override
  late final Stream<AccountSessionNotice> noticeChanges = _noticeEvents.stream;
  void _setNotice(AccountSessionNotice value) {
    if (_closing != null || _noticeEvents.isClosed || value == _notice) return;
    _notice = value;
    _noticeEvents.add(value);
  }

  void _publishNotice() => _setNotice(switch (persistence.phase) {
    SessionPersistencePhase.restoring ||
    SessionPersistencePhase.saving => AccountSessionNotice.checking,
    SessionPersistencePhase.failed => AccountSessionNotice.needsLogin,
    _ => AccountSessionNotice.none,
  });
  SessionRefreshScheduler? _refreshScheduler;
  StreamSubscription<void>? _refreshSubscription;
  SessionRefreshPhase? get refreshPhase => _refreshScheduler?.phase;
  void resume() => _refreshScheduler?.update();

  /// Trusted owner availability only; default and staging startup leave it off.
  bool get isAiTextEnabled => _aiTextEnabled;
  bool get isAiConversationEnabled => _aiConversationEnabled;
  @override
  Stream<void> get aiTextChanges => _aiOwner.changes;
  @override
  Stream<void> get aiConversationChanges => _aiOwner.changes;

  void _syncAiReadiness() {
    final ready = _closing == null ? account.readyRuntime : null;
    if (!identical(ready, _aiReadyRuntime)) {
      _aiOwner.invalidate();
      _aiReadyRuntime = ready;
      _aiGeneration = ready == null ? null : AiTextGeneration();
    }
    _aiOwner.check();
  }

  /// Explicit opt-in; no HTTP call occurs until a caller submits text. One
  /// capability per ready generation, with no replacement during old I/O drain.
  @override
  CapturedAiTextRepository? createAiTextRepository() {
    if (!_aiTextEnabled || _closing != null) return null;
    _syncAiReadiness();
    final ready = _aiReadyRuntime;
    final generation = _aiGeneration;
    final session = account.readySession;
    if (ready == null || generation == null || session == null) return null;
    return _aiOwner.acquire(
      auth: ready.auth,
      generation: generation,
      isReady: () =>
          _closing == null &&
          identical(account.readyRuntime, ready) &&
          identical(account.readySession, session) &&
          identical(_aiGeneration, generation),
    );
  }

  /// Separate trusted opt-in, not exposed by default startup/UI. Uses the same
  /// owner/transport/drain as text, after persisted rotation and own profile.
  @override
  CapturedConversationSession? createAiConversationSession() {
    if (!_aiConversationEnabled || _closing != null) return null;
    _syncAiReadiness();
    final ready = _aiReadyRuntime;
    final generation = _aiGeneration;
    final session = account.readySession;
    if (ready == null || generation == null || session == null) return null;
    return _aiOwner.acquireConversation(
      auth: ready.auth,
      generation: generation,
      isReady: () =>
          _closing == null &&
          identical(account.readyRuntime, ready) &&
          identical(account.readySession, session) &&
          identical(_aiGeneration, generation),
    );
  }

  /// Public scenario reader shares conversation opt-in/owned ready generation.
  /// Acquisition sends nothing; old transport drain still blocks replacement.
  @override
  CapturedConversationScenarios? createAiConversationScenarios() {
    if (!_aiConversationEnabled || _closing != null) return null;
    _syncAiReadiness();
    final ready = _aiReadyRuntime;
    final generation = _aiGeneration;
    final session = account.readySession;
    if (ready == null || generation == null || session == null) return null;
    return _aiOwner.acquireScenarios(
      auth: ready.auth,
      generation: generation,
      isReady: () =>
          _closing == null &&
          identical(account.readyRuntime, ready) &&
          identical(account.readySession, session) &&
          identical(_aiGeneration, generation),
    );
  }

  @override
  Stream<void> get aiConversationScenarioChanges => _aiOwner.changes;

  Future<void> start() async {
    try {
      await persistence.start();
    } finally {
      _publishNotice();
    }
    _refreshScheduler?.update();
  }

  /// Explicit owner assembly, after exact rotated-secret persistence and profile
  /// readiness. Each repository is tied to this precise ready-runtime instance;
  /// replacement/logout/close permanently invalidates the old lease. This does
  /// not install a UI, durable session queue or another SDK/token writer.
  DailyPlanRepository? createDailyPlanRepository() {
    if (_closing != null) return null;
    final ready = account.readyRuntime;
    final session = account.readySession;
    if (ready == null || session == null) return null;
    try {
      return DailyPlanRepository(
        CapturedDailyPlanGateway(
          auth: ready.auth,
          transport: _binding,
          isReady: () =>
              _closing == null &&
              identical(account.readyRuntime, ready) &&
              identical(account.readySession, session),
        ),
      );
    } on DailyPlanFailure {
      return null;
    }
  }

  DurableStudySessionRepository? createDurableStudySessionRepository() {
    final store = _studyStore;
    if (_closing != null || store == null || _studyOperations.isClosing) {
      return null;
    }
    final ready = account.readyRuntime;
    if (ready == null) return null;
    final delegate = createDailyPlanRepository();
    if (delegate == null || !identical(account.readyRuntime, ready)) {
      return null;
    }
    try {
      return DurableStudySessionRepository(
        auth: ready.auth,
        delegate: delegate,
        store: store,
        operations: _studyOperations,
      );
    } on DailyPlanFailure {
      return null;
    }
  }

  /// Optional borrowed local storage, bound to this exact ready runtime.
  /// Caller retains the store until close() drains all accepted operations.
  VocabularyQuizHistoryRepository? createVocabularyQuizHistoryRepository() {
    final store = _quizStore;
    if (_closing != null || store == null || _quizOperations.isClosing) {
      return null;
    }
    final ready = account.readyRuntime;
    final session = account.readySession;
    if (ready == null || session == null) return null;
    try {
      return VocabularyQuizHistoryRepository(
        auth: ready.auth,
        store: store,
        operations: _quizOperations,
        isReady: () =>
            _closing == null &&
            identical(account.readyRuntime, ready) &&
            identical(account.readySession, session),
      );
    } on VocabularyQuizSessionChanged {
      return null;
    }
  }

  @override
  Future<void> refresh() {
    _aiOwner.invalidate(); // Revoke synchronously before the vault/SDK barrier.
    return persistence.refresh();
  }

  /// Shutdown preserves confirmed stored credentials; explicit logout clears.
  Future<void> close() => _closing ??= () async {
    final aiClosing = _aiOwner.close(); // Revoke before the first await.
    account.dispose();
    _refreshScheduler?.dispose();
    await _noticeSubscription?.cancel();
    _notice = AccountSessionNotice.none;
    unawaited(_noticeEvents.close());
    await _refreshSubscription?.cancel();
    await _aiSubscription?.cancel();
    _aiReadyRuntime = null;
    _aiGeneration = null;
    // Preserve immediate Auth-close policy even while a study RPC is held.
    await Future.wait([
      persistence.close(),
      _studyOperations.revokeAndDrain(),
      _quizOperations.revokeAndDrain(),
      aiClosing,
    ]);
    await _port.close();
    _binding.dispose();
    await _client.dispose();
    _network.close();
  }();
}

/// One bounded attempt; timed-out responses cannot reach the SDK later.
final class _BoundedSessionHttp extends http.BaseClient {
  _BoundedSessionHttp(this.inner, this.owns, this.origin, this.timeout);
  final http.Client inner;
  final bool owns;
  final Uri origin;
  final Duration timeout;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.origin != origin.origin ||
        !request.url.path.startsWith('/auth/v1/') &&
            !request.url.path.startsWith('/rest/v1/')) {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
    request.followRedirects = false;
    final elapsed = Stopwatch()..start();
    var timedOut = false;
    final pending = inner.send(request);
    unawaited(
      pending.then<void>((response) async {
        if (timedOut) await response.stream.listen((_) {}).cancel();
      }, onError: (Object _, StackTrace __) {}),
    );
    try {
      final response = await pending.timeout(
        timeout,
        onTimeout: () {
          timedOut = true;
          throw TimeoutException('Session request unavailable');
        },
      );
      const maximum = 1024 * 1024;
      if ((response.contentLength ?? 0) > maximum) {
        await response.stream.listen((_) {}).cancel();
        throw const ReviewTransportFailure(ReviewErrorCode.internalError);
      }
      final bytes = BytesBuilder(copy: false);
      final iterator = StreamIterator(response.stream);
      try {
        while (await iterator.moveNext().timeout(timeout - elapsed.elapsed)) {
          final chunk = iterator.current;
          if (bytes.length + chunk.length > maximum) {
            throw const ReviewTransportFailure(ReviewErrorCode.internalError);
          }
          bytes.add(chunk);
        }
      } finally {
        await iterator.cancel();
      }
      return http.StreamedResponse(
        Stream.value(bytes.takeBytes()),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    } on Object {
      throw const ReviewTransportFailure(ReviewErrorCode.networkUnavailable);
    }
  }

  @override
  void close() {
    if (owns) inner.close();
  }
}

final class _OwnedSdkAccess implements RefreshableAccountAccess {
  _OwnedSdkAccess(this.client, this.binding) {
    _bindingSubscription = binding.sessionChanges.listen(
      (_) => _events.add(null),
      onError: (Object _, StackTrace __) => _events.addError(_failure()),
    );
    // Binding retains ReviewSession identity on same-lifecycle refresh and does
    // not emit a review invalidation. Persistence also needs every SDK rotation.
    _authSubscription = client.auth.onAuthStateChange.listen(
      (_) => _events.add(null),
      onError: (Object _, StackTrace __) => _events.addError(_failure()),
    );
  }
  final SupabaseClient client;
  final SupabaseReviewBinding binding;
  final _events = StreamController<void>.broadcast();
  late final StreamSubscription<void> _bindingSubscription;
  late final StreamSubscription<AuthState> _authSubscription;
  static ReviewTransportFailure _failure() =>
      const ReviewTransportFailure(ReviewErrorCode.unauthorized);
  @override
  Stream<void> get sessionChanges => _events.stream;
  @override
  ReviewSession? get currentSession => binding.currentSession;
  @override
  String? get currentRefreshToken =>
      currentSession == null ? null : client.auth.currentSession?.refreshToken;
  @override
  Future<void> signIn(String email, String password) =>
      SupabaseAccountAccess(binding).signIn(email, password);
  @override
  Future<void> signOut() => binding.signOutLocally();
  @override
  Future<void> restore(String refreshToken) async {
    try {
      await client.auth.setSession(refreshToken);
    } on Object {
      throw _failure();
    }
  }

  @override
  Future<void> refresh() async {
    try {
      await client.auth.refreshSession();
    } on Object {
      throw _failure();
    }
  }

  Future<void> close() async {
    await _bindingSubscription.cancel();
    await _authSubscription.cancel();
    await _events.close();
  }
}
