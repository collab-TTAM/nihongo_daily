// TEST ONLY Auth/RPC and memory storage. Actual native leases/restart are tested
// separately outside the widget fake clock in the SDK/native process suites.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:nihongo_daily/features/daily_plan/application/daily_plan_provider.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart';
import 'package:nihongo_daily/features/daily_plan/domain/completed_study_session.dart';
import '../srs/account_fixtures.dart' as account;
import '../srs/account_widget_test.dart' show Harness;
import 'study_session_recovery_fixtures.dart';

final class RecoveryMemoryStore implements StudySessionStore {
  final records = <String, StoredStudySession>{};
  String key(String userId, String eventId) => '$userId/$eventId';
  @override
  Future<List<StoredStudySession>> list(String userId) async =>
      records.values.where((r) => r.userId == userId).toList();
  @override
  Future<StoredStudySession> stage(
    String userId,
    CompletedStudySession event,
  ) async {
    final id = key(userId, event.clientEventId);
    return records.putIfAbsent(
      id,
      () => StoredStudySession(userId: userId, event: event),
    );
  }

  @override
  Future<void> acknowledge(String userId, String eventId) async {
    final id = key(userId, eventId);
    records[id] = StoredStudySession(
      userId: userId,
      event: records[id]!.event,
      acknowledged: true,
    );
  }

  @override
  Future<void> reject(
    String userId,
    String eventId,
    DailyPlanErrorCode code,
  ) async {
    final id = key(userId, eventId);
    records[id] = StoredStudySession(
      userId: userId,
      event: records[id]!.event,
      rejection: code,
    );
  }
}

final class RecoverySource implements DurableStudySessionSource {
  RecoverySource(this.harness, this.store, this.server);
  final Harness harness;
  final StudySessionStore store;
  final StudyServer server;
  int creations = 0;
  @override
  DurableStudySessionRepository? createDurableStudySessionRepository() {
    creations++;
    final ready = harness.runtime.readyRuntime;
    if (ready == null) return null;
    return DurableStudySessionRepository(
      auth: ready.auth,
      store: store,
      delegate: DailyPlanRepository(StudyGateway(ready.auth, server, store)),
    );
  }
}

final class RecoveryOwner<T>
    implements AccountStartupRuntime<T>, DurableStudySessionSource {
  RecoveryOwner(this.account, this.source);
  @override
  final T account;
  final RecoverySource source;
  @override
  bool get canOfferLogin => false;
  @override
  Future<void> start() async {}
  @override
  Future<void> close() async {}
  @override
  DurableStudySessionRepository? createDurableStudySessionRepository() =>
      source.createDurableStudySessionRepository();
}

Future<ProviderContainer> mountRecovery(
  WidgetTester tester, {
  Harness? harness,
  RecoverySource? source,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (harness != null)
        accountRuntimeProvider.overrideWithValue(harness.runtime),
      if (source != null) durableStudySourceProvider.overrideWithValue(source),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NihongoDailyApp(),
    ),
  );
  harness?.access.change(account.owner);
  container.read(routerProvider).go('/study-recovery');
  await tester.pumpAndSettle();
  if (harness != null && harness.delayed == null) {
    expect(harness.runtime.state.phase, AccountPhase.ready);
    expect(container.read(durableStudyRepositoryProvider), isNotNull);
  }
  return container;
}

