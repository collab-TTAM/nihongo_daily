// TEST ONLY: exercise the caller-owned Supabase SDK runtime against the
// disposable loopback GoTrue/PostgREST stack. Never used by the app default.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_runtime.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

const _runtimeOrigin = 'https://127.0.0.1:54321';
const _apiUrl = 'http://127.0.0.1:54321';
const _dueItemId = '00000000-0000-4000-8000-000000000002';
const _eventId = '00000000-0000-4000-8000-0000000000a1';
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
  const _Input(this.anonKey, this.userA, this.userB);
  final String anonKey;
  final _User userA;
  final _User userB;
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
        }.every(decoded.containsKey) ||
        decoded['api_url'] != _apiUrl) {
      throw const FormatException();
    }
    final anonKey = decoded['anon_key'];
    if (anonKey is! String ||
        anonKey.isEmpty ||
        anonKey.length > 4096 ||
        anonKey.contains(RegExp(r'\s'))) {
      throw const FormatException();
    }
    return _Input(
      anonKey,
      _readUser(decoded['user_a']),
      _readUser(decoded['user_b']),
    );
  } on Object {
    throw const _ProbeFailure('input');
  }
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
  _MemoryCredentialBackend(this.events)
    : _target =
          SessionCredentialVault.targetPrefix +
          Uri.parse(_runtimeOrigin).origin.toLowerCase();

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
  _LoopbackHttpClient(this.events);

  final List<String> events;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    if (uri.scheme != 'https' ||
        uri.host != '127.0.0.1' ||
        uri.port != 54321 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (!uri.path.startsWith('/auth/v1/') &&
            !uri.path.startsWith('/rest/v1/'))) {
      throw const _ProbeFailure('http-origin');
    }
    events.add('http:' + uri.path + (uri.hasQuery ? '?' + uri.query : ''));
    final body = await request.finalize().toBytes();
    final headers = Map<String, String>.from(request.headers)
      ..remove('content-length')
      ..remove('host');
    final forwarded = http.Request(request.method, uri.replace(scheme: 'http'));
    forwarded.headers.addAll(headers);
    forwarded.followRedirects = false;
    forwarded.maxRedirects = request.maxRedirects;
    forwarded.persistentConnection = request.persistentConnection;
    forwarded.bodyBytes = body;
    return _inner.send(forwarded);
  }

  @override
  void close() => _inner.close();
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
      projectUrl: _runtimeOrigin,
      publishableKey: input.anonKey,
      vault: SessionCredentialVault(
        projectUrl: _runtimeOrigin,
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
    await runtime.account.waitForCurrentProfile();
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

SrsReview _review(ReviewRating rating, DateTime occurredAt) => SrsReview(
  clientEventId: _eventId,
  itemType: LearningItemType.vocabulary,
  itemId: _dueItemId,
  rating: rating,
  isCorrect: rating.isCorrect,
  responseMs: 900,
  occurredAt: occurredAt,
);

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
    final backend = _MemoryCredentialBackend(events);
    httpClient = _LoopbackHttpClient(events);
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

    events.clear();
    phase = 'a-password-login';
    await bundle.runtime.account.signIn(
      input.userA.email,
      input.userA.password,
    );
    final readyA = await _waitReady(bundle.runtime, input.userA.id, phase);
    _expectOrder(events, const [
      'http:/auth/v1/token?grant_type=password',
      'vault.write',
      'http:/rest/v1/rpc/ensure_profile',
    ], 'a-password-order');

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
