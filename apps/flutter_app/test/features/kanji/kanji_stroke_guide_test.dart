import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:nihongo_daily/features/kanji/presentation/kanji_stroke_guide_panel.dart';
import '../daily_plan/daily_plan_widget_test.dart' show PlanOwner, PlanSource;
import '../srs/account_widget_test.dart' show Harness;
import 'package:nihongo_daily/features/kanji/application/kanji_catalog_provider.dart';
import 'package:nihongo_daily/features/kanji/application/kanji_stroke_guide_provider.dart';
import 'package:nihongo_daily/features/kanji/data/bundled_kanji_stroke_guides.dart';
import 'package:nihongo_daily/features/kanji/domain/kanji_catalog.dart';
import 'package:nihongo_daily/features/kanji/domain/kanji_stroke_guide.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import 'kanji_catalog_widget_test.dart'
    show CatalogFixture, tapCatalog, drawCatalogStroke;

final class GuideFixture implements KanjiStrokeGuideRepository {
  GuideFixture(this.loader);
  final Future<KanjiStrokeGuide?> Function(KanjiCatalogEntry) loader;
  int calls = 0;
  @override
  Future<KanjiStrokeGuide?> load(KanjiCatalogEntry entry) {
    calls++;
    return loader(entry);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String source;
  late String n4Source;
  late List<KanjiStrokeGuide> n4Guides;
  late List<KanjiCatalogEntry> n5;
  late List<KanjiCatalogEntry> n4;
  late List<KanjiStrokeGuide> guides;
  setUpAll(() async {
    source = await File('assets/kanji_references/n5.json').readAsString();
    n4Source = await File('assets/kanji_references/n4.json').readAsString();
    n4Guides = decodeKanjiStrokeGuides(n4Source, level: PreviewLevel.n4);
    n5 = decodeKanjiCatalog(
      await File('../../data/n5/kanji.json').readAsString(),
      PreviewLevel.n5,
    );
    n4 = decodeKanjiCatalog(
      await File('../../data/n4/kanji.json').readAsString(),
      PreviewLevel.n4,
    );
    guides = decodeKanjiStrokeGuides(source);
  });
  test(
    'actual asset exactly preserves eight original identities/counts and immutable geometry',
    () async {
      expect(
        await rootBundle.loadString('assets/kanji_references/n5.json'),
        source,
      );
      final repo = BundledKanjiStrokeGuides();
      for (var i = 0; i < n5.length; i++) {
        final guide = (await repo.load(n5[i]))!;
        expect(guide.kanjiId, n5[i].id);
        expect(guide.character, n5[i].character);
        expect(guide.contentVersion, n5[i].contentVersion);
        expect(guide.strokes.length, n5[i].strokeCount);
        expect(
          guide.strokes.every(
            (s) => s.every((p) => p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1),
          ),
          isTrue,
        );
        expect(() => guide.strokes.clear(), throwsUnsupportedError);
        expect(() => guide.strokes.first.clear(), throwsUnsupportedError);
      }
    },
  );
  test('incompatible N5 identity/version/count never substitutes', () async {
    var reads = 0;
    final repo = BundledKanjiStrokeGuides(
      read: (_) async {
        reads++;
        return source;
      },
    );
    final row =
        (jsonDecode(await File('../../data/n5/kanji.json').readAsString())
                    as List<dynamic>)
                .first
            as Map<String, dynamic>;
    for (final mutation in <Map<String, Object?>>[
      {'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'},
      {'content_version': 2},
      {'stroke_count': 5},
      {'character': '木'},
    ]) {
      final entry = decodeKanjiCatalog(
        jsonEncode([
          {...row, ...mutation},
        ]),
        PreviewLevel.n5,
      ).single;
      expect(await repo.load(entry), isNull);
    }
    expect(reads, 4);
  });
  for (final mode in [
    'version',
    'license',
    'duplicate',
    'outside',
    'shape',
    'degenerate',
    'order-count',
  ]) {
    test('invalid guide $mode fails closed', () {
      final document = jsonDecode(source) as Map<String, dynamic>;
      final entries = document['entries'] as List<dynamic>;
      final first = entries.first as Map<String, dynamic>;
      if (mode == 'version') {
        document['reference_version'] = 'future';
      }
      if (mode == 'license') {
        document['license'] = 'MIT';
      }
      if (mode == 'duplicate') {
        (entries[1] as Map<String, dynamic>)['kanji_id'] = first['kanji_id'];
      }
      if (mode == 'outside') {
        (first['strokes'] as List<dynamic>)[0] = [
          [2, 0],
          [1, 1],
        ];
      }
      if (mode == 'shape') {
        (first['strokes'] as List<dynamic>)[0] = [
          [true, 0],
          [1, 1],
        ];
      }
      if (mode == 'degenerate') {
        (first['strokes'] as List<dynamic>)[0] = [
          [0, 0],
          [0, 0],
        ];
      }
      if (mode == 'order-count') {
        first['stroke_count'] = 5;
      }
      expect(
        () => decodeKanjiStrokeGuides(jsonEncode(document)),
        throwsFormatException,
      );
    });
  }
  test(
    'guide size coverage missing source and raw errors never become a guide',
    () async {
      for (final input in [' ' * (1024 * 1024 + 1), '{}', '[]']) {
        expect(() => decodeKanjiStrokeGuides(input), throwsFormatException);
      }
      await expectLater(
        BundledKanjiStrokeGuides(
          read: (_) async => throw StateError('PRIVATE'),
        ).load(n5.first),
        throwsStateError,
      );
    },
  );

  test(
    'actual N4 asset preserves all95 original mappings and fixed level path',
    () async {
      expect(
        await rootBundle.loadString('assets/kanji_references/n4.json'),
        n4Source,
      );
      expect(n4Guides, hasLength(95));
      final paths = <String>[];
      final repo = BundledKanjiStrokeGuides(
        read: (path) async {
          paths.add(path);
          return path.endsWith('/n4.json') ? n4Source : source;
        },
      );
      for (final entry in n4) {
        final guide = (await repo.load(entry))!;
        expect(guide.level, PreviewLevel.n4);
        expect(guide.matches(entry), isTrue);
        expect(
          guide.strokes
              .expand((s) => s)
              .every((p) => p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1),
          isTrue,
        );
        expect(() => guide.strokes.clear(), throwsUnsupportedError);
        expect(() => guide.strokes.first.clear(), throwsUnsupportedError);
      }
      expect(paths, everyElement('assets/kanji_references/n4.json'));
      expect(paths, hasLength(95));
      expect((await repo.load(n5.first))!.matches(n5.first), isTrue);
      expect(paths.last, 'assets/kanji_references/n5.json');
    },
  );
  test(
    'level versions coverage and swapped assets reject without fallback',
    () async {
      for (final level in PreviewLevel.values) {
        final input = level == PreviewLevel.n5 ? source : n4Source;
        final foreign = level == PreviewLevel.n5 ? n4Source : source;
        expect(
          () => decodeKanjiStrokeGuides(foreign, level: level),
          throwsFormatException,
        );
        final document = jsonDecode(input) as Map<String, dynamic>;
        (document['entries'] as List<dynamic>).removeLast();
        expect(
          () => decodeKanjiStrokeGuides(jsonEncode(document), level: level),
          throwsFormatException,
        );
        final paths = <String>[];
        final repo = BundledKanjiStrokeGuides(
          read: (path) async {
            paths.add(path);
            return foreign;
          },
        );
        await expectLater(
          repo.load(level == PreviewLevel.n5 ? n5.first : n4.first),
          throwsFormatException,
        );
        expect(paths, ['assets/kanji_references/${level.name}.json']);
      }
    },
  );
  test(
    'N4 incompatible identity glyph version and count never substitute',
    () async {
      final original =
          (jsonDecode(await File('../../data/n4/kanji.json').readAsString())
                      as List<dynamic>)
                  .first
              as Map<String, dynamic>;
      final repo = BundledKanjiStrokeGuides(
        read: (path) async {
          expect(path, 'assets/kanji_references/n4.json');
          return n4Source;
        },
      );
      for (final mutation in <Map<String, Object?>>[
        {'id': n5.first.id},
        {'character': n4[1].character},
        {'content_version': 2},
        {'stroke_count': 7},
      ]) {
        final entry = decodeKanjiCatalog(
          jsonEncode([
            {...original, ...mutation},
          ]),
          PreviewLevel.n4,
        ).single;
        expect(await repo.load(entry), isNull);
      }
    },
  );

  Future<ProviderContainer> mount(
    WidgetTester tester,
    GuideFixture fixture, {
    PreviewLevel level = PreviewLevel.n5,
    Size size = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        kanjiCatalogRepositoryProvider.overrideWithValue(
          CatalogFixture(
            (selected) async => selected == PreviewLevel.n5 ? n5 : n4,
          ),
        ),
        kanjiStrokeGuideRepositoryProvider.overrideWithValue(fixture),
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
    final entry = level == PreviewLevel.n5 ? n5.first : n4.first;
    container
        .read(routerProvider)
        .go('/kanji/practice/${level.name}/${entry.id}');
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'explicit guide shows original ordered steps with bounds attribution and no grade',
    (tester) async {
      final fixture = GuideFixture((_) async => guides.first);
      await mount(tester, fixture);
      expect(fixture.calls, 0);
      await tapCatalog(tester, find.byKey(const Key('kanji-guide-toggle')));
      expect(fixture.calls, 1);
      expect(find.text('Nét 1 / 4'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('kanji-guide-previous')))
            .onPressed,
        isNull,
      );
      await tapCatalog(tester, find.byKey(const Key('kanji-guide-next')));
      expect(find.text('Nét 2 / 4'), findsOneWidget);
      await tapCatalog(tester, find.text('Xem toàn bộ'));
      expect(find.text('Nét 4 / 4'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('kanji-guide-next')))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('Nguồn: KanjiVG'), findsOneWidget);
      await tapCatalog(tester, find.byKey(const Key('kanji-guide-previous')));
      expect(find.text('Nét 3 / 4'), findsOneWidget);
      await drawCatalogStroke(tester);
      expect(find.text('Đã nhập 1 nét / 64'), findsOneWidget);
      expect(find.textContaining('Chấm điểm: chưa khả dụng'), findsOneWidget);
      await tapCatalog(tester, find.byKey(const Key('kanji-guide-toggle')));
      expect(find.byKey(const Key('kanji-guide-picture')), findsNothing);
      expect(find.text('Đã nhập 1 nét / 64'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('N4 guide dispatch is explicit and keeps drawing independent', (
    tester,
  ) async {
    final fixture = GuideFixture((_) async => n4Guides.first);
    await mount(tester, fixture, level: PreviewLevel.n4);
    expect(fixture.calls, 0);
    expect(find.byKey(const Key('kanji-guide-picture')), findsNothing);
    expect(find.textContaining('Có thể xem từng nét mẫu N4.'), findsOneWidget);
    await tapCatalog(tester, find.byKey(const Key('kanji-guide-toggle')));
    expect(fixture.calls, 1);
    expect(find.text('Nét 1 / 6'), findsOneWidget);
    expect(find.textContaining('Nguồn: KanjiVG'), findsOneWidget);
    await tapCatalog(tester, find.text('Xem toàn bộ'));
    expect(find.text('Nét 6 / 6'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('kanji-guide-next')))
          .onPressed,
      isNull,
    );
    await drawCatalogStroke(tester);
    expect(find.text('Đã nhập 1 nét / 64'), findsOneWidget);
    expect(find.textContaining('Chấm điểm: chưa khả dụng'), findsOneWidget);
    expect(find.textContaining('thiếu dữ liệu nét mẫu'), findsNothing);
    await tapCatalog(tester, find.byKey(const Key('kanji-guide-toggle')));
    expect(find.byKey(const Key('kanji-guide-picture')), findsNothing);
    expect(find.text('Đã nhập 1 nét / 64'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('N4 foreign returned guide is never displayed', (tester) async {
    await mount(
      tester,
      GuideFixture((_) async => guides.first),
      level: PreviewLevel.n4,
    );
    await tapCatalog(tester, find.byKey(const Key('kanji-guide-toggle')));
    expect(find.byKey(const Key('kanji-guide-missing')), findsOneWidget);
    expect(find.byKey(const Key('kanji-guide-picture')), findsNothing);
  });
  for (final level in PreviewLevel.values) {
    testWidgets(
      '${level.label} missing and safe-error retry never invent geometry',
      (tester) async {
        var fail = true;
        final fixture = GuideFixture((_) async {
          if (fail) {
            throw StateError('PRIVATE GUIDE PATH');
          }
          return null;
        });
        await mount(tester, fixture, level: level);
        await tapCatalog(tester, find.byKey(const Key('kanji-guide-toggle')));
        expect(find.textContaining('PRIVATE GUIDE PATH'), findsNothing);
        expect(find.byKey(const Key('kanji-guide-picture')), findsNothing);
        fail = false;
        await tapCatalog(tester, find.text('Thử tải nét mẫu'));
        expect(find.byKey(const Key('kanji-guide-missing')), findsOneWidget);
        expect(fixture.calls, 2);
      },
    );
  }
  testWidgets('late hidden guide cannot enter another character', (
    tester,
  ) async {
    final held = Completer<KanjiStrokeGuide?>();
    addTearDown(() {
      if (!held.isCompleted) {
        held.complete(guides.first);
      }
    });
    final fixture = GuideFixture((_) => held.future);
    final container = await mount(tester, fixture);
    // Do not settle the held loading indicator.
    await tester.ensureVisible(find.byKey(const Key('kanji-guide-toggle')));
    await tester.tap(find.byKey(const Key('kanji-guide-toggle')));
    await tester.pump();
    container.read(routerProvider).go('/kanji/practice/n5/${n5[1].id}');
    await tester.pumpAndSettle();
    held.complete(guides.first);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('kanji-selected-${n5[1].id}')), findsOneWidget);
    expect(find.byKey(const Key('kanji-guide-picture')), findsNothing);
    expect(find.text('Xem nét mẫu'), findsOneWidget);
    expect(fixture.calls, 1);
  });
  testWidgets('late N5 guide cannot cross into N4 practice', (tester) async {
    final held = Completer<KanjiStrokeGuide?>();
    addTearDown(() {
      if (!held.isCompleted) held.complete(guides.first);
    });
    final fixture = GuideFixture(
      (entry) => entry.level == PreviewLevel.n5
          ? held.future
          : Future.value(n4Guides.first),
    );
    final container = await mount(tester, fixture);
    await tester.ensureVisible(find.byKey(const Key('kanji-guide-toggle')));
    await tester.tap(find.byKey(const Key('kanji-guide-toggle')));
    await tester.pump();
    container.read(routerProvider).go('/kanji/practice/n4/${n4.first.id}');
    await tester.pumpAndSettle();
    held.complete(guides.first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('kanji-selected-${n4.first.id}')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('kanji-guide-picture')), findsNothing);
    expect(fixture.calls, 1);
    await tapCatalog(tester, find.byKey(const Key('kanji-guide-toggle')));
    expect(find.text('Nét 1 / 6'), findsOneWidget);
    expect(fixture.calls, 2);
    expect(tester.takeException(), isNull);
  });
  for (final level in PreviewLevel.values) {
    testWidgets(
      '${level.label} 320px 200-percent guide keeps square and step controls usable',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await mount(
          tester,
          GuideFixture(
            (_) async =>
                level == PreviewLevel.n5 ? guides.first : n4Guides.first,
          ),
          level: level,
          size: const Size(320, 640),
        );
        await tapCatalog(tester, find.byKey(const Key('kanji-guide-toggle')));
        await tapCatalog(tester, find.byKey(const Key('kanji-guide-next')));
        final rect = tester.getRect(
          find.byKey(const Key('kanji-guide-picture')),
        );
        expect(rect.width, closeTo(rect.height, 1e-6));
        expect(
          find.text('Nét 2 / ${level == PreviewLevel.n5 ? 4 : 6}'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final level in PreviewLevel.values) {
    testWidgets(
      '${level.label} owned exit retains expanded attribution EditableText while closing',
      (tester) async {
        final h = Harness();
        final owner = PlanOwner(h.runtime, PlanSource(h));
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
        final container = ProviderScope.containerOf(
          tester.element(find.byType(NihongoDailyApp)),
        );
        final content = kanjiCatalogProvider(level);
        final subscriptions = await tester.runAsync(() async {
          final catalog = container.listen(content, (_, _) {});
          try {
            final entries = await container.read(content.future);
            final guide = kanjiStrokeGuideProvider(entries.first);
            final listener = container.listen(guide, (_, _) {});
            try {
              await container.read(guide.future);
              return (catalog, listener, entries.first);
            } catch (_) {
              listener.close();
              rethrow;
            }
          } catch (_) {
            catalog.close();
            rethrow;
          }
        });
        addTearDown(() {
          subscriptions?.$1.close();
          subscriptions?.$2.close();
        });
        final router = container.read(routerProvider);
        router.go('/kanji/practice/${level.name}/${subscriptions!.$3.id}');
        await tester.pumpAndSettle();
        await tapCatalog(tester, find.byKey(const Key('kanji-guide-toggle')));
        final editableFinder = find.descendant(
          of: find.byType(KanjiStrokeGuidePanel),
          matching: find.byType(EditableText),
        );
        expect(editableFinder, findsOneWidget);
        final editableState = tester.state(editableFinder);
        owner.closing = Completer();
        var exited = false;
        final closing = tester.binding.handleRequestAppExit().then((value) {
          exited = true;
          return value;
        });
        await tester.pump();
        await tester.pump();
        expect(exited, isFalse);
        expect(startup.account, isNull);
        expect(identical(container.read(routerProvider), router), isTrue);
        expect(editableFinder, findsNothing);
        final hidden = find.descendant(
          of: find.byType(KanjiStrokeGuidePanel, skipOffstage: false),
          matching: find.byType(EditableText, skipOffstage: false),
          skipOffstage: false,
        );
        expect(identical(tester.state(hidden), editableState), isTrue);
        expect(
          tester.widget<EditableText>(hidden).focusNode.canRequestFocus,
          isFalse,
        );
        owner.closing!.complete();
        expect(await closing, AppExitResponse.exit);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
