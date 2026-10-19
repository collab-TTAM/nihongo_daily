import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/curriculum/application/curriculum_provider.dart';
import 'package:nihongo_daily/features/curriculum/data/bundled_curriculum_repository.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import 'package:nihongo_daily/shared/widgets/page_body.dart';

class FixtureCurriculumRepository implements CurriculumRepository {
  FixtureCurriculumRepository(this.loader);
  final Future<List<CurriculumEntry>> Function(CurriculumKind, PreviewLevel)
  loader;

  @override
  Future<List<CurriculumEntry>> load(CurriculumKind kind, PreviewLevel level) =>
      loader(kind, level);
}

Future<ProviderContainer> mountCurriculum(
  WidgetTester tester,
  CurriculumRepository repository,
  String path, {
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [curriculumRepositoryProvider.overrideWithValue(repository)],
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
  container.read(routerProvider).go(path);
  await tester.pump();
  return container;
}

void main() {
  final original = <CurriculumKind, List<CurriculumEntry>>{};
  setUpAll(() async {
    for (final kind in CurriculumKind.values) {
      original[kind] = decodeCurriculum(
        await File('../../data/n5/${kind.name}.json').readAsString(),
        kind,
        PreviewLevel.n5,
      );
    }
  });

  FixtureCurriculumRepository realSeedReader() => FixtureCurriculumRepository(
    (kind, level) async => level == PreviewLevel.n5 ? original[kind]! : [],
  );

  for (final kind in CurriculumKind.values) {
    testWidgets('${kind.name} opens original detail and returns to list', (
      tester,
    ) async {
      await mountCurriculum(tester, realSeedReader(), '/${kind.name}');
      await tester.pumpAndSettle();
      final entry = original[kind]!.first;
      await tester.tap(find.byKey(ValueKey(entry.id)));
      await tester.pumpAndSettle();
      expect(find.text(entry.meaningVi), findsOneWidget);
      expect(find.text(entry.explanationVi), findsOneWidget);
      expect(find.text(entry.examples.first.japanese), findsOneWidget);
      expect(find.text(entry.examples.first.reading), findsOneWidget);
      expect(find.text(entry.examples.first.vietnamese), findsOneWidget);
      expect(find.text('Chưa có âm thanh cho mục này.'), findsOneWidget);
      expect(find.textContaining('Chỉ đọc, chưa ghi tiến độ'), findsOneWidget);
      await tester.ensureVisible(find.text('Về danh sách'));
      await tester.tap(find.text('Về danh sách'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(entry.id)), findsOneWidget);
      expect(find.text(entry.explanationVi), findsNothing);
    });
  }

  testWidgets('changing to unavailable N4 hides old detail', (tester) async {
    await mountCurriculum(tester, realSeedReader(), '/vocabulary');
    await tester.pumpAndSettle();
    final entry = original[CurriculumKind.vocabulary]!.first;
    await tester.tap(find.byKey(ValueKey(entry.id)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('curriculum-level')));
    await tester.tap(find.byKey(const Key('curriculum-level')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('N4').last);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có nội dung N4 trong bản này.'), findsOneWidget);
    expect(find.text('私'), findsNothing);
    expect(find.text('わたし'), findsNothing);
    expect(find.byKey(const Key('curriculum-previous')), findsNothing);
    expect(find.byKey(const Key('curriculum-next')), findsNothing);
    expect(
      tester.widget<PageBody>(find.byType(PageBody)).scrollController!.offset,
      0,
    );
  });

  testWidgets('loading safe error and explicit retry work', (tester) async {
    final waiting = Completer<List<CurriculumEntry>>();
    var calls = 0;
    await mountCurriculum(
      tester,
      FixtureCurriculumRepository((kind, level) {
        calls++;
        return calls == 1 ? waiting.future : Future.value(original[kind]!);
      }),
      '/vocabulary',
    );
    await tester.pump();
    expect(find.text('Đang tải nội dung…'), findsOneWidget);
    waiting.completeError(StateError('PRIVATE ASSET TOKEN'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE ASSET TOKEN'), findsNothing);
    expect(calls, 1);
    await tester.tap(find.text('Thử tải lại'));
    await tester.pumpAndSettle();
    expect(find.text('私'), findsOneWidget);
    expect(calls, 2);
  });

  for (final kind in CurriculumKind.values) {
    testWidgets('${kind.name} reads adjacent entries without wrapping', (
      tester,
    ) async {
      final entries = original[kind]!.take(2).toList();
      await mountCurriculum(
        tester,
        FixtureCurriculumRepository((_, _) async => entries),
        '/${kind.name}',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(entries.first.id)));
      await tester.pumpAndSettle();
      final previous = find.byKey(const Key('curriculum-previous'));
      final next = find.byKey(const Key('curriculum-next'));
      expect(find.text('Mục 1 / 2'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(previous).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(next).onPressed, isNotNull);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Mục 2 / 2'), findsOneWidget);
      expect(find.text(entries.last.explanationVi), findsOneWidget);
      expect(find.text(entries.first.explanationVi), findsNothing);
      expect(tester.widget<OutlinedButton>(next).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(previous).onPressed, isNotNull);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(find.text('Mục 1 / 2'), findsOneWidget);
      expect(find.text(entries.first.explanationVi), findsOneWidget);
      expect(find.text(entries.last.explanationVi), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('single entry disables both adjacent actions', (tester) async {
    final entry = original[CurriculumKind.vocabulary]!.first;
    await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, _) async => [entry]),
      '/vocabulary',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(entry.id)));
    await tester.pumpAndSettle();
    expect(find.text('Mục 1 / 1'), findsOneWidget);
    for (final key in ['curriculum-previous', 'curriculum-next']) {
      expect(
        tester.widget<OutlinedButton>(find.byKey(Key(key))).onPressed,
        isNull,
      );
    }
    expect(find.text(entry.explanationVi), findsOneWidget);
  });

  testWidgets('search reads original matches and clear restores the list', (
    tester,
  ) async {
    await mountCurriculum(tester, realSeedReader(), '/vocabulary');
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('curriculum-search'));
    await tester.enterText(search, 'がくせい');
    await tester.pumpAndSettle();
    expect(find.text('学生'), findsOneWidget);
    expect(find.text('私'), findsNothing);
    expect(find.text('1 mục N5 · Chọn để xem bài'), findsOneWidget);
    await tester.enterText(search, 'GIAO VIEN');
    await tester.pumpAndSettle();
    expect(find.text('先生'), findsOneWidget);
    expect(find.text('学生'), findsNothing);
    await tester.enterText(search, 'not-in-the-original-export');
    await tester.pumpAndSettle();
    expect(find.textContaining('Không tìm thấy bài phù hợp.'), findsOneWidget);
    expect(find.textContaining('Chưa có nội dung N5'), findsNothing);
    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    expect(find.text('24 mục N5 · Chọn để xem bài'), findsOneWidget);
    expect(find.text('私'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtered grammar order and query survive detail navigation', (
    tester,
  ) async {
    await mountCurriculum(tester, realSeedReader(), '/grammar');
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('curriculum-search'));
    await tester.enterText(search, 'N1 は');
    await tester.pumpAndSettle();
    final entries = original[CurriculumKind.grammar]!;
    expect(find.text('3 mục N5 · Chọn để xem bài'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey(entries.first.id)));
    await tester.pumpAndSettle();
    expect(find.text('Mục 1 / 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('curriculum-next')));
    await tester.pumpAndSettle();
    expect(find.text('Mục 2 / 3'), findsOneWidget);
    expect(find.text(entries[1].explanationVi), findsOneWidget);
    await tester.tap(find.text('Về danh sách'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, 'N1 は');
    expect(find.text('3 mục N5 · Chọn để xem bài'), findsOneWidget);
    expect(find.byKey(ValueKey(entries[3].id)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing a detail query clears selection and N4 stays unavailable',
    (tester) async {
      await mountCurriculum(tester, realSeedReader(), '/vocabulary');
      await tester.pumpAndSettle();
      final entries = original[CurriculumKind.vocabulary]!;
      await tester.tap(find.byKey(ValueKey(entries.first.id)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('curriculum-search')),
        'HOC SINH',
      );
      await tester.pumpAndSettle();
      expect(find.text(entries.first.explanationVi), findsNothing);
      expect(find.byKey(const Key('curriculum-next')), findsNothing);
      expect(find.text('学生'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey(entries[1].id)));
      await tester.pumpAndSettle();
      expect(find.text(entries[1].explanationVi), findsOneWidget);
      await tester.tap(find.byKey(const Key('curriculum-level')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('N4').last);
      await tester.pumpAndSettle();
      expect(find.text('Chưa có nội dung N4 trong bản này.'), findsOneWidget);
      expect(find.textContaining('Không tìm thấy bài phù hợp.'), findsNothing);
      expect(find.text('学生'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new details start at top and list return restores position', (
    tester,
  ) async {
    await mountCurriculum(
      tester,
      realSeedReader(),
      '/vocabulary',
      size: const Size(375, 812),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<PageBody>(find.byType(PageBody))
        .scrollController!;
    final entry = original[CurriculumKind.vocabulary]![10];
    final tile = find.byKey(ValueKey(entry.id));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    final listOffset = controller.offset;
    expect(listOffset, greaterThan(0));
    expect(tile.hitTestable(), findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(find.text(entry.explanationVi), findsOneWidget);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('curriculum-next')));
    await tester.tap(find.byKey(const Key('curriculum-next')));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(
      find.text(original[CurriculumKind.vocabulary]![11].explanationVi),
      findsOneWidget,
    );
    await tester.tap(find.text('Về danh sách'));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(listOffset, 0.01));
    expect(tile.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final kind in CurriculumKind.values) {
    testWidgets('${kind.name} at 320px 200 percent has no overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mountCurriculum(
        tester,
        realSeedReader(),
        '/${kind.name}',
        size: const Size(320, 640),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final entry = original[kind]!.first;
      final tile = find.byKey(ValueKey(entry.id));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(tile.hitTestable(), findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(entry.explanationVi), findsOneWidget);
      expect(find.text(entry.examples.first.japanese), findsOneWidget);
      final next = find.byKey(const Key('curriculum-next'));
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      expect(next.hitTestable(), findsOneWidget);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text(original[kind]![1].explanationVi), findsOneWidget);
      expect(find.text(entry.explanationVi), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Về danh sách'));
      await tester.tap(find.text('Về danh sách'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tile, findsOneWidget);
      expect(find.text(entry.explanationVi), findsNothing);
      final search = find.byKey(const Key('curriculum-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'not-in-the-original-export');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Không tìm thấy bài phù hợp.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Xóa tìm kiếm'));
      await tester.tap(find.byTooltip('Xóa tìm kiếm'));
      await tester.pumpAndSettle();
      expect(tile, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