Future<void> checkPending(WidgetTester tester) async {
  final button = find.byKey(const Key('study-recovery-check'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> sendPending(WidgetTester tester) async {
  final button = find.byKey(
    Key('study-recovery-send-${studyEvent().clientEventId}'),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  late Harness h;
  late RecoveryMemoryStore memory;
  late StudyFaultStore store;
  late StudyServer server;
  late RecoverySource source;
  // Construct the Auth stream listener inside each testWidgets fake-clock zone.
  // setUp runs outside that zone: an immediate Future.value profile completion
  // would then escape pump's microtask queue and leave the UI profile-pending.
  Future<void> prepareRecovery() async {
    h = Harness();
    memory = RecoveryMemoryStore();
    store = StudyFaultStore(memory);
    server = StudyServer();
    source = RecoverySource(h, store, server);
    await memory.stage(account.owner, studyEvent());
    addTearDown(() async {
      final wait = server.writeWait;
      if (wait != null && !wait.isCompleted) wait.complete();
      await h.close();
    });
  }

  testWidgets('unconfigured recovery has no fabricated empty result', (
    tester,
  ) async {
    await prepareRecovery();
    await mountRecovery(tester);
    expect(find.text('Mở tài khoản'), findsOneWidget);
    expect(find.text('Không có buổi học chờ đồng bộ.'), findsNothing);
    expect(find.byKey(const Key('study-recovery-check')), findsNothing);
    expect(server.writes, 0);
  });

  testWidgets('profile gates service; local check never dispatches RPC', (
    tester,
  ) async {
    await prepareRecovery();
    h.delayed = Completer();
    final container = await mountRecovery(tester, harness: h, source: source);
    expect(container.read(durableStudyRepositoryProvider), isNull);
    expect(source.creations, 0);
    h.delayed!.complete(account.ownProfile());
    await tester.pumpAndSettle();
    expect(find.text('Không có buổi học chờ đồng bộ.'), findsNothing);
    await checkPending(tester);
    expect(find.text('Từ vựng · 2026-10-20'), findsOneWidget);
    expect(find.text('Bắt đầu: 2026-10-20 01:00:00 UTC'), findsOneWidget);
    expect(server.writes, 0);
    expect(server.reads, 0);
  });

  testWidgets(
    'explicit send disables duplicates and shows fresh plan after durable ack',
    (tester) async {
      await prepareRecovery();
      await mountRecovery(tester, harness: h, source: source);
      await checkPending(tester);
      server.writeWait = Completer();
      server.entered = Completer();
      await sendPending(tester);
      expect(server.entered!.isCompleted, isTrue);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('study-recovery-check')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(
                Key('study-recovery-send-${studyEvent().clientEventId}'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(server.writes, 1);
      server.writeWait!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Buổi học đã được ghi nhận.'), findsOneWidget);
      expect(find.text('Ngày 2026-10-20: 45/120 phút'), findsOneWidget);
      expect((await memory.list(account.owner)).single.acknowledged, isTrue);
      await checkPending(tester);
      expect(find.text('Không có buổi học chờ đồng bộ.'), findsOneWidget);
      expect(server.writes, 1);
    },
  );

  testWidgets('uncertain commit remains pending with exact manual retry only', (
    tester,
  ) async {
    await prepareRecovery();
    server.writeFailure = const DailyPlanFailure(
      DailyPlanErrorCode.networkUnavailable,
      retryable: true,
    );
    server.commitBeforeFailure = true;
    await mountRecovery(tester, harness: h, source: source);
    await checkPending(tester);
    await sendPending(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('study-recovery-error')), findsOneWidget);
    expect(find.byKey(const Key('study-recovery-confirmed')), findsNothing);
    expect((await memory.list(account.owner)).single.isPending, isTrue);
    await tester.pump(const Duration(seconds: 30));
    expect(server.writes, 1);
    server.writeFailure = null;
    await sendPending(tester);
    await tester.pumpAndSettle();
    expect(server.writes, 2);
    expect(server.committed.length, 1);
    expect(find.byKey(const Key('study-recovery-confirmed')), findsOneWidget);
  });

  testWidgets('failed plan reload preserves confirmed acknowledgment', (
    tester,
  ) async {
    await prepareRecovery();
    server.readFailure = const DailyPlanFailure(
      DailyPlanErrorCode.networkUnavailable,
    );
    await mountRecovery(tester, harness: h, source: source);
    await checkPending(tester);
    await sendPending(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Buổi học đã được ghi nhận. Chưa tải được tiến độ mới.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('study-recovery-progress')), findsNothing);
    expect(find.byKey(const Key('study-recovery-error')), findsNothing);
    expect((await memory.list(account.owner)).single.acknowledged, isTrue);
  });

  testWidgets(
    'storage errors are redacted and failed ack never claims confirmed',
    (tester) async {
      await prepareRecovery();
      store.failList = true;
      await mountRecovery(tester, harness: h, source: source);
      await checkPending(tester);
      expect(find.byKey(const Key('study-recovery-error')), findsOneWidget);
      expect(find.text('Không có buổi học chờ đồng bộ.'), findsNothing);
      expect(find.textContaining('PRIVATE'), findsNothing);
      store.failList = false;
      store.failAck = true;
      await checkPending(tester);
      await sendPending(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('study-recovery-confirmed')), findsNothing);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect((await memory.list(account.owner)).single.isPending, isTrue);
    },
  );

  testWidgets(
    'late old owner completion stays hidden; other owner cannot recover it',
    (tester) async {
      await prepareRecovery();
      final container = await mountRecovery(tester, harness: h, source: source);
      await checkPending(tester);
      server.writeWait = Completer();
      server.entered = Completer();
      await sendPending(tester);
      expect(server.entered!.isCompleted, isTrue);
      h.access.change(null);
      await tester.pumpAndSettle();
      expect(container.read(durableStudyRepositoryProvider), isNull);
      h.access.change(account.other);
      await tester.pumpAndSettle();
      await checkPending(tester);
      expect(find.text('Không có buổi học chờ đồng bộ.'), findsOneWidget);
      server.writeWait!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('study-recovery-confirmed')), findsNothing);
      expect((await memory.list(account.owner)).single.isPending, isTrue);
      h.access.change(account.owner);
      await tester.pumpAndSettle();
      await checkPending(tester);
      await sendPending(tester);
      await tester.pumpAndSettle();
      expect(server.committed.length, 1);
      expect(find.byKey(const Key('study-recovery-confirmed')), findsOneWidget);
    },
  );

  testWidgets(
    'narrow layout and large text preserve pending and confirmation',
    (tester) async {
      await prepareRecovery();
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mountRecovery(tester, harness: h, source: source);
      await checkPending(tester);
      expect(tester.takeException(), isNull);
      await sendPending(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('study-recovery-confirmed')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actual startup host publishes capability and account navigation',
    (tester) async {
      await prepareRecovery();
      final owner = RecoveryOwner(h.runtime, source);
      final controller = AccountStartupController(() async => owner);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await controller.close();
      });
      await tester.pumpWidget(AccountStartupApp(controller: controller));
      await tester.pumpAndSettle();
      h.access.change(account.owner);
      await tester.pumpAndSettle();
      expect(h.runtime.state.phase, AccountPhase.ready);
      expect(identical(controller.durableStudySource, owner), isTrue);
      final button = find.byKey(const Key('study-recovery-open'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await checkPending(tester);
      expect(find.text('Từ vựng · 2026-10-20'), findsOneWidget);
      expect(server.writes, 0);
    },
  );
}
