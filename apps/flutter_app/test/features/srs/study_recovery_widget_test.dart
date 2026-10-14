import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_controller.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_provider.dart';
import 'recovery_fixtures.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';

void main() {
  late Directory directory;
  late NativeReviewJournal journal;
  late RecoveryHarness h;
  late ProviderContainer mounted;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nd-recovery-widget-');
    journal = await NativeReviewJournal.open(directory);
    h = RecoveryHarness(journal);
    await h.stage();
  });
  tearDown(() async {
    h.dispose();
    await journal.close();
    await directory.delete(recursive: true);
  });
  Future<ProviderContainer> mount(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        srsStudyRuntimeProvider.overrideWithValue(
          SrsStudyRuntime(
            auth: h.base.auth,
            reviews: h.repository,
            queue: h.base.queue,
            sessionChanges: h.base.changes.stream,
          ),
        ),
      ],
    );
    mounted = container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NihongoDailyApp(),
      ),
    );
    container.read(routerProvider).go('/srs');
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    // Native disk work must run on the real event loop, rather than waiting
    // for file I/O while pumpAndSettle repeatedly advances Flutter's fake clock.
    final finished = Completer<void>();
    final subscription = mounted.listen<SrsStudyState>(srsStudyProvider, (
      _,
      state,
    ) {
      if (const {
            SrsStudyPhase.ready,
            SrsStudyPhase.recoveryReady,
            SrsStudyPhase.failed,
            SrsStudyPhase.empty,
            SrsStudyPhase.complete,
          }.contains(state.phase) &&
          !finished.isCompleted)
        finished.complete();
    });
    try {
      await tester.runAsync(() async {
        await tester.tap(finder);
        await finished.future.timeout(const Duration(seconds: 10));
      });
    } finally {
      subscription.close();
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'recovery shows original rating and manual replay before new card',
    (tester) async {
      await mount(tester);
      expect(find.text('Gửi lại lượt đã lưu'), findsOneWidget);
      expect(find.text('Đánh giá đã chọn: Tốt'), findsOneWidget);
      expect(find.text('Xem đáp án'), findsNothing);
      expect(find.text('Quên'), findsNothing);
      expect(h.base.queue.calls, 0);
      expect(h.base.rpc.requests, isEmpty);
      await tap(tester, 'Gửi lại lượt đã lưu');
      expect(h.base.rpc.requests.single, recoveryRequest());
      expect(find.text('猫'), findsOneWidget);
      expect(find.text('Đã nhận phản hồi xác nhận lượt ôn.'), findsNothing);
    },
  );
  testWidgets('storage read failure exposes safe recheck without new cards', (
    tester,
  ) async {
    h.store.failRead = true;
    await mount(tester);
    expect(find.textContaining('Kiểm tra bộ nhớ'), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(find.text('Xem đáp án'), findsNothing);
    h.store.failRead = false;
    await tap(tester, 'Tải lại danh sách');
    expect(find.text('Gửi lại lượt đã lưu'), findsOneWidget);
  });
  testWidgets('logout immediately hides recovered event and prevents replay', (
    tester,
  ) async {
    await mount(tester);
    h.base.auth.currentSession = null;
    h.base.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Gửi lại lượt đã lưu'), findsNothing);
    expect(find.text('Đánh giá đã chọn: Tốt'), findsNothing);
    expect(h.base.rpc.requests, isEmpty);
  });
  testWidgets(
    'recovery at 320px and 200 percent text has usable manual action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester);
      expect(tester.takeException(), isNull);
      await tap(tester, 'Gửi lại lượt đã lưu');
      expect(h.base.rpc.requests.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
