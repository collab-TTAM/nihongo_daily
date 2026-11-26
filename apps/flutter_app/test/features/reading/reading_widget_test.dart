import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/reading/application/reading_provider.dart';
import 'package:nihongo_daily/features/reading/data/bundled_reading_repository.dart';
import 'package:nihongo_daily/features/reading/data/local_reading_repository.dart';
import 'package:nihongo_daily/features/reading/domain/reading_material.dart';
import 'package:nihongo_daily/features/reading/domain/reading_repository.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';

// TEST ONLY source material, not reviewed curriculum or a production default.
String material({
  String id = 'fixture-a',
  String level = 'N5',
  int version = 1,
  String title = '図書館',
}) => jsonEncode({
  'schema_version': 1,
  'passages': [
    {
      'id': id,
      'jlpt_level': level,
      'content_version': version,
      'title_ja': title,
      'title_vi': 'Thư viện',
      'text_ja': '今日は図書館で本を読みます。',
      'reading_ja': 'きょうはとしょかんでほんをよみます。',
      'translation_vi': 'Hôm nay tôi đọc sách ở thư viện.',
      'source_note_vi': 'TEST ONLY widget material',
      'questions': [
        for (final id in ['q1', 'q2'])
          {
            'id': id,
            'prompt_ja': id == 'q1' ? '何を読みますか。' : 'どこで読みますか。',
            'reading_ja': id == 'q1' ? 'なにをよみますか。' : 'どこでよみますか。',
            'prompt_vi': id == 'q1' ? 'Đọc gì?' : 'Đọc ở đâu?',
            'choices': [
              {
                'id': 'a',
                'text_ja': '本',
                'reading_ja': 'ほん',
                'text_vi': 'Sách',
              },
              {
                'id': 'b',
                'text_ja': '図書館',
                'reading_ja': 'としょかん',
                'text_vi': 'Thư viện',
              },
            ],
            'correct_choice_id': id == 'q1' ? 'a' : 'b',
            'explanation_vi': id == 'q1' ? 'Đọc sách.' : 'Ở thư viện.',
          },
      ],
    },
  ],
});

class TestReadingRepository implements ReadingRepository {
  TestReadingRepository(this.read);
  final Future<List<ReadingPassage>> Function(PreviewLevel) read;
  @override
  Future<List<ReadingPassage>> load(PreviewLevel level) => read(level);
  @override
  Future<ReadingPassage?> find(
    PreviewLevel level,
    String id,
    int contentVersion,
  ) async {
    for (final p in await load(level)) {
      if (p.id == id && p.contentVersion == contentVersion) return p;
    }
    return null;
  }
}

