// TEST ONLY pinned Supabase SDK/Auth fixtures plus the configured learner UI.
// This is a vertical composition regression, not hosted learner acceptance.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_account_startup.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/persistent_account_access.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_runtime.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';

import 'own_profile_fixtures.dart' as profile;
import 'session_lifecycle_fixtures.dart' as fixture;
import 'supabase_review_binding_test.dart' as wire;

const _itemId = 'd4000000-0000-4000-8000-000000000001';

void main() {
  late fixture.MemoryVault backend;
  late SessionCredentialVault vault;
  late http.Client network;
  late PersistentSupabaseRuntime runtime;
  late Directory directory;
  late NativeReviewJournal journal;
  late DateTime now;
  late String secret;
  late String authUser;
  late String authSession;
  late Completer<http.Response>? profileWait;
  final requests = <http.Request>[];
  var profileWasRequested = false;
  var profileResponseWasReturned = false;
  var queueCalls = 0;
  var submitCalls = 0;

  http.Response authResponse() => http.Response(
    jsonEncode({
      'access_token': wire.token(authUser, authSession, now),
      'refresh_token': secret,
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': authUser,
        'aud': 'authenticated',
        'role': 'authenticated',
        'created_at': '2026-10-14T00:00:00Z',
        'app_metadata': <String, Object>{},
        'user_metadata': <String, Object>{},
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  http.Response ownProfileResponse() => http.Response(
    jsonEncode({...profile.profile(authUser), 'preferred_jlpt': 'N5'}),
    200,
    headers: {'content-type': 'application/json'},
  );

  Future<void> waitFor(
    WidgetTester tester,
    bool Function() condition, {
    required String reason,
    String Function()? diagnostics,
  }) async {
    // Keep UI polling bounded while allowing real HTTP/mock-client continuations
    // to run outside the widget test's fake-async clock.
    const maxFrames = 50;
    for (var frame = 0; frame < maxFrames && !condition(); frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync<void>(
        () => Future<void>.delayed(Duration.zero),
      );
    }
    final detail = diagnostics == null ? '' : '; ${diagnostics()}';
    expect(
      condition(),
      isTrue,
      reason: '$reason (after $maxFrames bounded 100 ms frames$detail)',
    );
  }

  Future<T> traceStage<T>(String label, Future<T> Function() operation) async {
    // Fixed labels only: never log Auth, profile or credential values.
    debugPrint('ND_SRS_WIDGET_STAGE_START:$label');
    try {
      final value = await operation();
      debugPrint('ND_SRS_WIDGET_STAGE_DONE:$label');
      return value;
    } on Object catch (error) {
      debugPrint('ND_SRS_WIDGET_STAGE_ERROR:$label:${error.runtimeType}');
      rethrow;
    }
  }

  Future<void> pumpUi(WidgetTester tester) async {
    // The app may intentionally retain an indeterminate progress indicator
    // while an asynchronous operation is pending. Advance the UI without
    // waiting for every ticker in the tree to become idle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  setUp(() async {
    requests.clear();
    profileWasRequested = false;
    profileResponseWasReturned = false;
    queueCalls = 0;
    submitCalls = 0;
    backend = fixture.MemoryVault();
    directory = await Directory.systemTemp.createTemp('nd-srs-owned-ui-');
    journal = await NativeReviewJournal.open(directory);
    now = DateTime.utc(2026, 10, 14, 3);
    secret = 'TEST_ONLY_ROTATED_SRS_UI';
    authUser = wire.a;
    authSession = wire.sid1;
    profileWait = null;
    vault = SessionCredentialVault(projectUrl: wire.origin, backend: backend);
    network = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/auth/v1/token') return authResponse();
      if (request.url.path == '/auth/v1/logout') {
        return http.Response('', 204);
      }
      if (request.url.path == '/rest/v1/rpc/ensure_profile') {
        profileWasRequested = true;
        final response =
            await (profileWait?.future ?? Future.value(ownProfileResponse()));
        profileResponseWasReturned = true;
        return response;
      }
      if (request.url.path == '/rest/v1/rpc/get_review_queue') {
        queueCalls++;
        final items = queueCalls == 1
            ? [
                {
                  'item_type': 'VOCABULARY',
                  'item_id': _itemId,
                  'prompt_ja': '猫',
                  'reading_ja': 'ねこ',
                  'answer_vi': 'con mèo',
                  'next_review_at': '2020-01-02T00:00:00.000000Z',
                },
              ]
            : <Map<String, Object>>[];
        return http.Response(
          jsonEncode({
            'jlpt_level': 'N5',
            'server_time': '2026-10-14T03:00:00.000000Z',
            'items': items,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/rest/v1/rpc/submit_review') {
        submitCalls++;
        return http.Response(
          jsonEncode({
            'srs_state': 'LEARNING',
            'next_review_at': '2026-10-14T03:10:00Z',
            'interval_days': 1.0,
            'difficulty': 0.5,
            'review_count': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      throw StateError('unexpected TEST ONLY endpoint');
    });
    runtime = PersistentSupabaseRuntime(
      projectUrl: wire.origin,
      publishableKey: wire.key,
      vault: vault,
      store: journal,
      httpClient: network,
      now: () => now,
    );
  });

  tearDown(() async {
    if (profileWait != null && !profileWait!.isCompleted) {
      profileWait!.complete(ownProfileResponse());
    }
    await runtime.close();
    await journal.close();
    await directory.delete(recursive: true);
    network.close();
  });

  testWidgets(
    'configured startup gates SRS UI until vault rotation and own profile settle',
    (tester) async {
      backend.secret = 'TEST_ONLY_SAVED_SRS_REFRESH';
      backend.writeWait = Completer<void>();
      profileWait = Completer<http.Response>();
      final controller =
          AccountStartupController<AccountController<SrsStudyRuntime>>(
            () async => PersistentAccountStartup(runtime),
          );

      try {
        await traceStage(
          'mount-startup-app',
          () => tester.pumpWidget(AccountStartupApp(controller: controller)),
        );
        await traceStage(
          'vault-rotation-barrier',
          () => waitFor(
            tester,
            () =>
                backend.writes == 1 &&
                runtime.persistence.phase == SessionPersistencePhase.saving,
            reason: 'startup did not reach the rotated-secret vault barrier',
            diagnostics: () => [
              'startup=${controller.phase.name}',
              'account=${runtime.account.state.phase.name}',
              'persistence=${runtime.persistence.phase.name}',
              'vaultOwner=${runtime.persistence.hasVaultOwner}',
              'vaultOperations=${backend.operations.join(',')}',
              'vaultWrites=${backend.writes}',
              'authRequests=${requests.where((request) => request.url.path.startsWith('/auth/v1/')).length}',
              'profileRequests=${requests.where((request) => request.url.path == '/rest/v1/rpc/ensure_profile').length}',
            ].join(', '),
          ),
        );
        await traceStage('pump-vault-pending', () => tester.pump());

        expect(controller.phase, AccountStartupPhase.loading);
        expect(controller.account, isNull);
        expect(runtime.account.readyRuntime, isNull);
        expect(find.text('Đang khôi phục phiên đăng nhập…'), findsOneWidget);
        expect(find.byKey(const Key('account-email')), findsNothing);
        expect(
          requests.where(
            (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
          ),
          isEmpty,
        );
        expect(
          requests.where(
            (request) => request.url.path == '/rest/v1/rpc/get_review_queue',
          ),
          isEmpty,
        );
        expect(backend.secret, 'TEST_ONLY_SAVED_SRS_REFRESH');

        backend.writeWait!.complete();
        await traceStage(
          'own-profile-request',
          () => waitFor(
            tester,
            () => profileWasRequested,
            reason: 'own-profile request did not follow the saved rotation',
          ),
        );
        await traceStage('pump-profile-pending', () => tester.pump());

        final profileRequests = requests
            .where(
              (request) => request.url.path == '/rest/v1/rpc/ensure_profile',
            )
            .toList();
        expect(controller.phase, AccountStartupPhase.loading);
        expect(controller.account, isNull);
        expect(runtime.account.readyRuntime, isNull);
        expect(find.byKey(const Key('account-email')), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Ôn tập'), findsNothing);
        expect(backend.secret, secret);
        expect(profileRequests, hasLength(1));
        expect(
          profileRequests.single.headers['authorization'],
          'Bearer ${wire.token(wire.a, wire.sid1, now)}',
        );
        expect(backend.operations, ['read', 'write']);

        profileWait!.complete(ownProfileResponse());
        await traceStage(
          'profile-readiness',
          () => waitFor(
            tester,
            () =>
                profileResponseWasReturned &&
                controller.phase == AccountStartupPhase.active,
            reason: 'startup did not wait for the captured own profile',
          ),
        );
        await traceStage('pump-active-app', () => pumpUi(tester));

        expect(controller.account, same(runtime.account));
        expect(runtime.account.state.phase, AccountPhase.ready);
        expect(runtime.account.readyRuntime, isNotNull);
        expect(find.byKey(const Key('account-profile-name')), findsOneWidget);
        final openSrs = find.widgetWithText(FilledButton, 'Ôn tập');
        expect(openSrs, findsOneWidget);

        await traceStage(
          'ensure-visible-open-srs',
          () => tester.ensureVisible(openSrs),
        );
        await traceStage('tap-open-srs', () => tester.tap(openSrs));
        await traceStage(
          'authenticated-queue-dispatch',
          () => waitFor(
            tester,
            () => queueCalls == 1,
            reason: 'configured SRS route did not load the authenticated queue',
          ),
        );
        await traceStage(
          'queue-item-render',
          () => waitFor(
            tester,
            () => find.text('猫').evaluate().isNotEmpty,
            reason: 'the authenticated queue response did not render its item',
          ),
        );
        await traceStage('pump-srs-queue', () => pumpUi(tester));

        final queueRequest = requests.singleWhere(
          (request) => request.url.path == '/rest/v1/rpc/get_review_queue',
        );
        expect(queueRequest.method, 'POST');
        expect(
          queueRequest.headers['authorization'],
          'Bearer ${wire.token(wire.a, wire.sid1, now)}',
        );
        expect(jsonDecode(queueRequest.body), {
          'p_request': {'jlpt_level': 'N5', 'limit': 100},
        });
        expect(find.text('Danh sách N5 • Từ vựng'), findsOneWidget);
        expect(find.text('猫'), findsOneWidget);

        await traceStage(
          'ensure-visible-answer',
          () => tester.ensureVisible(find.text('Xem đáp án')),
        );
        await traceStage(
          'tap-reveal-answer',
          () => tester.tap(find.text('Xem đáp án')),
        );
        await traceStage('pump-answer-visible', () => pumpUi(tester));
        expect(find.text('ねこ'), findsOneWidget);
        expect(find.text('con mèo'), findsOneWidget);

        await traceStage(
          'ensure-visible-rating',
          () => tester.ensureVisible(find.text('Tốt')),
        );
        await traceStage('tap-good-rating', () => tester.tap(find.text('Tốt')));
        await traceStage(
          'submit-review-dispatch',
          () => waitFor(
            tester,
            () => submitCalls == 1,
            reason: 'one explicit rating did not dispatch submit_review',
          ),
        );
        await traceStage(
          'review-reload-empty-queue',
          () => waitFor(
            tester,
            () => find
                .text('Không có mục đến hạn trong danh sách đã tải.')
                .evaluate()
                .isNotEmpty,
            reason:
                'the confirmed review did not reload the empty server queue',
          ),
        );
        await traceStage('pump-review-reload', () => pumpUi(tester));

        final submitRequest = requests.singleWhere(
          (request) => request.url.path == '/rest/v1/rpc/submit_review',
        );
        expect(submitRequest.method, 'POST');
        expect(
          submitRequest.headers['authorization'],
          queueRequest.headers['authorization'],
        );
        final envelope = jsonDecode(submitRequest.body) as Map<String, Object?>;
        expect(envelope.keys.toSet(), {'p_request'});
        final payload = envelope['p_request']! as Map<String, Object?>;
        expect(payload.keys.toSet(), {
          'client_event_id',
          'item_type',
          'item_id',
          'rating',
          'is_correct',
          'response_ms',
          'occurred_at',
        });
        expect(payload['item_type'], 'VOCABULARY');
        expect(payload['item_id'], _itemId);
        expect(payload['rating'], 2);
        expect(payload['is_correct'], isTrue);
        expect(payload['response_ms'], isA<int>());
        expect(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(payload['client_event_id']! as String),
          isTrue,
        );
        expect(queueCalls, 2);
        expect(submitCalls, 1);
        expect(await journal.list(wire.a), isEmpty);
        expect(
          find.text('Không có mục đến hạn trong danh sách đã tải.'),
          findsOneWidget,
        );
        expect(
          requests
              .where((request) => request.url.path.startsWith('/rest/v1/'))
              .every((request) => request.url.path.startsWith('/rest/v1/rpc/')),
          isTrue,
        );

        await traceStage(
          'logout-drain',
          () => runtime.account.signOut().timeout(const Duration(seconds: 10)),
        );
        await traceStage(
          'logout-revocation-and-vault-clear',
          () => waitFor(
            tester,
            () =>
                runtime.account.readyRuntime == null && backend.secret == null,
            reason:
                'logout did not revoke study access and clear the saved secret',
          ),
        );
        await traceStage('pump-after-logout', () => pumpUi(tester));
        expect(runtime.account.readyRuntime, isNull);
        expect(backend.secret, isNull);
        expect(find.text('猫'), findsNothing);
        expect(find.text('ねこ'), findsNothing);
        expect(find.text('con mèo'), findsNothing);
      } finally {
        if (backend.writeWait != null && !backend.writeWait!.isCompleted) {
          backend.writeWait!.complete();
        }
        if (profileWait != null && !profileWait!.isCompleted) {
          profileWait!.complete(ownProfileResponse());
        }
        await traceStage('controller-close', () async {
          await tester.runAsync<void>(
            () => controller.close().timeout(const Duration(seconds: 5)),
          );
        });
        await traceStage(
          'unmount-app',
          () => tester.pumpWidget(const SizedBox.shrink()),
        );
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
