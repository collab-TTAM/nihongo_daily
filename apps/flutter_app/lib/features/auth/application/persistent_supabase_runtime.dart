import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:supabase/supabase.dart';
import '../../ai/application/ai_text_runtime_owner.dart';
import '../../ai/application/receipt_ai_runtime_owner.dart';
import '../../ai/data/conversation_receipt_store.dart';
import '../../ai/data/windows_pending_command_protector.dart';
import '../../ai/domain/conversation_receipt_reference.dart';
import '../../ai/data/receipt_guarded_ai_transport.dart';
import '../../ai/data/ai_text_repository_source.dart';
import '../../ai/data/ai_conversation_source.dart';
import '../../ai/data/ai_conversation_scenario_source.dart';
import '../../ai/data/captured_conversation_scenarios.dart';
import '../../ai/data/captured_ai_text_repository.dart';
import '../../ai/data/captured_conversation_receipt_lookup.dart';
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
import '../data/supabase_refreshable_account_access.dart';
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
    ConversationReceiptStore? conversationReceiptStore,
    http.Client? httpClient,
    http.Client? aiHttpClient,
    DateTime Function()? now,
    bool automaticRefresh = false,
    bool aiTextEnabled = false,
    bool aiConversationEnabled = false,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _commandScope = conversationReceiptStore?.scope,
       _studyStore = studyStore,
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
    // Reject before SDK creation/receipt ownership transfer.
    if (conversationReceiptStore != null &&
        (!aiConversationEnabled ||
            conversationReceiptStore.scope.projectOrigin !=
                Uri.parse(url).origin.toLowerCase() ||
            conversationReceiptStore.phase !=
                ConversationReceiptStorePhase.open)) {
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
    _port = SupabaseRefreshableAccountAccess(_client, _binding);
    persistence = PersistentAccountAccess(sdk: _port, vault: vault);
    account = createSupabaseAccountRuntime(
      _binding,
      store: store,
      access: conversationReceiptStore == null
          ? persistence
          : _ReceiptAccountAccess(persistence, _signOutWithReceipt),
    );
    if (conversationReceiptStore == null) {
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
    } else {
      final receiptOwner = ReceiptAiRuntimeOwner(
        store: conversationReceiptStore,
        createTransport: ({required auth, required isReady, required store}) {
          final session = auth.currentSession;
          if (session == null ||
              session.userId != store.scope.ownerId ||
              !isReady()) {
            throw const AiTextFailure(AiTextErrorCode.unauthorized);
          }
          return ReceiptGuardedAiTransport(
            inner: SupabaseAiTextTransport(
              client: _client,
              auth: auth,
              isReady: isReady,
              projectUrl: url,
              publishableKey: key,
              httpClient: aiHttpClient,
              now: now,
              timeout: requestTimeout,
            ),
            store: store,
            auth: auth,
            capturedSession: session,
            isReady: isReady,
          );
        },
      );
      _receiptOwner = receiptOwner;
      _aiOwner =
          receiptOwner.runtime; // One shared text/conversation/scenario lane.
    }
    _aiSubscription = account.changes.listen(
      (_) => _syncAiReadiness(),
      onError: (Object _, StackTrace _) => _invalidateAiCapabilities(),
      onDone: _invalidateAiCapabilities,
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
  final ConversationReceiptScope? _commandScope;
  WindowsPendingCommandProtector? _commandProtector;
  Future<void>? _commandDraining;
  Future<void>? _commandRefresh;
  bool _commandTerminal = false;

  Future<void> _drainCommandProtection() {
    if (_commandDraining != null) return _commandDraining!;
    final old = _commandProtector;
    _commandProtector = null;
    if (old == null) return Future<void>.value();
    final done = Completer<void>();
    _commandDraining =
        done.future; // Before synchronous revoke can be observed.
    unawaited(
      old.revokeAndDrain().then<void>((_) {
        _commandDraining = null;
        done.complete();
      }),
    );
    return done.future;
  }

  void _invalidateAiCapabilities() {
    _aiOwner.invalidate();
    unawaited(_drainCommandProtection());
  }

  /// Explicit byte capability only; no persistence, dispatch or default wiring.
  WindowsPendingCommandProtector? createWindowsPendingCommandProtector() {
    if (!_aiConversationEnabled ||
        _commandScope == null ||
        _closing != null ||
        _receiptLogout != null ||
        _commandRefresh != null ||
        _commandTerminal ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.windows) {
      return null;
    }
    _syncAiReadiness();
    if (_commandDraining != null) return null;
    final ready = _aiReadyRuntime;
    final generation = _aiGeneration;
    final session = account.readySession;
    if (ready == null || generation == null || session == null) return null;
    final existing = _commandProtector;
    if (existing != null) return existing.isCurrent ? existing : null;
    try {
      return _commandProtector = WindowsPendingCommandProtector(
        auth: ready.auth,
        scope: _commandScope,
        isReady: () =>
            _closing == null &&
            !_commandTerminal &&
            _commandRefresh == null &&
            _receiptLogout == null &&
            identical(account.readyRuntime, ready) &&
            identical(account.readySession, session) &&
            identical(_aiGeneration, generation),
      );
    } on CommandProtectionFailure {
      return null;
    }
  }

  final StudySessionStore? _studyStore;
  final VocabularyQuizAttemptStore? _quizStore;
  final bool _aiTextEnabled;
  final bool _aiConversationEnabled;
  late final AiTextRuntimeOwner _aiOwner;
  ReceiptAiRuntimeOwner? _receiptOwner;
  Future<void>? _receiptLogout;
  StreamSubscription<AccountState>? _aiSubscription;
  SrsStudyRuntime? _aiReadyRuntime;
  AiTextGeneration? _aiGeneration;
  final _quizOperations = VocabularyQuizOperationDrain();
  final _studyOperations = StudySessionOperationDrain();
  late final SupabaseClient _client;
  late final _BoundedSessionHttp _network;
  late final SupabaseReviewBinding _binding;
  late final SupabaseRefreshableAccountAccess _port;
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
      _invalidateAiCapabilities();
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

  /// Explicit read capability; shares the original AI owner and ready generation.
  CapturedConversationReceiptLookup? createConversationReceiptLookup() {
    if (!_aiConversationEnabled || _closing != null) return null;
    _syncAiReadiness();
    final ready = _aiReadyRuntime;
    final generation = _aiGeneration;
    final session = account.readySession;
    if (ready == null || generation == null || session == null) return null;
    return _aiOwner.acquireReceiptLookup(
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

  Future<void> _signOutWithReceipt() {
    if (_receiptLogout != null) return _receiptLogout!;
    final done = Completer<void>();
    _receiptLogout = done.future; // Before revocation or SDK callbacks reenter.
    _commandTerminal = true;
    final commandDraining = _drainCommandProtection();
    final receipt = _receiptOwner!;
    // Both revoke immediately; attempt Auth cleanup even if receipt cleanup fails.
    final clearing = receipt.signOut();
    final signingOut = Future<void>.sync(persistence.signOut);
    unawaited(
      Future.wait<void>([clearing, signingOut, commandDraining]).then<void>(
        (_) {
          _receiptLogout = null;
          done.complete();
        },
        onError: (Object _, StackTrace _) {
          _receiptLogout =
              null; // Only another explicit logout retries failed clear.
          done.completeError(
            const ReviewTransportFailure(ReviewErrorCode.internalError),
          );
        },
      ),
    );
    return done.future;
  }

  @override
  Future<void> refresh() {
    if (_commandRefresh != null) return _commandRefresh!;
    final done = Completer<void>();
    _commandRefresh =
        done.future; // Fence acquisition before callbacks reenter.
    _aiOwner.invalidate(); // Revoke synchronously before the vault/SDK barrier.
    final draining = _drainCommandProtection();
    final refreshing = Future<void>.sync(persistence.refresh);
    unawaited(
      Future.wait<void>([refreshing, draining]).then<void>(
        (_) {
          _commandRefresh = null;
          done.complete();
        },
        onError: (Object error, StackTrace stack) {
          _commandRefresh = null;
          done.completeError(
            error,
            stack,
          ); // Preserve the existing safe Auth failure.
        },
      ),
    );
    return done.future;
  }

  /// Shutdown preserves confirmed stored credentials; explicit logout clears.
  Future<void> close() => _closing ??= () async {
    _commandTerminal = true;
    final commandClosing = _drainCommandProtection();
    final aiClosing =
        _receiptOwner?.close() ??
        _aiOwner.close(); // Revoke before first await.
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
      commandClosing,
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

/// Optional receipt lifetime adds cleanup to the existing Auth port only.
/// Account readiness, login and persistence behavior remain in their owners.
final class _ReceiptAccountAccess implements AccountAccess {
  _ReceiptAccountAccess(this._auth, this._logout);
  final PersistentAccountAccess _auth;
  final Future<void> Function() _logout;
  @override
  ReviewSession? get currentSession => _auth.currentSession;
  @override
  Stream<void> get sessionChanges => _auth.sessionChanges;
  @override
  Future<void> signIn(String email, String password) =>
      _auth.signIn(email, password);
  @override
  Future<void> signOut() => _logout();
}
