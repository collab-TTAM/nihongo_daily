import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/home/application/study_preview_provider.dart';
import 'package:nihongo_daily/features/home/data/demo_study_preview_repository.dart';
import 'package:nihongo_daily/features/home/domain/study_preview.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';

class TestPreviewRepository implements StudyPreviewRepository {
  TestPreviewRepository(this.loader);

  final Future<StudyPreview> Function(PreviewLevel) loader;

  @override
  Future<StudyPreview> load(PreviewLevel level) => loader(level);
}

Future<ProviderContainer> mountApp(
  WidgetTester tester, {
  StudyPreviewRepository? repository,
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      if (repository != null)
        studyPreviewRepositoryProvider.overrideWithValue(repository),
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
  return container;
}

void main() {
  testWidgets('mobile navigation opens Kanji and returns home', (tester) async {
    await mountApp(tester, size: const Size(375, 812));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.draw_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kanji-canvas')), findsOneWidget);
    expect(find.textContaining('Chấm điểm: chưa khả dụng'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    await tester.tap(find.byIcon(Icons.today_outlined));
    await tester.pumpAndSettle();
    expect(find.text('120 phút mỗi ngày'), findsOneWidget);
  });

  testWidgets('desktop starts with a clearly labeled demo allocation', (
    tester,
  ) async {
    await mountApp(tester);
    await tester.pumpAndSettle();
    expect(find.text('120 phút mỗi ngày'), findsOneWidget);
    expect(find.text('LỘ TRÌNH MẪU · N5'), findsOneWidget);
    expect(find.textContaining('BẢN XEM TRƯỚC'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home CTA opens original vocabulary and returns to study', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/curriculum/n5/vocabulary.json');
    });
    await mountApp(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khám phá các phần học'));
    await tester.pumpAndSettle();
    expect(find.text('Không gian học tập'), findsOneWidget);
    await tester.tap(find.text('Từ vựng'));
    await tester.pumpAndSettle();
    expect(find.text('私'), findsOneWidget);
    await tester.tap(find.text('私'));
    await tester.pumpAndSettle();
    expect(find.text('わたし'), findsOneWidget);
    expect(find.text('Chưa có âm thanh cho mục này.'), findsOneWidget);
    await tester.ensureVisible(find.text('Về các phần học'));
    await tester.tap(find.text('Về các phần học'));
    await tester.pumpAndSettle();
    expect(find.text('Không gian học tập'), findsOneWidget);
  });

  for (final entry in previewRoutes.entries) {
    testWidgets('${entry.key} opens safely without live services', (
      tester,
    ) async {
      final container = await mountApp(tester);
      await tester.pumpAndSettle();
      container.read(routerProvider).go(entry.key);
      await tester.pumpAndSettle();
      expect(find.text(entry.value.description), findsOneWidget);
      expect(find.text('Đang xây dựng'), findsOneWidget);
      expect(find.textContaining('BẢN XEM TRƯỚC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unknown paths recover to study without throwing', (
    tester,
  ) async {
    final container = await mountApp(tester);
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/not-a-page');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy trang'), findsOneWidget);
    await tester.tap(find.text('Về các phần học'));
    await tester.pumpAndSettle();
    expect(find.text('Không gian học tập'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('N4 preference changes the preview and survives navigation', (
    tester,
  ) async {
    final container = await mountApp(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cài đặt bản xem trước'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('N4'));
    await tester.pumpAndSettle();
    expect(container.read(previewLevelProvider), PreviewLevel.n4);
    container.read(routerProvider).go('/');
    await tester.pumpAndSettle();
    expect(find.text('LỘ TRÌNH MẪU · N4'), findsOneWidget);
  });

  testWidgets('theme selection updates the app without resetting the level', (
    tester,
  ) async {
    final container = await mountApp(tester);
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.text('N4'));
    await tester.tap(find.text('Theo thiết bị'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tối').last);
    await tester.pumpAndSettle();
    expect(container.read(previewThemeProvider), ThemeMode.dark);
    expect(container.read(previewLevelProvider), PreviewLevel.n4);
    expect(
      Theme.of(tester.element(find.text('Cài đặt bản xem trước'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('loading state waits for the repository', (tester) async {
    final completer = Completer<StudyPreview>();
    await mountApp(
      tester,
      repository: TestPreviewRepository((level) => completer.future),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(
      await const DemoStudyPreviewRepository().load(PreviewLevel.n5),
    );
    await tester.pumpAndSettle();
    expect(find.text('120 phút mỗi ngày'), findsOneWidget);
  });

  testWidgets('failure is safe and retry reloads the repository', (
    tester,
  ) async {
    var attempts = 0;
    await mountApp(
      tester,
      repository: TestPreviewRepository((level) async {
        attempts++;
        if (attempts == 1) throw StateError('sensitive-internal-detail');
        return const DemoStudyPreviewRepository().load(level);
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được bản xem trước'), findsOneWidget);
    expect(find.textContaining('sensitive-internal-detail'), findsNothing);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('120 phút mỗi ngày'), findsOneWidget);
  });

  testWidgets('empty preview explains the missing allocation', (tester) async {
    await mountApp(
      tester,
      repository: TestPreviewRepository(
        (level) async => StudyPreview(level: level, blocks: []),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa có phần học trong bản xem trước này.'),
      findsOneWidget,
    );
  });

  for (final size in [const Size(375, 812), const Size(320, 640)]) {
    testWidgets('mobile $size and large text have no layout overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await mountApp(tester, size: size);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.takeException(), isNull);
      for (final path in ['/study', '/settings', '/kanji', '/ai']) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: path);
      }
    });
  }
}
