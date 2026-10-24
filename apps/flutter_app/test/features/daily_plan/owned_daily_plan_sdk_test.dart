// TEST ONLY actual pinned SDK + simulated HTTP/vault; no hosted JWT proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nihongo_daily/app/staging_bootstrap.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/application/persistent_account_startup.dart';
import 'package:nihongo_daily/features/auth/application/persistent_supabase_runtime.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/auth/data/persistent_account_access.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart';
import 'package:nihongo_daily/features/daily_plan/data/native_study_session_journal.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/domain/completed_study_session.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import '../srs/session_lifecycle_fixtures.dart' as fixture;
import '../srs/own_profile_fixtures.dart' as profile;
import '../srs/supabase_review_binding_test.dart' as wire;

void main() {
  late fixture.MemoryVault backend;
  late MockClient network;
  late PersistentSupabaseRuntime runtime;
  late NativeReviewJournal journal;
  late NativeStudySessionJournal studyJournal;
  late Directory directory;
  late DateTime now;
  late String secret;
  Completer<http.Response>? profileWait;
  Completer<http.Response>? dayWait;
  Completer<http.Response>? rpcWait;
  Completer<void>? rpcEntered;
  late int rpcStatus;
  late int serverMinutes;
  final requests = <http.Request>[];
  final date = DailyPlanDate('2026-10-14');
  final unauthorized = isA<DailyPlanFailure>().having(
    (e) => e.code,
    'code',
    DailyPlanErrorCode.unauthorized,
  );
  Map<String, Object?> plan(int minutes) {
    final fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    return (fixtures['get_daily_plan_response']! as Map<String, Object?>)
      ..['plan_date'] = '2026-10-14'
      ..['completed_minutes'] = minutes;
  }

  http.Response profileResponse() => http.Response(
    jsonEncode(profile.profile(wire.a)),
    200,
    headers: {'content-type': 'application/json'},
  );
  CompletedStudySession report() => CompletedStudySession(
    clientEventId: 'e1400000-0000-4000-8000-000000000001',
    date: date,
    area: DailyPlanArea.vocabulary,
    startedAt: DateTime.utc(2026, 10, 14, 1),
    endedAt: DateTime.utc(2026, 10, 14, 1, 15),
  );
  Future<void> ready() async {
    if (runtime.account.state.phase != AccountPhase.ready) {
      final state = await runtime.account.changes
          .firstWhere(
            (state) => const {
              AccountPhase.ready,
              AccountPhase.profileError,
              AccountPhase.signInError,
              AccountPhase.unavailable,
            }.contains(state.phase),
          )
          .timeout(const Duration(seconds: 5));
      expect(state.phase, AccountPhase.ready);
    }
    expect(runtime.createDailyPlanRepository(), isNotNull);
  }

  Future<void> login() async {
    await runtime.account.signIn(
      'fixture@example.invalid',
      'TEST_ONLY_PASSWORD',
    );
    await ready();
  }

  setUp(() async {
    now = DateTime.utc(2026, 10, 14, 3);
    secret = 'TEST_ONLY_PLAN_ROTATED_1';
    rpcStatus = 200;
    serverMinutes = 0;
    requests.clear();
    profileWait = null;
    dayWait = null;
    rpcWait = null;
    rpcEntered = null;
    backend = fixture.MemoryVault();
    directory = await Directory.systemTemp.createTemp('nd-plan-sdk-');
    journal = await NativeReviewJournal.open(directory);
    studyJournal = await NativeStudySessionJournal.open(directory);
    network = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/auth/v1/token') {
        return http.Response(
          jsonEncode({
            'access_token': wire.token(wire.a, wire.sid1, now),
            'refresh_token': secret,
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': wire.a,
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
      }
      if (request.url.path == '/auth/v1/logout') return http.Response('', 204);
      if (request.url.path == '/rest/v1/rpc/ensure_profile') {
        return profileWait?.future ?? Future.value(profileResponse());
      }
      if (request.url.path == '/rest/v1/rpc/get_study_day') {
        return dayWait?.future ??
            Future.value(
              http.Response(
                jsonEncode({'date': '2026-10-15', 'timezone': 'Asia/Tokyo'}),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
      }
      if (request.url.path == '/rest/v1/rpc/get_daily_plan' ||
          request.url.path == '/rest/v1/rpc/submit_study_session') {
        if (rpcEntered != null && !rpcEntered!.isCompleted) {
          rpcEntered!.complete();
        }
        if (rpcWait == null &&
            rpcStatus == 200 &&
            request.url.path.endsWith('submit_study_session')) {
          serverMinutes = 15;
        }
        return rpcWait?.future ??
            Future.value(
              http.Response(
                rpcStatus == 200
                    ? jsonEncode(plan(serverMinutes))
                    : 'TEST ONLY PRIVATE SQL',
                rpcStatus,
                headers: {'content-type': 'application/json'},
              ),
            );
      }
      throw StateError('unexpected TEST ONLY endpoint');
    });
    runtime = PersistentSupabaseRuntime(
      projectUrl: wire.origin,
      publishableKey: wire.key,
      vault: SessionCredentialVault(projectUrl: wire.origin, backend: backend),
      store: journal,
      studyStore: studyJournal,
      httpClient: network,
      now: () => now,
    );
  });
  tearDown(() async {
    final waiting = backend.writeWait;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
    if (profileWait != null && !profileWait!.isCompleted) {
      profileWait!.complete(profileResponse());
    }
    if (rpcWait != null && !rpcWait!.isCompleted) {
      rpcWait!.complete(
        http.Response(
          jsonEncode(plan(15)),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
    }
    if (dayWait != null && !dayWait!.isCompleted) {
      dayWait!.complete(
        http.Response(
          jsonEncode({'date': '2026-10-15', 'timezone': 'Asia/Tokyo'}),
          200,
        ),
      );
    }
    await runtime.close();
    await studyJournal.close();
    await journal.close();
    await directory.delete(recursive: true);
    network.close();
  });

  test(
    'owned study day uses captured SDK empty request and fences late logout result',
    () async {
      await runtime.start();
      expect(runtime.createDailyPlanRepository(), isNull);
      await login();
      final repository = runtime.createDailyPlanRepository()!;
      final day = await repository.loadStudyDay('Asia/Tokyo');
      expect(day.date.value, '2026-10-15');
      final request = requests.singleWhere(
        (r) => r.url.path.endsWith('/get_study_day'),
      );
      expect(jsonDecode(request.body), {'p_request': <String, Object>{}});
      expect(request.headers['apikey'], wire.key);
      expect(
        request.headers['authorization'],
        'Bearer ${wire.token(wire.a, wire.sid1, now)}',
      );
      expect(request.followRedirects, isFalse);
      dayWait = Completer<http.Response>();
      final stale = expectLater(
        repository.loadStudyDay('Asia/Tokyo'),
        throwsA(unauthorized),
      );
      await fixture.flush();
      await runtime.account.signOut();
      dayWait!.complete(
        http.Response(
          jsonEncode({'date': '2026-10-15', 'timezone': 'Asia/Tokyo'}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await stale;
    },
  );

  test(
    'owned study source recovers actual disk and acknowledges through captured SDK',
    () async {
      final owner = WindowsStagingOwner(
        PersistentAccountStartup(runtime),
        journal,
        studyJournal: studyJournal,
      );
      final controller = AccountStartupController(() async => owner);
      addTearDown(controller.close);
      expect(controller.durableStudySource, isNull);
      await controller.start();
      expect(identical(controller.durableStudySource, owner), isTrue);
      expect(owner.createDurableStudySessionRepository(), isNull);
      await login();
      await studyJournal.stage(wire.a, report());
      final service = controller.durableStudySource!
          .createDurableStudySessionRepository()!;
      final before = requests.length;
      expect(
        (await service.recoverPending()).single.toJson(),
        report().toJson(),
      );
      expect(requests.length, before);
      final acknowledged = await service.submit(report());
      expect(acknowledged.latestPlan!.completedMinutes, 15);
      expect(acknowledged.reloadFailure, isNull);
      expect((await studyJournal.list(wire.a)).single.acknowledged, isTrue);
      final write = requests.singleWhere(
        (r) => r.url.path.endsWith('/submit_study_session'),
      );
      expect(jsonDecode(write.body), {'p_request': report().toJson()});
      await service.submit(report());
      expect(
        requests
            .where((r) => r.url.path.endsWith('/submit_study_session'))
            .length,
        1,
      );
      expect(
        requests.where((r) => r.url.path.endsWith('/get_daily_plan')).length,
        2,
      );
      await controller.close();
      expect(controller.durableStudySource, isNull);
      expect(owner.createDurableStudySessionRepository(), isNull);
      await expectLater(service.recoverPending(), throwsA(unauthorized));
      final reopened = await NativeStudySessionJournal.open(directory);
      expect((await reopened.list(wire.a)).single.acknowledged, isTrue);
      await reopened.close();
    },
  );

  test(
    'owned close drains study dispatch and concurrent Auth before releasing both leases',
    () async {
      final owner = WindowsStagingOwner(
        PersistentAccountStartup(runtime),
        journal,
        studyJournal: studyJournal,
      );
      final controller = AccountStartupController(() async => owner);
      addTearDown(() async {
        final waitingWrite = backend.writeWait;
        if (waitingWrite != null && !waitingWrite.isCompleted) {
          waitingWrite.complete();
        }
        if (rpcWait != null && !rpcWait!.isCompleted) {
          rpcWait!.complete(http.Response(jsonEncode(plan(15)), 200));
        }
        await controller.close();
      });
      await controller.start();
      await login();
      final service = owner.createDurableStudySessionRepository()!;
      rpcWait = Completer<http.Response>();
      rpcEntered = Completer<void>();
      final sending = expectLater(
        service.submit(report()),
        throwsA(unauthorized),
      );
      await rpcEntered!.future.timeout(const Duration(seconds: 5));
      secret = 'TEST_ONLY_CLOSING_STUDY_ROTATION';
      backend.writeWait = Completer<void>();
      final rotation = expectLater(
        runtime.refresh(),
        throwsA(
          isA<ReviewTransportFailure>().having(
            (e) => e.code,
            'code',
            ReviewErrorCode.unauthorized,
          ),
        ),
      );
      await fixture.flush();
      var closed = false;
      final closing = controller.close().then((_) => closed = true);
      expect(controller.durableStudySource, isNull);
      expect(owner.createDurableStudySessionRepository(), isNull);
      await fixture.flush();
      expect(runtime.persistence.phase, SessionPersistencePhase.closed);
      expect(closed, isFalse);
      await expectLater(
        NativeReviewJournal.open(directory),
        throwsA(isA<ReviewStorageFailure>()),
      );
      await expectLater(
        NativeStudySessionJournal.open(directory),
        throwsA(isA<StudySessionStorageFailure>()),
      );
      backend.writeWait!.complete();
      await rotation;
      expect(backend.secret, isNull);
      expect(closed, isFalse);
      rpcWait!.complete(
        http.Response(
          jsonEncode(plan(15)),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await sending;
      await closing;
      final reopened = await NativeStudySessionJournal.open(directory);
      expect((await reopened.list(wire.a)).single.isPending, isTrue);
      expect(
        (await reopened.list(wire.a)).single.event.toJson(),
        report().toJson(),
      );
      await reopened.close();
      final reviewReopened = await NativeReviewJournal.open(directory);
      await reviewReopened.close();
    },
  );

  test(
    'production Windows owner forwards ready plan source and drains SDK before journal release',
    () async {
      final owner = WindowsStagingOwner(
        PersistentAccountStartup(runtime),
        journal,
      );
      final controller = AccountStartupController(() async => owner);
      addTearDown(() async {
        final wait = backend.writeWait;
        if (wait != null && !wait.isCompleted) wait.complete();
        await controller.close();
      });
      expect(controller.dailyPlanSource, isNull);
      expect(owner.createDailyPlanRepository(), isNull);
      await controller.start();
      expect(identical(controller.dailyPlanSource, owner), isTrue);
      expect(controller.dailyPlanSource!.createDailyPlanRepository(), isNull);
      await login();
      final repository = controller.dailyPlanSource!
          .createDailyPlanRepository()!;
      expect((await repository.load(date)).completedMinutes, 0);
      expect(
        requests.where((r) => r.url.path.endsWith('/get_daily_plan')).length,
        1,
      );
      secret = 'TEST_ONLY_WINDOWS_PLAN_ROTATED_2';
      backend.writeWait = Completer<void>();
      final writes = backend.writes;
      final rotation = expectLater(
        runtime.refresh(),
        throwsA(
          isA<ReviewTransportFailure>().having(
            (e) => e.code,
            'code',
            ReviewErrorCode.unauthorized,
          ),
        ),
      );
      expect(owner.createDailyPlanRepository(), isNull);
      await fixture.flush();
      expect(backend.writes, writes + 1);
      var closed = false;
      final closing = controller.close().then((_) => closed = true);
      expect(controller.dailyPlanSource, isNull);
      expect(owner.createDailyPlanRepository(), isNull);
      await fixture.flush();
      expect(closed, isFalse);
      await expectLater(
        NativeReviewJournal.open(directory),
        throwsA(isA<ReviewStorageFailure>()),
      );
      backend.writeWait!.complete();
      await rotation;
      await closing;
      expect(closed, isTrue);
      // Existing Auth policy cancels/cleans an interrupted refresh on close.
      expect(backend.secret, isNull);
      await expectLater(repository.load(date), throwsA(unauthorized));
      final reopened = await NativeReviewJournal.open(directory);
      await reopened.close();
    },
  );

  test(
    'owned factory waits for persisted rotation/profile and dispatches captured SDK HTTP',
    () async {
      expect(runtime.createDailyPlanRepository(), isNull);
      backend.secret = 'TEST_ONLY_SAVED';
      backend.writeWait = Completer<void>();
      profileWait = Completer<http.Response>();
      final starting = runtime.start();
      await fixture.flush();
      expect(runtime.createDailyPlanRepository(), isNull);
      expect(
        requests.where((r) => r.url.path.startsWith('/rest/v1/')),
        isEmpty,
      );
      backend.writeWait!.complete();
      await starting;
      await fixture.flush();
      expect(backend.secret, secret);
      expect(runtime.createDailyPlanRepository(), isNull);
      profileWait!.complete(profileResponse());
      await ready();
      final repository = runtime.createDailyPlanRepository()!;
      expect((await repository.load(date)).completedMinutes, 0);
      expect((await repository.submit(report())).completedMinutes, 15);
      final read = requests.singleWhere(
        (r) => r.url.path.endsWith('/get_daily_plan'),
      );
      final write = requests.singleWhere(
        (r) => r.url.path.endsWith('/submit_study_session'),
      );
      expect(jsonDecode(read.body), {
        'p_request': {'date': date.value},
      });
      expect(jsonDecode(write.body), {'p_request': report().toJson()});
      for (final request in [read, write]) {
        expect(request.headers['apikey'], wire.key);
        expect(
          request.headers['authorization'],
          'Bearer ${wire.token(wire.a, wire.sid1, now)}',
        );
        expect(request.followRedirects, isFalse);
      }
    },
  );

  test(
    'logout fences in-flight submit and old lease cannot survive same-user relogin',
    () async {
      await runtime.start();
      await login();
      final old = runtime.createDailyPlanRepository()!;
      rpcWait = Completer<http.Response>();
      rpcEntered = Completer<void>();
      final saving = old.submit(report());
      final rejected = expectLater(saving, throwsA(unauthorized));
      await rpcEntered!.future.timeout(const Duration(seconds: 5));
      await runtime.account.signOut();
      expect(runtime.createDailyPlanRepository(), isNull);
      // TEST ONLY server committed despite client revocation.
      serverMinutes = 15;
      rpcWait!.complete(
        http.Response(
          jsonEncode(plan(15)),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await rejected;
      rpcWait = null;
      await login();
      final before = requests.length;
      await expectLater(old.load(date), throwsA(unauthorized));
      expect(requests.length, before);
      expect(
        (await runtime.createDailyPlanRepository()!.load(
          date,
        )).completedMinutes,
        15,
      );
    },
  );

  test(
    'explicit refresh vault barrier revokes old plan lease before SDK reuse',
    () async {
      await runtime.start();
      await login();
      final old = runtime.createDailyPlanRepository()!;
      secret = 'TEST_ONLY_PLAN_ROTATED_2';
      backend.writeWait = Completer<void>();
      final rotation = runtime.refresh();
      expect(runtime.createDailyPlanRepository(), isNull);
      final before = requests
          .where((r) => r.url.path.contains('daily_plan'))
          .length;
      await expectLater(old.load(date), throwsA(unauthorized));
      expect(
        requests.where((r) => r.url.path.contains('daily_plan')).length,
        before,
      );
      backend.writeWait!.complete();
      await rotation;
      await ready();
      expect(backend.secret, secret);
      await expectLater(old.load(date), throwsA(unauthorized));
      expect(
        (await runtime.createDailyPlanRepository()!.load(
          date,
        )).completedMinutes,
        0,
      );
    },
  );

  test(
    'SDK failure maps safe once; expiry/close prevent any further HTTP',
    () async {
      await runtime.start();
      await login();
      final repository = runtime.createDailyPlanRepository()!;
      rpcStatus = 503;
      await expectLater(
        repository.submit(report()),
        throwsA(
          isA<DailyPlanFailure>()
              .having(
                (e) => e.code,
                'code',
                DailyPlanErrorCode.networkUnavailable,
              )
              .having((e) => e.toString(), 'safe', isNot(contains('PRIVATE'))),
        ),
      );
      expect(
        requests
            .where((r) => r.url.path.endsWith('/submit_study_session'))
            .length,
        1,
      );
      now = now.add(const Duration(hours: 2));
      final before = requests.length;
      await expectLater(repository.load(date), throwsA(unauthorized));
      expect(runtime.createDailyPlanRepository(), isNull);
      expect(requests.length, before);
      await runtime.close();
      expect(runtime.createDailyPlanRepository(), isNull);
      await expectLater(repository.submit(report()), throwsA(unauthorized));
      expect(requests.length, before);
    },
  );
}
