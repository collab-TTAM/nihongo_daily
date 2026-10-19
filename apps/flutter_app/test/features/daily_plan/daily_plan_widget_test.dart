import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:nihongo_daily/features/daily_plan/application/daily_plan_provider.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import '../srs/account_fixtures.dart' as fixture;
import '../srs/account_widget_test.dart' show Harness;
import 'daily_plan_test.dart' show planJson, blocksOf;

// TEST ONLY Auth/profile/server fixtures. No hosted learner evidence.
final class PlanSource implements DailyPlanRepositorySource {
  PlanSource(this.harness);
  final Harness harness;
  int creations = 0;
  int requests = 0;
  Map<String, Object>? parameters;
  Future<Object?> Function() response = () async => planJson();
  @override
  DailyPlanRepository? createDailyPlanRepository() {
    creations++;
    final runtime = harness.runtime.readyRuntime;
    if (runtime == null) return null;
    return DailyPlanRepository(
      PlanGateway(() => identical(harness.runtime.readyRuntime, runtime), (
        value,
      ) {
        requests++;
        parameters = value;
        return response();
      }),
    );
  }
}

final class PlanGateway implements DailyPlanSessionGateway {
  PlanGateway(this.current, this.read);
  final bool Function() current;
  final Future<Object?> Function(Map<String, Object>) read;
  @override
  bool get isCurrent => current();
  @override
  Future<Object?> getDailyPlan(Map<String, Object> parameters) =>
      read(parameters);
}

final class PlanOwner<T>
    implements AccountStartupRuntime<T>, DailyPlanRepositorySource {
  PlanOwner(this.account, this.source);
  @override
  final T account;
  final PlanSource source;
  Completer<void>? starting;
  Completer<void>? closing;
  @override
  bool get canOfferLogin => false;
  @override
  Future<void> start() async => await starting?.future;
  @override
  Future<void> close() async => await closing?.future;
  @override
  DailyPlanRepository? createDailyPlanRepository() =>
      source.createDailyPlanRepository();
}

Future<ProviderContainer> mountPlan(
  WidgetTester tester, {
  Harness? harness,
  PlanSource? source,
  bool signIn = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (harness != null)
        accountRuntimeProvider.overrideWithValue(harness.runtime),
      if (source != null) dailyPlanSourceProvider.overrideWithValue(source),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await harness?.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NihongoDailyApp(),
    ),
  );
  if (signIn) harness?.access.change(fixture.owner);
  container.read(routerProvider).go('/plan');
  await tester.pumpAndSettle();
  return container;
}

Future<void> loadPlan(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('plan-date')), '2026-10-19');
  await tester.ensureVisible(find.byKey(const Key('plan-load')));
  await tester.tap(find.byKey(const Key('plan-load')));
  await tester.pump();
}

