import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/application/vocabulary_quiz_provider.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_repository.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/features/quiz/presentation/vocabulary_quiz_screen.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';

const _entries = [
  VocabularyQuizEntry(
    id: '17745f5e-9f28-59ac-8e19-6935ae77363b',
    jlptLevel: 'N5',
    contentVersion: 1,
    expression: '私',
    reading: 'わたし',
    meaningVi: 'tôi',
    isActive: true,
  ),
  VocabularyQuizEntry(
    id: '1ca82497-f4a7-5d55-9085-b0f6bddda015',
    jlptLevel: 'N5',
    contentVersion: 1,
    expression: '学生',
    reading: 'がくせい',
    meaningVi: 'học sinh; sinh viên',
    isActive: true,
  ),
  VocabularyQuizEntry(
    id: 'ea196360-05d4-5be9-8aa4-1c96d9dbf4ea',
    jlptLevel: 'N5',
    contentVersion: 1,
    expression: '先生',
    reading: 'せんせい',
    meaningVi: 'giáo viên',
    isActive: true,
  ),
  VocabularyQuizEntry(
    id: 'ee2c390b-6b01-561a-892e-3d8c9e45c670',
    jlptLevel: 'N5',
    contentVersion: 1,
    expression: '友達',
    reading: 'ともだち',
    meaningVi: 'bạn bè',
    isActive: true,
  ),
];

class _MemoryQuizRepository implements VocabularyQuizRepository {
  _MemoryQuizRepository(this.loader);

  final Future<List<VocabularyQuizEntry>> Function(String) loader;
  final requestedLevels = <String>[];

  @override
  Future<List<VocabularyQuizEntry>> load(String level) {
    requestedLevels.add(level);
    return loader(level);
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _MemoryQuizRepository repository, {
  PreviewLevel level = PreviewLevel.n5,
  Size size = const Size(800, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      vocabularyQuizRepositoryProvider.overrideWithValue(repository),
    ],
  );
  container.read(previewLevelProvider.notifier).state = level;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: VocabularyQuizScreen()),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets(
    'answers the first question and shows Vietnamese feedback without saving progress',
    (tester) async {
      final repository = _MemoryQuizRepository((_) async => _entries);
      await _mount(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('私'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quiz-option-がくせい')));
      await tester.pumpAndSettle();
      expect(find.text('Chưa chính xác.'), findsOneWidget);
      expect(find.text('Cách đọc theo bài gốc: わたし'), findsOneWidget);
      expect(find.textContaining('Chưa lưu lịch sử'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quiz-next')));
      await tester.pumpAndSettle();
      expect(find.text('学生'), findsOneWidget);

      for (final reading in ['がくせい', 'せんせい', 'ともだち']) {
        await tester.tap(find.byKey(Key('quiz-option-$reading')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('quiz-next')));
        await tester.pumpAndSettle();
      }

      expect(find.text('Kết quả: 3/4'), findsOneWidget);
      expect(find.text('Cần ôn lại'), findsOneWidget);
      expect(find.textContaining('わたし · tôi'), findsOneWidget);
    },
  );

  testWidgets('shows a loading state while bundled content is resolving', (
    tester,
  ) async {
    final completer = Completer<List<VocabularyQuizEntry>>();
    final repository = _MemoryQuizRepository((_) => completer.future);
    await _mount(tester, repository);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(_entries);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-question-expression')), findsOneWidget);
  });

  testWidgets('redacts load failures and retries the same selected level', (
    tester,
  ) async {
    var attempts = 0;
    final repository = _MemoryQuizRepository((_) async {
      attempts++;
      if (attempts == 1) throw StateError('private-token-detail');
      return _entries;
    });
    await _mount(tester, repository);
    await tester.pumpAndSettle();

    expect(find.textContaining('Không tải được câu hỏi'), findsOneWidget);
    expect(find.textContaining('private-token-detail'), findsNothing);
    await tester.tap(find.byKey(const Key('quiz-retry')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byKey(const Key('quiz-question-expression')), findsOneWidget);
    expect(repository.requestedLevels, ['N5', 'N5']);
  });

  testWidgets('shows N4 unavailable without falling back to N5', (
    tester,
  ) async {
    final repository = _MemoryQuizRepository((level) async {
      if (level == 'N4') throw QuizContentUnavailable(level);
      return _entries;
    });
    final container = await _mount(tester, repository);
    await tester.pumpAndSettle();

    container.read(previewLevelProvider.notifier).state = PreviewLevel.n4;
    await tester.pumpAndSettle();

    expect(find.textContaining('N4 chưa được tích hợp'), findsOneWidget);
    expect(repository.requestedLevels, ['N5', 'N4']);
  });

  testWidgets('shows an empty state when no Kanji prompt is eligible', (
    tester,
  ) async {
    final repository = _MemoryQuizRepository((_) async => [
      const VocabularyQuizEntry(
        id: '17745f5e-9f28-59ac-8e19-6935ae77363b',
        jlptLevel: 'N5',
        contentVersion: 1,
        expression: 'かな',
        reading: 'かな',
        meaningVi: 'kana',
        isActive: true,
      ),
    ]);
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-empty')), findsOneWidget);
  });

  testWidgets('shows insufficient content when fewer than four readings exist', (
    tester,
  ) async {
    final repository = _MemoryQuizRepository((_) async => [
      _entries[0],
      _entries[1],
      _entries[2],
      const VocabularyQuizEntry(
        id: 'b1f64e62-8d5b-4b4a-a4d4-77f7e16d3d61',
        jlptLevel: 'N5',
        contentVersion: 1,
        expression: '友達',
        reading: 'がくせい',
        meaningVi: 'bạn bè',
        isActive: true,
      ),
    ]);
    await _mount(tester, repository);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-insufficient')), findsOneWidget);
  });

  testWidgets('keeps the quiz usable at 320px and 200 percent text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = _MemoryQuizRepository((_) async => _entries);
    await _mount(tester, repository, size: const Size(320, 640));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-question-expression')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
