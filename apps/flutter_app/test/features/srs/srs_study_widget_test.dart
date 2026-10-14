import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_controller.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_provider.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

import 'study_fixtures.dart';

Future<ProviderContainer> mountSrs(
  WidgetTester tester, {
  StudyHarness? fixture,
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      if (fixture != null)
        srsStudyRuntimeProvider.overrideWithValue(
          SrsStudyRuntime(
            auth: fixture.auth,
            reviews: fixture.repository,
            queue: fixture.queue,
            sessionChanges: fixture.changes.stream,
          ),
        ),
    ],
  );
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
  await tester.pump();
  return container;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late StudyHarness h;
  setUp(() => h = StudyHarness());
  tearDown(() => h.dispose());

  testWidgets(
    'absent canonical grammar reading is explicit instead of invented',
    (tester) async {
      h.queue.items = [
        SrsStudyItem(
          type: LearningItemType.grammar,
          itemId: fixtureItem().itemId,
          level: PreviewLevel.n5,
          prompt: '～です',
          reading: '',
          answerVi: 'là',
        ),
      ];
      await mountSrs(tester, fixture: h);
      await tester.pumpAndSettle();
      await tapText(tester, 'Xem đáp án');
      expect(
        find.text('Chưa có cách đọc trong dữ liệu của mục này.'),
        findsOneWidget,
      );
      expect(find.text('là'), findsOneWidget);
    },
  );

  testWidgets(
    'default SRS route is unconfigured and cannot fabricate a saved review',
    (tester) async {
      await mountSrs(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa kết nối Supabase.'), findsOneWidget);
      expect(find.text('Xem đáp án'), findsNothing);
      expect(find.text('Tốt'), findsNothing);
      expect(find.text('Đã nhận phản hồi xác nhận lượt ôn.'), findsNothing);
      await tapText(tester, 'Xem trạng thái tài khoản');
      expect(find.text('Tài khoản'), findsOneWidget);
    },
  );

  testWidgets(
    'TEST ONLY UI reveals then grades and shows only acknowledged progress',
    (tester) async {
      await mountSrs(tester, fixture: h);
      await tester.pumpAndSettle();
      expect(find.text('猫'), findsOneWidget);
      expect(find.text('con mèo'), findsNothing);
      expect(find.text('Tốt'), findsNothing);
      await tapText(tester, 'Xem đáp án');
      expect(find.text('ねこ'), findsOneWidget);
      expect(find.text('con mèo'), findsOneWidget);
      for (final label in ['Quên', 'Khó', 'Tốt', 'Dễ']) {
        expect(find.text(label), findsOneWidget);
      }
      await tapText(tester, 'Tốt');
      expect(h.rpc.requests.length, 1);
      expect(
        find.text('Đã xử lý hết danh sách của phiên này.'),
        findsOneWidget,
      );
      expect(
        find.text('Đã xác nhận 1 / 1 lượt trong phiên này.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('queue loading empty and safe error states are visible', (
    tester,
  ) async {
    final pending = Completer<List<SrsStudyItem>>();
    h.queue.loader = () => pending.future;
    await mountSrs(tester, fixture: h);
    await tester.pump();
    expect(find.text('Đang tải danh sách ôn tập…'), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.text('Không có mục đến hạn trong danh sách đã tải.'),
      findsOneWidget,
    );
    h.queue.loader = () => throw StateError('PRIVATE SECRET');
    await tapText(tester, 'Tải lại danh sách');
    expect(find.textContaining('PRIVATE SECRET'), findsNothing);
    expect(find.text('Không thể xác nhận kết quả ôn tập.'), findsOneWidget);
  });

  testWidgets('retry survives navigation and never changes the pending event', (
    tester,
  ) async {
    h.rpc.reply = () => Future.error(
      const ReviewTransportFailure(
        ReviewErrorCode.networkUnavailable,
        retryable: true,
      ),
    );
    final container = await mountSrs(tester, fixture: h);
    await tester.pumpAndSettle();
    await tapText(tester, 'Xem đáp án');
    await tapText(tester, 'Khó');
    final original = h.rpc.requests.single;
    expect(find.text('Thử lại cùng lượt ôn'), findsOneWidget);
    expect(find.text('Tải lại danh sách'), findsNothing);
    expect(find.text('Dễ'), findsNothing);
    container.read(routerProvider).go('/study');
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/srs');
    await tester.pumpAndSettle();
    expect(find.text('Thử lại cùng lượt ôn'), findsOneWidget);
    expect(h.queue.calls, 1);
    h.rpc.reply = null;
    await tapText(tester, 'Thử lại cùng lượt ôn');
    expect(h.rpc.requests.last, original);
    expect(
      find.text('Đã xác nhận 1 / 1 lượt trong phiên này.'),
      findsOneWidget,
    );
  });

  testWidgets('session notification clears visible answer immediately', (
    tester,
  ) async {
    await mountSrs(tester, fixture: h);
    await tester.pumpAndSettle();
    await tapText(tester, 'Xem đáp án');
    h.auth.currentSession = null;
    h.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('猫'), findsNothing);
    expect(find.text('con mèo'), findsNothing);
    expect(find.textContaining('Danh sách cũ đã được ẩn.'), findsOneWidget);
    expect(h.rpc.requests, isEmpty);
  });

  testWidgets(
    'conflict is not success and offers only explicit rejected-event reload',
    (tester) async {
      h.rpc.reply = () => Future.value({
        'code': 'SYNC_CONFLICT',
        'message_vi': 'PRIVATE SECRET',
        'retryable': false,
      });
      await mountSrs(tester, fixture: h);
      await tester.pumpAndSettle();
      await tapText(tester, 'Xem đáp án');
      await tapText(tester, 'Tốt');
      expect(find.text('Bỏ lượt bị từ chối và tải lại'), findsOneWidget);
      expect(find.text('Thử lại cùng lượt ôn'), findsNothing);
      expect(find.textContaining('PRIVATE SECRET'), findsNothing);
      expect(
        find.text('Đã xác nhận 0 / 1 lượt trong phiên này.'),
        findsOneWidget,
      );
    },
  );

  for (final size in [const Size(320, 640), const Size(375, 812)]) {
    testWidgets(
      'SRS $size at 200% text keeps all rating controls without overflow',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await mountSrs(tester, fixture: h, size: size);
        await tester.pumpAndSettle();
        await tapText(tester, 'Xem đáp án');
        expect(tester.takeException(), isNull);
        await tapText(tester, 'Dễ');
        expect(tester.takeException(), isNull);
        expect(h.rpc.requests.single['rating'], 3);
      },
    );
  }

  testWidgets(
    'closed lifecycle notifications disable runtime and hide old content',
    (tester) async {
      await mountSrs(tester, fixture: h);
      await tester.pumpAndSettle();
      await tapText(tester, 'Xem đáp án');
      await h.changes.close();
      await tester.pumpAndSettle();
      expect(find.text('con mèo'), findsNothing);
      expect(find.textContaining('Chưa kết nối Supabase.'), findsOneWidget);
    },
  );
}
