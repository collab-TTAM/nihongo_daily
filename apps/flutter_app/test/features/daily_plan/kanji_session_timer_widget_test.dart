import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/daily_plan_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/srs_session_recorder_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/study_session_recorder.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';
import 'package:nihongo_daily/features/kanji/application/kanji_catalog_provider.dart';
import 'package:nihongo_daily/features/kanji/domain/kanji_catalog.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import '../srs/account_fixtures.dart' as account;
import '../srs/study_fixtures.dart' show fixtureItem;
import 'srs_session_timer_widget_test.dart' show TimerHarness;

KanjiCatalogEntry _entry(PreviewLevel level, int index) {
  final isN4 = level == PreviewLevel.n4;
  final ids = isN4
      ? [
          'a4000000-0000-4000-8000-000000000001',
          'a4000000-0000-4000-8000-000000000002',
        ]
      : [
          'a5000000-0000-4000-8000-000000000001',
          'a5000000-0000-4000-8000-000000000002',
        ];
  final characters = isN4 ? ['日', '月'] : ['火', '水'];
  final meanings = isN4 ? ['mặt trời', 'mặt trăng'] : ['lửa', 'nước'];
  return KanjiCatalogEntry(
    id: ids[index],
    level: level,
    contentVersion: 1,
    character: characters[index],
    meaningVi: meanings[index],
    onyomi: const ['ニチ'],
    kunyomi: const ['ひ'],
    strokeCount: 4,
    radical: null,
    hasStrokeReference: false,
  );
}

final class KanjiFixtureRepository implements KanjiCatalogRepository {
  KanjiFixtureRepository({this.empty = false});
  final bool empty;

  @override
  Future<List<KanjiCatalogEntry>> load(PreviewLevel level) async => empty
      ? []
      : [
          _entry(level, 0),
          _entry(level, 1),
        ];
}

Future<TimerHarness> mountKanjiTimer(
  WidgetTester tester, {
  bool configured = true,
  PreviewLevel routeLevel = PreviewLevel.n4,
  bool emptyCatalog = false,
}) async {
  final f = TimerHarness();
  f.h.queue.items = [fixtureItem(level: PreviewLevel.n4)];
  f.container = ProviderContainer(
    overrides: [
      if (configured) accountRuntimeProvider.overrideWithValue(f.h.runtime),
      if (configured) durableStudySourceProvider.overrideWithValue(f.source),
      studyRecorderClockProvider.overrideWithValue(f.clock),
      kanjiCatalogRepositoryProvider.overrideWithValue(
        KanjiFixtureRepository(empty: emptyCatalog),
      ),
    ],
  );
  f.container.read(previewLevelProvider.notifier).state = PreviewLevel.n4;
  addTearDown(() async {
    final wait = f.server.writeWait;
    if (wait != null && !wait.isCompleted) wait.complete();
    await tester.pumpWidget(const SizedBox());
    f.container.dispose();
    await f.h.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: f.container,
      child: const NihongoDailyApp(),
    ),
  );
  if (configured) f.h.access.change(account.owner);
  await tester.pumpAndSettle();
  final selected = _entry(routeLevel, 0);
  f.container.read(routerProvider).go(
    '/kanji/practice/${routeLevel.name}/${selected.id}',
  );
  await tester.pumpAndSettle();
  return f;
}

void main() {
  testWidgets('unconfigured Kanji preview cannot create a study report', (
    tester,
  ) async {
    final f = await mountKanjiTimer(tester, configured: false);
    expect(find.byKey(const Key('kanji-timer-date')), findsNothing);
    expect(find.byKey(const Key('kanji-timer-start')), findsNothing);
    expect(f.server.reads, 0);
    expect(f.server.writes, 0);
  });

  testWidgets(
    'configured Kanji practice records one acknowledged foreground session',
    (tester) async {
      final f = await mountKanjiTimer(tester);
      expect(
        f.container.read(canStartStudyRecorderProvider(DailyPlanArea.kanji)),
        isTrue,
      );
      expect(find.text('Thời gian học hán tự'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('kanji-timer-date')),
        '2026-10-20',
      );
      final start = find.byKey(const Key('kanji-timer-start'));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kanji-timer-elapsed')), findsOneWidget);
      expect(f.server.reads, 1);
      expect(f.server.writes, 0);

      f.clock.advance(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 1));
      final finish = find.byKey(const Key('kanji-timer-finish'));
      await tester.ensureVisible(finish);
      await tester.tap(finish);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('kanji-timer-confirmed')), findsOneWidget);
      expect(f.server.writes, 1);
      expect(f.clock.ids, 1);
      final records = await f.memory.list(account.owner);
      expect(records, hasLength(1));
      expect(records.single.acknowledged, isTrue);
      expect(records.single.event.area, DailyPlanArea.kanji);
      expect(records.single.event.date, DailyPlanDate('2026-10-20'));
      expect(find.textContaining('Chấm điểm: chưa khả dụng'), findsOneWidget);
    },
  );

  testWidgets('empty Kanji catalog cannot start a study report', (
    tester,
  ) async {
    final f = await mountKanjiTimer(tester, emptyCatalog: true);
    expect(
      f.container.read(canStartStudyRecorderProvider(DailyPlanArea.kanji)),
      isFalse,
    );
    expect(find.byKey(const Key('kanji-timer-start')), findsNothing);
    expect(f.server.reads, 0);
    expect(f.server.writes, 0);
  });

  testWidgets('profile-level mismatch disables Kanji time reporting', (
    tester,
  ) async {
    final f = await mountKanjiTimer(tester, routeLevel: PreviewLevel.n5);
    final start = find.byKey(const Key('kanji-timer-start'));
    expect(start, findsOneWidget);
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    expect(
      find.text('Cần danh mục Kanji khả dụng ở đúng trình độ hồ sơ.'),
      findsOneWidget,
    );
    expect(f.server.reads, 0);
    expect(f.server.writes, 0);
  });

  testWidgets('changing the selected character cancels unfinished Kanji time', (
    tester,
  ) async {
    final f = await mountKanjiTimer(tester);
    await tester.enterText(
      find.byKey(const Key('kanji-timer-date')),
      '2026-10-20',
    );
    final start = find.byKey(const Key('kanji-timer-start'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(
      f.container.read(studySessionRecorderProvider).phase,
      StudyRecorderPhase.running,
    );
    f.clock.advance(const Duration(seconds: 30));

    final next = _entry(PreviewLevel.n4, 1);
    f.container.read(routerProvider).go(
      '/kanji/practice/n4/${next.id}',
    );
    await tester.pumpAndSettle();

    expect(
      f.container.read(studySessionRecorderProvider).phase,
      StudyRecorderPhase.canceled,
    );
    expect(f.server.writes, 0);
    expect(f.clock.ids, 0);
    expect(await f.memory.list(account.owner), isEmpty);
  });
}
