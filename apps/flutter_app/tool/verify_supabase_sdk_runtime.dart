// TEST ONLY: exercise the caller-owned Supabase SDK runtime against the
// disposable loopback GoTrue/PostgREST stack. Never used by the app default.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_runtime.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

const _dueItemId = '00000000-0000-4000-8000-000000000002';
const _eventId = '00000000-0000-4000-8000-0000000000a1';
const _deviceOfflineEventId = '00000000-0000-4000-8000-0000000000a2';
const _deviceOnlineEventId = '00000000-0000-4000-8000-0000000000a3';
const _duePrompt = '同期テスト';
const _dueReading = 'どうきテスト';
const _dueAnswer = 'kiểm thử đồng bộ';

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

final class _ProbeFailure implements Exception {
  const _ProbeFailure(this.phase);
  final String phase;
}

final class _User {
  const _User(this.id, this.email, this.password);
  final String id;
  final String email;
  final String password;
}

final class _Input {
  const _Input(this.apiUrl, this.anonKey, this.userA, this.userB);
  final Uri apiUrl;
  final String anonKey;
  final _User userA;
  final _User userB;

  String get runtimeOrigin => apiUrl.replace(scheme: 'https').origin;
}

final class _ReadyStudy {
  const _ReadyStudy(this.session, this.study);
  final ReviewSession session;
  final SrsStudyRuntime study;
}

final class _RuntimeBundle {
  const _RuntimeBundle(this.runtime, this.journal);
  final PersistentSupabaseRuntime runtime;
  final NativeReviewJournal journal;
}

void _expect(bool value, String phase) {
  if (!value) throw _ProbeFailure(phase);
}

_Input _readInput(String rawInput) {
  try {
    final decoded = jsonDecode(rawInput);
    if (decoded is! Map<String, Object?> ||
        decoded.length != 4 ||
        !const {
          'api_url',
          'anon_key',
          'user_a',
          'user_b',
        }.every(decoded.containsKey)) {
      throw const FormatException();
    }
    final apiUrl = parseLocalSupabaseProbeApiUrl(decoded['api_url']);
    final anonKey = decoded['anon_key'];
    if (anonKey is! String ||
        anonKey.isEmpty ||
        anonKey.length > 4096 ||
        anonKey.contains(RegExp(r'\s'))) {
      throw const FormatException();
    }
    return _Input(
      apiUrl,
      anonKey,
      _readUser(decoded['user_a']),
      _readUser(decoded['user_b']),
    );
  } on Object {
    throw const _ProbeFailure('input');
  }
}

/// TEST ONLY: accepts an explicit dynamic API port only on the local IPv4
/// loopback. The production runtime still receives an HTTPS origin derived
/// from this validated URI; learner-provided remote URLs are never accepted.
Uri parseLocalSupabaseProbeApiUrl(Object? value) {
  if (value is! String || value.length > 2048 || value != value.trim()) {
    throw const FormatException();
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'http' ||
      uri.host != '127.0.0.1' ||
      !uri.hasPort ||
      uri.port < 1024 ||
      uri.port > 65535 ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const FormatException();
  }
  return uri.replace(path: '');
}

_User _readUser(Object? value) {
  if (value is! Map<String, Object?> ||
      value.length != 3 ||
      !const {'id', 'email', 'password'}.every(value.containsKey)) {
    throw const FormatException();
  }
  final id = value['id'];
  final email = value['email'];
  final password = value['password'];
  if (id is! String ||
      !_uuid.hasMatch(id) ||
      email is! String ||
      email.length > 254 ||
      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ||
      password is! String ||
      password.isEmpty ||
      password.length > 4096) {
    throw const FormatException();
  }
  return _User(id.toLowerCase(), email, password);
}

/// In-memory TEST ONLY port. It records operation names, never secret values.
final class _MemoryCredentialBackend implements SessionCredentialBackend {
  _MemoryCredentialBackend(this.events, String runtimeOrigin)
    : _target =
          SessionCredentialVault.targetPrefix +
          Uri.parse(runtimeOrigin).origin.toLowerCase();

  final List<String> events;
  final String _target;
  String? secret;

