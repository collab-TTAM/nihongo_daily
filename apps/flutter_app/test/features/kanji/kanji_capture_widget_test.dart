import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/kanji/application/kanji_capture_provider.dart';

import '../../app_test.dart' show mountApp;

Future<ProviderContainer> openCanvas(
  WidgetTester tester, {
  Size size = const Size(1200, 900),
}) async {
  final container = await mountApp(tester, size: size);
  container.read(routerProvider).go('/kanji');
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('kanji-canvas')));
  return container;
}

void main() {
  for (final kind in [
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
  ]) {
    testWidgets('$kind draws a stroke without scrolling the page', (
      tester,
    ) async {
      final container = await openCanvas(tester, size: const Size(375, 812));
      final canvas = find.byKey(const Key('kanji-canvas'));
      final rect = tester.getRect(canvas);
      final start = Offset(
        rect.left + rect.width * .25,
        rect.top + rect.height * .25,
      );
      final gesture = await tester.startGesture(start, kind: kind);
      await gesture.moveTo(start + Offset(rect.width * .4, rect.height * .4));
      await gesture.up();
      await tester.pumpAndSettle();
      final state = container.read(kanjiCaptureProvider);
      expect(state.strokes.length, 1);
      expect(state.strokes.single.points.first.x, closeTo(.25, 1e-6));
      expect(state.strokes.single.points.last.y, closeTo(.65, 1e-6));
      expect(tester.getRect(canvas).top, rect.top);
      expect(find.textContaining('Chấm điểm: chưa khả dụng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'cancel, tap, second pointer and right click do not invent strokes',
    (tester) async {
      final container = await openCanvas(tester);
      final center = tester.getCenter(find.byKey(const Key('kanji-canvas')));
      final first = await tester.startGesture(center, pointer: 1);
      final second = await tester.startGesture(center, pointer: 2);
      await second.moveBy(const Offset(30, 20));
      await second.up();
      await first.cancel();
      await tester.tapAt(center);
      final right = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await right.moveBy(const Offset(20, 20));
      await right.up();
      await tester.pumpAndSettle();
      expect(container.read(kanjiCaptureProvider).strokes, isEmpty);
      expect(container.read(kanjiCaptureProvider).active, isEmpty);
    },
  );
  testWidgets('undo/clear and route exit discard local session', (
    tester,
  ) async {
    final container = await openCanvas(tester);
    final center = tester.getCenter(find.byKey(const Key('kanji-canvas')));
    for (var i = 0; i < 2; i++) {
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(50, 20));
      await gesture.up();
    }
    await tester.pumpAndSettle();
    expect(find.text('Đã nhập 2 nét / 64'), findsOneWidget);
    await tester.ensureVisible(find.text('Hoàn tác nét'));
    await tester.tap(find.text('Hoàn tác nét'));
    await tester.pumpAndSettle();
    expect(container.read(kanjiCaptureProvider).strokes.length, 1);
    await tester.tap(find.text('Xóa tất cả'));
    await tester.pumpAndSettle();
    expect(container.read(kanjiCaptureProvider).strokes, isEmpty);
    container.read(kanjiCaptureProvider.notifier).begin(1, 10, 10, 100, 0);
    container.read(kanjiCaptureProvider.notifier).end(1, 20, 20, 100, 10);
    container.read(routerProvider).go('/');
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/kanji');
    await tester.pumpAndSettle();
    expect(find.text('Đã nhập 0 nét / 64'), findsOneWidget);
  });
  testWidgets(
    'capture error is shown and square survives large text/small viewport',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await openCanvas(tester, size: const Size(320, 640));
      final rect = tester.getRect(find.byKey(const Key('kanji-canvas')));
      expect(rect.width, closeTo(rect.height, 1e-6));
      final controller = container.read(kanjiCaptureProvider.notifier);
      controller.begin(1, 10, 10, 100, 0);
      controller.end(1, 10, 10, 100, 1);
      await tester.pumpAndSettle();
      expect(find.textContaining('chạm một điểm chưa tạo nét'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
