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

class FixtureCurriculumRepository implements CurriculumRepository {
  FixtureCurriculumRepository(this.loader);
  final Future<List<CurriculumEntry>> Function(
    CurriculumKind,
    PreviewLevel,
  ) loader;

  @override
  Future<List<CurriculumEntry>> load(
    CurriculumKind kind,
    PreviewLevel level,
  ) => loader(kind, level);
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
    overrides: [
      curriculumRepositoryProvider.overrideWithValue(repository),
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
      await tester.tap(find.byKey(ValueKey(original[kind]!.first.id)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Về danh sách'));
      await tester.tap(find.text('Về danh sách'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