  @override
  Future<Object?> invoke(String method, Map<String, Object> arguments) async {
    if (arguments['target'] != _target) {
      throw const _ProbeFailure('vault-target');
    }
    switch (method) {
      case 'read':
        events.add('vault.read');
        return secret;
      case 'write':
        final token = arguments['token'];
        if (token is! String) throw const _ProbeFailure('vault-write');
        secret = token;
        events.add('vault.write');
        return true;
      case 'clear':
        secret = null;
        events.add('vault.clear');
        return true;
      default:
        throw const _ProbeFailure('vault-method');
    }
  }
}

/// The production runtime requires HTTPS. This TEST ONLY adapter accepts one
/// exact trusted HTTPS loopback origin and forwards it to local HTTP Supabase.
/// No caller-supplied or remote origin can pass this boundary.
final class _LoopbackHttpClient extends http.BaseClient {
  _LoopbackHttpClient(this.events, this.apiPort);

  final List<String> events;
  final int apiPort;
  final http.Client _inner = http.Client();
  bool _holdNextProfileResponse = false;
  bool _profileResponseCancelledBeforeRelease = false;
  bool _profileResponseReleased = false;
  bool _failNextReviewDispatch = false;
  Completer<void>? _profileResponseHeld;
  Completer<void>? _releaseProfileResponse;
  Completer<void>? _profileResponseConsumed;

  bool get profileResponseCancelledBeforeRelease =>
      _profileResponseCancelledBeforeRelease;

  void failNextReviewDispatch() {
    if (_failNextReviewDispatch) {
      throw StateError('Review dispatch gate already armed');
    }
    _failNextReviewDispatch = true;
  }

  void holdNextProfileResponse() {
    if (_holdNextProfileResponse || _profileResponseHeld != null) {
      throw StateError('Profile response gate already used');
    }
    _holdNextProfileResponse = true;
    _profileResponseCancelledBeforeRelease = false;
    _profileResponseReleased = false;
    _profileResponseHeld = Completer<void>();
    _releaseProfileResponse = Completer<void>();
    _profileResponseConsumed = Completer<void>();
  }

  Future<void> waitForProfileResponseHeld() async {
    await _profileResponseHeld!.future.timeout(const Duration(seconds: 15));
  }

  void releaseProfileResponse() {
    final release = _releaseProfileResponse;
    if (release == null || release.isCompleted) {
      throw StateError('Profile response gate is not waiting');
    }
    _profileResponseReleased = true;
    release.complete();
  }

  Future<void> waitForProfileResponseConsumed() async {
    await _profileResponseConsumed!.future.timeout(const Duration(seconds: 15));
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    if (uri.scheme != 'https' ||
        uri.host != '127.0.0.1' ||
        uri.port != apiPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (!uri.path.startsWith('/auth/v1/') &&
            !uri.path.startsWith('/rest/v1/'))) {
      throw const _ProbeFailure('http-origin');
    }
    events.add('http:${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}');
    final body = await request.finalize().toBytes();
    if (uri.path == '/rest/v1/rpc/submit_review' && _failNextReviewDispatch) {
      _failNextReviewDispatch = false;
      throw http.ClientException('TEST ONLY offline', uri);
    }
    final headers = Map<String, String>.from(request.headers)
      ..remove('content-length')
      ..remove('host');
    final forwarded = http.Request(request.method, uri.replace(scheme: 'http'));
    forwarded.headers.addAll(headers);
    forwarded.followRedirects = false;
    forwarded.maxRedirects = request.maxRedirects;
    forwarded.persistentConnection = request.persistentConnection;
    forwarded.bodyBytes = body;
    final response = await _inner.send(forwarded);
    if (uri.path != '/rest/v1/rpc/ensure_profile' ||
        !_holdNextProfileResponse) {
      return response;
    }
    _holdNextProfileResponse = false;
    if (response.statusCode != 200) {
      throw const _ProbeFailure('held-profile-status');
    }
    final responseBytes = await response.stream.toBytes();
    final held = _profileResponseHeld!;
    final release = _releaseProfileResponse!;
    final consumed = _profileResponseConsumed!;
    late final StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () {
        if (!held.isCompleted) held.complete();
        unawaited(() async {
          await release.future;
          if (!_profileResponseCancelledBeforeRelease && !controller.isClosed) {
            controller.add(responseBytes);
            await controller.close();
          }
          if (!consumed.isCompleted) consumed.complete();
        }());
      },
      onCancel: () {
        // The bounded production transport cancels its iterator after it has
        // buffered a complete body. Only cancellation before release means the
        // deliberately delayed response was actually discarded.
        if (!_profileResponseReleased) {
          _profileResponseCancelledBeforeRelease = true;
        }
        if (!consumed.isCompleted) consumed.complete();
      },
    );
    return http.StreamedResponse(
      controller.stream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    final release = _releaseProfileResponse;
    if (release != null && !release.isCompleted) {
      _profileResponseReleased = true;
      release.complete();
    }
    _inner.close();
  }
}

