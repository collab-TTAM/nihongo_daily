// TEST ONLY actual pinned SDK/runtime with simulated Auth/vault/HTTP. No hosted
// JWT verification, provider activation or live learner acceptance.
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_receipt_lookup.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_snapshot.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nihongo_daily/features/ai/data/windows_pending_command_protector.dart';
import 'package:nihongo_daily/features/ai/domain/pending_conversation_command_envelope.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/retained_conversation_command.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/auth/application/persistent_account_startup.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/app/staging_bootstrap.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import '../srs/session_lifecycle_fixtures.dart' as lifecycle;
import '../srs/supabase_review_binding_test.dart' as wire;
import '../srs/own_profile_fixtures.dart' as profile;

final unauthorized = isA<AiTextFailure>().having(
  (e) => e.code,
  'code',
  AiTextErrorCode.unauthorized,
);
final question = TutorExplainRequest(
  level: AiTextLevel.n5,
  questionVi: 'TEST ONLY',
);
late Map<String, Object?> fixtures;
http.StreamedResponse answer([String operation = 'tutor_explain']) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(fixtures['${operation}_response']))),
      200,
      headers: {'content-type': 'application/json'},
    );

final class _AiHttp extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  Future<http.StreamedResponse> Function(http.BaseRequest)? onSend;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return Future<http.StreamedResponse>.sync(() => onSend!(request));
  }

  @override
  void close() {
    closed = true;
  }
}

final class _ReceiptBackend implements SecureConversationReceiptBackend {
  Object? value;
  bool failClear = false;
  bool failRead = false;
  bool failBeforeWrite = false;
  bool failAfterWrite = false;
  Completer<void>? writeWait;
  final entered = Completer<void>();
  final calls = <String>[];
  @override
  Future<Object?> read(String target) async {
    calls.add('read');
    if (failRead) throw StateError('TEST_ONLY_PRIVATE_RECEIPT_READ');
    return value;
  }

  @override
  Future<void> write(String target, String encoded) async {
    entered.complete();
    await writeWait?.future;
    if (failBeforeWrite) throw StateError('TEST_ONLY_PRIVATE_RECEIPT_WRITE');
    value = encoded;
    calls.add('write');
    if (failAfterWrite) throw StateError('TEST_ONLY_PRIVATE_RECEIPT_WRITE');
  }

