// TEST ONLY unsigned JWT/Auth HTTP and streamed AI responses. Actual SDK session,
// http request/abort/stream behavior; no hosted Auth, provider or learner proof.
import 'package:nihongo_daily/features/ai/application/account_receipt_ai_runtime.dart';
import 'package:nihongo_daily/features/ai/application/supabase_account_receipt_ai_runtime.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/data/own_profile_repository.dart';
import 'package:nihongo_daily/features/auth/data/supabase_account_access.dart';
import 'package:nihongo_daily/features/auth/data/supabase_refreshable_account_access.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nihongo_daily/features/ai/application/ai_text_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/application/receipt_ai_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/data/receipt_guarded_ai_transport.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_snapshot.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/supabase_ai_text_transport.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_scenarios.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/supabase_review_binding.dart';
import 'package:supabase/supabase.dart';

const origin = 'https://example.supabase.invalid';
const key = 'sb_publishable_TEST_ONLY_1234567890';
const userA = 'a1000000-0000-4000-8000-000000000001';
const userB = 'a1000000-0000-4000-8000-000000000002';
const sid = 'c1000000-0000-4000-8000-000000000001';
late Map<String, Object?> fixtures;
Object? fixture(String operation, String kind) =>
    fixtures['${operation}_$kind'];
Map<String, Object> request(String operation) => Map<String, Object>.from(
  fixture(operation, 'request')! as Map<String, Object?>,
);
String output([String operation = 'tutor_explain']) =>
    jsonEncode(fixture(operation, 'response'));
TypeMatcher<AiTextFailure> failure(AiTextErrorCode code) =>
    isA<AiTextFailure>().having((f) => f.code, 'safe code', code);
String segment(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
String token(
  DateTime now,
  String user,
  int generation, {
  String role = 'authenticated',
}) =>
    '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment({'sub': user, 'session_id': sid, 'role': role, 'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000, 'fixture_generation': generation})}.${segment('TEST ONLY NOT A SIGNATURE')}';

final class _Http extends http.BaseClient {
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

http.StreamedResponse response(
  String text, {
  int status = 200,
  Map<String, String>? headers,
  int? length,
}) => http.StreamedResponse(
  Stream.value(utf8.encode(text)),
  status,
  headers: headers ?? {'content-type': 'application/json; charset=utf-8'},
  contentLength: length,
);

// TEST ONLY secure-storage port. No production plaintext fallback.
final class _ReceiptBackend implements SecureConversationReceiptBackend {
  Object? value;
  bool failRead = false;
  bool failWrite = false;
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
    calls.add('write-begin');
    entered.complete();
    await writeWait?.future;
    value = encoded; // Deliberately ambiguous write failure retains metadata.
    if (failWrite) throw StateError('TEST_ONLY_PRIVATE_RECEIPT_WRITE');
    calls.add('write-end');
  }

  @override
  Future<void> clear(String target) async {
    calls.add('clear');
    value = null;
  }
}