Future<_RuntimeBundle> _openBundle(
  Directory directory,
  _Input input,
  _MemoryCredentialBackend backend,
  _LoopbackHttpClient httpClient,
) async {
  final journal = await NativeReviewJournal.open(directory);
  try {
    final runtime = PersistentSupabaseRuntime(
      projectUrl: input.runtimeOrigin,
      publishableKey: input.anonKey,
      vault: SessionCredentialVault(
        projectUrl: input.runtimeOrigin,
        backend: backend,
      ),
      store: journal,
      httpClient: httpClient,
    );
    return _RuntimeBundle(runtime, journal);
  } on Object {
    await journal.close();
    rethrow;
  }
}

Future<_ReadyStudy> _waitReady(
  PersistentSupabaseRuntime runtime,
  String expectedUserId,
  String phase,
) async {
  try {
    await _waitForAccountSettlement(runtime);
  } on Object {
    throw _ProbeFailure(phase);
  }
  final state = runtime.account.state;
  final session = runtime.account.readySession;
  final study = runtime.account.readyRuntime;
  if (state.phase != AccountPhase.ready ||
      state.profile?.id != expectedUserId ||
      session?.userId != expectedUserId ||
      study is! SrsStudyRuntime) {
    throw _ProbeFailure(phase);
  }
  return _ReadyStudy(session!, study);
}

Future<void> _waitForAccountSettlement(
  PersistentSupabaseRuntime runtime,
) async {
  final account = runtime.account;
  // The Auth owner may have persisted a restored session just before the
  // AccountController receives its broadcast. Do not mistake that brief
  // signed-out snapshot for a settled profile state.
  if (runtime.persistence.currentSession == null) return;

  bool settled(AccountPhase phase) => const {
    AccountPhase.ready,
    AccountPhase.profileError,
    AccountPhase.signInError,
    AccountPhase.signOutError,
    AccountPhase.unavailable,
  }.contains(phase);

  if (settled(account.state.phase)) return;
  final completion = Completer<void>();
  late final StreamSubscription<AccountState> subscription;
  subscription = account.changes.listen(
    (state) {
      if (settled(state.phase) && !completion.isCompleted) {
        completion.complete();
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completion.isCompleted) {
        completion.completeError(error, stackTrace);
      }
    },
    onDone: () {
      if (!completion.isCompleted) {
        completion.completeError(StateError('Account state stream closed'));
      }
    },
  );

  // Subscribe before re-reading state to close the broadcast-stream race.
  final afterListen = account.state;
  if (settled(afterListen.phase) && !completion.isCompleted) {
    completion.complete();
  }
  try {
    await completion.future.timeout(const Duration(seconds: 15));
  } finally {
    await subscription.cancel();
  }
}

PreparedReview _prepare(SrsStudyRuntime study, SrsReview review, String phase) {
  final prepared = study.reviews.prepare(review);
  if (prepared == null) throw _ProbeFailure(phase);
  return prepared;
}

ReviewSuccess _success(ReviewOutcome outcome, String phase) {
  if (outcome is! ReviewSuccess) throw _ProbeFailure(phase);
  return outcome;
}

void _expectOrder(List<String> events, List<String> expected, String phase) {
  var previous = -1;
  for (final event in expected) {
    final index = events.indexOf(event);
    if (index <= previous) throw _ProbeFailure(phase);
    previous = index;
  }
}

int _count(List<String> events, String value) =>
    events.where((event) => event == value).length;

Future<void> _closeBundle(_RuntimeBundle bundle) async {
  await bundle.runtime.close();
  await bundle.journal.close();
}

