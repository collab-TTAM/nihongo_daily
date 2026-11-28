import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:nihongo_daily/features/kanji/application/kanji_capture_provider.dart';
import 'package:nihongo_daily/features/kanji/application/kanji_catalog_provider.dart';
import 'package:nihongo_daily/features/kanji/domain/kanji_catalog.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import '../daily_plan/daily_plan_widget_test.dart' show PlanOwner, PlanSource;
import '../srs/account_widget_test.dart' show Harness;
import '../srs/account_fixtures.dart' as account;

final originals = <PreviewLevel, List<KanjiCatalogEntry>>{};

final class CatalogFixture implements KanjiCatalogRepository {
  CatalogFixture(this.loader);
  final Future<List<KanjiCatalogEntry>> Function(PreviewLevel) loader;
  @override
  Future<List<KanjiCatalogEntry>> load(PreviewLevel level) => loader(level);
}

Future<ProviderContainer> mountCatalog(
  WidgetTester tester, {
  KanjiCatalogRepository? repository,
  String path = '/kanji/characters',
  bool settle = true,
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      kanjiCatalogRepositoryProvider.overrideWithValue(
        repository ?? CatalogFixture((level) async => originals[level]!),
      ),
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
  await tester.pumpAndSettle();
  container.read(routerProvider).go(path);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return container;
}

Future<void> tapCatalog(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> drawCatalogStroke(WidgetTester tester) async {
  final canvas = find.byKey(const Key('kanji-canvas'));
  await tester.ensureVisible(canvas);
  await tester.pumpAndSettle();
  final rect = tester.getRect(canvas);
  final gesture = await tester.startGesture(
    Offset(rect.left + rect.width * .25, rect.top + rect.height * .25),
  );
  await gesture.moveBy(Offset(rect.width * .4, rect.height * .4));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> selectCatalogLevel(WidgetTester tester, String level) async {
  await tapCatalog(tester, find.byKey(const Key('kanji-catalog-level')));
  await tester.tap(find.text(level).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    for (final level in PreviewLevel.values) {
      originals[level] = decodeKanjiCatalog(
        await File('../../data/${level.name}/kanji.json').readAsString(),
        level,
      );
    }
  });
  for (final level in PreviewLevel.values) {
    testWidgets(
      '${level.name} original selected character draws in an isolated local session',
      (tester) async {
        final container = await mountCatalog(tester, path: '/kanji');
        // Preserve the free canvas; its strokes must not enter selected practice.
        await drawCatalogStroke(tester);
        expect(find.text('Đã nhập 1 nét / 64'), findsOneWidget);
        await tapCatalog(tester, find.byKey(const Key('kanji-open-catalog')));
        if (level == PreviewLevel.n4) {
          await selectCatalogLevel(tester, 'N4');
        }
        final first = originals[level]!.first;
        await tapCatalog(tester, find.byKey(ValueKey('kanji-${first.id}')));
        expect(
          find.byKey(ValueKey('kanji-selected-${first.id}')),
          findsOneWidget,
        );
        expect(find.text(first.meaningVi), findsOneWidget);
        expect(find.text('Âm On: ${first.onyomi.join('、')}'), findsOneWidget);
        expect(find.text('Âm Kun: ${first.kunyomi.join('、')}'), findsOneWidget);
        expect(
          find.text(
            '${level.label} · Số nét theo nội dung: ${first.strokeCount}',
          ),
          findsOneWidget,
        );
        expect(find.text('Đã nhập 0 nét / 64'), findsOneWidget);
        final inner = ProviderScope.containerOf(
          tester.element(find.byKey(const Key('kanji-canvas'))),
        );
        expect(identical(inner, container), isFalse);
        await drawCatalogStroke(tester);
        expect(inner.read(kanjiCaptureProvider).strokes.length, 1);
        expect(find.textContaining('Chấm điểm: chưa khả dụng'), findsOneWidget);
        await tapCatalog(tester, find.byKey(const Key('kanji-open-catalog')));
        expect(
          find.text('${originals[level]!.length} chữ ${level.label}'),
          findsOneWidget,
        );
        final next = originals[level]![1];
        await tapCatalog(tester, find.byKey(ValueKey('kanji-${next.id}')));
        expect(
          find.byKey(ValueKey('kanji-selected-${first.id}')),
          findsNothing,
        );
        expect(
          find.byKey(ValueKey('kanji-selected-${next.id}')),
          findsOneWidget,
        );
        expect(find.text('Đã nhập 0 nét / 64'), findsOneWidget);
        expect(
          tester
              .widget<NavigationRail>(find.byType(NavigationRail))
              .selectedIndex,
          2,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'search uses original glyph/readings/accentless meaning and clears on level change',
    (tester) async {
      await mountCatalog(tester);
      final search = find.byKey(const Key('kanji-catalog-search'));
      for (final query in ['MAT TROI', 'ニチ', '日']) {
        await tester.enterText(search, query);
        await tester.pumpAndSettle();
        expect(find.text('1 chữ N5'), findsOneWidget);
        final result = find.byKey(
          ValueKey('kanji-${originals[PreviewLevel.n5]!.first.id}'),
        );
        expect(result, findsOneWidget);
        expect(
          find.descendant(of: result, matching: find.text('日')),
          findsOneWidget,
        );
        expect(tester.widget<TextField>(search).controller!.text, query);
      }
      await tester.enterText(search, '[');
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy Kanji phù hợp.'), findsOneWidget);
      await tapCatalog(tester, find.byTooltip('Xóa tìm Kanji'));
      expect(find.text('8 chữ N5'), findsOneWidget);
      await tester.enterText(search, 'MAT TROI');
      await selectCatalogLevel(tester, 'N4');
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(find.text('95 chữ N4'), findsOneWidget);
    },
  );
  testWidgets('loading, redacted error, explicit retry and empty catalog', (
    tester,
  ) async {
    final pending = Completer<List<KanjiCatalogEntry>>();
    addTearDown(() {
      if (!pending.isCompleted) {
        pending.complete([]);
      }
    });
    var calls = 0;
    final container = await mountCatalog(
      tester,
      settle: false,
      repository: CatalogFixture((_) {
        calls++;
        return calls == 1 ? pending.future : Future.value([]);
      }),
    );
    expect(find.text('Đang tải Kanji…'), findsOneWidget);
    expect(find.byKey(const Key('kanji-canvas')), findsNothing);
    pending.completeError(StateError('PRIVATE ASSET TOKEN'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE ASSET TOKEN'), findsNothing);
    await tapCatalog(tester, find.byKey(const Key('kanji-catalog-retry')));
    expect(calls, 2);
    expect(find.text('Chưa có Kanji N5 trong bản này.'), findsOneWidget);
    expect(
      container.read(kanjiCatalogProvider(PreviewLevel.n5)).hasError,
      isFalse,
    );
  });
  testWidgets('late N5 load cannot replace the selected N4 catalog', (
    tester,
  ) async {
    final pending = Completer<List<KanjiCatalogEntry>>();
    addTearDown(() {
      if (!pending.isCompleted) {
        pending.complete(originals[PreviewLevel.n5]!);
      }
    });
    await mountCatalog(
      tester,
      settle: false,
      repository: CatalogFixture(
        (level) => level == PreviewLevel.n5
            ? pending.future
            : Future.value(originals[level]!),
      ),
    );
    // The held spinner cannot settle; interact while it remains pending.
    final dropdown = find.byKey(const Key('kanji-catalog-level'));
    await tester.tap(dropdown);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('N4').last);
    await tester.pumpAndSettle();
    expect(find.text('95 chữ N4'), findsOneWidget);
    pending.complete(originals[PreviewLevel.n5]!);
    await tester.pumpAndSettle();
    expect(find.text('95 chữ N4'), findsOneWidget);
    expect(find.text('8 chữ N5'), findsNothing);
  });
  for (final path in [
    '/kanji/practice/n3/unknown',
    '/kanji/characters?level=n3',
    '/kanji/practice/n4/unknown',
    '/kanji/practice/n4/61a835f4-ad41-59be-a714-3476285759d7',
  ]) {
    testWidgets('$path never falls back to a foreign practice character', (
      tester,
    ) async {
      await mountCatalog(tester, path: path);
      expect(find.byKey(const Key('kanji-canvas')), findsNothing);
      expect(
        find.textContaining(
          path.contains('n3')
              ? 'Cấp độ Kanji chưa khả dụng'
              : 'Không tìm thấy chữ Kanji',
        ),
        findsOneWidget,
      );
    });
  }
  testWidgets(
    'selected N4 practice survives 320px and 200-percent text, undo and clear',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final entry = originals[PreviewLevel.n4]!.first;
      await mountCatalog(
        tester,
        path: '/kanji/practice/n4/${entry.id}',
        size: const Size(320, 640),
      );
      await drawCatalogStroke(tester);
      final rect = tester.getRect(find.byKey(const Key('kanji-canvas')));
      expect(rect.width, closeTo(rect.height, 1e-6));
      expect(find.text('Đã nhập 1 nét / 64'), findsOneWidget);
      await tapCatalog(tester, find.text('Hoàn tác nét'));
      expect(find.text('Đã nhập 0 nét / 64'), findsOneWidget);
      await drawCatalogStroke(tester);
      await tapCatalog(tester, find.text('Xóa tất cả'));
      expect(find.text('Đã nhập 0 nét / 64'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'direct identity change and held source reload discard old strokes',
    (tester) async {
      final entries = originals[PreviewLevel.n5]!;
      final held = Completer<List<KanjiCatalogEntry>>();
      addTearDown(() {
        if (!held.isCompleted) {
          held.complete(entries);
        }
      });
      var loads = 0;
      final container = await mountCatalog(
        tester,
        path: '/kanji/practice/n5/${entries.first.id}',
        repository: CatalogFixture(
          (_) => ++loads == 1 ? Future.value(entries) : held.future,
        ),
      );
      await drawCatalogStroke(tester);
      expect(find.text('Đã nhập 1 nét / 64'), findsOneWidget);
      container.read(routerProvider).go('/kanji/practice/n5/${entries[1].id}');
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('kanji-selected-${entries[1].id}')),
        findsOneWidget,
      );
      expect(find.text('Đã nhập 0 nét / 64'), findsOneWidget);
      await drawCatalogStroke(tester);
      container.invalidate(kanjiCatalogProvider(PreviewLevel.n5));
      await tester.pump();
      await tester.pump();
      expect(find.text('Đang tải Kanji…'), findsOneWidget);
      expect(find.byKey(const Key('kanji-canvas')), findsNothing);
      held.complete(entries);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('kanji-selected-${entries[1].id}')),
        findsOneWidget,
      );
      expect(find.text('Đã nhập 0 nét / 64'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'owned actual bundled catalog retains search listener during awaited exit',
    (tester) async {
      final h = Harness();
      final source = PlanSource(h);
      final owner = PlanOwner(h.runtime, source);
      final startup = AccountStartupController(() async => owner);
      addTearDown(() async {
        if (!(owner.closing?.isCompleted ?? true)) {
          owner.closing!.complete();
        }
        await tester.pumpWidget(const SizedBox());
        await startup.close();
        await h.close();
      });
      await tester.pumpWidget(AccountStartupApp(controller: startup));
      await tester.pumpAndSettle();
      h.access.change(account.owner);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NihongoDailyApp)),
      );
      final content = kanjiCatalogProvider(PreviewLevel.n5);
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
      final router = container.read(routerProvider);
      router.go('/kanji/characters');
      await tester.pumpAndSettle();
      final search = find.byKey(const Key('kanji-catalog-search'));
      await tester.enterText(search, 'MAT TROI');
      await tester.pumpAndSettle();
      expect(find.text('日'), findsOneWidget);
      expect(container.read(accountStateProvider).profile!.level, 'N4');
      expect(source.requests, 0);
      expect(h.queue.calls, 0);
      final field = tester.state(search);
      owner.closing = Completer();
      var exited = false;
      final exiting = tester.binding.handleRequestAppExit().then((value) {
        exited = true;
        return value;
      });
      await tester.pump();
      await tester.pump();
      expect(exited, isFalse);
      expect(startup.account, isNull);
      expect(identical(container.read(routerProvider), router), isTrue);
      expect(search, findsNothing);
      final hidden = find.byKey(
        const Key('kanji-catalog-search'),
        skipOffstage: false,
      );
      expect(identical(tester.state(hidden), field), isTrue);
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: hidden,
          matching: find.byType(EditableText, skipOffstage: false),
          skipOffstage: false,
        ),
      );
      expect(editable.focusNode.canRequestFocus, isFalse);
      owner.closing!.complete();
      expect(await exiting, AppExitResponse.exit);
      expect(tester.takeException(), isNull);
    },
  );
}