void main() {
  late DateTime now;
  late String nextUser;
  late int generation;
  late SupabaseClient sdk;
  late SupabaseReviewBinding auth;
  late MockClient authHttp;
  late _Http network;
  late bool ready;
  late bool brokenReady;
  late List<SupabaseAiTextTransport> transports;

  Future<void> login() async {
    await sdk.auth.signInWithPassword(
      email: 'fixture@example.invalid',
      password: 'TEST_ONLY_PASSWORD',
    );
    await Future<void>.delayed(Duration.zero);
  }

  SupabaseAiTextTransport make({
    Duration timeout = const Duration(seconds: 1),
    bool Function()? readiness,
  }) {
    final t = SupabaseAiTextTransport(
      client: sdk,
      auth: auth,
      isReady:
          readiness ??
          () {
            if (brokenReady) throw StateError('TEST_ONLY_SECRET');
            return ready;
          },
      projectUrl: origin,
      publishableKey: key,
      httpClient: network,
      now: () => now,
      timeout: timeout,
    );
    transports.add(t);
    return t;
  }

  Future<Object?> invoke(
    SupabaseAiTextTransport t, {
    String operation = 'tutor_explain',
    Map<String, Object>? body,
    ReviewSession? session,
  }) => operation == 'tutor_explain'
      ? t.tutorExplain(
          capturedSession: session ?? auth.currentSession!,
          body: body ?? request(operation),
        )
      : t.correctSentence(
          capturedSession: session ?? auth.currentSession!,
          body: body ?? request(operation),
        );

  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  setUp(() async {
    now = DateTime.utc(2026, 10, 24);
    nextUser = userA;
    generation = 0;
    ready = true;
    brokenReady = false;
    transports = [];
    network = _Http()
      ..onSend = (r) async => response(output(r.url.path.split('/').last));
    authHttp = MockClient((r) async {
      if (r.url.path == '/auth/v1/logout') return http.Response('', 204);
      if (r.url.path != '/auth/v1/token') {
        throw StateError('Unexpected TEST ONLY Auth operation');
      }
      return http.Response(
        jsonEncode({
          'access_token': token(now, nextUser, generation),
          'refresh_token': 'TEST_ONLY_REFRESH',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': nextUser,
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
    });
    sdk = SupabaseClient(
      origin,
      key,
      httpClient: authHttp,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    auth = SupabaseReviewBinding(
      client: sdk,
      projectUrl: origin,
      publishableKey: key,
      httpClient: authHttp,
      now: () => now,
    );
    await login();
  });
  tearDown(() async {
    for (final t in transports) {
      await t.close();
    }
    auth.dispose();
    await sdk.dispose();
    authHttp.close();
    network.close();
  });

  AccountReceiptAiRuntime<ReviewAuth> accountReceipt(
    _ReceiptBackend backend, {
    Completer<OwnProfile>? profileWait,
    String project = origin,
    String publicKey = key,
  }) {
    final account = AccountController<ReviewAuth>(
      access: SupabaseAccountAccess(auth),
      ensureProfile: () =>
          profileWait?.future ??
          Future.value(
            decodeOwnProfile({
              'id': auth.currentSession!.userId,
              'display_name': 'TEST ONLY',
              'preferred_jlpt': 'N5',
              'daily_target_minutes': 120,
              'timezone': 'Asia/Saigon',
            }, auth.currentSession!.userId),
          ),
      buildStudyRuntime: (readyAuth, changes) => readyAuth,
    );
    addTearDown(account.dispose);
    final store = ConversationReceiptStore(
      scope: ConversationReceiptScope(projectUrl: origin, ownerId: userA),
      backend: backend,
    );
    addTearDown(store.close); // Test cleanup also covers rejected ownership.
    final owner = createSupabaseAccountReceiptAiRuntime(
      client: sdk,
      account: account,
      authForRuntime: (ready) => ready,
      projectUrl: project,
      publishableKey: publicKey,
      store: store,
      httpClient: network,
      now: () => now,
    );
    addTearDown(owner.close);
    return owner;
  }

  Future<void> settleAccount() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  ConversationReceiptReference receiptReference(
    String operation, {
    String owner = userA,
    String project = origin,
  }) => ConversationReceiptReference.fromJson({
    'version': 1,
    'project_origin': project,
    'owner_id': owner,
    'operation': operation,
    'client_event_id': request(operation)['client_event_id'],
  });
  Map<String, Object?> receiptRow(String operation, String status) => {
    'user_id': userA,
    'operation': operation,
    'client_event_id': request(operation)['client_event_id'],
    'status': status,
    'response_json': status == 'COMPLETED'
        ? fixture(operation, 'response')
        : null,
  };

  Future<ConversationReceiptSnapshot> originalLookup(
    SupabaseAiTextTransport t,
    String op, {
    ConversationReceiptReference? ref,
    Map<String, Object>? original,
  }) {
    final r = ref ?? receiptReference(op);
    final body = original ?? request(op);
    return switch (op) {
      'start_conversation' => t.lookupStartReceipt(
        r,
        StartConversationRequest.fromJson(body),
      ),
      'conversation_turn' => t.lookupTurnReceipt(
        r,
        ConversationTurnRequest.fromJson(body),
      ),
      'finish_conversation' => t.lookupFinishReceipt(
        r,
        FinishConversationRequest.fromJson(body),
      ),
      _ => throw StateError('Unexpected TEST ONLY operation'),
    };
  }

  Map<String, Object?> originalRow(String op, String status) => {
    ...receiptRow(op, status),
    'request_json': request(op),
  };

  for (final op in [
    'start_conversation',
    'conversation_turn',
    'finish_conversation',
  ]) {
    for (final status in ['UNKNOWN', 'PENDING', 'COMPLETED']) {
      test('original-bound receipt GET $op $status', () async {
        final t = make();
        network.onSend = (r) async {
          expect(r.method, 'GET');
          expect(r.url.origin, origin);
          expect(r.url.path, '/rest/v1/operation_receipts');
          expect(r.url.queryParameters, {
            'select':
                'user_id,operation,client_event_id,request_json,status,response_json',
            'user_id': 'eq.$userA',
            'operation': 'eq.$op',
            'client_event_id': 'eq.${receiptReference(op).clientEventId}',
            'limit': '2',
          });
          expect((r as http.Request).body, isEmpty);
          expect(
            r.headers['authorization'],
            'Bearer ${token(now, userA, generation)}',
          );
          expect(r.headers['apikey'], key);
          expect(r.headers['cache-control'], 'no-store');
          expect(r.followRedirects, isFalse);
          expect(r.maxRedirects, 0);
          return response(
            jsonEncode(status == 'UNKNOWN' ? [] : [originalRow(op, status)]),
          );
        };
        final result = await originalLookup(t, op);
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
        expect(network.requests.length, 1);
        expect(t.isCurrent, isTrue);
        expect(network.closed, isFalse);
      });
    }
  }

  test(
    'original-bound receipt rejects foreign scope and command before HTTP',
    () async {
      final t = make();
      for (final op in [
        'start_conversation',
        'conversation_turn',
        'finish_conversation',
      ]) {
        for (final ref in [
          receiptReference(op, owner: userB),
          receiptReference(op, project: 'https://foreign.invalid'),
        ]) {
          await expectLater(
            originalLookup(t, op, ref: ref),
            throwsA(failure(AiTextErrorCode.unauthorized)),
          );
        }
        await expectLater(
          originalLookup(
            t,
            op,
            original: {...request(op), 'client_event_id': sid},
          ),
          throwsA(failure(AiTextErrorCode.validationFailure)),
        );
        final wrong = op == 'start_conversation'
            ? 'finish_conversation'
            : 'start_conversation';
        await expectLater(
          originalLookup(t, op, ref: receiptReference(wrong)),
          throwsA(failure(AiTextErrorCode.validationFailure)),
        );
      }
      expect(network.requests, isEmpty);
    },
  );

  test(
    'original-bound receipt refuses changed request and legacy projection',
    () async {
      final t = make();
      for (final op in [
        'start_conversation',
        'conversation_turn',
        'finish_conversation',
      ]) {
        for (final status in ['PENDING', 'COMPLETED']) {
          for (final bad in [
            [receiptRow(op, status)],
            [
              originalRow(op, status)
                ..['request_json'] = {...request(op), 'client_event_id': sid},
            ],
            [
              originalRow(op, status)
                ..['request_json'] = {...request(op), 'extra': true},
            ],
            [originalRow(op, status)..['user_id'] = userB],
            [originalRow(op, status), originalRow(op, status)],
            for (final field in request(op).keys)
              [
                originalRow(op, status)
                  ..['request_json'] = (Map.of(request(op))..remove(field)),
              ],
          ]) {
            network.onSend = (_) async => response(jsonEncode(bad));
            await expectLater(
              originalLookup(t, op),
              throwsA(failure(AiTextErrorCode.internalError)),
            );
          }
        }
      }
      expect(
        network.requests.every(
          (r) => r.method == 'GET' && (r as http.Request).body.isEmpty,
        ),
        isTrue,
      );
    },
  );

  test(
    'original-bound receipt late result cannot survive revoke or release busy lane early',
    () async {
      final t = make();
      final held = Completer<http.StreamedResponse>();
      final entered = Completer<void>();
      final aborted = Completer<void>();
      network.onSend = (r) {
        unawaited(
          (r as http.AbortableRequest).abortTrigger!.then(
            (_) => aborted.complete(),
          ),
        );
        entered.complete();
        return held.future;
      };
      const op = 'conversation_turn';
      final result = expectLater(
        originalLookup(t, op),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      try {
        await entered.future;
        await expectLater(invoke(t), throwsA(isA<AiTextRequestPending>()));
        await expectLater(
          t.lookupReceipt(receiptReference(op)),
          throwsA(isA<AiTextRequestPending>()),
        );
        var closed = false;
        final closing = t.close().then((_) => closed = true);
        await aborted.future;
        await result;
        expect(closed, isFalse);
        expect(network.closed, isFalse);
        held.complete(response(jsonEncode([originalRow(op, 'COMPLETED')])));
        await closing;
        expect(closed, isTrue);
        expect(network.requests.length, 1);
        await expectLater(
          originalLookup(t, op),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        expect(network.requests.length, 1);
      } finally {
        if (!held.isCompleted) {
          held.complete(response('[]'));
        }
        await result;
        await t.close();
      }
    },
  );

  for (final status in ['UNKNOWN', 'PENDING', 'COMPLETED']) {
    test('receipt lookup fixed captured GET status=$status', () async {
      const op = 'start_conversation';
      final ref = receiptReference(op);
      final t = make();
      network.onSend = (r) async {
        expect(r.method, 'GET');
        expect(r.url.origin, origin);
        expect(r.url.path, '/rest/v1/operation_receipts');
        expect(r.url.queryParameters, {
          'select': 'user_id,operation,client_event_id,status,response_json',
          'user_id': 'eq.$userA',
          'operation': 'eq.$op',
          'client_event_id': 'eq.${ref.clientEventId}',
          'limit': '2',
        });
        expect((r as http.Request).body, isEmpty);
        expect(
          r.headers['authorization'],
          'Bearer ${token(now, userA, generation)}',
        );
        expect(r.headers['apikey'], key);
        expect(r.headers['cache-control'], 'no-store');
        expect(r.followRedirects, isFalse);
        return response(
          jsonEncode(status == 'UNKNOWN' ? [] : [receiptRow(op, status)]),
        );
      };
      final result = await t.lookupReceipt(ref);
      expect(result.status.name, status.toLowerCase());
      expect(result.start != null, status == 'COMPLETED');
      expect(result.turn, isNull);
      expect(result.finish, isNull);
      expect(result.toString(), isNot(contains('TEST ONLY')));
      expect(network.requests.length, 1);
      expect(network.closed, isFalse);
    });
  }
  for (final op in ['conversation_turn', 'finish_conversation']) {
    test('receipt lookup validates completed $op', () async {
      network.onSend = (_) async =>
          response(jsonEncode([receiptRow(op, 'COMPLETED')]));
      final result = await make().lookupReceipt(receiptReference(op));
      expect(result.status, ConversationReceiptStatus.completed);
      expect(result.turn != null, op == 'conversation_turn');
      expect(result.finish != null, op == 'finish_conversation');
      expect(network.requests.single.method, 'GET');
    });
  }
  test('receipt lookup rejects foreign scope before HTTP', () async {
    final t = make();
    for (final ref in [
      receiptReference('start_conversation', owner: userB),
      receiptReference('start_conversation', project: 'https://other.invalid'),
    ]) {
      await expectLater(
        t.lookupReceipt(ref),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
    }
    expect(network.requests, isEmpty);
  });
  test(
    'receipt lookup rejects malformed or misassociated projection',
    () async {
      const op = 'start_conversation';
      final good = receiptRow(op, 'COMPLETED');
      final bad = <Object?>[
        {},
        [good, good],
        [
          {...good, 'user_id': userB},
        ],
        [
          {...good, 'operation': 'conversation_turn'},
        ],
        [
          {...good, 'client_event_id': sid},
        ],
        [
          {...good, 'extra': true},
        ],
        [
          {...good, 'status': 'PENDING'},
        ],
        [
          {...good, 'response_json': null},
        ],
        [
          {
            ...good,
            'response_json': {'TEST_ONLY_PRIVATE': true},
          },
        ],
      ];
      final t = make();
      for (final value in bad) {
        network.onSend = (_) async => response(jsonEncode(value));
        await expectLater(
          t.lookupReceipt(receiptReference(op)),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
      }
      expect(network.requests.every((r) => r.method == 'GET'), isTrue);
    },
  );
  test('receipt lookup revoked late HTTP drains shared lane', () async {
    final t = make();
    final held = Completer<http.StreamedResponse>();
    final entered = Completer<void>();
    final aborted = Completer<void>();
    network.onSend = (r) {
      unawaited(
        (r as http.AbortableRequest).abortTrigger!.then(
          (_) => aborted.complete(),
        ),
      );
      entered.complete();
      return held.future;
    };
    final result = expectLater(
      t.lookupReceipt(receiptReference('start_conversation')),
      throwsA(failure(AiTextErrorCode.unauthorized)),
    );
    try {
      await entered.future;
      await expectLater(invoke(t), throwsA(isA<AiTextRequestPending>()));
      var closed = false;
      final closing = t.close().then((_) => closed = true);
      await aborted.future;
      await result;
      expect(closed, isFalse);
      expect(network.closed, isFalse);
      held.complete(
        response(jsonEncode([receiptRow('start_conversation', 'COMPLETED')])),
      );
      await closing;
      expect(closed, isTrue);
      expect(network.requests.length, 1);
    } finally {
      if (!held.isCompleted) {
        held.complete(response('[]'));
      }
      await result;
      await t.close();
    }
  });

  test(
    'shared SDK Auth port observes same-session rotation and borrows SDK lifetime',
    () async {
      final port = SupabaseRefreshableAccountAccess(sdk, auth);
      var closed = false;
      addTearDown(() async {
        if (!closed) {
          await port.close();
        }
      });
      var events = 0;
      final subscription = port.sessionChanges.listen((_) => events++);
      final original = port.currentSession;
      await settleAccount();
      events = 0;
      generation++;
      await port.refresh();
      await settleAccount();
      expect(identical(port.currentSession, original), isTrue);
      expect(port.currentRefreshToken, 'TEST_ONLY_REFRESH');
      expect(
        events,
        greaterThan(0),
      ); // SDK rotation signal despite stable binding identity.
      await port.close();
      closed = true;
      await subscription.cancel();
      final stopped = events;
      generation++;
      await sdk.auth.refreshSession();
      await settleAccount();
      expect(events, stopped);
      expect(sdk.auth.currentSession, isNotNull);
    },
  );

  for (final operation in ['restore', 'refresh']) {
    test('shared SDK Auth port redacts $operation failure', () async {
      var requests = 0;
      final failedHttp = MockClient((r) async {
        requests++;
        return http.Response(
          '{"error":"invalid_grant","error_description":"TEST_ONLY_PRIVATE_REFRESH"}',
          400,
          headers: {'content-type': 'application/json'},
        );
      });
      final failedSdk = SupabaseClient(
        origin,
        key,
        httpClient: failedHttp,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final failedBinding = SupabaseReviewBinding(
        client: failedSdk,
        projectUrl: origin,
        publishableKey: key,
        httpClient: failedHttp,
        now: () => now,
      );
      final port = SupabaseRefreshableAccountAccess(failedSdk, failedBinding);
      try {
        final result = operation == 'restore'
            ? port.restore('TEST_ONLY_REFRESH')
            : port.refresh();
        await expectLater(
          result,
          throwsA(
            isA<ReviewTransportFailure>()
                .having((e) => e.code, 'code', ReviewErrorCode.unauthorized)
                .having((e) => e.toString().contains('PRIVATE'), 'safe', false),
          ),
        );
        expect(port.currentSession, isNull);
        expect(port.currentRefreshToken, isNull);
        expect(requests, operation == 'restore' ? 1 : 0);
      } finally {
        await port.close();
        failedBinding.dispose();
        await failedSdk.dispose();
        failedHttp.close();
      }
    });
  }

  test(
    'same SDK receipt factory waits own profile before exact captured HTTP',
    () async {
      final backend = _ReceiptBackend();
      final profile = Completer<OwnProfile>();
      final owner = accountReceipt(backend, profileWait: profile);
      expect(owner.createAiConversationSession(), isNull);
      expect(owner.createAiTextRepository(), isNull);
      expect(network.requests, isEmpty);
      expect(backend.calls, isEmpty);
      profile.complete(
        decodeOwnProfile({
          'id': userA,
          'display_name': 'TEST ONLY',
          'preferred_jlpt': 'N5',
          'daily_target_minutes': 120,
          'timezone': 'Asia/Saigon',
        }, userA),
      );
      await settleAccount();
      final session = owner.createAiConversationSession()!;
      network.onSend = (r) async {
        expect(backend.calls.last, 'write-end');
        expect(
          ConversationReceiptReference.decode(backend.value! as String).ownerId,
          userA,
        );
        return response(output('start_conversation'));
      };
      await session.start(
        StartConversationRequest.fromJson(request('start_conversation')),
      );
      final sent = network.requests.single as http.AbortableRequest;
      expect(sent.url.toString(), '$origin/functions/v1/start_conversation');
      expect(sent.headers['authorization'], 'Bearer ${token(now, userA, 0)}');
      expect(sent.headers['apikey'], key);
      expect(sent.followRedirects, isFalse);
      expect(jsonDecode(sent.body), request('start_conversation'));
      await owner.close();
      expect(backend.value, isNotNull);
      expect(sdk.auth.currentSession, isNotNull);
      expect(network.closed, isFalse);
    },
  );

  for (final bad in ['project', 'key']) {
    test(
      'same SDK receipt factory rejects $bad mismatch before store ownership transfer',
      () async {
        final backend = _ReceiptBackend();
        expect(
          () => accountReceipt(
            backend,
            project: bad == 'project'
                ? 'https://other.supabase.invalid'
                : origin,
            publicKey: bad == 'key'
                ? 'sb_publishable_TEST_ONLY_0987654321'
                : key,
          ),
          throwsA(failure(AiTextErrorCode.validationFailure)),
        );
        expect(backend.calls, isEmpty);
        expect(network.requests, isEmpty);
        expect(sdk.auth.currentSession, isNotNull);
      },
    );
  }

  test(
    'same SDK receipt profile binding drains late write across A-B-A',
    () async {
      final backend = _ReceiptBackend()..writeWait = Completer<void>();
      final owner = accountReceipt(backend);
      await settleAccount();
      final old = owner.createAiConversationSession()!;
      final result = expectLater(
        old.start(
          StartConversationRequest.fromJson(request('start_conversation')),
        ),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      try {
        await backend.entered.future;
        nextUser = userB;
        await login();
        await settleAccount();
        expect(owner.createAiConversationSession(), isNull);
        nextUser = userA;
        generation++;
        await login();
        await settleAccount();
        expect(owner.createAiConversationSession(), isNull);
        expect(network.requests, isEmpty);
        backend.writeWait!.complete();
        await result;
        await settleAccount();
        final next = owner.createAiConversationSession()!;
        expect(identical(next, old), isFalse);
        await expectLater(
          next.start(
            StartConversationRequest.fromJson(request('start_conversation')),
          ),
          throwsA(failure(AiTextErrorCode.syncConflict)),
        );
        expect(network.requests, isEmpty);
        expect(backend.value, isNotNull);
      } finally {
        if (!backend.writeWait!.isCompleted) {
          backend.writeWait!.complete();
        }
      }
    },
  );

  for (final error in [false, true]) {
    test(
      'same SDK receipt local clear drains actual ignored abort error=$error',
      () async {
        final backend = _ReceiptBackend();
        final owner = accountReceipt(backend);
        await settleAccount();
        final held = Completer<http.StreamedResponse>();
        final entered = Completer<void>();
        final aborted = Completer<void>();
        network.onSend = (r) {
          final req = r as http.AbortableRequest;
          unawaited(req.abortTrigger!.then((_) => aborted.complete()));
          entered.complete();
          return held.future;
        };
        final session = owner.createAiConversationSession()!;
        final result = expectLater(
          session.start(
            StartConversationRequest.fromJson(request('start_conversation')),
          ),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        try {
          await entered.future;
          var done = false;
          final clearing = owner.clearForSignOut().then((_) => done = true);
          await aborted.future;
          await auth.signOutLocally(); // Host separately owns SDK logout.
          await settleAccount();
          expect(done, isFalse);
          expect(backend.calls, isNot(contains('clear')));
          expect(backend.value, isNotNull);
          expect(sdk.auth.currentSession, isNull);
          if (error) {
            held.completeError(StateError('TEST_ONLY_PRIVATE_LATE'));
          } else {
            held.complete(response(output('start_conversation')));
          }
          await result;
          await clearing;
          expect(backend.value, isNull);
          expect(backend.calls.last, 'clear');
          expect(network.requests.length, 1);
          expect(network.closed, isFalse);
        } finally {
          if (!held.isCompleted) {
            held.completeError(StateError('TEST_ONLY_CLEANUP'));
          }
        }
      },
    );
  }

  test(
    'fixed text endpoints use captured SDK bearer and exact original frozen bodies',
    () async {
      final t = make();
      for (final operation in ['tutor_explain', 'correct_sentence']) {
        expect(
          await invoke(t, operation: operation),
          fixture(operation, 'response'),
        );
        final sent = network.requests.last as http.AbortableRequest;
        expect(sent.method, 'POST');
        expect(sent.url.toString(), '$origin/functions/v1/$operation');
        expect(sent.followRedirects, isFalse);
        expect(sent.maxRedirects, 0);
        expect(sent.headers['authorization'], 'Bearer ${token(now, userA, 0)}');
        expect(sent.headers['apikey'], key);
        expect(sent.headers['cache-control'], 'no-store');
        expect(jsonDecode(sent.body), fixture(operation, 'request'));
      }
      expect(network.requests, hasLength(2));
      expect(network.closed, isFalse);
    },
  );

  test(
    'construction rejects readiness getter and timeout or project mismatch safely',
    () {
      ready = false;
      expect(make, throwsA(failure(AiTextErrorCode.unauthorized)));
      ready = true;
      brokenReady = true;
      expect(make, throwsA(failure(AiTextErrorCode.unauthorized)));
      brokenReady = false;
      for (final timeout in [Duration.zero, const Duration(seconds: 16)]) {
        expect(() => make(timeout: timeout), throwsArgumentError);
      }
      expect(
        () => SupabaseAiTextTransport(
          client: sdk,
          auth: auth,
          isReady: () => true,
          projectUrl: 'https://other.invalid',
          publishableKey: key,
        ),
        throwsArgumentError,
      );
      expect(
        () => SupabaseAiTextTransport(
          client: sdk,
          auth: auth,
          isReady: () => true,
          projectUrl: origin,
          publishableKey: 'TEST_ONLY_PRIVATE_KEY',
        ),
        throwsArgumentError,
      );
      expect(network.requests, isEmpty);
    },
  );

  test(
    'wrong captured identity is rejected without retargeting or dispatch',
    () async {
      final t = make();
      await expectLater(
        invoke(t, session: ReviewSession(userId: userA)),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(network.requests, isEmpty);
      expect(await invoke(t), fixture('tutor_explain', 'response'));
    },
  );

  test(
    'readiness loss or getter error permanently fences a capability',
    () async {
      for (final broken in [false, true]) {
        final t = make();
        brokenReady = broken;
        ready = false;
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        ready = true;
        brokenReady = false;
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
      }
      expect(network.requests, isEmpty);
    },
  );

  test(
    'expiry is checked before dispatch and cannot revive with clock rollback',
    () async {
      final t = make();
      final session = auth.currentSession!;
      now = now.add(const Duration(hours: 2));
      await expectLater(
        invoke(t, session: session),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      now = now.subtract(const Duration(hours: 2));
      await expectLater(
        invoke(t, session: session),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(network.requests, isEmpty);
    },
  );

  for (final change in ['refresh', 'account', 'logout']) {
    test(
      'SDK $change aborts held headers and never publishes with new credentials',
      () async {
        final t = make();
        final session = auth.currentSession!;
        final pending = Completer<http.StreamedResponse>();
        network.onSend = (_) => pending.future;
        final rejected = expectLater(
          invoke(t, session: session),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        final original = network.requests.single as http.AbortableRequest;
        if (change == 'logout') {
          await sdk.auth.signOut(scope: SignOutScope.local);
        } else {
          generation++;
          if (change == 'account') nextUser = userB;
          await login();
        }
        await Future<void>.delayed(Duration.zero);
        await rejected;
        expect(
          original.headers['authorization'],
          'Bearer ${token(now, userA, 0)}',
        );
        await expectLater(original.abortTrigger, completes);
        expect(t.isBusy, isTrue);
        var cancelled = false;
        final body = StreamController<List<int>>(
          onCancel: () {
            cancelled = true;
          },
        );
        pending.complete(http.StreamedResponse(body.stream, 200));
        await Future<void>.delayed(Duration.zero);
        expect(cancelled, isTrue);
        expect(t.isBusy, isFalse);
        expect(t.isCurrent, isFalse);
        await body.close();
        expect(network.requests, hasLength(1));
      },
    );
  }

  test(
    'unknown owner fields invalid contexts and byte overflow fail before HTTP',
    () async {
      final t = make();
      for (final body in [
        {...request('tutor_explain'), 'user_id': userA},
        {
          ...request('tutor_explain'),
          'context': <String, Object>{'recent_grammar_ids': <String>[]},
        },
        {...request('tutor_explain'), 'jlpt_level': 'UNKNOWN'},
        {...request('tutor_explain'), 'question_vi': ''},
        TutorExplainRequest(
          level: AiTextLevel.n5,
          questionVi: '\u0001' * 5000,
          recentGrammarIds: List.generate(
            100,
            (i) =>
                'a1000000-0000-4000-8000-${(i + 1).toString().padLeft(12, '0')}',
          ),
        ).toJson(),
      ]) {
        await expectLater(
          invoke(t, body: body),
          throwsA(failure(AiTextErrorCode.validationFailure)),
        );
      }
      expect(network.requests, isEmpty);
      expect(t.isBusy, isFalse);
    },
  );

  test(
    'single-flight registration precedes synchronous HTTP reentry',
    () async {
      final t = make();
      Future<void>? nested;
      network.onSend = (_) async {
        nested = expectLater(
          invoke(t, operation: 'correct_sentence'),
          throwsA(isA<AiTextRequestPending>()),
        );
        return response(output());
      };
      await invoke(t);
      await nested!;
      expect(network.requests, hasLength(1));
    },
  );

  test(
    'redirects are rejected and bodies cancelled without following Location',
    () async {
      final t = make();
      for (final code in [301, 302, 307, 308]) {
        var cancelled = false;
        final stream = StreamController<List<int>>(
          onCancel: () {
            cancelled = true;
          },
        );
        network.onSend = (_) async => http.StreamedResponse(
          stream.stream,
          code,
          headers: {'location': 'https://untrusted.invalid/TEST_ONLY_SECRET'},
        );
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
        await Future<void>.delayed(Duration.zero);
        expect(cancelled, isTrue);
        await stream.close();
      }
      expect(network.requests, hasLength(4));
    },
  );

  test(
    'unsupported media encoding and malformed declared lengths fail closed',
    () async {
      final t = make();
      for (final headers in <Map<String, String>>[
        {},
        {'content-type': 'text/html'},
        {'content-type': 'application/json; charset=latin1'},
        {'content-type': 'application/json', 'content-encoding': 'gzip'},
        {'content-type': 'application/json', 'content-length': '01'},
        {'content-type': 'application/json', 'content-length': '-1'},
        {'content-type': 'application/json', 'content-length': '1048577'},
        {
          'content-type': 'application/json',
          'Content-Type': 'application/json',
        },
      ]) {
        network.onSend = (_) async => response(output(), headers: headers);
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
      }
    },
  );

  test(
    'declared byte length must match actual bytes and SDK length metadata',
    () async {
      final t = make();
      final n = utf8.encode(output()).length;
      for (final declared in [n - 1, n + 1]) {
        network.onSend = (_) async => response(
          output(),
          headers: {
            'content-type': 'application/json',
            'content-length': '$declared',
          },
        );
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
      }
      network.onSend = (_) async => response(
        output(),
        length: n,
        headers: {
          'content-type': 'application/json',
          'content-length': '${n + 1}',
        },
      );
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
      network.onSend = (_) async => response(output(), length: n);
      expect(await invoke(t), fixture('tutor_explain', 'response'));
    },
  );

  test(
    'actual stream cap accepts exact limit and cancels one byte overflow',
    () async {
      final t = make(timeout: const Duration(seconds: 5));
      final base = utf8.encode(output());
      final exact = [
        ...base,
        ...List.filled(
          SupabaseAiTextTransport.maxResponseBytes - base.length,
          32,
        ),
      ];
      network.onSend = (_) async => http.StreamedResponse(
        Stream.value(exact),
        200,
        headers: {'content-type': 'application/json'},
      );
      expect(await invoke(t), fixture('tutor_explain', 'response'));
      var cancelled = false;
      final stream = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      network.onSend = (_) async => http.StreamedResponse(
        stream.stream,
        200,
        headers: {'content-type': 'application/json'},
      );
      final rejected = expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
      stream.add(exact);
      stream.add([32]);
      await rejected;
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      await stream.close();
    },
  );

  test(
    'split UTF8 succeeds while malformed truncated and BOM input is rejected',
    () async {
      final t = make();
      final valid = utf8.encode(output());
      network.onSend = (_) async => http.StreamedResponse(
        Stream.fromIterable(valid.map((b) => [b])),
        200,
        headers: {'content-type': 'application/json'},
      );
      expect(await invoke(t), fixture('tutor_explain', 'response'));
      for (final bytes in [
        [...valid, 0xc0, 0xaf],
        [...valid, 0xe3, 0x81],
        [239, 187, 191, ...valid],
      ]) {
        network.onSend = (_) async => http.StreamedResponse(
          Stream.value(bytes),
          200,
          headers: {'content-type': 'application/json'},
        );
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
      }
    },
  );

  test(
    'duplicate escaped nested keys excessive depth and malformed JSON are rejected',
    () async {
      final t = make();
      for (final text in [
        '{"answer_vi":"old","answer_vi":"new","examples":[],"practice":[]}',
        r'{"answer_vi":"old","\u0061nswer_vi":"new","examples":[],"practice":[]}',
        '{"answer_vi":"x","examples":[{"sentence_ja":"x","sentence_ja":"y","reading_ja":"x","translation_vi":"x"}],"practice":[]}',
        '${'[' * 17}0${']' * 17}',
        '${output()} trailing',
        '[]',
        'null',
        output('correct_sentence'),
      ]) {
        network.onSend = (_) async => response(text);
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
      }
    },
  );

  test('empty chunk floods are bounded and cancelled', () async {
    final t = make();
    var cancelled = false;
    final stream = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    network.onSend = (_) async => http.StreamedResponse(
      stream.stream,
      200,
      headers: {'content-type': 'application/json'},
    );
    final rejected = expectLater(
      invoke(t),
      throwsA(failure(AiTextErrorCode.internalError)),
    );
    for (var i = 0; i <= SupabaseAiTextTransport.maxResponseReads; i++) {
      stream.add([]);
    }
    await rejected;
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isTrue);
    await stream.close();
  });

  test(
    'raw client and stream exceptions expose only fixed safe failures',
    () async {
      final t = make();
      for (final error in [
        http.ClientException('TEST_ONLY_RAW_SECRET'),
        StateError('TEST_ONLY_RAW_SECRET'),
      ]) {
        network.onSend = (_) => Future.error(error);
        try {
          await invoke(t);
          fail('expected safe failure');
        } on AiTextFailure catch (e) {
          expect(
            e.code,
            error is http.ClientException
                ? AiTextErrorCode.networkUnavailable
                : AiTextErrorCode.internalError,
          );
          expect(e.toString(), isNot(contains('SECRET')));
          expect(e.messageVi, isNot(contains('SECRET')));
        }
      }
      network.onSend = (_) async => http.StreamedResponse(
        Stream.error(StateError('TEST_ONLY_RAW_SECRET')),
        200,
        headers: {'content-type': 'application/json'},
      );
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
    },
  );

  test(
    'matching HTTP errors discard server text and clamp permanent retry flags',
    () async {
      final t = make();
      for (final entry in <AiTextErrorCode, int>{
        AiTextErrorCode.forbidden: 403,
        AiTextErrorCode.notFound: 404,
        AiTextErrorCode.validationFailure: 400,
        AiTextErrorCode.rateLimited: 429,
        AiTextErrorCode.networkUnavailable: 503,
        AiTextErrorCode.providerUnavailable: 503,
        AiTextErrorCode.syncConflict: 409,
        AiTextErrorCode.internalError: 500,
      }.entries) {
        network.onSend = (_) async => response(
          jsonEncode({
            'code': entry.key.wireName,
            'message_vi': 'TEST_ONLY_SERVER_SECRET',
            'retryable': true,
          }),
          status: entry.value,
        );
        await expectLater(
          invoke(t),
          throwsA(
            failure(entry.key)
                .having(
                  (f) => f.messageVi,
                  'fixed message',
                  entry.key.messageVi,
                )
                .having(
                  (f) => f.retryable,
                  'transient only',
                  [
                    AiTextErrorCode.rateLimited,
                    AiTextErrorCode.networkUnavailable,
                    AiTextErrorCode.providerUnavailable,
                  ].contains(entry.key),
                ),
          ),
        );
      }
      network.onSend = (_) async => response(output(), status: 409);
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.syncConflict)),
      );
      network.onSend = (_) async =>
          response('{"code":"FORBIDDEN","message_vi":"raw","retryable":false}');
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
    },
  );

  test(
    'HTTP unauthorized revokes before reading an invalid gateway body',
    () async {
      final t = make();
      network.onSend = (_) async => response(
        'TEST_ONLY_RAW_SECRET',
        status: 401,
        headers: {'content-type': 'text/html'},
      );
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(network.requests, hasLength(1));
    },
  );

  for (final lateError in [false, true]) {
    test(
      'header timeout retains lock through late settlement error=$lateError',
      () async {
        final t = make(timeout: const Duration(milliseconds: 25));
        final pending = Completer<http.StreamedResponse>();
        network.onSend = (_) => pending.future;
        await expectLater(
          invoke(t),
          throwsA(failure(AiTextErrorCode.networkUnavailable)),
        );
        expect(t.isBusy, isTrue);
        await expectLater(
          (network.requests.single as http.AbortableRequest).abortTrigger,
          completes,
        );
        await expectLater(invoke(t), throwsA(isA<AiTextRequestPending>()));
        expect(network.requests, hasLength(1));
        var cancelled = false;
        final stream = StreamController<List<int>>(
          onCancel: () {
            cancelled = true;
          },
        );
        if (lateError) {
          pending.completeError(StateError('TEST_ONLY_LATE_SECRET'));
        } else {
          pending.complete(http.StreamedResponse(stream.stream, 200));
        }
        await Future<void>.delayed(Duration.zero);
        expect(t.isBusy, isFalse);
        expect(cancelled, !lateError);
        // No response ever owns this fixture stream in the late-error case.
        if (lateError) unawaited(stream.stream.drain<void>());
        await stream.close();
        network.onSend = (_) async => response(output());
        await invoke(t);
        expect(network.requests, hasLength(2));
      },
    );
  }

  test('body stall has one overall deadline and cancels its stream', () async {
    final t = make(timeout: const Duration(milliseconds: 50));
    var cancelled = false;
    final stream = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    network.onSend = (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.StreamedResponse(
        stream.stream,
        200,
        headers: {'content-type': 'application/json'},
      );
    };
    await expectLater(
      invoke(t),
      throwsA(failure(AiTextErrorCode.networkUnavailable)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isTrue);
    expect(t.isBusy, isFalse);
    await stream.close();
    expect(network.requests, hasLength(1));
  });

  test(
    'owner revoke fences a held body without closing borrowed SDK or HTTP',
    () async {
      final t = make();
      var listening = Completer<void>();
      var cancelled = false;
      final stream = StreamController<List<int>>(
        onListen: () => listening.complete(),
        onCancel: () {
          cancelled = true;
        },
      );
      network.onSend = (_) async => http.StreamedResponse(
        stream.stream,
        200,
        headers: {'content-type': 'application/json'},
      );
      final rejected = expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      await listening.future;
      t.revoke();
      await rejected;
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      expect(network.closed, isFalse);
      expect(sdk.auth.currentSession, isNotNull);
      await stream.close();
    },
  );

  test(
    'close is idempotent drains ignored abort and leaves borrowed clients open',
    () async {
      final t = make();
      final session = auth.currentSession!;
      final pending = Completer<http.StreamedResponse>();
      network.onSend = (_) => pending.future;
      final rejected = expectLater(
        invoke(t, session: session),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      var drained = false;
      final closing = t.close()
        ..then((_) {
          drained = true;
        });
      expect(identical(closing, t.close()), isTrue);
      await rejected;
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      pending.completeError(StateError('TEST_ONLY_LATE_SECRET'));
      await closing;
      expect(drained, isTrue);
      expect(network.closed, isFalse);
      expect(sdk.auth.currentSession, isNotNull);
    },
  );

  test(
    'repository preserves local pending while HTTP remains held after timeout',
    () async {
      final t = make(timeout: const Duration(milliseconds: 25));
      final repo = CapturedAiTextRepository(
        auth: auth,
        transport: t,
        isReady: () => ready,
      );
      final pending = Completer<http.StreamedResponse>();
      network.onSend = (_) => pending.future;
      final request = TutorExplainRequest(
        level: AiTextLevel.n5,
        questionVi: 'TEST ONLY',
      );
      await expectLater(
        repo.explain(request),
        throwsA(failure(AiTextErrorCode.networkUnavailable)),
      );
      await expectLater(
        repo.explain(request),
        throwsA(isA<AiTextRequestPending>()),
      );
      expect(network.requests, hasLength(1));
      pending.completeError(StateError('TEST_ONLY_LATE_SECRET'));
      await Future<void>.delayed(Duration.zero);
      network.onSend = (_) async => response(output());
      await repo.explain(request);
      expect(network.requests, hasLength(2));
    },
  );
  test(
    'uncooperative stream cancellation retains busy until cleanup settles',
    () async {
      final t = make(timeout: const Duration(milliseconds: 25));
      final cleanup = Completer<void>();
      var cancelled = false;
      final stream = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
          return cleanup.future;
        },
      );
      network.onSend = (_) async => http.StreamedResponse(
        stream.stream,
        200,
        headers: {'content-type': 'text/html'},
      );
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
      expect(cancelled, isTrue);
      expect(t.isBusy, isTrue);
      await expectLater(invoke(t), throwsA(isA<AiTextRequestPending>()));
      expect(network.requests, hasLength(1));
      cleanup.complete();
      await Future<void>.delayed(Duration.zero);
      expect(t.isBusy, isFalse);
      await stream.close();
    },
  );

  test(
    'cancellation failure permanently revokes without exposing raw detail',
    () async {
      final t = make();
      final stream = StreamController<List<int>>(
        onCancel: () =>
            Future<void>.error(StateError('TEST_ONLY_CANCEL_SECRET')),
      );
      network.onSend = (_) async => http.StreamedResponse(
        stream.stream,
        200,
        headers: {'content-type': 'text/html'},
      );
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
      expect(t.isCurrent, isFalse);
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(network.requests, hasLength(1));
      expect(network.closed, isFalse);
      await stream.close();
    },
  );

  test(
    'conversation fixed endpoints preserve captured bearer event and exact wire',
    () async {
      final t = make();
      for (final op in [
        'start_conversation',
        'conversation_turn',
        'finish_conversation',
      ]) {
        final body = request(op);
        if (op == 'conversation_turn') body['text_ja'] = '  日\u3099  ';
        expect(
          await t.invoke(
            capturedSession: auth.currentSession!,
            operation: op,
            body: body,
          ),
          fixture(op, 'response'),
        );
        final sent = network.requests.last as http.AbortableRequest;
        expect(sent.url.toString(), '$origin/functions/v1/$op');
        expect(sent.method, 'POST');
        expect(sent.headers['authorization'], 'Bearer ${token(now, userA, 0)}');
        expect(sent.headers['apikey'], key);
        expect(sent.headers['cache-control'], 'no-store');
        expect(sent.followRedirects, isFalse);
        expect(sent.maxRedirects, 0);
        expect(jsonDecode(sent.body), body);
      }
      expect(network.requests, hasLength(3));
    },
  );
  test(
    'conversation operation allowlist and strict bodies reject before HTTP',
    () async {
      final t = make();
      for (final op in [
        'tutor_explain',
        'correct_sentence',
        '../auth/v1/token',
        'start_conversation?owner=x',
        'https://evil.invalid',
      ]) {
        await expectLater(
          t.invoke(
            capturedSession: auth.currentSession!,
            operation: op,
            body: request('start_conversation'),
          ),
          throwsA(failure(AiTextErrorCode.validationFailure)),
        );
      }
      for (final op in [
        'start_conversation',
        'conversation_turn',
        'finish_conversation',
      ]) {
        for (final body in [
          {...request(op), 'user_id': userB},
          {...request(op), 'client_event_id': 'private malformed id'},
          <String, Object>{},
        ]) {
          await expectLater(
            t.invoke(
              capturedSession: auth.currentSession!,
              operation: op,
              body: body,
            ),
            throwsA(failure(AiTextErrorCode.validationFailure)),
          );
        }
        await expectLater(
          t.invoke(
            capturedSession: ReviewSession(userId: userA),
            operation: op,
            body: request(op),
          ),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
      }
      expect(network.requests, isEmpty);
    },
  );
  for (final op in [
    'start_conversation',
    'conversation_turn',
    'finish_conversation',
  ]) {
    test(
      'conversation strict response decoding $op rejects foreign shape and duplicate JSON keys',
      () async {
        final t = make();
        for (final raw in [
          output('tutor_explain'),
          '{"scores":{},"scores":{}}',
          '{"private":"malformed"}',
        ]) {
          network.onSend = (_) async => response(raw);
          await expectLater(
            t.invoke(
              capturedSession: auth.currentSession!,
              operation: op,
              body: request(op),
            ),
            throwsA(failure(AiTextErrorCode.internalError)),
          );
        }
        expect(network.requests, hasLength(3));
        network.onSend = (_) async => response(output(op));
        expect(
          await t.invoke(
            capturedSession: auth.currentSession!,
            operation: op,
            body: request(op),
          ),
          fixture(op, 'response'),
        );
      },
    );
  }
  for (final firstConversation in [true, false]) {
    test(
      'text and conversation share one actual HTTP busy lease conversationFirst=$firstConversation',
      () async {
        final t = make();
        final held = Completer<http.StreamedResponse>();
        network.onSend = (_) => held.future;
        Future<Object?> conversation() => t.invoke(
          capturedSession: auth.currentSession!,
          operation: 'start_conversation',
          body: request('start_conversation'),
        );
        final first = firstConversation ? conversation() : invoke(t);
        await expectLater(
          firstConversation ? invoke(t) : conversation(),
          throwsA(isA<AiTextRequestPending>()),
        );
        expect(network.requests, hasLength(1));
        held.complete(
          response(
            output(firstConversation ? 'start_conversation' : 'tutor_explain'),
          ),
        );
        await first;
        expect(t.isBusy, isFalse);
        network.onSend = (r) async =>
            response(output(r.url.path.split('/').last));
        await (firstConversation ? invoke(t) : conversation());
        expect(network.requests, hasLength(2));
      },
    );
  }
  test(
    'captured conversation progression uses SDK HTTP and replays locally without redispatch',
    () async {
      final t = make();
      final flow = CapturedConversationSession(
        auth: auth,
        transport: t,
        isReady: () => ready && t.isCurrent,
      );
      network.onSend = (r) async {
        final op = r.url.path.split('/').last;
        final raw = jsonDecode(output(op)) as Map<String, Object?>;
        if (op == 'conversation_turn') {
          final message = raw['assistant_message']! as Map<String, Object?>;
          message['sequence_no'] = 2;
          message['id'] = userB;
        }
        return response(jsonEncode(raw));
      };
      final start = StartConversationRequest.fromJson(
        request('start_conversation'),
      );
      final turn = ConversationTurnRequest.fromJson(
        request('conversation_turn'),
      );
      final finish = FinishConversationRequest.fromJson(
        request('finish_conversation'),
      );
      await flow.start(start);
      await flow.turn(turn);
      final active = flow.snapshot;
      await flow.start(start);
      await flow.turn(turn);
      expect(identical(flow.snapshot, active), isTrue);
      final summary = await flow.finish(finish);
      expect(identical(await flow.finish(finish), summary), isTrue);
      expect(flow.snapshot.phase, ConversationSessionPhase.finished);
      expect(flow.snapshot.messages.map((m) => m.sequenceNo), [0, 2]);
      expect(network.requests, hasLength(3));
      flow.revoke();
      expect(flow.snapshot.messages, isEmpty);
      expect(network.closed, isFalse);
    },
  );
  test(
    'conversation timeout fences ignored abort then exact event retry after actual drain',
    () async {
      final t = make(timeout: const Duration(milliseconds: 25));
      final flow = CapturedConversationSession(
        auth: auth,
        transport: t,
        isReady: () => ready && t.isCurrent,
      );
      final held = Completer<http.StreamedResponse>();
      network.onSend = (_) => held.future;
      final start = StartConversationRequest.fromJson(
        request('start_conversation'),
      );
      await expectLater(
        flow.start(start),
        throwsA(failure(AiTextErrorCode.networkUnavailable)),
      );
      expect(t.isBusy, isTrue);
      expect(flow.hasUnresolvedMutation, isTrue);
      expect(flow.snapshot.phase, ConversationSessionPhase.notStarted);
      await expectLater(
        flow.start(start),
        throwsA(isA<AiTextRequestPending>()),
      );
      await expectLater(invoke(t), throwsA(isA<AiTextRequestPending>()));
      held.completeError(StateError('TEST_ONLY_PRIVATE_LATE'));
      await Future<void>.delayed(Duration.zero);
      expect(t.isBusy, isFalse);
      expect(flow.hasUnresolvedMutation, isTrue);
      await expectLater(
        flow.start(
          StartConversationRequest(
            scenarioId: start.scenarioId,
            level: start.level,
            clientEventId: userB,
          ),
        ),
        throwsA(isA<AiTextRequestPending>()),
      );
      expect(network.requests, hasLength(1));
      network.onSend = (_) async => response(output('start_conversation'));
      await flow.start(start);
      final first = network.requests.first as http.Request;
      final second = network.requests.last as http.Request;
      expect(first.bodyBytes, second.bodyBytes);
      expect(flow.snapshot.phase, ConversationSessionPhase.active);
      expect(flow.hasUnresolvedMutation, isFalse);
      expect(network.requests, hasLength(2));
    },
  );
  test(
    'conversation 401 and SDK session replacement permanently fence old capability',
    () async {
      final t = make();
      final old = auth.currentSession!;
      network.onSend = (_) async => response(
        'TEST_ONLY_PRIVATE_BODY',
        status: 401,
        headers: {'content-type': 'text/plain'},
      );
      await expectLater(
        t.invoke(
          capturedSession: old,
          operation: 'start_conversation',
          body: request('start_conversation'),
        ),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(t.isCurrent, isFalse);
      await expectLater(
        invoke(t),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      generation++;
      await login();
      final fresh = make();
      generation++;
      await login();
      await expectLater(
        fresh.invoke(
          capturedSession: auth.currentSession!,
          operation: 'start_conversation',
          body: request('start_conversation'),
        ),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(network.requests, hasLength(1));
      await t.close();
      expect(network.closed, isFalse);
      expect(sdk.auth.currentSession, isNotNull);
    },
  );

  Map<String, Object> scenarioRow([String level = 'N5']) => {
    'id': userA,
    'jlpt_level': level,
    'title_vi': 'Tình huống',
    'title_ja': '会話',
    'description_vi': 'Mô tả',
    'content_version': 1,
    'is_active': true,
  };
  CapturedConversationScenarios catalog(SupabaseAiTextTransport t) =>
      CapturedConversationScenarios(auth: auth, port: t, isReady: () => ready);

  test(
    'scenario GET uses fixed public query and captured SDK bearer without provider call',
    () async {
      final t = make();
      final r = catalog(t);
      expect(network.requests, isEmpty);
      for (final level in [AiTextLevel.n5, AiTextLevel.n4]) {
        network.onSend = (_) async =>
            response(jsonEncode([scenarioRow(level.wireName)]));
        expect((await r.load(level)).single.level, level);
        final sent = network.requests.last as http.AbortableRequest;
        expect(sent.method, 'GET');
        expect(sent.url.path, '/rest/v1/conversation_scenarios');
        expect(sent.url.origin, origin);
        expect(sent.url.queryParameters, {
          'select':
              'id,jlpt_level,title_vi,title_ja,description_vi,content_version,is_active',
          'is_active': 'eq.true',
          'jlpt_level': 'eq.${level.wireName}',
          'order': 'id.asc',
          'limit': '101',
        });
        expect(sent.bodyBytes, isEmpty);
        expect(sent.followRedirects, isFalse);
        expect(sent.maxRedirects, 0);
        expect(sent.headers['authorization'], 'Bearer ${token(now, userA, 0)}');
        expect(sent.headers['apikey'], key);
        expect(sent.headers['cache-control'], 'no-store');
      }
      expect(network.requests, hasLength(2));
    },
  );
  test(
    'scenario read rejects unsupported level foreign owner and operation injection before HTTP',
    () async {
      final t = make();
      await expectLater(
        t.read(capturedSession: auth.currentSession!, level: AiTextLevel.n3),
        throwsA(failure(AiTextErrorCode.validationFailure)),
      );
      await expectLater(
        t.read(
          capturedSession: ReviewSession(userId: userA),
          level: AiTextLevel.n5,
        ),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      await expectLater(
        t.invoke(
          capturedSession: auth.currentSession!,
          operation: 'conversation_scenarios',
          body: {'jlpt_level': 'N5'},
        ),
        throwsA(failure(AiTextErrorCode.validationFailure)),
      );
      expect(network.requests, isEmpty);
    },
  );
  test(
    'scenario pipeline rejects private mixed duplicate and overflow rows without partial publication',
    () async {
      final t = make();
      final r = catalog(t);
      for (final rows in <Object>[
        [
          scenarioRow(),
          {...scenarioRow(), 'system_context': 'PRIVATE'},
        ],
        [scenarioRow('N4')],
        [scenarioRow(), scenarioRow()],
        List.generate(101, (_) => scenarioRow()),
        List.generate(102, (_) => scenarioRow()),
      ]) {
        network.onSend = (_) async => response(jsonEncode(rows));
        await expectLater(
          r.load(AiTextLevel.n5),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
        expect(t.isBusy, isFalse);
      }
      network.onSend = (_) async => response('[]');
      expect(await r.load(AiTextLevel.n5), isEmpty);
    },
  );
  test(
    'scenario HTTP preserves bounded headers UTF8 duplicate-key and JSON defenses',
    () async {
      final t = make();
      final r = catalog(t);
      for (final reply in <http.StreamedResponse>[
        response(
          '[]',
          status: 302,
          headers: {'location': 'https://private.invalid'},
        ),
        response('[]', headers: {'content-type': 'text/html'}),
        response(
          '[]',
          headers: {
            'content-type': 'application/json',
            'content-length': '1048577',
          },
        ),
        response('[]', length: 3),
        response('\ufeff[]'),
        response('[{"id":"one","id":"two"}]'),
        response(List.filled(17, '[').join() + List.filled(17, ']').join()),
        http.StreamedResponse(
          Stream.value([255]),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ]) {
        network.onSend = (_) async => reply;
        await expectLater(
          r.load(AiTextLevel.n5),
          throwsA(isA<AiTextFailure>()),
        );
        expect(t.isBusy, isFalse);
      }
      expect(network.requests, hasLength(8));
    },
  );
  test(
    'scenario response chunk byte limit and read budget are enforced',
    () async {
      final t = make();
      final r = catalog(t);
      network.onSend = (_) async => http.StreamedResponse(
        Stream.value(
          List.filled(SupabaseAiTextTransport.maxResponseBytes + 1, 32),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
      await expectLater(
        r.load(AiTextLevel.n5),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
      network.onSend = (_) async => http.StreamedResponse(
        Stream.fromIterable(
          List.generate(
            SupabaseAiTextTransport.maxResponseReads + 1,
            (_) => <int>[],
          ),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
      await expectLater(
        r.load(AiTextLevel.n5),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
      expect(network.requests, hasLength(2));
    },
  );
  for (final lateError in [false, true]) {
    test(
      'scenario timeout holds shared text/conversation busy lease until late header drains error=$lateError',
      () async {
        final t = make(timeout: const Duration(milliseconds: 10));
        final r = catalog(t);
        final held = Completer<http.StreamedResponse>();
        network.onSend = (_) => held.future;
        await expectLater(
          r.load(AiTextLevel.n5),
          throwsA(failure(AiTextErrorCode.networkUnavailable)),
        );
        expect(t.isBusy, isTrue);
        await expectLater(invoke(t), throwsA(isA<AiTextRequestPending>()));
        await expectLater(
          t.invoke(
            capturedSession: auth.currentSession!,
            operation: 'start_conversation',
            body: request('start_conversation'),
          ),
          throwsA(isA<AiTextRequestPending>()),
        );
        expect(network.requests, hasLength(1));
        if (lateError) {
          held.completeError(StateError('PRIVATE'));
        } else {
          held.complete(response('[]'));
        }
        await Future<void>.delayed(Duration.zero);
        expect(t.isBusy, isFalse);
        network.onSend = (_) async => response('[]');
        expect(await r.load(AiTextLevel.n5), isEmpty);
        expect(network.requests, hasLength(2));
      },
    );
  }
  test(
    'held text blocks scenario dispatch and close preserves borrowed SDK and HTTP',
    () async {
      final t = make();
      final held = Completer<http.StreamedResponse>();
      network.onSend = (_) => held.future;
      final first = invoke(t);
      await expectLater(
        t.read(capturedSession: auth.currentSession!, level: AiTextLevel.n5),
        throwsA(isA<AiTextRequestPending>()),
      );
      held.complete(response(output()));
      await first;
      await t.close();
      expect(network.requests, hasLength(1));
      expect(network.closed, isFalse);
      expect(sdk.auth.currentSession, isNotNull);
    },
  );
  for (final mode in ['ready', 'session', '401']) {
    test(
      'scenario read fences ready SDK replacement and unauthorized mode=$mode',
      () async {
        final t = make();
        final r = catalog(t);
        final held = Completer<http.StreamedResponse>();
        network.onSend = (_) => held.future;
        final work = r.load(AiTextLevel.n5);
        final checked = expectLater(
          work,
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        if (mode == 'ready') {
          ready = false;
          t.revoke();
        }
        if (mode == 'session') {
          generation++;
          await login();
        }
        held.complete(
          mode == '401'
              ? response(
                  'PRIVATE',
                  status: 401,
                  headers: {'content-type': 'text/plain'},
                )
              : response(jsonEncode([scenarioRow()])),
        );
        await checked;
        expect(t.isCurrent, isFalse);
        expect(r.isCurrent, isFalse);
        expect(network.requests, hasLength(1));
        ready = true;
        await expectLater(
          r.load(AiTextLevel.n5),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
      },
    );
  }
  // TEST ONLY storage ports; actual pinned SDK/Auth binding/HTTP transport and
  // receipt lifecycle composition. No hosted JWT/provider/native storage proof.
  ReceiptAiRuntimeOwner receiptOwner(_ReceiptBackend backend) {
    final store = ConversationReceiptStore(
      scope: ConversationReceiptScope(projectUrl: origin, ownerId: userA),
      backend: backend,
    );
    addTearDown(store.close);
    final owner = ReceiptAiRuntimeOwner(
      store: store,
      createTransport: ({required auth, required isReady, required store}) =>
          ReceiptGuardedAiTransport(
            inner: make(readiness: isReady),
            store: store,
            auth: auth,
            capturedSession: auth.currentSession!,
            isReady: isReady,
          ),
    );
    addTearDown(owner.close);
    return owner;
  }

  test(
    'SDK receipt confirmed before exact captured wire and reopen never redispatches',
    () async {
      final backend = _ReceiptBackend()..writeWait = Completer<void>();
      final owner = receiptOwner(backend);
      final command = StartConversationRequest.fromJson(
        request('start_conversation'),
      );
      final session = owner.runtime.acquireConversation(
        auth: auth,
        generation: AiTextGeneration(),
        isReady: () => ready,
      )!;
      network.onSend = (sent) async {
        expect(
          backend.value,
          ConversationReceiptReference.fromStart(
            projectUrl: origin,
            ownerId: userA,
            request: command,
          ).encode(),
        );
        expect(backend.calls.last, 'write-end');
        return response(output('start_conversation'));
      };
      try {
        final accepted = session.start(command);
        await backend.entered.future;
        expect(network.requests, isEmpty);
        backend.writeWait!.complete();
        expect((await accepted).sessionId, isNotEmpty);
        final wire = network.requests.single as http.AbortableRequest;
        expect(wire.url.toString(), '$origin/functions/v1/start_conversation');
        expect(wire.headers['authorization'], 'Bearer ${token(now, userA, 0)}');
        expect(wire.headers['apikey'], key);
        expect(wire.followRedirects, false);
        expect(jsonDecode(wire.body), command.toJson());
        final saved = backend.value;
        await owner.close();
        expect(backend.value, saved);
        expect(backend.calls.contains('clear'), false);
        final reopened = receiptOwner(backend);
        final fresh = reopened.runtime.acquireConversation(
          auth: auth,
          generation: AiTextGeneration(),
          isReady: () => ready,
        )!;
        await expectLater(
          fresh.start(command),
          throwsA(failure(AiTextErrorCode.syncConflict)),
        );
        expect(network.requests, hasLength(1));
        await reopened.signOut();
        expect(backend.value, isNull);
        expect(
          sdk.auth.currentUser!.id,
          userA,
        ); // Local receipt clear is not Auth logout.
      } finally {
        if (!backend.writeWait!.isCompleted) backend.writeWait!.complete();
        await owner.close();
      }
    },
  );

  for (final write in [false, true]) {
    test(
      'SDK receipt storage failure blocks HTTP even after ambiguous write=$write',
      () async {
        final backend = _ReceiptBackend()
          ..failRead = !write
          ..failWrite = write;
        final owner = receiptOwner(backend);
        final session = owner.runtime.acquireConversation(
          auth: auth,
          generation: AiTextGeneration(),
          isReady: () => ready,
        )!;
        await expectLater(
          session.start(
            StartConversationRequest.fromJson(request('start_conversation')),
          ),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
        expect(network.requests, isEmpty);
        if (write) {
          expect(
            backend.value,
            isNotNull,
          ); // Ambiguous failure remains pending.
        }
        await owner.signOut();
        expect(backend.value, isNull);
        expect(backend.calls.last, 'clear');
        expect(sdk.auth.currentUser!.id, userA);
      },
    );
  }

  for (final error in [false, true]) {
    test(
      'SDK receipt signout drains ignored-abort HTTP before clear error=$error',
      () async {
        final backend = _ReceiptBackend();
        final owner = receiptOwner(backend);
        final pending = Completer<http.StreamedResponse>();
        final entered = Completer<void>();
        network.onSend = (_) {
          expect(backend.value, isNotNull);
          entered.complete();
          return pending
              .future; // Deliberately ignores the actual abort signal.
        };
        final session = owner.runtime.acquireConversation(
          auth: auth,
          generation: AiTextGeneration(),
          isReady: () => ready,
        )!;
        final rejected = expectLater(
          session.start(
            StartConversationRequest.fromJson(request('start_conversation')),
          ),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        try {
          await entered.future;
          final wire = network.requests.single as http.AbortableRequest;
          var ended = false;
          final signingOut = owner.signOut().then((_) {
            ended = true;
          });
          await expectLater(wire.abortTrigger, completes);
          await Future<void>.delayed(Duration.zero);
          expect(ended, false);
          expect(backend.value, isNotNull);
          expect(backend.calls.contains('clear'), false);
          expect(
            wire.headers['authorization'],
            'Bearer ${token(now, userA, 0)}',
          );
          if (error) {
            pending.completeError(StateError('TEST_ONLY_PRIVATE_OLD_HTTP'));
          } else {
            pending.complete(response(output('start_conversation')));
          }
          await rejected;
          await signingOut;
          expect(backend.value, isNull);
          expect(backend.calls.last, 'clear');
          expect(network.requests, hasLength(1));
          expect(
            network.closed,
            false,
          ); // SDK transport borrows this HTTP client.
          await sdk.auth.signOut(
            scope: SignOutScope.local,
          ); // Host-controlled Auth logout.
          expect(sdk.auth.currentSession, isNull);
        } finally {
          if (!pending.isCompleted) {
            pending.completeError(StateError('TEST_ONLY_CLEANUP'));
          }
          await owner.close();
        }
      },
    );
  }

  for (final change in ['refresh', 'account', 'A-B-A']) {
    test(
      'SDK receipt late write cannot send under $change credentials',
      () async {
        final backend = _ReceiptBackend()..writeWait = Completer<void>();
        final owner = receiptOwner(backend);
        final session = owner.runtime.acquireConversation(
          auth: auth,
          generation: AiTextGeneration(),
          isReady: () => ready,
        )!;
        final rejected = expectLater(
          session.start(
            StartConversationRequest.fromJson(request('start_conversation')),
          ),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        try {
          await backend.entered.future;
          expect(network.requests, isEmpty);
          generation++;
          if (change == 'refresh') {
            await sdk.auth.refreshSession();
          } else {
            nextUser = userB;
            await login();
            if (change == 'A-B-A') {
              generation++;
              nextUser = userA;
              await login();
            }
          }
          await Future<void>.delayed(Duration.zero);
          owner.runtime.check();
          expect(owner.runtime.isDraining, true);
          var closed = false;
          final closing = owner.close().then((_) {
            closed = true;
          });
          await Future<void>.delayed(Duration.zero);
          expect(closed, false);
          backend.writeWait!.complete();
          await rejected;
          await closing;
          expect(network.requests, isEmpty);
          expect(backend.value, isNotNull);
          expect(backend.calls.contains('clear'), false);
          expect(session.isCurrent, false);
        } finally {
          if (!backend.writeWait!.isCompleted) backend.writeWait!.complete();
          await owner.close();
        }
      },
    );
  }
}