SrsReview _review(
  ReviewRating rating,
  DateTime occurredAt, {
  String eventId = _eventId,
}) => SrsReview(
  clientEventId: eventId,
  itemType: LearningItemType.vocabulary,
  itemId: _dueItemId,
  rating: rating,
  isCorrect: rating.isCorrect,
  responseMs: 900,
  occurredAt: occurredAt,
);

/// LOCAL_TWO_DEVICE_OFFLINE_REPLAY: separate runtimes, journals and credential backends.
Future<void> _verifyLocalTwoDeviceOfflineReplay(_Input input) async {
  var phase = 'device-a-open';
  Directory? directoryA;
  Directory? directoryB;
  _RuntimeBundle? deviceA;
  _RuntimeBundle? deviceB;
  _LoopbackHttpClient? httpA;
  _LoopbackHttpClient? httpB;
  String? failure;
  final eventsA = <String>[];
  final eventsB = <String>[];
  final backendA = _MemoryCredentialBackend(eventsA, input.runtimeOrigin);
  final backendB = _MemoryCredentialBackend(eventsB, input.runtimeOrigin);

  try {
    final openedDirectoryA = await Directory.systemTemp.createTemp(
      'nd-device-a-offline-',
    );
    directoryA = openedDirectoryA;
    final openedHttpA = _LoopbackHttpClient(eventsA, input.apiUrl.port);
    httpA = openedHttpA;
    final openedA = await _openBundle(
      openedDirectoryA,
      input,
      backendA,
      openedHttpA,
    );
    deviceA = openedA;
    await openedA.runtime.start();
    await openedA.runtime.account.signIn(
      input.userA.email,
      input.userA.password,
    );
    final readyA = await _waitReady(
      openedA.runtime,
      input.userA.id,
      'device-a-login',
    );
    final offlineAt = DateTime.now().toUtc().add(const Duration(seconds: 1));
    final offlineReview = _review(
      ReviewRating.good,
      offlineAt,
      eventId: _deviceOfflineEventId,
    );
    openedHttpA.failNextReviewDispatch();

    phase = 'device-a-offline-stage';
    final offlineOutcome = await readyA.study.reviews.submit(
      _prepare(readyA.study, offlineReview, phase),
    );
    _expect(
      offlineOutcome is ReviewFailure &&
          offlineOutcome.code == ReviewErrorCode.networkUnavailable &&
          offlineOutcome.retryable,
      phase,
    );
    final pendingA = await openedA.journal.list(input.userA.id);
    _expect(
      pendingA.length == 1 &&
          pendingA.single.isPending &&
          pendingA.single.eventId == _deviceOfflineEventId &&
          pendingA.single.request['occurred_at'] ==
              offlineReview.toJson()['occurred_at'],
      'device-a-pending-journal',
    );
    final savedA = backendA.secret;
    _expect(savedA != null, 'device-a-refresh-persisted');

    phase = 'device-a-close-preserves-pending';
    await _closeBundle(openedA);
    deviceA = null;
    _expect(backendA.secret == savedA, phase);

    final openedDirectoryB = await Directory.systemTemp.createTemp(
      'nd-device-b-offline-',
    );
    directoryB = openedDirectoryB;
    final openedHttpB = _LoopbackHttpClient(eventsB, input.apiUrl.port);
    httpB = openedHttpB;
    final openedB = await _openBundle(
      openedDirectoryB,
      input,
      backendB,
      openedHttpB,
    );
    deviceB = openedB;
    await openedB.runtime.start();
    await openedB.runtime.account.signIn(
      input.userA.email,
      input.userA.password,
    );
    final readyB = await _waitReady(
      openedB.runtime,
      input.userA.id,
      'device-b-login',
    );
    _expect(
      !identical(readyA.session, readyB.session),
      'device-b-independent-auth-session',
    );
    eventsB.clear();

    phase = 'device-b-newer-event';
    final onlineReview = _review(
      ReviewRating.easy,
      offlineAt.add(const Duration(seconds: 2)),
      eventId: _deviceOnlineEventId,
    );
    final receiptB = _success(
      await readyB.study.reviews.submit(
        _prepare(readyB.study, onlineReview, phase),
      ),
      phase,
    );
    final recordsB = await openedB.journal.list(input.userA.id);
    _expect(
      receiptB.reviewCount == 3 &&
          recordsB.length == 1 &&
          recordsB.single.eventId == _deviceOnlineEventId &&
          recordsB.single.receipt?.reviewCount == 3 &&
          recordsB.single.rejection == null &&
          _count(eventsB, 'http:/rest/v1/rpc/submit_review') == 1,
      'device-b-authoritative-receipt',
    );

    phase = 'device-b-close';
    await _closeBundle(openedB);
    deviceB = null;

    eventsA.clear();
    phase = 'device-a-restore';
    final restoredA = await _openBundle(
      openedDirectoryA,
      input,
      backendA,
      openedHttpA,
    );
    deviceA = restoredA;
    await restoredA.runtime.start();
    final readyA2 = await _waitReady(restoredA.runtime, input.userA.id, phase);
    _expect(
      backendA.secret != null &&
          backendA.secret != savedA &&
          !identical(readyA.session, readyA2.session) &&
          !identical(readyB.session, readyA2.session),
      'device-a-fresh-session-restored',
    );
    final recovery = readyA2.study.reviews;
    _expect(recovery is ReviewRecovery, 'device-a-recovery-capability');
    final recovered = await (recovery as ReviewRecovery).recoverPending();
    _expect(
      recovered.length == 1 &&
          recovered.single.request['client_event_id'] ==
              _deviceOfflineEventId &&
          recovered.single.request['occurred_at'] ==
              offlineReview.toJson()['occurred_at'] &&
          _count(eventsA, 'http:/rest/v1/rpc/submit_review') == 0,
      'device-a-restores-exact-event-without-auto-submit',
    );

    phase = 'device-a-replay-after-reconnect';
    final staleOutcome = await readyA2.study.reviews.submit(recovered.single);
    _expect(
      staleOutcome is ReviewFailure &&
          staleOutcome.code == ReviewErrorCode.syncConflict,
      phase,
    );
    final settledA = await restoredA.journal.list(input.userA.id);
    _expect(
      settledA.length == 1 &&
          settledA.single.eventId == _deviceOfflineEventId &&
          settledA.single.receipt == null &&
          settledA.single.rejection?.code == ReviewErrorCode.syncConflict,
      'device-a-terminal-stale-rejection',
    );
    final unresolved = await (readyA2.study.reviews as ReviewRecovery)
        .recoverPending();
    _expect(
      unresolved.isEmpty &&
          _count(eventsA, 'http:/rest/v1/rpc/submit_review') == 1,
      'device-a-manual-replay-settles-once',
    );
    phase = 'device-a-authoritative-queue';
    final queueAfterConflict = await readyA2.study.queue.load(
      readyA2.session,
      PreviewLevel.n5,
    );
    _expect(queueAfterConflict.isEmpty, phase);

    phase = 'device-a-close-after-terminal-conflict';
    await _closeBundle(restoredA);
    deviceA = null;

    // The terminal rejection is part of the native journal, not process memory.
    // Reopen A with a fresh Auth session and prove the same event cannot dispatch
    // again or become a pending review after a second process restart.
    eventsA.clear();
    phase = 'device-a-restore-terminal-conflict';
    final restoredAfterConflict = await _openBundle(
      openedDirectoryA,
      input,
      backendA,
      openedHttpA,
    );
    deviceA = restoredAfterConflict;
    await restoredAfterConflict.runtime.start();
    final readyA3 = await _waitReady(
      restoredAfterConflict.runtime,
      input.userA.id,
      phase,
    );
    _expect(
      !identical(readyA2.session, readyA3.session),
      'device-a-new-session-after-terminal-conflict-restart',
    );
    final recoveryAfterRestart = readyA3.study.reviews;
    _expect(
      recoveryAfterRestart is ReviewRecovery,
      'device-a-recovery-capability-after-terminal-conflict-restart',
    );
    final pendingAfterRestart = await (recoveryAfterRestart as ReviewRecovery)
        .recoverPending();
    final terminalRecordsAfterRestart = await restoredAfterConflict.journal
        .list(input.userA.id);
    _expect(
      pendingAfterRestart.isEmpty &&
          terminalRecordsAfterRestart.length == 1 &&
          terminalRecordsAfterRestart.single.eventId == _deviceOfflineEventId &&
          terminalRecordsAfterRestart.single.receipt == null &&
          terminalRecordsAfterRestart.single.rejection?.code ==
              ReviewErrorCode.syncConflict &&
          _count(eventsA, 'http:/rest/v1/rpc/submit_review') == 0,
      'device-a-terminal-rejection-survives-restart',
    );

    phase = 'device-a-duplicate-terminal-replay';
    final duplicateTerminalOutcome = await readyA3.study.reviews.submit(
      _prepare(readyA3.study, offlineReview, phase),
    );
    _expect(
      duplicateTerminalOutcome is ReviewFailure &&
          duplicateTerminalOutcome.code == ReviewErrorCode.syncConflict &&
          _count(eventsA, 'http:/rest/v1/rpc/submit_review') == 0,
      phase,
    );

    phase = 'device-a-authoritative-queue-after-restart';
    final queueAfterRestart = await readyA3.study.queue.load(
      readyA3.session,
      PreviewLevel.n5,
    );
    _expect(queueAfterRestart.isEmpty, phase);

    phase = 'device-a-final-close';
    await _closeBundle(restoredAfterConflict);
    deviceA = null;
  } on Object catch (error) {
    failure = error is _ProbeFailure ? error.phase : phase;
  } finally {
    if (deviceA != null) {
      try {
        await _closeBundle(deviceA);
      } on Object {
        failure ??= 'cleanup-device-a';
      }
    }
    if (deviceB != null) {
      try {
        await _closeBundle(deviceB);
      } on Object {
        failure ??= 'cleanup-device-b';
      }
    }
    try {
      httpA?.close();
    } on Object {
      failure ??= 'cleanup-device-a-http';
    }
    try {
      httpB?.close();
    } on Object {
      failure ??= 'cleanup-device-b-http';
    }
    if (directoryA != null) {
      try {
        await directoryA.delete(recursive: true);
      } on Object {
        failure ??= 'cleanup-device-a-directory';
      }
    }
    if (directoryB != null) {
      try {
        await directoryB.delete(recursive: true);
      } on Object {
        failure ??= 'cleanup-device-b-directory';
      }
    }
  }
  if (failure != null) throw _ProbeFailure(failure);
}