void main() {
  testWidgets('preview route never fabricates account or plan', (tester) async {
    await mountPlan(tester);
    expect(find.text('Mở tài khoản'), findsOneWidget);
    expect(find.byKey(const Key('plan-date')), findsNothing);
    expect(find.byKey(const Key('plan-progress')), findsNothing);
    await tester.tap(find.text('Mở tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập hiện chưa khả dụng.'), findsOneWidget);
  });

  testWidgets('profile barrier gates source and requires explicit local date', (
    tester,
  ) async {
    final h = Harness()..delayed = Completer();
    final source = PlanSource(h);
    final container = await mountPlan(tester, harness: h, source: source);
    expect(container.read(dailyPlanRepositoryProvider), isNull);
    expect(source.creations, 0);
    expect(source.requests, 0);
    expect(find.byKey(const Key('plan-date')), findsNothing);
    h.delayed!.complete(fixture.ownProfile());
    await tester.pumpAndSettle();
    expect(find.textContaining('Asia/Tokyo'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('plan-date')))
          .controller!
          .text,
      isEmpty,
    );
    expect(source.requests, 0);
  });

  testWidgets(
    'date validation loading single dispatch and server over-target',
    (tester) async {
      final h = Harness();
      final source = PlanSource(h);
      final wait = Completer<Object?>();
      source.response = () => wait.future;
      await mountPlan(tester, harness: h, source: source);
      await tester.enterText(find.byKey(const Key('plan-date')), '2026-02-29');
      await tester.tap(find.byKey(const Key('plan-load')));
      await tester.pumpAndSettle();
      expect(
        find.text('Nhập ngày hợp lệ theo dạng YYYY-MM-DD.'),
        findsOneWidget,
      );
      expect(source.requests, 0);
      await loadPlan(tester);
      expect(find.text('Đang tải kế hoạch…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('plan-load')))
            .onPressed,
        isNull,
      );
      expect(source.requests, 1);
      expect(source.parameters, {
        'p_request': {'date': '2026-10-19'},
      });
      wait.complete(planJson());
      await tester.pumpAndSettle();
      expect(find.text('145/120 phút'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1,
      );
      expect(find.text('20 phút · Đang học'), findsOneWidget);
      expect(find.text('15 phút · Hoàn thành'), findsOneWidget);
      expect(find.textContaining('Chưa khả dụng'), findsWidgets);
    },
  );

  testWidgets(
    'offline read clears prior data and only explicit retry recovers',
    (tester) async {
      final h = Harness();
      final source = PlanSource(h);
      await mountPlan(tester, harness: h, source: source);
      await loadPlan(tester);
      await tester.pumpAndSettle();
      expect(find.text('145/120 phút'), findsOneWidget);
      source.response = () async => throw const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
        retryable: true,
      );
      await loadPlan(tester);
      await tester.pumpAndSettle();
      expect(find.text('Không có kết nối mạng.'), findsOneWidget);
      expect(find.byKey(const Key('plan-progress')), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(source.requests, 2);
      source.response = () async => planJson();
      await tester.tap(find.byKey(const Key('plan-load')));
      await tester.pumpAndSettle();
      expect(source.requests, 3);
      expect(find.text('145/120 phút'), findsOneWidget);
    },
  );

  testWidgets('unknown errors are redacted without false offline or progress', (
    tester,
  ) async {
    final h = Harness();
    final source = PlanSource(h)
      ..response = () async => throw StateError('PRIVATE TOKEN SQL PATH');
    await mountPlan(tester, harness: h, source: source);
    await loadPlan(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-error')), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(find.text('Không có kết nối mạng.'), findsNothing);
    expect(find.byKey(const Key('plan-progress')), findsNothing);
    expect(source.requests, 1);
  });

  testWidgets(
    'navigation discards view state and explicit return reloads server',
    (tester) async {
      final h = Harness();
      final source = PlanSource(h);
      final container = await mountPlan(tester, harness: h, source: source);
      await loadPlan(tester);
      await tester.pumpAndSettle();
      expect(find.text('145/120 phút'), findsOneWidget);
      container.read(routerProvider).go('/auth');
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/plan');
      await tester.pumpAndSettle();
      expect(source.requests, 1);
      expect(find.byKey(const Key('plan-progress')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('plan-date')))
            .controller!
            .text,
        isEmpty,
      );
      source.response = () async => planJson()..['completed_minutes'] = 150;
      await loadPlan(tester);
      await tester.pumpAndSettle();
      expect(source.requests, 2);
      expect(find.text('150/120 phút'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final lateError in [false, true]) {
    testWidgets(
      'owner replacement fences late error=$lateError and clears date',
      (tester) async {
        final h = Harness();
        final source = PlanSource(h);
        final wait = Completer<Object?>();
        source.response = () => wait.future;
        final container = await mountPlan(tester, harness: h, source: source);
        await loadPlan(tester);
        final oldRepository = container.read(dailyPlanRepositoryProvider);
        await h.runtime.signOut();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('plan-date')), findsNothing);
        h.access.change(lateError ? fixture.other : fixture.owner);
        await tester.pumpAndSettle();
        expect(
          identical(container.read(dailyPlanRepositoryProvider), oldRepository),
          isFalse,
        );
        if (lateError) {
          wait.completeError(StateError('PRIVATE OLD OWNER'));
        } else {
          wait.complete(planJson());
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('plan-progress')), findsNothing);
        expect(find.byKey(const Key('plan-error')), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('plan-date')))
              .controller!
              .text,
          isEmpty,
        );
        expect(source.requests, 1);
        source.response = () async => planJson()..['completed_minutes'] = 9;
        await loadPlan(tester);
        await tester.pumpAndSettle();
        expect(find.text('9/120 phút'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('blocked plan and 320px 200 percent text remain readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = Harness();
    final source = PlanSource(h)
      ..response = () async {
        final plan = planJson()..['completed_minutes'] = 0;
        for (final block in blocksOf(plan)) {
          block['status'] = 'BLOCKED';
          block['item_count'] = 0;
        }
        return plan;
      };
    await mountPlan(tester, harness: h, source: source);
    await loadPlan(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa có phần học khả dụng cho ngày này.'),
      findsOneWidget,
    );
    expect(find.text('0/120 phút'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'owned startup publishes plan source and exit retains cleared field observer',
    (tester) async {
      final h = Harness();
      final source = PlanSource(h);
      final owner = PlanOwner(h.runtime, source)..starting = Completer();
      final controller = AccountStartupController(() async => owner);
      addTearDown(() async {
        if (!(owner.starting?.isCompleted ?? true)) owner.starting!.complete();
        if (!(owner.closing?.isCompleted ?? true)) owner.closing!.complete();
        await tester.pumpWidget(const SizedBox());
        await controller.close();
        await h.close();
      });
      expect(controller.dailyPlanSource, isNull);
      await tester.pumpWidget(AccountStartupApp(controller: controller));
      await tester.pump();
      expect(controller.dailyPlanSource, isNull);
      owner.starting!.complete();
      await tester.pumpAndSettle();
      h.access.change(fixture.owner);
      await tester.pumpAndSettle();
      expect(identical(controller.dailyPlanSource, owner), isTrue);
      await tester.ensureVisible(find.text('Kế hoạch học'));
      await tester.tap(find.text('Kế hoạch học'));
      await tester.pumpAndSettle();
      await loadPlan(tester);
      await tester.pumpAndSettle();
      expect(find.text('145/120 phút'), findsOneWidget);
      final fieldState = tester.state(find.byKey(const Key('plan-date')));
      owner.closing = Completer();
      final exit = tester.binding.handleRequestAppExit();
      await tester.pump();
      await tester.pump();
      expect(controller.dailyPlanSource, isNull);
      expect(find.byKey(const Key('plan-progress')), findsNothing);
      final hidden = find.byKey(const Key('plan-date'), skipOffstage: false);
      expect(identical(tester.state(hidden), fieldState), isTrue);
      expect(tester.widget<TextField>(hidden).enabled, isFalse);
      expect(tester.widget<TextField>(hidden).controller!.text, isEmpty);
      owner.closing!.complete();
      expect(await exit, AppExitResponse.exit);
      expect(tester.takeException(), isNull);
    },
  );
}