/// Holds the exact packaged asset bytes after a bounded real-async preflight.
/// The widget/provider then parses the same source without a fake-clock I/O wait.
final class _LoadedReadingAssetBundle extends CachingAssetBundle {
  _LoadedReadingAssetBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async {
    if (key != BundledReadingRepository.assetPath) {
      throw FlutterError('Unexpected reading test asset request');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  }
}

Future<
  ({ProviderContainer container, StateProvider<ReadingRepository?> source})
>
mountReading(
  WidgetTester tester, {
  ReadingRepository? repository,
  Size size = const Size(1100, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source = StateProvider<ReadingRepository?>((ref) => repository);
  final container = ProviderContainer(
    overrides: [
      if (repository != null)
        readingRepositoryProvider.overrideWith((ref) => ref.watch(source)),
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
  container.read(routerProvider).go('/listening');
  await tester.pump();
  return (container: container, source: source);
}

Future<void> tapReading(
  WidgetTester tester,
  Finder target, {
  bool settle = true,
}) async {
  await tester.ensureVisible(target);
  await tester.pump();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
}

Future<BundledReadingRepository> loadBundledN5ReadingRepository(
  WidgetTester tester,
) async {
  // Read the actual package asset before mounting widgets. Keeping the platform
  // asset I/O outside the provider's FakeAsync lifetime avoids a pending
  // Future.timeout that cannot fire until a pump, while runAsync is awaiting it.
  final source = await tester.runAsync(
    () => rootBundle
        .loadString(BundledReadingRepository.assetPath)
        .timeout(const Duration(seconds: 5)),
  );
  if (source == null) {
    throw StateError('Bundled reading asset did not load');
  }
  final repository = BundledReadingRepository(
    bundle: _LoadedReadingAssetBundle(source),
  );
  expect(await repository.load(PreviewLevel.n5), hasLength(13));
  return repository;
}

Future<void> openReading(WidgetTester tester, {String id = 'fixture-a'}) async {
  await tapReading(tester, find.byKey(ValueKey('reading-open-$id')));
}

void main() {
  testWidgets(
    'default route uses bundled N5 reading; audio and saved result stay unavailable',
    (tester) async {
      final repository = await loadBundledN5ReadingRepository(tester);
      final h = await mountReading(tester, repository: repository);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reading-loading')), findsNothing);
      expect(find.byKey(const Key('reading-error')), findsNothing);
      expect(find.byKey(const Key('reading-empty')), findsNothing);
      expect(
        h.container.read(readingRepositoryProvider),
        isA<BundledReadingRepository>(),
      );
      expect(find.byKey(const Key('reading-unavailable')), findsNothing);
      expect(find.text('13 bài đọc · Chọn để mở'), findsOneWidget);
      expect(
        find.byKey(const Key('reading-open-n5-daily-routine-01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reading-open-n5-sunday-meal-01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reading-open-n5-bus-commute-01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reading-open-n5-friend-house-01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reading-open-n5-birthday-01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reading-open-n5-supermarket-01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reading-open-n5-winter-morning-01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reading-open-n5-tennis-invitation-01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reading-open-n5-family-breakfast-01')),
        findsOneWidget,
      );
      await tapReading(
        tester,
        find.byKey(const Key('reading-open-n5-birthday-01')),
      );
      expect(find.text('誕生日の一日'), findsOneWidget);
      expect(find.textContaining('きのうは私の誕生日でした。'), findsOneWidget);
      await tapReading(
        tester,
        find.byKey(const Key('reading-show-translation')),
      );
      expect(
        find.textContaining('Hôm qua là sinh nhật của tôi.'),
        findsOneWidget,
      );
      await tapReading(tester, find.byKey(const Key('reading-back')));
      expect(find.byKey(const Key('reading-result')), findsNothing);
      await tapReading(
        tester,
        find.byKey(const Key('reading-open-n5-supermarket-01')),
      );
      expect(find.text('スーパーで買い物'), findsOneWidget);
      expect(find.textContaining('土曜日、私は母とスーパーへ行きました。'), findsOneWidget);
      await tapReading(tester, find.byKey(const Key('reading-back')));
      await tapReading(
        tester,
        find.byKey(const Key('reading-open-n5-winter-morning-01')),
      );
      expect(find.text('冬の朝'), findsOneWidget);
      expect(find.textContaining('冬の朝は寒いです。'), findsOneWidget);
      final readingToggle = tester.widget<CheckboxListTile>(
        find.byKey(const Key('reading-show-reading')),
      );
      if (readingToggle.value != true) {
        await tapReading(tester, find.byKey(const Key('reading-show-reading')));
      }
      final translationToggle = tester.widget<CheckboxListTile>(
        find.byKey(const Key('reading-show-translation')),
      );
      if (translationToggle.value != true) {
        await tapReading(
          tester,
          find.byKey(const Key('reading-show-translation')),
        );
      }
      expect(find.textContaining('ろくじはんにおきて'), findsOneWidget);
      expect(find.textContaining('uống trà nóng'), findsOneWidget);
      for (final question in ['q1', 'q2', 'q3']) {
        await tapReading(
          tester,
          find.byKey(ValueKey('reading-choice-$question-a')),
        );
      }
      expect(find.text('Kết quả: 3 / 3'), findsOneWidget);
      await tapReading(tester, find.byKey(const Key('reading-back')));

      await tapReading(
        tester,
        find.byKey(const Key('reading-open-n5-tennis-invitation-01')),
      );
      expect(find.text('土曜日にテニスをします'), findsOneWidget);
      expect(find.textContaining('土曜日の午後、私は友達の田中さんと公園へ行きます。'), findsOneWidget);
      expect(find.text('田中さんは何が好きですか。'), findsOneWidget);
      expect(find.text('何時に公園で会いますか。'), findsOneWidget);
      await tapReading(tester, find.byKey(const Key('reading-back')));

      await tapReading(
        tester,
        find.byKey(const Key('reading-open-n5-family-breakfast-01')),
      );
      expect(find.text('日曜日の朝ごはん'), findsOneWidget);
      expect(find.textContaining('日曜日の朝、私は六時半に起きました。'), findsOneWidget);
      expect(find.text('父は何を飲みましたか。'), findsOneWidget);
      expect(find.text('朝ごはんのあとで、私は何をしましたか。'), findsOneWidget);
      await tapReading(tester, find.byKey(const Key('reading-back')));

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('reading-audio-unavailable')),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('chưa lưu tiến độ'), findsOneWidget);

      h.container.read(previewLevelProvider.notifier).state = PreviewLevel.n4;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reading-empty')), findsOneWidget);
      expect(
        find.text('Chưa có bài đọc N4 trong nguồn hiện tại.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('reading-result')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('read answer feedback completion restart and stale callbacks', (
    tester,
  ) async {
    await mountReading(
      tester,
      repository: LocalReadingRepository(read: () async => material()),
    );
    await tester.pumpAndSettle();
    await openReading(tester);
    expect(find.byKey(const Key('reading-text')), findsOneWidget);
    expect(find.byKey(const Key('reading-kana')), findsNothing);
    expect(find.byKey(const Key('reading-vietnamese')), findsNothing);
    await tapReading(tester, find.byKey(const Key('reading-show-reading')));
    await tapReading(tester, find.byKey(const Key('reading-show-translation')));
    expect(find.byKey(const Key('reading-kana')), findsOneWidget);
    expect(find.text('Hôm nay tôi đọc sách ở thư viện.'), findsOneWidget);
    expect(find.text('Nguồn: TEST ONLY widget material'), findsOneWidget);
    final q1 = find.byKey(const ValueKey('reading-choice-q1-a'));
    final staleAnswer = tester.widget<OutlinedButton>(q1).onPressed!;
    await tapReading(tester, q1);
    staleAnswer();
    await tester.pump();
    expect(find.text('Đúng theo bài đọc.'), findsOneWidget);
    expect(find.byKey(const Key('reading-result')), findsNothing);
    final q2 = find.byKey(const ValueKey('reading-choice-q2-a'));
    await tapReading(tester, q2);
    expect(find.text('Chưa đúng theo bài đọc.'), findsOneWidget);
    expect(find.text('Kết quả: 1 / 2'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(q1).onPressed, isNull);
    final restart = find.byKey(const Key('reading-restart'));
    final staleRestart = tester.widget<OutlinedButton>(restart).onPressed!;
    await tapReading(tester, restart);
    staleAnswer();
    await tester.pump();
    expect(find.text('Đã trả lời 0 / 2'), findsOneWidget);
    await tapReading(tester, q1);
    staleRestart();
    await tester.pump();
    expect(find.text('Đã trả lời 1 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'back and reopening start a fresh round and reject disposed callbacks',
    (tester) async {
      await mountReading(
        tester,
        repository: LocalReadingRepository(read: () async => material()),
      );
      await tester.pumpAndSettle();
      await openReading(tester);
      final q1 = find.byKey(const ValueKey('reading-choice-q1-a'));
      final stale = tester.widget<OutlinedButton>(q1).onPressed!;
      final back = find.byKey(const Key('reading-back'));
      await tapReading(tester, back);
      stale();
      await tester.pump();
      expect(find.byKey(const Key('reading-passage')), findsNothing);
      await openReading(tester);
      stale();
      await tester.pump();
      expect(find.text('Đã trả lời 0 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loader error is redacted and retry can produce an empty level', (
    tester,
  ) async {
    final held = Completer<List<ReadingPassage>>();
    var reads = 0;
    await mountReading(
      tester,
      repository: TestReadingRepository(
        (_) => ++reads == 1 ? held.future : Future.value([]),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('reading-loading')), findsOneWidget);
    held.completeError(StateError('PRIVATE path/token/source'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reading-error')), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(reads, 1);
    await tapReading(tester, find.byKey(const Key('reading-retry')));
    expect(reads, 2);
    expect(
      find.text('Chưa có bài đọc N5 trong nguồn hiện tại.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reading-passage')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level change during loading rejects late old-level success', (
    tester,
  ) async {
    final held = Completer<List<ReadingPassage>>();
    final h = await mountReading(
      tester,
      repository: TestReadingRepository(
        (level) => level == PreviewLevel.n5
            ? held.future
            : Future.value(
                decodeReadingMaterial(
                  material(id: 'fixture-b', level: 'N4', title: '新しい記事'),
                  level,
                ),
              ),
      ),
    );
    h.container.read(previewLevelProvider.notifier).state = PreviewLevel.n4;
    await tester.pumpAndSettle();
    held.complete(
      decodeReadingMaterial(material(title: '古い記事'), PreviewLevel.n5),
    );
    await tester.pumpAndSettle();
    expect(find.text('古い記事'), findsNothing);
    expect(find.text('新しい記事'), findsOneWidget);
    await openReading(tester, id: 'fixture-b');
    expect(find.text('Đã trả lời 0 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level change during loading consumes late old-level errors', (
    tester,
  ) async {
    final held = Completer<List<ReadingPassage>>();
    final h = await mountReading(
      tester,
      repository: TestReadingRepository(
        (level) => level == PreviewLevel.n5 ? held.future : Future.value([]),
      ),
    );
    h.container.read(previewLevelProvider.notifier).state = PreviewLevel.n4;
    await tester.pumpAndSettle();
    held.completeError(StateError('PRIVATE late old-level error'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reading-error')), findsNothing);
    expect(
      find.text('Chưa có bài đọc N4 trong nguồn hiện tại.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'source replacement and null source clear answers for the same level',
    (tester) async {
      final h = await mountReading(
        tester,
        repository: LocalReadingRepository(read: () async => material()),
      );
      await tester.pumpAndSettle();
      await openReading(tester);
      final stale = tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('reading-choice-q1-a')),
          )
          .onPressed!;
      await tapReading(
        tester,
        find.byKey(const ValueKey('reading-choice-q1-a')),
      );
      h.container.read(h.source.notifier).state = LocalReadingRepository(
        read: () async => material(title: '別の資料'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reading-passage')), findsNothing);
      await openReading(tester);
      stale();
      await tester.pump();
      expect(find.text('別の資料'), findsOneWidget);
      expect(find.text('Đã trả lời 0 / 2'), findsOneWidget);
      h.container.read(h.source.notifier).state = null;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reading-unavailable')), findsOneWidget);
      expect(find.byKey(const Key('reading-passage')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'level selector clears an answered round before opening another level',
    (tester) async {
      await mountReading(
        tester,
        repository: TestReadingRepository(
          (level) async => decodeReadingMaterial(
            material(level: level.label, title: '記事${level.label}'),
            level,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openReading(tester);
      final stale = tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('reading-choice-q1-a')),
          )
          .onPressed!;
      await tapReading(
        tester,
        find.byKey(const ValueKey('reading-choice-q1-a')),
      );
      await tapReading(tester, find.byKey(const Key('reading-level')));
      await tapReading(tester, find.text('N4').last);
      expect(find.text('記事N5'), findsNothing);
      expect(find.text('記事N4'), findsOneWidget);
      expect(find.byKey(const Key('reading-passage')), findsNothing);
      await openReading(tester);
      stale();
      await tester.pump();
      expect(find.text('Đã trả lời 0 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('source replacement during pending load rejects late data', (
    tester,
  ) async {
    final held = Completer<List<ReadingPassage>>();
    final h = await mountReading(
      tester,
      repository: TestReadingRepository((_) => held.future),
    );
    await tester.pump();
    h.container.read(h.source.notifier).state = LocalReadingRepository(
      read: () async => material(title: '新しい資料'),
    );
    await tester.pumpAndSettle();
    held.complete(
      decodeReadingMaterial(material(title: '古い資料'), PreviewLevel.n5),
    );
    await tester.pumpAndSettle();
    expect(find.text('新しい資料'), findsOneWidget);
    expect(find.text('古い資料'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reload clears old round while pending and accepts newer version',
    (tester) async {
      final held = Completer<String>();
      var reads = 0;
      await mountReading(
        tester,
        repository: LocalReadingRepository(
          read: () => ++reads == 1 ? Future.value(material()) : held.future,
        ),
      );
      await tester.pumpAndSettle();
      await openReading(tester);
      final stale = tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('reading-choice-q1-a')),
          )
          .onPressed!;
      await tapReading(
        tester,
        find.byKey(const ValueKey('reading-choice-q1-a')),
      );
      await tapReading(
        tester,
        find.byKey(const Key('reading-reload')),
        settle: false,
      );
      expect(reads, 2);
      expect(find.byKey(const Key('reading-loading')), findsOneWidget);
      expect(find.byKey(const Key('reading-passage')), findsNothing);
      stale();
      held.complete(material(version: 2, title: '更新した記事'));
      await tester.pumpAndSettle();
      await openReading(tester);
      expect(find.text('更新した記事'), findsOneWidget);
      expect(find.text('Đã trả lời 0 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('immediate reload of an identical list still resets the round', (
    tester,
  ) async {
    final passages = decodeReadingMaterial(material(), PreviewLevel.n5);
    await mountReading(
      tester,
      repository: TestReadingRepository((_) async => passages),
    );
    await tester.pumpAndSettle();
    await openReading(tester);
    await tapReading(tester, find.byKey(const ValueKey('reading-choice-q1-a')));
    await tapReading(tester, find.byKey(const Key('reading-reload')));
    expect(find.byKey(const Key('reading-passage')), findsNothing);
    await openReading(tester);
    expect(find.text('Đã trả lời 0 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same-version source conflict shows an error instead of stale content',
    (tester) async {
      var source = material();
      await mountReading(
        tester,
        repository: LocalReadingRepository(read: () async => source),
      );
      await tester.pumpAndSettle();
      await openReading(tester);
      source = material(title: 'Không hợp lệ');
      await tapReading(tester, find.byKey(const Key('reading-reload')));
      expect(find.byKey(const Key('reading-error')), findsOneWidget);
      expect(find.text('Không hợp lệ'), findsNothing);
      expect(find.byKey(const Key('reading-passage')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('navigation disposes the round and consumes a late load', (
    tester,
  ) async {
    final held = Completer<List<ReadingPassage>>();
    final h = await mountReading(
      tester,
      repository: TestReadingRepository((_) => held.future),
    );
    await tester.pump();
    final staleReload = tester
        .widget<OutlinedButton>(find.byKey(const Key('reading-reload')))
        .onPressed!;
    final staleLevel = tester
        .widget<DropdownButton<PreviewLevel>>(
          find.byKey(const Key('reading-level')),
        )
        .onChanged!;
    h.container.read(routerProvider).go('/study');
    await tester.pumpAndSettle();
    staleReload();
    staleLevel(PreviewLevel.n4);
    held.completeError(StateError('PRIVATE disposed source'));
    await tester.pumpAndSettle();
    expect(find.text('Không gian học tập'), findsOneWidget);
    expect(find.byKey(const Key('reading-error')), findsNothing);
    expect(h.container.read(previewLevelProvider), PreviewLevel.n5);
    expect(tester.takeException(), isNull);
  });

  for (final level in PreviewLevel.values) {
    testWidgets(
      '${level.name} 320px 200 percent controls and answers remain accessible',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final h = await mountReading(
          tester,
          size: const Size(320, 640),
          repository: LocalReadingRepository(
            read: () async => material(level: level.label),
          ),
        );
        h.container.read(previewLevelProvider.notifier).state = level;
        await tester.pumpAndSettle();
        await openReading(tester);
        await tapReading(tester, find.byKey(const Key('reading-show-reading')));
        await tapReading(
          tester,
          find.byKey(const Key('reading-show-translation')),
        );
        await tapReading(
          tester,
          find.byKey(const ValueKey('reading-choice-q1-a')),
        );
        await tapReading(
          tester,
          find.byKey(const ValueKey('reading-choice-q2-b')),
        );
        expect(find.text('Kết quả: 2 / 2'), findsOneWidget);
        await tapReading(tester, find.byKey(const Key('reading-restart')));
        expect(find.text('Đã trả lời 0 / 2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
