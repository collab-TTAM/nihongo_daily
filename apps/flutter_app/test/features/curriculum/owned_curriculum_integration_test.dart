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
import 'package:nihongo_daily/features/curriculum/application/curriculum_provider.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';

import '../daily_plan/daily_plan_widget_test.dart'
    show PlanOwner, PlanSource, loadPlan;
import '../srs/account_fixtures.dart' as fixture;
import '../srs/account_widget_test.dart' show Harness;

// Actual packaged reader and owned host; Auth/plan are TEST ONLY fixtures.
// This does not prove hosted login, learning progress or actual OS shutdown.
void main() {
  for (final kind in CurriculumKind.values) {
    testWidgets('owned ${kind.name} retains plan and awaits exit with search', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = Harness();
      final source = PlanSource(h);
      final owner = PlanOwner(h.runtime, source);
      final controller = AccountStartupController(() async => owner);
      addTearDown(() async {
        if (!(owner.closing?.isCompleted ?? true)) owner.closing!.complete();
        await tester.pumpWidget(const SizedBox());
        await controller.close();
        await h.close();
      });
      await tester.pumpWidget(AccountStartupApp(controller: controller));
      await tester.pumpAndSettle();
      h.access.change(fixture.owner);
      await tester.pumpAndSettle();
      expect(identical(controller.dailyPlanSource, owner), isTrue);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NihongoDailyApp)),
      );
      final router = container.read(routerProvider);
      router.go('/plan');
      await tester.pumpAndSettle();
      expect(source.requests, 0);
      await loadPlan(tester);
      await tester.pumpAndSettle();
      expect(find.text('145/120 phút'), findsOneWidget);
      expect(source.requests, 1);

      // Observe the real asset provider in the real async zone, as in app_test.
      // Keep it alive through navigation; do not replace bundled content.
      final content = curriculumProvider(kind);
      final subscription = await tester.runAsync(() async {
        final listener = container.listen(content, (_, _) {});
        try {
          await container.read(content.future);
          return listener;
        } catch (_) {
          listener.close();
          rethrow;
        }
      });
      addTearDown(() => subscription?.close());
      router.go('/${kind.name}');
      await tester.pumpAndSettle();
      expect(find.textContaining('Chỉ đọc, chưa ghi tiến độ'), findsOneWidget);
      // Public N5 browsing must not retarget the authenticated N4 profile.
      expect(container.read(accountStateProvider).profile!.level, 'N4');
      final query = kind == CurriculumKind.vocabulary ? 'HOC SINH' : 'PHU DINH';
      final heading = kind == CurriculumKind.vocabulary
          ? '学生'
          : 'N1 は N2 ではありません';
      final search = find.byKey(const Key('curriculum-search'));
      await tester.ensureVisible(search);
      expect(search.hitTestable(), findsOneWidget);
      await tester.enterText(search, query);
      await tester.pumpAndSettle();
      expect(find.text(heading), findsOneWidget);
      expect(source.requests, 1);
      expect(h.queue.calls, 0);
      expect(h.profiles, 1);
      final fieldState = tester.state(search);
      final textController = tester.widget<TextField>(search).controller;
      owner.closing = Completer();
      var exited = false;
      final exit = tester.binding.handleRequestAppExit().then((result) {
        exited = true;
        return result;
      });
      await tester.pump();
      await tester.pump();
      expect(exited, isFalse);
      expect(controller.account, isNull);
      expect(controller.dailyPlanSource, isNull);
      expect(identical(container.read(routerProvider), router), isTrue);
      expect(find.byKey(const Key('curriculum-search')), findsNothing);
      final hidden = find.byKey(
        const Key('curriculum-search'),
        skipOffstage: false,
      );
      expect(identical(tester.state(hidden), fieldState), isTrue);
      expect(
        identical(tester.widget<TextField>(hidden).controller, textController),
        isTrue,
      );
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: hidden,
          matching: find.byType(EditableText, skipOffstage: false),
          skipOffstage: false,
        ),
      );
      expect(editable.focusNode.hasFocus, isFalse);
      expect(editable.focusNode.canRequestFocus, isFalse);
      owner.closing!.complete();
      expect(await exit, AppExitResponse.exit);
      expect(tester.takeException(), isNull);
    });
  }
}