  @override
  Future<void> clear(String target) async {
    calls.add('clear');
    if (failClear) throw StateError('TEST_ONLY_PRIVATE_CLEAR');
    value = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late lifecycle.MemoryVault backend;
  late SessionCredentialVault vault;
  late Directory directory;
  late NativeReviewJournal journal;
  late MockClient authHttp;
  late _AiHttp aiHttp;
  late PersistentSupabaseRuntime runtime;
  late DateTime now;
  late String user;
  late String secret;
  late int generation;
  late int profileStatus;
  Completer<http.Response>? profileWait;
  final authRequests = <http.Request>[];

  PersistentSupabaseRuntime build({
    bool enabled = true,
    bool conversationEnabled = false,
    ConversationReceiptStore? receiptStore,
  }) => PersistentSupabaseRuntime(
    projectUrl: wire.origin,
    publishableKey: wire.key,
    vault: vault,
    store: journal,
    conversationReceiptStore: receiptStore,
    httpClient: authHttp,
    aiHttpClient: aiHttp,
    now: () => now,
    aiTextEnabled: enabled,
    aiConversationEnabled: conversationEnabled,
    requestTimeout: const Duration(seconds: 2),
  );
  Future<void> ready() async {
    if (runtime.account.state.phase != AccountPhase.ready) {
      final state = await runtime.account.changes
          .firstWhere(
            (s) => const {
              AccountPhase.ready,
              AccountPhase.profileError,
              AccountPhase.signInError,
              AccountPhase.unavailable,
            }.contains(s.phase),
          )
          .timeout(const Duration(seconds: 5));
      expect(state.phase, AccountPhase.ready);
    }
    expect(runtime.account.readyRuntime, isNotNull);
  }

  Future<void> login() async {
    await runtime.account.signIn(
      'fixture@example.invalid',
      'TEST_ONLY_PASSWORD',
    );
    await ready();
  }

  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  setUp(() async {
    backend = lifecycle.MemoryVault();
    vault = SessionCredentialVault(projectUrl: wire.origin, backend: backend);
    directory = await Directory.systemTemp.createTemp('nd-ai-owned-');
    journal = await NativeReviewJournal.open(directory);
    now = DateTime.utc(2026, 10, 24);
    user = wire.a;
    secret = 'TEST_ONLY_REFRESH_1';
    generation = 0;
    profileStatus = 200;
    profileWait = null;
    authRequests.clear();
    aiHttp = _AiHttp()
      ..onSend = (r) async => answer(r.url.path.split('/').last);
    authHttp = MockClient((r) async {
      authRequests.add(r);
      if (r.url.path == '/auth/v1/token') {
        return http.Response(
          jsonEncode({
            'access_token': wire.token(
              user,
              wire.sid1,
              now,
              generation: generation,
            ),
            'refresh_token': secret,
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': user,
              'aud': 'authenticated',
              'role': 'authenticated',
              'created_at': '2026-10-24T00:00:00Z',
              'app_metadata': <String, Object>{},
              'user_metadata': <String, Object>{},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (r.url.path == '/auth/v1/logout') return http.Response('', 204);
      if (r.url.path == '/rest/v1/rpc/ensure_profile') {
        return profileWait?.future ??
            Future.value(
              http.Response(
                profileStatus == 200
                    ? jsonEncode(profile.profile(user))
                    : '{"message":"TEST_ONLY_PROFILE_SECRET"}',
                profileStatus,
                headers: {'content-type': 'application/json'},
              ),
            );
      }
      throw StateError('unexpected TEST ONLY Auth/REST endpoint');
    });
    runtime = build();
  });
  tearDown(() async {
    await runtime.close();
    await journal.close();
    await directory.delete(recursive: true);
    authHttp.close();
    aiHttp.close();
  });

  late ConversationReceiptStore receiptStore;
  Future<_ReceiptBackend> openReceiptRuntime() async {
    await runtime.close();
    final receipts = _ReceiptBackend();
    receiptStore = ConversationReceiptStore(
      scope: ConversationReceiptScope(projectUrl: wire.origin, ownerId: wire.a),
      backend: receipts,
    );
    runtime = build(conversationEnabled: true, receiptStore: receiptStore);
    return receipts;
  }

  const protectionChannel = MethodChannel(
    'nihongo_daily/conversation_receipts_v1',
  );
  final protectionCalls = <MethodCall>[];
  void nativeProtection(Future<Object?> Function(MethodCall) handler) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    protectionCalls.clear();
    messenger.setMockMethodCallHandler(protectionChannel, (call) {
      protectionCalls.add(call);
      return handler(call);
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(protectionChannel, null);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  PendingConversationCommandEnvelope protectedCommand() =>
      PendingConversationCommandEnvelope.fromStart(
        projectUrl: wire.origin,
        ownerId: wire.a,
        request: StartConversationRequest.fromJson(
          fixtures['start_conversation_request'],
        ),
      );
  Matcher getProtectionUnauthorized() => isA<CommandProtectionFailure>().having(
    (e) => e.code,
    'code',
    CommandProtectionError.unauthorized,
  );
  test('owned command factory unavailable without receipt opt-in', () async {
    nativeProtection((_) async => Uint8List(1));
    await login();
    expect(runtime.createWindowsPendingCommandProtector(), isNull);
    expect(protectionCalls, isEmpty);
  });
  test(
    'owned command factory waits for persisted token own profile and caches generation',
    () async {
      nativeProtection((_) async => Uint8List.fromList([1, 2]));
      await openReceiptRuntime();
      expect(runtime.createWindowsPendingCommandProtector(), isNull);
      profileWait = Completer<http.Response>();
      final signing = runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      try {
        await Future<void>.delayed(Duration.zero);
        expect(runtime.createWindowsPendingCommandProtector(), isNull);
        profileWait!.complete(
          http.Response(
            jsonEncode(profile.profile(user)),
            200,
            headers: {'content-type': 'application/json'},
          ),
        );
        await signing;
        await ready();
        expect(await vault.readRefreshToken(), secret);
        final p = runtime.createWindowsPendingCommandProtector();
        expect(p, isNotNull);
        expect(runtime.createWindowsPendingCommandProtector(), same(p));
        expect(protectionCalls, isEmpty);
        expect(await p!.protect(protectedCommand()), [1, 2]);
        expect(aiHttp.requests, isEmpty);
      } finally {
        if (!profileWait!.isCompleted)
          profileWait!.complete(http.Response('{}', 500));
        await signing;
      }
    },
  );
  for (final action in ['refresh', 'logout', 'close']) {
    for (final error in [false, true]) {
      test(
        'owned command $action waits for actual native drain error=$error',
        () async {
          final held = Completer<Object?>();
          final entered = Completer<void>();
          nativeProtection((_) {
            entered.complete();
            return held.future;
          });
          await openReceiptRuntime();
          await login();
          final p = runtime.createWindowsPendingCommandProtector()!;
          final operation = p.protect(protectedCommand());
          final rejected = expectLater(
            operation,
            throwsA(getProtectionUnauthorized()),
          );
          await entered.future;
          generation++;
          secret = 'TEST_ONLY_COMMAND_REFRESH_2';
          final Future<void> ending;
          if (action == 'refresh') {
            ending = runtime.refresh();
            expect(runtime.refresh(), same(ending));
          } else if (action == 'logout') {
            ending = runtime.account.signOut();
          } else {
            ending = runtime.close();
            expect(runtime.close(), same(ending));
          }
          var settled = false;
          final observed = ending.then<void>((_) {
            settled = true;
          });
          try {
            expect(p.isCurrent, false);
            expect(runtime.createWindowsPendingCommandProtector(), isNull);
            await Future<void>.delayed(Duration.zero);
            expect(settled, false);
            if (action == 'logout') {
              expect(await vault.readRefreshToken(), isNull);
            }
            expect(protectionCalls.length, 1);
            if (error) {
              held.completeError(StateError('PRIVATE_NATIVE_LATE'));
            } else {
              held.complete(Uint8List.fromList([7, 8]));
            }
            await rejected;
            await observed;
            expect(settled, true);
            expect(p.isCurrent, false);
            if (action == 'refresh') {
              await ready();
              final next = runtime.createWindowsPendingCommandProtector();
              expect(next, isNotNull);
              expect(next, isNot(same(p)));
              expect(await vault.readRefreshToken(), secret);
            } else {
              expect(runtime.createWindowsPendingCommandProtector(), isNull);
              if (action == 'logout') {
                user = wire.b;
                await login();
                expect(runtime.createWindowsPendingCommandProtector(), isNull);
                await runtime.account.signOut();
                user = wire.a;
                await login();
                expect(runtime.createWindowsPendingCommandProtector(), isNull);
              }
            }
            expect(aiHttp.requests, isEmpty);
          } finally {
            if (!held.isCompleted) held.complete(Uint8List(1));
            await rejected;
            await observed;
          }
        },
      );
    }
  }

  StartConversationRequest startRequest() =>
      StartConversationRequest.fromJson(fixtures['start_conversation_request']);
  Matcher aiCode(AiTextErrorCode code) =>
      isA<AiTextFailure>().having((e) => e.code, 'code', code);

  ConversationReceiptReference receiptReference({String owner = wire.a}) =>
      ConversationReceiptReference.fromStart(
        projectUrl: wire.origin,
        ownerId: owner,
        request: startRequest(),
      );
  http.StreamedResponse receiptAnswer(String status) => http.StreamedResponse(
    Stream.value(
      utf8.encode(
        jsonEncode(
          status == 'UNKNOWN'
              ? []
              : [
                  {
                    'user_id': wire.a,
                    'operation': 'start_conversation',
                    'client_event_id': startRequest().clientEventId,
                    'status': status,
                    'response_json': status == 'COMPLETED'
                        ? fixtures['start_conversation_response']
                        : null,
                  },
                ],
        ),
      ),
    ),
    200,
    headers: {'content-type': 'application/json'},
  );

  ConversationReceiptReference originalReference(String op) =>
      ConversationReceiptReference.fromJson({
        'version': 1,
        'project_origin': wire.origin,
        'owner_id': wire.a,
        'operation': op,
        'client_event_id':
            (fixtures['${op}_request']!
                as Map<String, Object?>)['client_event_id'],
      });
  Future<ConversationReceiptSnapshot> originalRead(
    CapturedConversationReceiptLookup reader,
    String op,
  ) => switch (op) {
    'start_conversation' => reader.lookupStart(
      originalReference(op),
      StartConversationRequest.fromJson(fixtures['${op}_request']),
    ),
    'conversation_turn' => reader.lookupTurn(
      originalReference(op),
      ConversationTurnRequest.fromJson(fixtures['${op}_request']),
    ),
    'finish_conversation' => reader.lookupFinish(
      originalReference(op),
      FinishConversationRequest.fromJson(fixtures['${op}_request']),
    ),
    _ => throw StateError('TEST ONLY operation'),
  };
  http.StreamedResponse originalAnswer(String op, String status) =>
      http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode(
              status == 'UNKNOWN'
                  ? []
                  : [
                      {
                        'user_id': wire.a,
                        'operation': op,
                        'client_event_id': originalReference(op).clientEventId,
                        'request_json': fixtures['${op}_request'],
                        'status': status,
                        'response_json': status == 'COMPLETED'
                            ? fixtures['${op}_response']
                            : null,
                      },
                    ],
            ),
          ),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
  for (final op in [
    'start_conversation',
    'conversation_turn',
    'finish_conversation',
  ]) {
    for (final status in ['UNKNOWN', 'PENDING', 'COMPLETED']) {
      test('owned original receipt reader shared SDK $op $status', () async {
        final receipts = await openReceiptRuntime();
        await runtime.start();
        expect(runtime.createConversationReceiptLookup(), isNull);
        await login();
        final reader = runtime.createConversationReceiptLookup()!;
        expect(
          identical(reader, runtime.createConversationReceiptLookup()),
          isTrue,
        );
        expect(aiHttp.requests, isEmpty);
        aiHttp.onSend = (r) async {
          expect(r.method, 'GET');
          expect(r.url.origin, wire.origin);
          expect(r.url.path, '/rest/v1/operation_receipts');
          expect(r.url.queryParameters, {
            'select':
                'user_id,operation,client_event_id,request_json,status,response_json',
            'user_id': 'eq.${wire.a}',
            'operation': 'eq.$op',
            'client_event_id': 'eq.${originalReference(op).clientEventId}',
            'limit': '2',
          });
          expect((r as http.Request).body, isEmpty);
          expect(
            r.headers['authorization'],
            'Bearer ${wire.token(user, wire.sid1, now, generation: generation)}',
          );
          expect(r.headers['cache-control'], 'no-store');
          expect(r.followRedirects, isFalse);
          return originalAnswer(op, status);
        };
        final result = await originalRead(reader, op);
        expect(result.status.name, status.toLowerCase());
        expect(
          result.start != null,
          status == 'COMPLETED' && op == 'start_conversation',
        );
        expect(
          result.turn != null,
          status == 'COMPLETED' && op == 'conversation_turn',
        );
        expect(
          result.finish != null,
          status == 'COMPLETED' && op == 'finish_conversation',
        );
        expect(receipts.calls, isEmpty);
        expect(receipts.value, isNull);
        expect(aiHttp.requests.length, 1);
      });
    }
  }

  test(
    'owned original receipt reader completed projection never clears pending',
    () async {
      final receipts = await openReceiptRuntime();
      receipts.value = receiptReference().encode();
      await runtime.start();
      await login();
      aiHttp.onSend = (_) async =>
          originalAnswer('start_conversation', 'COMPLETED');
      final reader = runtime.createConversationReceiptLookup()!;
      expect(
        (await originalRead(reader, 'start_conversation')).status,
        ConversationReceiptStatus.completed,
      );
      expect(receipts.value, receiptReference().encode());
      await expectLater(
        runtime.createAiConversationSession()!.start(startRequest()),
        throwsA(aiCode(AiTextErrorCode.syncConflict)),
      );
      expect(aiHttp.requests.length, 1);
      expect(receipts.calls, isNot(contains('clear')));
      expect(receipts.value, receiptReference().encode());
    },
  );
  test(
    'owned original receipt reader rejects foreign owner without HTTP',
    () async {
      await openReceiptRuntime();
      await runtime.start();
      await login();
      await expectLater(
        runtime.createConversationReceiptLookup()!.lookupStart(
          receiptReference(owner: wire.b),
          startRequest(),
        ),
        throwsA(unauthorized),
      );
      expect(aiHttp.requests, isEmpty);
    },
  );
  for (final status in ['UNKNOWN', 'PENDING', 'COMPLETED']) {
    test('owned retained command lookup $status never releases pending', () async {
      final receipts = await openReceiptRuntime();
      await runtime.start();
      await login();
      final flow = runtime.createAiConversationSession()!;
      final original = startRequest();
      aiHttp.onSend = (r) async {
        expect(r.method, 'POST');
        throw StateError('TEST ONLY uncertain network result');
      };
      await expectLater(flow.start(original), throwsA(isA<AiTextFailure>()));
      expect(aiHttp.requests, hasLength(1));
      expect(receipts.value, receiptReference().encode());
      final retained = flow.retainedCommand! as RetainedConversationStart;
      expect(identical(retained.request, original), isTrue);
      expect(identical(flow, runtime.createAiConversationSession()), isTrue);
      aiHttp.onSend = (r) async {
        expect(r.method, 'GET');
        expect(r.url.path, '/rest/v1/operation_receipts');
        expect(
          r.url.queryParameters['select'],
          'user_id,operation,client_event_id,request_json,status,response_json',
        );
        expect(
          r.headers['authorization'],
          'Bearer ${wire.token(user, wire.sid1, now, generation: generation)}',
        );
        return originalAnswer('start_conversation', status);
      };
      final result = await runtime
          .createConversationReceiptLookup()!
          .lookupStart(receiptReference(), retained.request);
      expect(result.status.name, status.toLowerCase());
      expect(flow.snapshot.phase, ConversationSessionPhase.notStarted);
      expect(flow.hasUnresolvedMutation, isTrue);
      expect(identical(flow.retainedCommand, retained), isTrue);
      await expectLater(
        flow.start(retained.request),
        throwsA(aiCode(AiTextErrorCode.syncConflict)),
      );
      await expectLater(
        flow.start(
          StartConversationRequest(
            scenarioId: original.scenarioId,
            level: original.level,
            clientEventId: '44444444-4444-4444-8444-444444444444',
          ),
        ),
        throwsA(isA<AiTextRequestPending>()),
      );
      expect(identical(flow.retainedCommand, retained), isTrue);
      expect(aiHttp.requests.map((r) => r.method), ['POST', 'GET']);
      expect(receipts.calls, isNot(contains('clear')));
      expect(receipts.value, receiptReference().encode());
      await runtime.account.signOut();
      expect(flow.retainedCommand, isNull);
      expect(receipts.value, isNull);
      expect(backend.secret, isNull);
      expect(aiHttp.requests, hasLength(2));
    });
  }
  for (final logout in [false, true]) {
    test(
      'owned original receipt reader actual drain on transition logout=$logout',
      () async {
        final receipts = await openReceiptRuntime();
        receipts.value = receiptReference().encode();
        await runtime.start();
        await login();
        final reader = runtime.createConversationReceiptLookup()!;
        final held = Completer<http.StreamedResponse>();
        final entered = Completer<void>();
        final aborted = Completer<void>();
        aiHttp.onSend = (r) {
          unawaited(
            (r as http.AbortableRequest).abortTrigger!.then(
              (_) => aborted.complete(),
            ),
          );
          entered.complete();
          return held.future;
        };
        final result = expectLater(
          originalRead(reader, 'start_conversation'),
          throwsA(unauthorized),
        );
        Future<void>? transition;
        try {
          await entered.future;
          await expectLater(
            runtime.createAiTextRepository()!.explain(question),
            throwsA(isA<AiTextRequestPending>()),
          );
          var done = false;
          transition = (logout ? runtime.account.signOut() : runtime.refresh())
              .then((_) => done = true);
          await aborted.future;
          await result;
          await lifecycle.flush();
          expect(reader.isCurrent, isFalse);
          expect(runtime.createConversationReceiptLookup(), isNull);
          expect(receipts.value, receiptReference().encode());
          expect(receipts.calls, isNot(contains('clear')));
          if (logout) {
            expect(done, isFalse);
            expect(backend.secret, isNull);
          }
          held.complete(originalAnswer('start_conversation', 'COMPLETED'));
          await transition;
          await lifecycle.flush();
          if (logout) {
            expect(runtime.account.state.phase, AccountPhase.signedOut);
            expect(receipts.value, isNull);
            expect(runtime.createConversationReceiptLookup(), isNull);
          } else {
            await ready();
            final fresh = runtime.createConversationReceiptLookup()!;
            expect(identical(fresh, reader), isFalse);
            expect(receipts.value, receiptReference().encode());
          }
          expect(aiHttp.requests.length, 1);
          expect(aiHttp.closed, isFalse);
        } finally {
          if (!held.isCompleted) {
            held.complete(originalAnswer('start_conversation', 'PENDING'));
          }
          await result;
          await transition;
        }
      },
    );
  }

  for (final status in ['UNKNOWN', 'PENDING', 'COMPLETED']) {
    test('owned receipt reader shared SDK status=$status', () async {
      final receipts = await openReceiptRuntime();
      await runtime.start();
      expect(runtime.createConversationReceiptLookup(), isNull);
      await login();
      final reader = runtime.createConversationReceiptLookup()!;
      expect(
        identical(reader, runtime.createConversationReceiptLookup()),
        isTrue,
      );
      expect(aiHttp.requests, isEmpty);
      aiHttp.onSend = (r) async {
        expect(r.method, 'GET');
        expect(r.url.path, '/rest/v1/operation_receipts');
        expect(r.url.queryParameters['user_id'], 'eq.${wire.a}');
        expect(
          r.headers['authorization'],
          'Bearer ${wire.token(user, wire.sid1, now, generation: generation)}',
        );
        return receiptAnswer(status);
      };
      expect(
        (await reader.lookup(receiptReference())).status.name,
        status.toLowerCase(),
      );
      expect(receipts.calls, isEmpty);
      expect(receipts.value, isNull);
    });
  }
  test('owned receipt reader waits own profile and explicit flag', () async {
    await openReceiptRuntime();
    profileWait = Completer<http.Response>();
    await runtime.start();
    final loginFuture = runtime.account.signIn(
      'fixture@example.invalid',
      'TEST_ONLY_PASSWORD',
    );
    try {
      await lifecycle.flush();
      expect(runtime.createConversationReceiptLookup(), isNull);
      expect(aiHttp.requests, isEmpty);
      profileWait!.complete(
        http.Response(
          jsonEncode(profile.profile(user)),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await loginFuture;
      await ready();
      expect(runtime.createConversationReceiptLookup(), isNotNull);
      await runtime.close();
      runtime = build(conversationEnabled: false);
      await runtime.start();
      await ready();
      expect(runtime.createConversationReceiptLookup(), isNull);
      expect(aiHttp.requests, isEmpty);
    } finally {
      if (!profileWait!.isCompleted) {
        profileWait!.complete(http.Response('{}', 500));
      }
      await loginFuture;
    }
  });
  test(
    'owned receipt reader completed projection never clears pending',
    () async {
      final receipts = await openReceiptRuntime();
      receipts.value = receiptReference().encode();
      await runtime.start();
      await login();
      aiHttp.onSend = (_) async => receiptAnswer('COMPLETED');
      final reader = runtime.createConversationReceiptLookup()!;
      expect(
        (await reader.lookup(receiptReference())).status,
        ConversationReceiptStatus.completed,
      );
      expect(receipts.value, receiptReference().encode());
      await expectLater(
        runtime.createAiConversationSession()!.start(startRequest()),
        throwsA(aiCode(AiTextErrorCode.syncConflict)),
      );
      expect(aiHttp.requests.length, 1);
      expect(receipts.calls, isNot(contains('clear')));
      expect(receipts.value, receiptReference().encode());
    },
  );
  test('owned receipt reader rejects foreign owner without HTTP', () async {
    await openReceiptRuntime();
    await runtime.start();
    await login();
    await expectLater(
      runtime.createConversationReceiptLookup()!.lookup(
        receiptReference(owner: wire.b),
      ),
      throwsA(unauthorized),
    );
    expect(aiHttp.requests, isEmpty);
  });
  for (final logout in [false, true]) {
    test(
      'owned receipt reader actual drain on transition logout=$logout',
      () async {
        final receipts = await openReceiptRuntime();
        receipts.value = receiptReference().encode();
        await runtime.start();
        await login();
        final reader = runtime.createConversationReceiptLookup()!;
        final held = Completer<http.StreamedResponse>();
        final entered = Completer<void>();
        final aborted = Completer<void>();
        aiHttp.onSend = (r) {
          unawaited(
            (r as http.AbortableRequest).abortTrigger!.then(
              (_) => aborted.complete(),
            ),
          );
          entered.complete();
          return held.future;
        };
        final result = expectLater(
          reader.lookup(receiptReference()),
          throwsA(unauthorized),
        );
        Future<void>? transition;
        try {
          await entered.future;
          await expectLater(
            runtime.createAiTextRepository()!.explain(question),
            throwsA(isA<AiTextRequestPending>()),
          );
          var done = false;
          transition = (logout ? runtime.account.signOut() : runtime.refresh())
              .then((_) => done = true);
          await aborted.future;
          await result;
          await lifecycle.flush();
          expect(reader.isCurrent, isFalse);
          expect(runtime.createConversationReceiptLookup(), isNull);
          expect(receipts.value, receiptReference().encode());
          expect(receipts.calls, isNot(contains('clear')));
          if (logout) {
            expect(done, isFalse);
            expect(backend.secret, isNull);
          }
          held.complete(receiptAnswer('COMPLETED'));
          await transition;
          await lifecycle.flush();
          if (logout) {
            expect(runtime.account.state.phase, AccountPhase.signedOut);
            expect(receipts.value, isNull);
            expect(runtime.createConversationReceiptLookup(), isNull);
          } else {
            await ready();
            final fresh = runtime.createConversationReceiptLookup()!;
            expect(identical(fresh, reader), isFalse);
            expect(receipts.value, receiptReference().encode());
          }
          expect(aiHttp.requests.length, 1);
          expect(aiHttp.closed, isFalse);
        } finally {
          if (!held.isCompleted) {
            held.complete(receiptAnswer('PENDING'));
          }
          await result;
          await transition;
        }
      },
    );
  }

  for (final lateWriteError in [false, true]) {
    test(
      'owned receipt A-B-A logout fence during storage error=$lateWriteError',
      () async {
        final receipts = await openReceiptRuntime();
        await runtime.start();
        await login();
        final original = runtime.createAiConversationSession()!;
        receipts.writeWait = Completer<void>();
        receipts.failAfterWrite = lateWriteError;
        final result = expectLater(
          original.start(startRequest()),
          throwsA(unauthorized),
        );
        Future<void>? logout;
        try {
          await receipts.entered.future;
          logout = runtime.account.signOut();
          await lifecycle.flush();
          final tokensBeforeBlockedLogin = authRequests
              .where((r) => r.url.path == '/auth/v1/token')
              .length;
          user = wire.b;
          generation++;
          secret = 'TEST_ONLY_ACCOUNT_B';
          // Caller cannot race a replacement login against the old owned drain.
          await runtime.account.signIn(
            'fixture@example.invalid',
            'TEST_ONLY_PASSWORD',
          );
          expect(
            authRequests.where((r) => r.url.path == '/auth/v1/token').length,
            tokensBeforeBlockedLogin,
          );
          expect(runtime.account.readyRuntime, isNull);
          expect(runtime.createAiConversationSession(), isNull);
          expect(backend.secret, isNull);
          expect(receipts.calls, isNot(contains('clear')));
          expect(aiHttp.requests, isEmpty);
          receipts.writeWait!.complete();
          await result;
          await logout;
          expect(runtime.account.state.phase, AccountPhase.signedOut);
          expect(receipts.value, isNull);
          expect(receiptStore.scope.ownerId, wire.a);
          expect(receiptStore.phase, ConversationReceiptStorePhase.closed);
          await login();
          expect(runtime.account.readySession!.userId, wire.b);
          expect(backend.secret, secret);
          expect(runtime.createAiConversationSession(), isNull);
          expect(runtime.createAiTextRepository(), isNull);
          expect(original.isCurrent, isFalse);
          await expectLater(
            original.start(startRequest()),
            throwsA(unauthorized),
          );
          await runtime.account.signOut();
          user = wire.a;
          generation++;
          secret = 'TEST_ONLY_ACCOUNT_A_RETURN';
          await login();
          expect(runtime.account.readySession!.userId, wire.a);
          expect(backend.secret, secret);
          expect(runtime.createAiConversationSession(), isNull);
          expect(runtime.createAiTextRepository(), isNull);
          await expectLater(
            original.start(startRequest()),
            throwsA(unauthorized),
          );
          expect(receipts.value, isNull);
          expect(aiHttp.requests, isEmpty);
          expect(await journal.list(wire.a), isEmpty);
          expect(await journal.list(wire.b), isEmpty);
          // Metadata remains absent after the original claim has been released.
          final reopened = ConversationReceiptStore(
            scope: receiptStore.scope,
            backend: receipts,
          );
          try {
            expect(await reopened.read(), isNull);
          } finally {
            await reopened.close();
          }
        } finally {
          if (!receipts.writeWait!.isCompleted) {
            receipts.writeWait!.complete();
          }
          await result;
          await logout;
        }
      },
    );
  }

  for (final mode in ['read', 'corrupt', 'write-before', 'write-after']) {
    test('owned receipt storage failure blocks dispatch mode=$mode', () async {
      final receipts = await openReceiptRuntime();
      await runtime.start();
      await login();
      receipts.failRead = mode == 'read';
      receipts.failBeforeWrite = mode == 'write-before';
      receipts.failAfterWrite = mode == 'write-after';
      if (mode == 'corrupt') {
        receipts.value = 'TEST_ONLY_PRIVATE_CORRUPT';
      }
      final session = runtime.createAiConversationSession()!;
      await expectLater(
        session.start(startRequest()),
        throwsA(
          isA<AiTextFailure>()
              .having((e) => e.code, 'code', AiTextErrorCode.internalError)
              .having((e) => e.retryable, 'retryable', false)
              .having(
                (e) => e.toString(),
                'redacted',
                isNot(contains('TEST_ONLY_PRIVATE')),
              ),
        ),
      );
      expect(receiptStore.phase, ConversationReceiptStorePhase.failed);
      expect(aiHttp.requests, isEmpty);
      expect(backend.secret, secret);
      if (mode == 'write-after') {
        final saved = ConversationReceiptReference.decode(
          receipts.value! as String,
        );
        expect(saved.clientEventId, startRequest().clientEventId);
        expect(saved.ownerId, wire.a);
      } else if (mode != 'corrupt') {
        expect(receipts.value, isNull);
      }
      final savedValue = receipts.value;
      receipts.failRead = false;
      receipts.failBeforeWrite = false;
      receipts.failAfterWrite = false;
      // Fixing the port and rotating Auth cannot renew an attempted command.
      secret = 'TEST_ONLY_ROTATED_AFTER_STORAGE_FAILURE';
      generation++;
      await runtime.refresh();
      await lifecycle.flush();
      await ready();
      final fresh = runtime.createAiConversationSession()!;
      await expectLater(
        fresh.start(startRequest()),
        throwsA(aiCode(AiTextErrorCode.syncConflict)),
      );
      expect(aiHttp.requests, isEmpty);
      expect(receipts.value, savedValue);
      expect(receipts.calls, isNot(contains('clear')));
      await runtime.account.signOut();
      expect(runtime.account.state.phase, AccountPhase.signedOut);
      expect(backend.secret, isNull);
      expect(receipts.value, isNull);
      expect(receiptStore.phase, ConversationReceiptStorePhase.closed);
      expect(aiHttp.requests, isEmpty);
    });
  }

  for (final lateWriteError in [false, true]) {
    test(
      'owned receipt logout waits actual held storage error=$lateWriteError',
      () async {
        final receipts = await openReceiptRuntime();
        await runtime.start();
        await login();
        receipts.writeWait = Completer<void>();
        receipts.failAfterWrite = lateWriteError;
        final session = runtime.createAiConversationSession()!;
        final result = expectLater(
          session.start(startRequest()),
          throwsA(unauthorized),
        );
        Future<void>? logout;
        try {
          await receipts.entered.future;
          var done = false;
          logout = runtime.account.signOut().then((_) => done = true);
          await lifecycle.flush();
          expect(runtime.account.readyRuntime, isNull);
          expect(runtime.createAiConversationSession(), isNull);
          expect(backend.secret, isNull);
          expect(done, isFalse);
          expect(receipts.value, isNull);
          expect(receipts.calls, isNot(contains('clear')));
          expect(aiHttp.requests, isEmpty);
          expect(
            () => ConversationReceiptStore(
              scope: receiptStore.scope,
              backend: receipts,
            ),
            throwsA(
              isA<ConversationReceiptStoreFailure>().having(
                (e) => e.code,
                'held partition',
                ConversationReceiptStoreError.owned,
              ),
            ),
          );
          receipts.writeWait!.complete();
          await result;
          await logout;
          expect(done, isTrue);
          expect(runtime.account.state.phase, AccountPhase.signedOut);
          expect(receipts.value, isNull);
          expect(
            receipts.calls.indexOf('write'),
            lessThan(receipts.calls.indexOf('clear')),
          );
          expect(receiptStore.phase, ConversationReceiptStorePhase.closed);
          expect(aiHttp.requests, isEmpty);
          expect(aiHttp.closed, isFalse);
        } finally {
          if (!receipts.writeWait!.isCompleted) {
            receipts.writeWait!.complete();
          }
          await result;
          await logout;
        }
      },
    );
  }

  test(
    'owned receipt startup waits rotated refresh vault and own profile',
    () async {
      final receipts = await openReceiptRuntime();
      backend.secret = 'TEST_ONLY_SAVED';
      backend.writeWait = Completer<void>();
      profileWait = Completer<http.Response>();
      final starting = runtime.start();
      try {
        await lifecycle.flush();
        expect(runtime.persistence.currentSession, isNull);
        expect(runtime.createAiConversationSession(), isNull);
        expect(
          authRequests.where((r) => r.url.path.contains('ensure_profile')),
          isEmpty,
        );
        expect(aiHttp.requests, isEmpty);
        backend.writeWait!.complete();
        await starting;
        await lifecycle.flush();
        expect(backend.secret, secret);
        expect(runtime.account.state.phase, AccountPhase.loadingProfile);
        expect(runtime.createAiConversationSession(), isNull);
        profileWait!.complete(
          http.Response(
            jsonEncode(profile.profile(user)),
            200,
            headers: {'content-type': 'application/json'},
          ),
        );
        await ready();
        expect(runtime.createAiConversationSession(), isNotNull);
        expect(receipts.calls, isEmpty);
        final authRequest = authRequests.firstWhere(
          (r) => r.url.path == '/auth/v1/token',
        );
        expect(authRequest.url.queryParameters['grant_type'], 'refresh_token');
        expect(
          (jsonDecode(authRequest.body)
              as Map<String, Object?>)['refresh_token'],
          'TEST_ONLY_SAVED',
        );
      } finally {
        if (!backend.writeWait!.isCompleted) {
          backend.writeWait!.complete();
        }
        if (!profileWait!.isCompleted) {
          profileWait!.complete(
            http.Response(
              jsonEncode(profile.profile(user)),
              200,
              headers: {'content-type': 'application/json'},
            ),
          );
        }
        await starting;
      }
    },
  );

  test(
    'owned receipt command persists before SDK HTTP and close preserves metadata',
    () async {
      final receipts = await openReceiptRuntime();
      await runtime.start();
      await login();
      aiHttp.onSend = (r) async {
        expect(receipts.calls.last, 'write');
        expect(receipts.value, isA<String>());
        expect(
          r.headers['authorization'],
          'Bearer ${wire.token(user, wire.sid1, now, generation: generation)}',
        );
        return answer('start_conversation');
      };
      await runtime.createAiConversationSession()!.start(startRequest());
      expect(aiHttp.requests.length, 1);
      await runtime.close();
      expect(receiptStore.phase, ConversationReceiptStorePhase.closed);
      expect(receipts.value, isNotNull);
      final reopened = ConversationReceiptStore(
        scope: receiptStore.scope,
        backend: receipts,
      );
      try {
        expect(
          (await reopened.read())!.clientEventId,
          startRequest().clientEventId,
        );
      } finally {
        await reopened.close();
      }
      expect(aiHttp.closed, isFalse);
    },
  );

  for (final error in [false, true]) {
    test(
      'owned receipt logout drains actual HTTP before clear error=$error',
      () async {
        final receipts = await openReceiptRuntime();
        await runtime.start();
        await login();
        final held = Completer<http.StreamedResponse>();
        final entered = Completer<void>();
        final aborted = Completer<void>();
        aiHttp.onSend = (r) {
          unawaited(
            (r as http.AbortableRequest).abortTrigger!.then(
              (_) => aborted.complete(),
            ),
          );
          entered.complete();
          return held.future;
        };
        final session = runtime.createAiConversationSession()!;
        final result = expectLater(
          session.start(startRequest()),
          throwsA(unauthorized),
        );
        try {
          await entered.future;
          var done = false;
          final logout = runtime.account.signOut().then((_) => done = true);
          await aborted.future;
          await lifecycle.flush();
          expect(done, isFalse);
          expect(backend.secret, isNull);
          expect(receipts.value, isNotNull);
          expect(receipts.calls, isNot(contains('clear')));
          expect(runtime.createAiConversationSession(), isNull);
          if (error) {
            held.completeError(StateError('TEST_ONLY_LATE_PRIVATE'));
          } else {
            held.complete(answer('start_conversation'));
          }
          await result;
          await logout;
          expect(runtime.account.state.phase, AccountPhase.signedOut);
          expect(receipts.value, isNull);
          expect(receipts.calls.last, 'clear');
          expect(aiHttp.requests.length, 1);
          expect(aiHttp.closed, isFalse);
        } finally {
          if (!held.isCompleted) {
            held.completeError(StateError('TEST_ONLY_CLEANUP'));
          }
        }
      },
    );
  }

  test(
    'owned receipt failed clear reports logout error and explicit retry retains partition',
    () async {
      final receipts = await openReceiptRuntime();
      await runtime.start();
      await login();
      await runtime.createAiConversationSession()!.start(startRequest());
      receipts.failClear = true;
      try {
        await runtime.account.signOut();
        expect(runtime.account.state.phase, AccountPhase.signOutError);
        expect(backend.secret, isNull);
        expect(receipts.value, isNotNull);
        expect(
          () => ConversationReceiptStore(
            scope: receiptStore.scope,
            backend: receipts,
          ),
          throwsA(isA<ConversationReceiptStoreFailure>()),
        );
        expect(runtime.createAiConversationSession(), isNull);
        receipts.failClear = false;
        await runtime.account.signOut();
        expect(runtime.account.state.phase, AccountPhase.signedOut);
        expect(receipts.value, isNull);
        expect(receipts.calls.where((c) => c == 'clear').length, 2);
      } finally {
        receipts.failClear = false;
        await runtime.account.signOut();
      }
    },
  );

  test(
    'owned receipt refresh during held write never dispatches old command',
    () async {
      final receipts = await openReceiptRuntime();
      await runtime.start();
      await login();
      receipts.writeWait = Completer<void>();
      final old = runtime.createAiConversationSession()!;
      final result = expectLater(
        old.start(startRequest()),
        throwsA(unauthorized),
      );
      try {
        await receipts.entered.future;
        secret = 'TEST_ONLY_REFRESH_ROTATED';
        generation++;
        await runtime.refresh();
        await lifecycle.flush();
        await ready();
        expect(runtime.createAiConversationSession(), isNull);
        expect(aiHttp.requests, isEmpty);
        receipts.writeWait!.complete();
        await result;
        await lifecycle.flush();
        expect(old.isCurrent, isFalse);
        final fresh = runtime.createAiConversationSession()!;
        await expectLater(
          fresh.start(startRequest()),
          throwsA(aiCode(AiTextErrorCode.syncConflict)),
        );
        expect(aiHttp.requests, isEmpty);
        expect(receipts.value, isNotNull);
      } finally {
        if (!receipts.writeWait!.isCompleted) {
          receipts.writeWait!.complete();
        }
      }
    },
  );

  test(
    'owned receipt source stays retired after logout and another account login',
    () async {
      final receipts = await openReceiptRuntime();
      await runtime.start();
      await login();
      await runtime.createAiConversationSession()!.start(startRequest());
      await runtime.account.signOut();
      user = wire.b;
      generation++;
      secret = 'TEST_ONLY_OTHER_REFRESH';
      await login();
      expect(runtime.account.readySession!.userId, wire.b);
      expect(runtime.createAiConversationSession(), isNull);
      expect(runtime.createAiTextRepository(), isNull);
      expect(receiptStore.phase, ConversationReceiptStorePhase.closed);
      expect(receipts.value, isNull);
      expect(aiHttp.requests.length, 1);
    },
  );

  test(
    'owned receipt foreign project rejected before SDK ownership transfer',
    () async {
      await runtime.close();
      final receipts = _ReceiptBackend();
      final foreign = ConversationReceiptStore(
        scope: ConversationReceiptScope(
          projectUrl: 'https://other.invalid',
          ownerId: wire.a,
        ),
        backend: receipts,
      );
      try {
        expect(
          () => build(conversationEnabled: true, receiptStore: foreign),
          throwsA(isA<SessionVaultFailure>()),
        );
        expect(foreign.phase, ConversationReceiptStorePhase.open);
        expect(receipts.calls, isEmpty);
        expect(authRequests, isEmpty);
      } finally {
        await foreign.close();
      }
    },
  );

  test(
    'AI owner flag defaults off even with an authenticated ready runtime',
    () async {
      await runtime.close();
      runtime = PersistentSupabaseRuntime(
        projectUrl: wire.origin,
        publishableKey: wire.key,
        vault: vault,
        store: journal,
        httpClient: authHttp,
        aiHttpClient: aiHttp,
        now: () => now,
      );
      await runtime.start();
      await login();
      expect(runtime.isAiTextEnabled, isFalse);
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, isEmpty);
    },
  );
  test(
    'AI factory waits for persisted rotation and own profile then caches one capability',
    () async {
      backend.secret = 'TEST_ONLY_SAVED';
      backend.writeWait = Completer<void>();
      profileWait = Completer<http.Response>();
      final starting = runtime.start();
      await lifecycle.flush();
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, isEmpty);
      expect(
        authRequests.where((r) => r.url.path.contains('ensure_profile')),
        isEmpty,
      );
      backend.writeWait!.complete();
      await starting;
      await lifecycle.flush();
      expect(backend.secret, secret);
      expect(runtime.account.state.phase, AccountPhase.loadingProfile);
      expect(runtime.createAiTextRepository(), isNull);
      profileWait!.complete(
        http.Response(
          jsonEncode(profile.profile(user)),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await ready();
      final repo = runtime.createAiTextRepository();
      expect(repo, isNotNull);
      expect(identical(repo, runtime.createAiTextRepository()), isTrue);
      expect(aiHttp.requests, isEmpty);
      expect(
        (await repo!.explain(question)).toJson(),
        fixtures['tutor_explain_response'],
      );
      expect(aiHttp.requests.single.url.path, '/functions/v1/tutor_explain');
      expect(
        aiHttp.requests.single.headers['authorization'],
        'Bearer ${wire.token(user, wire.sid1, now)}',
      );
      expect(
        authRequests.every(
          (r) =>
              r.url.path.startsWith('/auth/v1/') ||
              r.url.path.startsWith('/rest/v1/'),
        ),
        isTrue,
      );
    },
  );
  test(
    'refresh revokes AI synchronously and holds new generation until old headers drain',
    () async {
      await runtime.start();
      await login();
      final old = runtime.createAiTextRepository()!;
      final pending = Completer<http.StreamedResponse>();
      aiHttp.onSend = (_) => pending.future;
      final rejected = expectLater(
        old.explain(question),
        throwsA(unauthorized),
      );
      final first = aiHttp.requests.single as http.AbortableRequest;
      secret = 'TEST_ONLY_REFRESH_2';
      generation++;
      backend.writeWait = Completer<void>();
      final rotating = runtime.refresh();
      expect(old.isCurrent, isFalse);
      expect(runtime.createAiTextRepository(), isNull);
      await rejected;
      await expectLater(first.abortTrigger, completes);
      await lifecycle.flush();
      backend.writeWait!.complete();
      await rotating;
      await ready();
      expect(backend.secret, secret);
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, hasLength(1));
      pending.complete(answer());
      await lifecycle.flush();
      final next = runtime.createAiTextRepository();
      expect(next, isNotNull);
      expect(identical(old, next), isFalse);
      await expectLater(old.explain(question), throwsA(unauthorized));
      aiHttp.onSend = (r) async => answer();
      await next!.explain(question);
      expect(
        first.headers['authorization'],
        'Bearer ${wire.token(user, wire.sid1, now)}',
      );
      expect(
        aiHttp.requests.last.headers['authorization'],
        'Bearer ${wire.token(user, wire.sid1, now, generation: generation)}',
      );
      expect(aiHttp.requests, hasLength(2));
    },
  );
  test(
    'logout and new account cannot reuse or overlap a late old AI request',
    () async {
      await runtime.start();
      await login();
      final old = runtime.createAiTextRepository()!;
      final pending = Completer<http.StreamedResponse>();
      aiHttp.onSend = (_) => pending.future;
      final rejected = expectLater(
        old.explain(question),
        throwsA(unauthorized),
      );
      final logout = runtime.account.signOut();
      expect(old.isCurrent, isFalse);
      expect(runtime.createAiTextRepository(), isNull);
      await rejected;
      await logout;
      expect(backend.secret, isNull);
      user = wire.b;
      secret = 'TEST_ONLY_ACCOUNT_B';
      generation++;
      await login();
      expect(runtime.createAiTextRepository(), isNull);
      pending.completeError(StateError('TEST_ONLY_OLD_SECRET'));
      await lifecycle.flush();
      final next = runtime.createAiTextRepository();
      expect(next, isNotNull);
      aiHttp.onSend = (r) async => answer();
      await next!.explain(question);
      expect(aiHttp.requests, hasLength(2));
      expect(
        aiHttp.requests.last.headers['authorization'],
        'Bearer ${wire.token(wire.b, wire.sid1, now, generation: generation)}',
      );
      await expectLater(old.explain(question), throwsA(unauthorized));
    },
  );
  test(
    'shutdown revokes AI immediately and waits for ignored abort before SDK disposal',
    () async {
      await runtime.start();
      await login();
      final repo = runtime.createAiTextRepository()!;
      final pending = Completer<http.StreamedResponse>();
      aiHttp.onSend = (_) => pending.future;
      final rejected = expectLater(
        repo.explain(question),
        throwsA(unauthorized),
      );
      var closed = false;
      final closing = runtime.close()
        ..then((_) {
          closed = true;
        });
      expect(identical(closing, runtime.close()), isTrue);
      expect(repo.isCurrent, isFalse);
      expect(runtime.createAiTextRepository(), isNull);
      await rejected;
      await lifecycle.flush();
      expect(closed, isFalse);
      expect(backend.secret, secret);
      pending.completeError(StateError('TEST_ONLY_LATE_SECRET'));
      await closing;
      expect(closed, isTrue);
      expect(aiHttp.closed, isFalse);
      expect(runtime.createAiTextRepository(), isNull);
    },
  );
  test(
    'vault write failure cannot grant an AI repository or reach own profile',
    () async {
      backend.failWrite = true;
      await runtime.start();
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await lifecycle.flush();
      expect(runtime.account.readyRuntime, isNull);
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, isEmpty);
      expect(
        authRequests.where((r) => r.url.path.contains('ensure_profile')),
        isEmpty,
      );
    },
  );
  test(
    'profile failure blocks AI until an explicit successful profile retry',
    () async {
      profileStatus = 500;
      await runtime.start();
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await lifecycle.flush();
      expect(runtime.account.state.phase, AccountPhase.profileError);
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, isEmpty);
      profileStatus = 200;
      await runtime.account.retryProfile();
      await ready();
      expect(runtime.createAiTextRepository(), isNotNull);
      expect(aiHttp.requests, isEmpty);
    },
  );
  test(
    'HTTP unauthorized cannot reconstruct an AI capability without a fresh ready barrier',
    () async {
      await runtime.start();
      await login();
      final repo = runtime.createAiTextRepository()!;
      aiHttp.onSend = (_) async => http.StreamedResponse(
        Stream.value(utf8.encode('TEST_ONLY_RAW_SECRET')),
        401,
      );
      await expectLater(repo.explain(question), throwsA(unauthorized));
      expect(runtime.createAiTextRepository(), isNull);
      await lifecycle.flush();
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, hasLength(1));
      secret = 'TEST_ONLY_REFRESH_2';
      generation++;
      await runtime.refresh();
      await ready();
      expect(runtime.createAiTextRepository(), isNotNull);
      expect(aiHttp.requests, hasLength(1));
    },
  );

  test(
    'conversation is separately disabled while text owner is enabled',
    () async {
      await runtime.start();
      await login();
      expect(runtime.isAiConversationEnabled, isFalse);
      expect(runtime.createAiConversationSession(), isNull);
      expect(runtime.createAiTextRepository(), isNotNull);
      expect(aiHttp.requests, isEmpty);
    },
  );
  test(
    'conversation factory waits for vault and profile then retains one session without text exposure',
    () async {
      await runtime.close();
      runtime = build(enabled: false, conversationEnabled: true);
      backend.secret = 'TEST_ONLY_SAVED';
      backend.writeWait = Completer<void>();
      profileWait = Completer<http.Response>();
      final starting = runtime.start();
      await lifecycle.flush();
      expect(runtime.createAiConversationSession(), isNull);
      backend.writeWait!.complete();
      await starting;
      await lifecycle.flush();
      expect(runtime.createAiConversationSession(), isNull);
      expect(aiHttp.requests, isEmpty);
      profileWait!.complete(
        http.Response(
          jsonEncode(profile.profile(user)),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await ready();
      final flow = runtime.createAiConversationSession()!;
      expect(identical(runtime.createAiConversationSession(), flow), isTrue);
      expect(runtime.createAiTextRepository(), isNull);
      expect(flow.snapshot.phase, ConversationSessionPhase.notStarted);
      expect(aiHttp.requests, isEmpty);
      await flow.start(
        StartConversationRequest.fromJson(
          fixtures['start_conversation_request'],
        ),
      );
      expect(flow.snapshot.phase, ConversationSessionPhase.active);
      expect(aiHttp.requests, hasLength(1));
    },
  );
  test(
    'conversation refresh revokes before rotation and waits for old ignored-abort HTTP drain',
    () async {
      await runtime.close();
      runtime = build(conversationEnabled: true);
      await runtime.start();
      await login();
      final flow = runtime.createAiConversationSession()!;
      final held = Completer<http.StreamedResponse>();
      aiHttp.onSend = (_) => held.future;
      final rejected = expectLater(
        flow.start(
          StartConversationRequest.fromJson(
            fixtures['start_conversation_request'],
          ),
        ),
        throwsA(unauthorized),
      );
      secret = 'TEST_ONLY_ROTATED_CONVERSATION';
      generation++;
      final refreshing = runtime.refresh();
      expect(flow.snapshot.messages, isEmpty);
      expect(flow.isCurrent, isFalse);
      try {
        await rejected;
        await refreshing;
        await ready();
        expect(backend.secret, secret);
        expect(runtime.createAiConversationSession(), isNull);
        expect(aiHttp.requests, hasLength(1));
      } finally {
        if (!held.isCompleted) {
          held.completeError(StateError('TEST_ONLY_LATE_CONVERSATION'));
        }
      }
      await lifecycle.flush();
      final next = runtime.createAiConversationSession()!;
      expect(identical(next, flow), isFalse);
      aiHttp.onSend = (r) async => answer(r.url.path.split('/').last);
      await next.start(
        StartConversationRequest.fromJson(
          fixtures['start_conversation_request'],
        ),
      );
      expect(
        aiHttp.requests.last.headers['authorization'],
        'Bearer ${wire.token(user, wire.sid1, now, generation: generation)}',
      );
      await runtime.account.signOut();
      expect(next.snapshot.messages, isEmpty);
      expect(runtime.createAiConversationSession(), isNull);
    },
  );
  test(
    'conversation owned close clears publication immediately and drains held HTTP preserving vault',
    () async {
      await runtime.close();
      runtime = build(conversationEnabled: true);
      await runtime.start();
      await login();
      final flow = runtime.createAiConversationSession()!;
      final saved = backend.secret;
      final held = Completer<http.StreamedResponse>();
      aiHttp.onSend = (_) => held.future;
      final rejected = expectLater(
        flow.start(
          StartConversationRequest.fromJson(
            fixtures['start_conversation_request'],
          ),
        ),
        throwsA(unauthorized),
      );
      var drained = false;
      final closing = runtime.close()
        ..then((_) {
          drained = true;
        });
      expect(flow.isCurrent, isFalse);
      expect(runtime.createAiConversationSession(), isNull);
      try {
        await rejected;
        await lifecycle.flush();
        expect(drained, isFalse);
        expect(aiHttp.closed, isFalse);
      } finally {
        if (!held.isCompleted) {
          held.completeError(StateError('TEST_ONLY_LATE_CLOSE'));
        }
      }
      await closing;
      expect(drained, isTrue);
      expect(backend.secret, saved);
      expect(aiHttp.closed, isFalse);
    },
  );

  http.StreamedResponse scenarioAnswer() => http.StreamedResponse(
    Stream.value(
      utf8.encode(
        jsonEncode([
          {
            'id': wire.a,
            'jlpt_level': 'N5',
            'title_vi': 'Tình huống',
            'title_ja': '会話',
            'description_vi': 'Mô tả',
            'content_version': 1,
            'is_active': true,
          },
        ]),
      ),
    ),
    200,
    headers: {'content-type': 'application/json'},
  );

  test(
    'scenario factory waits for persisted vault and profile then retains no-dispatch reader',
    () async {
      await runtime.close();
      runtime = build(enabled: false, conversationEnabled: true);
      backend.secret = 'TEST_ONLY_SAVED';
      backend.writeWait = Completer<void>();
      profileWait = Completer<http.Response>();
      final starting = runtime.start();
      await lifecycle.flush();
      expect(runtime.createAiConversationScenarios(), isNull);
      backend.writeWait!.complete();
      await starting;
      await lifecycle.flush();
      expect(runtime.createAiConversationScenarios(), isNull);
      expect(aiHttp.requests, isEmpty);
      profileWait!.complete(
        http.Response(
          jsonEncode(profile.profile(user)),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await ready();
      final reader = runtime.createAiConversationScenarios()!;
      expect(
        identical(reader, runtime.createAiConversationScenarios()),
        isTrue,
      );
      expect(runtime.createAiTextRepository(), isNull);
      expect(aiHttp.requests, isEmpty);
      aiHttp.onSend = (_) async => scenarioAnswer();
      expect((await reader.load(AiTextLevel.n5)).single.id, wire.a);
      expect(aiHttp.requests.single.method, 'GET');
      expect(
        aiHttp.requests.single.url.path,
        '/rest/v1/conversation_scenarios',
      );
    },
  );
  test('scenario factory remains off with ready text-only account', () async {
    await runtime.start();
    await login();
    expect(runtime.createAiTextRepository(), isNotNull);
    expect(runtime.createAiConversationScenarios(), isNull);
    expect(aiHttp.requests, isEmpty);
  });
  for (final barrier in ['vault', 'profile']) {
    test('scenario reader cannot bypass failed $barrier barrier', () async {
      await runtime.close();
      runtime = build(conversationEnabled: true);
      if (barrier == 'vault') {
        backend.failWrite = true;
      } else {
        profileStatus = 500;
      }
      await runtime.start();
      await runtime.account.signIn(
        'fixture@example.invalid',
        'TEST_ONLY_PASSWORD',
      );
      await lifecycle.flush();
      expect(runtime.createAiConversationScenarios(), isNull);
      expect(runtime.createAiConversationSession(), isNull);
      expect(aiHttp.requests, isEmpty);
    });
  }
  test(
    'scenario refresh retires reader before rotation and blocks fresh read until old HTTP drains',
    () async {
      await runtime.close();
      runtime = build(conversationEnabled: true);
      await runtime.start();
      await login();
      final old = runtime.createAiConversationScenarios()!;
      final held = Completer<http.StreamedResponse>();
      aiHttp.onSend = (_) => held.future;
      final rejected = expectLater(
        old.load(AiTextLevel.n5),
        throwsA(unauthorized),
      );
      generation++;
      secret = 'TEST_ONLY_SCENARIO_ROTATED';
      final refreshing = runtime.refresh();
      expect(old.isCurrent, isFalse);
      try {
        await rejected;
        await refreshing;
        await ready();
        expect(backend.secret, secret);
        expect(runtime.createAiConversationScenarios(), isNull);
        expect(aiHttp.requests, hasLength(1));
      } finally {
        if (!held.isCompleted) {
          held.completeError(StateError('TEST_ONLY_LATE_SCENARIO'));
        }
      }
      await lifecycle.flush();
      final fresh = runtime.createAiConversationScenarios()!;
      expect(identical(old, fresh), isFalse);
      aiHttp.onSend = (_) async => scenarioAnswer();
      expect(await fresh.load(AiTextLevel.n5), hasLength(1));
      expect(
        aiHttp.requests.last.headers['authorization'],
        'Bearer ${wire.token(user, wire.sid1, now, generation: generation)}',
      );
      await runtime.account.signOut();
      expect(fresh.isCurrent, isFalse);
      expect(runtime.createAiConversationScenarios(), isNull);
    },
  );
  test(
    'scenario source forwards through real Windows startup only while controller active',
    () async {
      await runtime.close();
      runtime = build(conversationEnabled: true);
      final session = PersistentAccountStartup(runtime);
      final owner = WindowsStagingOwner(session, journal);
      final controller = AccountStartupController(() async => owner);
      expect(controller.aiConversationScenarioSource, isNull);
      final starting = controller.start();
      expect(controller.aiConversationScenarioSource, isNull);
      await starting;
      expect(identical(controller.aiConversationScenarioSource, owner), isTrue);
      expect(owner.createAiConversationScenarios(), isNull);
      expect(
        identical(
          owner.aiConversationScenarioChanges,
          runtime.aiConversationScenarioChanges,
        ),
        isTrue,
      );
      await login();
      final reader = controller.aiConversationScenarioSource!
          .createAiConversationScenarios()!;
      expect(
        identical(reader, session.createAiConversationScenarios()),
        isTrue,
      );
      expect(aiHttp.requests, isEmpty);
      await controller.close();
      expect(controller.aiConversationScenarioSource, isNull);
      expect(owner.createAiConversationScenarios(), isNull);
      expect(reader.isCurrent, isFalse);
    },
  );
}