Future<void> main() async {
  final rawInput = await stdin.transform(utf8.decoder).join();
  final status = await runSupabaseSdkRuntimeProbe(rawInput);
  stdout.writeln(status);
  if (status != 'LOCAL_SUPABASE_SDK_RUNTIME_OK') {
    exitCode = 1;
  }
}

Future<String> runSupabaseSdkRuntimeProbe(String rawInput) async {
  var phase = 'input';
  String? failure;
  _RuntimeBundle? bundle;
  Directory? journalDirectory;
  _LoopbackHttpClient? httpClient;
  try {
    final input = _readInput(rawInput);
    final events = <String>[];
    final backend = _MemoryCredentialBackend(events, input.runtimeOrigin);
    httpClient = _LoopbackHttpClient(events, input.apiUrl.port);
    journalDirectory = await Directory.systemTemp.createTemp(
      'nihongo-sdk-runtime-',
    );
    bundle = await _openBundle(journalDirectory, input, backend, httpClient);

    phase = 'empty-start';
    await bundle.runtime.start();
    _expect(
      bundle.runtime.account.state.phase == AccountPhase.signedOut &&
          backend.secret == null &&
          !events.any((event) => event.startsWith('http:')),
      phase,
    );

    httpClient.holdNextProfileResponse();
    events.clear();
    phase = 'a-held-profile-login';
    await bundle.runtime.account.signIn(
      input.userA.email,
      input.userA.password,
    );
    await httpClient.waitForProfileResponseHeld();
    final oldSessionA = bundle.runtime.persistence.currentSession;
    _expect(
      oldSessionA != null &&
          oldSessionA.userId == input.userA.id &&
          bundle.runtime.account.state.phase == AccountPhase.loadingProfile &&
          bundle.runtime.account.readyRuntime == null &&
          backend.secret != null,
      phase,
    );
    _expectOrder(events, const [
      'http:/auth/v1/token?grant_type=password',
      'vault.write',
      'http:/rest/v1/rpc/ensure_profile',
    ], 'a-held-profile-order');

    phase = 'a-logout-before-profile';
    await bundle.runtime.account.signOut();
    _expect(
      backend.secret == null &&
          bundle.runtime.account.state.phase == AccountPhase.signedOut &&
          bundle.runtime.account.readyRuntime == null,
      phase,
    );
    _expectOrder(events, const [
      'http:/auth/v1/token?grant_type=password',
      'vault.write',
      'http:/rest/v1/rpc/ensure_profile',
      'http:/auth/v1/logout?scope=local',
      'vault.clear',
    ], phase);

    events.clear();
    phase = 'b-login-while-a-profile-held';
    await bundle.runtime.account.signIn(
      input.userB.email,
      input.userB.password,
    );
    final readyBWhileAProfileHeld = await _waitReady(
      bundle.runtime,
      input.userB.id,
      phase,
    );
    _expect(
      backend.secret != null &&
          readyBWhileAProfileHeld.session.userId == input.userB.id,
      phase,
    );
    _expectOrder(events, const [
      'http:/auth/v1/token?grant_type=password',
      'vault.write',
      'http:/rest/v1/rpc/ensure_profile',
    ], 'b-password-order-before-a-late-profile');

    events.clear();
    phase = 'b-logout-before-a-relogin';
    await bundle.runtime.account.signOut();
    _expect(
      backend.secret == null &&
          bundle.runtime.account.state.phase == AccountPhase.signedOut,
      phase,
    );
    _expectOrder(events, const [
      'http:/auth/v1/logout?scope=local',
      'vault.clear',
    ], phase);

    events.clear();
    phase = 'a-relogin-same-owner-new-session';
    await bundle.runtime.account.signIn(
      input.userA.email,
      input.userA.password,
    );
    final readyA = await _waitReady(bundle.runtime, input.userA.id, phase);
    final refreshA = backend.secret;
    _expect(
      oldSessionA != null &&
          !identical(oldSessionA, readyA.session) &&
          readyA.session.userId == input.userA.id &&
          refreshA != null,
      phase,
    );
    _expectOrder(events, const [
      'http:/auth/v1/token?grant_type=password',
      'vault.write',
      'http:/rest/v1/rpc/ensure_profile',
    ], 'a-relogin-order');

    phase = 'a-late-old-profile-response';
    httpClient.releaseProfileResponse();
    await httpClient.waitForProfileResponseConsumed();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _expect(
      !httpClient.profileResponseCancelledBeforeRelease &&
          bundle.runtime.account.state.phase == AccountPhase.ready &&
          bundle.runtime.account.state.profile?.id == input.userA.id &&
          identical(bundle.runtime.account.readySession, readyA.session) &&
          identical(bundle.runtime.account.readyRuntime, readyA.study) &&
          backend.secret == refreshA,
      phase,
    );

    phase = 'a-due-queue';
    final dueA = await readyA.study.queue.load(readyA.session, PreviewLevel.n5);
    _expect(
      dueA.length == 1 &&
          dueA.single.itemId == _dueItemId &&
          dueA.single.prompt == _duePrompt &&
          dueA.single.reading == _dueReading &&
          dueA.single.answerVi == _dueAnswer,
      phase,
    );

    final reviewA = _review(ReviewRating.good, DateTime.now().toUtc());
    phase = 'a-submit';
    final receiptA = _success(
      await readyA.study.reviews.submit(_prepare(readyA.study, reviewA, phase)),
      phase,
    );
    _expect(receiptA.reviewCount == 2, phase);

    phase = 'a-queue-after-review';
    final dueAfterA = await readyA.study.queue.load(
      readyA.session,
      PreviewLevel.n5,
    );
    _expect(dueAfterA.isEmpty, phase);

    final firstRefreshToken = backend.secret;
    _expect(firstRefreshToken != null, 'a-close-preserves-token');
    phase = 'a-close-preserves-token';
    await _closeBundle(bundle);
    bundle = null;
    _expect(backend.secret == firstRefreshToken, phase);

    phase = 'a-restore';
    bundle = await _openBundle(journalDirectory, input, backend, httpClient);
    events.clear();
    await bundle.runtime.start();
    final readyA2 = await _waitReady(bundle.runtime, input.userA.id, phase);
    _expect(
      backend.secret != null && backend.secret != firstRefreshToken,
      phase,
    );
    _expectOrder(events, const [
      'http:/auth/v1/token?grant_type=refresh_token',
      'vault.write',
      'http:/rest/v1/rpc/ensure_profile',
    ], 'a-restore-order');

    phase = 'a-local-replay';
    final beforeLocalReplay = _count(events, 'http:/rest/v1/rpc/submit_review');
    final localReplay = _success(
      await readyA2.study.reviews.submit(
        _prepare(readyA2.study, reviewA, phase),
      ),
      phase,
    );
    final aRecords = await bundle.journal.list(input.userA.id);
    _expect(
      localReplay.reviewCount == 2 &&
          _count(events, 'http:/rest/v1/rpc/submit_review') ==
              beforeLocalReplay &&
          aRecords.length == 1 &&
          aRecords.single.receipt?.reviewCount == 2,
      phase,
    );

    events.clear();
    phase = 'a-logout';
    await bundle.runtime.account.signOut();
    _expect(
      backend.secret == null &&
          bundle.runtime.account.state.phase == AccountPhase.signedOut,
      phase,
    );
    _expectOrder(events, const [
      'http:/auth/v1/logout?scope=local',
      'vault.clear',
    ], 'a-logout-order');

    phase = 'b-password-login';
    await bundle.runtime.account.signIn(
      input.userB.email,
      input.userB.password,
    );
    final readyB = await _waitReady(bundle.runtime, input.userB.id, phase);
    _expectOrder(events, const [
      'http:/auth/v1/logout?scope=local',
      'vault.clear',
      'http:/auth/v1/token?grant_type=password',
      'vault.write',
      'http:/rest/v1/rpc/ensure_profile',
    ], 'b-password-order');

    phase = 'b-queue-isolation';
    final dueB = await readyB.study.queue.load(readyB.session, PreviewLevel.n5);
    final aRecordsAfterSwitch = await bundle.journal.list(input.userA.id);
    final bRecordsBeforeReview = await bundle.journal.list(input.userB.id);
    _expect(
      dueB.isEmpty &&
          aRecordsAfterSwitch.length == 1 &&
          bRecordsBeforeReview.isEmpty,
      phase,
    );

    phase = 'b-same-event';
    final reviewB = _review(ReviewRating.easy, DateTime.now().toUtc());
    final receiptB = _success(
      await readyB.study.reviews.submit(_prepare(readyB.study, reviewB, phase)),
      phase,
    );
    final bRecordsAfterReview = await bundle.journal.list(input.userB.id);
    _expect(
      receiptB.reviewCount == 1 &&
          bRecordsAfterReview.length == 1 &&
          bRecordsAfterReview.single.eventId == _eventId &&
          aRecordsAfterSwitch.single.eventId == _eventId,
      'b-owner-partition',
    );

    events.clear();
    phase = 'b-logout';
    await bundle.runtime.account.signOut();
    _expect(
      backend.secret == null &&
          bundle.runtime.account.state.phase == AccountPhase.signedOut,
      phase,
    );
    _expectOrder(events, const [
      'http:/auth/v1/logout?scope=local',
      'vault.clear',
    ], phase);
    await _closeBundle(bundle);
    bundle = null;

    phase = 'two-device-offline-replay';
    await _verifyLocalTwoDeviceOfflineReplay(input);
  } on Object catch (error) {
    failure = error is _ProbeFailure ? error.phase : phase;
  } finally {
    if (bundle != null) {
      try {
        await _closeBundle(bundle);
      } on Object {
        failure ??= 'cleanup-runtime';
      }
    }
    try {
      httpClient?.close();
    } on Object {
      failure ??= 'cleanup-http';
    }
    if (journalDirectory != null) {
      try {
        await journalDirectory.delete(recursive: true);
      } on Object {
        failure ??= 'cleanup-directory';
      }
    }
  }

  if (failure == null) {
    return 'LOCAL_SUPABASE_SDK_RUNTIME_OK';
  }
  return 'LOCAL_SUPABASE_SDK_RUNTIME_FAILED:$failure';
}
