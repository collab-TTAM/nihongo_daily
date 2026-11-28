// Synthetic grammar/source ports only; no content ownership or hosted proof.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/curriculum/application/curriculum_provider.dart';
import 'package:nihongo_daily/features/quiz/application/grammar_quiz_provider.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';

import '../curriculum/curriculum_widget_test.dart';
import 'grammar_quiz_test.dart' show sample;

List<CurriculumEntry> source(PreviewLevel level, [int count = 4]) => [
  for (var i = 0; i < count; i++) sample(i, level: level),
];

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

const feedbackTitle = 'Cách dùng và ví dụ theo bài gốc';

List<CurriculumEntry> contextSource(PreviewLevel level) => [
  for (final entry in source(level))
    CurriculumEntry(
      id: entry.id,
      kind: entry.kind,
      level: entry.level,
      contentVersion: entry.contentVersion,
      heading: entry.heading,
      caption: entry.caption,
      reading: entry.reading,
      meaningVi: entry.meaningVi,
      explanationVi: entry.explanationVi,
      hasAudioReference: entry.hasAudioReference,
      notes: ['TEST ONLY note ${entry.id}'],
      mistakes: ['TEST ONLY mistake ${entry.id}'],
      examples: [
        for (var i = 0; i < 2; i++)
          CurriculumExample(
            japanese: 'TEST ONLY 日本語 ${entry.id} $i',
            reading: 'TEST ONLY よみ ${entry.id} $i',
            vietnamese: 'TEST ONLY Việt ${entry.id} $i',
          ),
      ],
    ),
];

Future<void> finishGrammar(
  WidgetTester tester,
  List<int> ids, {
  Set<int> wrong = const {},
}) async {
  for (final id in ids) {
    final choice = wrong.contains(id) ? id + 1 : id;
    await tap(tester, find.byKey(ValueKey('grammar-choice-grammar-$choice')));
    await tap(tester, find.byKey(const Key('grammar-quiz-next')));
  }
}

void main() {
  for (final narrow in [false, true]) {
    testWidgets(
      'grammar mistake summary preserves accepted choices narrow=$narrow',
      (tester) async {
        if (narrow) {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        var reads = 0;
        final entries = [
          for (final entry in source(PreviewLevel.n5))
            CurriculumEntry(
              id: entry.id,
              kind: entry.kind,
              level: entry.level,
              contentVersion: entry.contentVersion,
              heading: entry.heading,
              caption: entry.caption,
              reading: entry.reading,
              meaningVi: entry.meaningVi,
              explanationVi: 'TEST ONLY explanation ${entry.id}',
              hasAudioReference: false,
              notes: const [],
              mistakes: const [],
              examples: const [],
            ),
        ];
        await mountCurriculum(
          tester,
          FixtureCurriculumRepository((_, level) async {
            reads++;
            return entries;
          }),
          '/quiz/grammar',
          size: narrow ? const Size(320, 900) : const Size(1200, 900),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Bạn đã chọn:'), findsNothing);
        await finishGrammar(tester, [0, 1, 2, 3], wrong: {0, 2});
        expect(find.text('Kết quả theo bài gốc: 2 / 4'), findsOneWidget);
        for (final id in [0, 2]) {
          expect(
            find.text('Bạn đã chọn: ${entries[id + 1].meaningVi}'),
            findsOneWidget,
          );
          expect(
            find.text('Ôn lại theo bài gốc: ${entries[id].meaningVi}'),
            findsOneWidget,
          );
          expect(find.text(entries[id].explanationVi), findsOneWidget);
        }
        expect(find.textContaining('Bạn đã chọn:'), findsNWidgets(2));
        expect(find.text(entries[1].explanationVi), findsNothing);
        await tap(tester, find.byKey(const Key('grammar-review-errors')));
        expect(find.textContaining('Bạn đã chọn:'), findsNothing);
        // Correction answers belong only to the new subset; original score is fixed.
        await finishGrammar(tester, [0, 2], wrong: {2});
        expect(find.text('Bộ gốc: 2 / 4'), findsOneWidget);
        expect(find.text('Kết quả theo bài gốc: 1 / 2'), findsOneWidget);
        expect(find.textContaining('Bạn đã chọn:'), findsOneWidget);
        expect(
          find.text('Bạn đã chọn: ${entries[3].meaningVi}'),
          findsOneWidget,
        );
        expect(
          find.text('Ôn lại theo bài gốc: ${entries[0].meaningVi}'),
          findsNothing,
        );
        await tap(tester, find.byKey(const Key('grammar-review-original')));
        expect(find.textContaining('Bạn đã chọn:'), findsNothing);
        expect(find.text('Câu 1 / 4'), findsOneWidget);
        expect(reads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('grammar focused review keeps original score and batch offset', (
    tester,
  ) async {
    var reads = 0;
    await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, level) async {
        reads++;
        return source(level, 11);
      }),
      '/quiz/grammar',
    );
    await tester.pumpAndSettle();
    await finishGrammar(tester, List.generate(10, (i) => i), wrong: {0, 2});
    expect(find.text('Kết quả theo bài gốc: 8 / 10'), findsOneWidget);
    final focus = find.byKey(const Key('grammar-review-errors'));
    final staleFocus = tester.widget<OutlinedButton>(focus).onPressed!;
    final staleBatch = tester
        .widget<OutlinedButton>(find.byKey(const Key('grammar-quiz-batch')))
        .onPressed!;
    await tap(tester, focus);
    staleFocus();
    staleBatch();
    await tester.pumpAndSettle();
    expect(find.text('Bộ gốc: 8 / 10'), findsOneWidget);
    expect(find.text('Câu 1 / 2'), findsOneWidget);
    final oldAnswer = tester
        .widget<OutlinedButton>(
          find.byKey(const ValueKey('grammar-choice-grammar-0')),
        )
        .onPressed!;
    await finishGrammar(tester, [0, 2]);
    expect(find.text('Kết quả theo bài gốc: 2 / 2'), findsOneWidget);
    expect(find.byKey(const Key('grammar-review-errors')), findsNothing);
    final repeat = find.byKey(const Key('grammar-quiz-restart'));
    final staleRepeat = tester.widget<OutlinedButton>(repeat).onPressed!;
    await tap(tester, repeat);
    oldAnswer();
    staleRepeat();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('grammar-quiz-next')))
          .onPressed,
      isNull,
    );
    expect(find.text('Bộ gốc: 8 / 10'), findsOneWidget);
    await finishGrammar(tester, [0, 2]);
    await tap(tester, find.byKey(const Key('grammar-quiz-batch')));
    expect(find.text('Câu 1 / 1'), findsOneWidget);
    expect(find.text('TEST ONLY pattern 10'), findsOneWidget);
    expect(find.textContaining('Bộ gốc:'), findsNothing);
    expect(reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'grammar focused restart restores whole original batch and perfect hides review',
    (tester) async {
      await mountCurriculum(
        tester,
        FixtureCurriculumRepository((_, level) async => source(level)),
        '/quiz/grammar',
      );
      await tester.pumpAndSettle();
      await finishGrammar(tester, [0, 1, 2, 3], wrong: {0});
      await tap(tester, find.byKey(const Key('grammar-review-errors')));
      expect(find.text('Câu 1 / 1'), findsOneWidget);
      final oldAnswer = tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('grammar-choice-grammar-0')),
          )
          .onPressed!;
      final original = find.byKey(const Key('grammar-review-original'));
      final oldOriginal = tester.widget<OutlinedButton>(original).onPressed!;
      await tap(tester, original);
      oldAnswer();
      oldOriginal();
      await tester.pumpAndSettle();
      expect(find.text('Câu 1 / 4'), findsOneWidget);
      expect(find.textContaining('Bộ gốc:'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('grammar-quiz-next')))
            .onPressed,
        isNull,
      );
      await finishGrammar(tester, [0, 1, 2, 3]);
      expect(find.text('Kết quả theo bài gốc: 4 / 4'), findsOneWidget);
      expect(find.byKey(const Key('grammar-review-errors')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'grammar focused callbacks retire on reload level and route exit',
    (tester) async {
      var reads = 0;
      final container = await mountCurriculum(
        tester,
        FixtureCurriculumRepository((_, level) async {
          reads++;
          return source(level);
        }),
        '/quiz/grammar',
      );
      await tester.pumpAndSettle();
      await finishGrammar(tester, [0, 1, 2, 3], wrong: {0});
      final staleFocus = tester
          .widget<OutlinedButton>(
            find.byKey(const Key('grammar-review-errors')),
          )
          .onPressed!;
      await tap(tester, find.byKey(const Key('grammar-review-errors')));
      final oldOriginal = tester
          .widget<OutlinedButton>(
            find.byKey(const Key('grammar-review-original')),
          )
          .onPressed!;
      final oldAnswer = tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('grammar-choice-grammar-0')),
          )
          .onPressed!;
      final reload = tester
          .widget<OutlinedButton>(find.byKey(const Key('grammar-quiz-reload')))
          .onPressed!;
      reload();
      oldAnswer();
      oldOriginal();
      await tester.pumpAndSettle();
      expect(find.textContaining('Bộ gốc:'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('grammar-quiz-next')))
            .onPressed,
        isNull,
      );
      container.read(previewLevelProvider.notifier).state = PreviewLevel.n4;
      staleFocus();
      oldOriginal();
      await tester.pumpAndSettle();
      expect(find.text('Câu 1 / 4'), findsOneWidget);
      expect(find.byKey(const Key('grammar-review-original')), findsNothing);
      final beforeExit = reads;
      container.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
      staleFocus();
      oldAnswer();
      oldOriginal();
      await tester.pumpAndSettle();
      expect(reads, beforeExit);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('grammar focused review controls usable at narrow large text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, level) async => source(level)),
      '/quiz/grammar',
      size: const Size(320, 900),
    );
    await tester.pumpAndSettle();
    await finishGrammar(tester, [0, 1, 2, 3], wrong: {0});
    await tap(tester, find.byKey(const Key('grammar-review-errors')));
    expect(find.text('Bộ gốc: 3 / 4'), findsOneWidget);
    await finishGrammar(tester, [0]);
    expect(find.text('Kết quả theo bài gốc: 1 / 1'), findsOneWidget);
    await tap(tester, find.byKey(const Key('grammar-quiz-restart')));
    await tap(tester, find.byKey(const Key('grammar-review-original')));
    expect(find.text('Câu 1 / 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grammar source feedback follows the answered target only', (
    tester,
  ) async {
    var reads = 0;
    await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, level) async {
        reads++;
        return contextSource(level);
      }),
      '/quiz/grammar',
    );
    await tester.pumpAndSettle();
    expect(find.text(feedbackTitle), findsNothing);
    expect(find.text('TEST ONLY note grammar-0'), findsNothing);
    await tap(tester, find.byKey(const ValueKey('grammar-choice-grammar-1')));
    expect(find.text('Chưa đúng theo bài gốc.'), findsOneWidget);
    expect(find.text('TEST ONLY note grammar-0'), findsNothing);
    await tap(tester, find.text(feedbackTitle));
    expect(find.text('TEST ONLY note grammar-0'), findsOneWidget);
    expect(find.text('TEST ONLY mistake grammar-0'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      expect(find.text('TEST ONLY 日本語 grammar-0 $i'), findsOneWidget);
      expect(find.text('TEST ONLY よみ grammar-0 $i'), findsOneWidget);
      expect(find.text('TEST ONLY Việt grammar-0 $i'), findsOneWidget);
    }
    expect(find.text('TEST ONLY note grammar-1'), findsNothing);
    await tap(tester, find.byKey(const Key('grammar-quiz-next')));
    expect(find.text(feedbackTitle), findsNothing);
    expect(find.text('TEST ONLY note grammar-0'), findsNothing);
    await tap(tester, find.byKey(const ValueKey('grammar-choice-grammar-1')));
    expect(find.text('Đúng theo bài gốc.'), findsOneWidget);
    expect(find.text('TEST ONLY note grammar-1'), findsNothing);
    await tap(tester, find.text(feedbackTitle));
    expect(find.text('TEST ONLY note grammar-1'), findsOneWidget);
    expect(find.text('TEST ONLY note grammar-0'), findsNothing);
    expect(reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grammar feedback marks missing examples and clears on reload', (
    tester,
  ) async {
    var reads = 0;
    await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, level) async {
        reads++;
        return source(level);
      }),
      '/quiz/grammar',
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('grammar-choice-grammar-0')));
    await tap(tester, find.text(feedbackTitle));
    expect(find.text('Bài gốc chưa có ví dụ.'), findsOneWidget);
    expect(find.text('Cách dùng'), findsNothing);
    expect(find.text('Lỗi thường gặp'), findsNothing);
    expect(reads, 1);
    await tap(tester, find.byKey(const Key('grammar-quiz-reload')));
    expect(find.text(feedbackTitle), findsNothing);
    expect(find.text('Bài gốc chưa có ví dụ.'), findsNothing);
    expect(reads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grammar feedback expands at 320px and 200 percent text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var reads = 0;
    await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, level) async {
        reads++;
        return contextSource(level);
      }),
      '/quiz/grammar',
      size: const Size(320, 900),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('grammar-choice-grammar-0')));
    await tap(tester, find.text(feedbackTitle));
    expect(find.text('TEST ONLY note grammar-0'), findsOneWidget);
    expect(find.text('TEST ONLY よみ grammar-0 1'), findsOneWidget);
    expect(find.text('TEST ONLY Việt grammar-0 1'), findsOneWidget);
    await tap(tester, find.byKey(const Key('grammar-quiz-next')));
    expect(find.text('Câu 2 / 4'), findsOneWidget);
    expect(find.text('TEST ONLY note grammar-0'), findsNothing);
    expect(reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grammar route scores first answers and batches without reads', (
    tester,
  ) async {
    var reads = 0;
    final container = await mountCurriculum(
      tester,
      FixtureCurriculumRepository((kind, level) async {
        expect(kind, CurriculumKind.grammar);
        reads++;
        return source(level, 11);
      }),
      '/quiz/grammar',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('grammar-quiz-next')))
          .onPressed,
      isNull,
    );
    VoidCallback? oldAnswer;
    VoidCallback? oldNext;
    for (var i = 0; i < 10; i++) {
      final choice = find.byKey(
        ValueKey('grammar-choice-grammar-${i == 0 ? 1 : i}'),
      );
      final callback = tester.widget<OutlinedButton>(choice).onPressed!;
      oldAnswer ??= callback;
      await tap(tester, choice);
      callback();
      final next = find.byKey(const Key('grammar-quiz-next'));
      final advance = tester.widget<FilledButton>(next).onPressed!;
      oldNext ??= advance;
      await tap(tester, next);
      advance();
      await tester.pumpAndSettle();
    }
    expect(find.text('Kết quả theo bài gốc: 9 / 10'), findsOneWidget);
    expect(
      find.text('Ôn lại theo bài gốc: TEST ONLY meaning 0'),
      findsOneWidget,
    );
    await tap(tester, find.byKey(const Key('grammar-quiz-restart')));
    oldAnswer!();
    oldNext!();
    await tester.pumpAndSettle();
    expect(find.text('Câu 1 / 10'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('grammar-quiz-next')))
          .onPressed,
      isNull,
    );
    for (var i = 0; i < 10; i++) {
      await tap(tester, find.byKey(ValueKey('grammar-choice-grammar-$i')));
      await tap(tester, find.byKey(const Key('grammar-quiz-next')));
    }
    await tap(tester, find.byKey(const Key('grammar-quiz-batch')));
    expect(find.text('Câu 1 / 1'), findsOneWidget);
    expect(find.text('TEST ONLY pattern 10'), findsOneWidget);
    expect(reads, 1);
    expect(
      container.read(grammarQuizProvider(PreviewLevel.n5)).hasValue,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('grammar load error is safe and explicit reload handles empty', (
    tester,
  ) async {
    var calls = 0;
    await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, level) async {
        calls++;
        if (calls == 1) throw StateError('PRIVATE SOURCE PAYLOAD');
        return source(level, calls == 2 ? 3 : 4);
      }),
      '/quiz/grammar',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Không tải được ngữ pháp. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.textContaining('PRIVATE SOURCE'), findsNothing);
    await tap(tester, find.byKey(const Key('grammar-quiz-reload')));
    expect(
      find.text('Chưa đủ mẫu có nghĩa khác nhau để tạo bộ câu hỏi.'),
      findsOneWidget,
    );
    await tap(tester, find.byKey(const Key('grammar-quiz-reload')));
    expect(find.text('Câu 1 / 4'), findsOneWidget);
    expect(calls, 3);
    expect(tester.takeException(), isNull);
  });

  for (final lateError in [false, true]) {
    testWidgets(
      'old grammar level late completion stays inert error=$lateError',
      (tester) async {
        final held = Completer<List<CurriculumEntry>>();
        final container = await mountCurriculum(
          tester,
          FixtureCurriculumRepository((_, level) async {
            if (level == PreviewLevel.n5) return held.future;
            return source(level);
          }),
          '/quiz/grammar',
        );
        await tester.pump();
        expect(find.text('Đang tải ngữ pháp…'), findsOneWidget);
        container.read(previewLevelProvider.notifier).state = PreviewLevel.n4;
        await tester.pumpAndSettle();
        await tap(
          tester,
          find.byKey(const ValueKey('grammar-choice-grammar-0')),
        );
        expect(find.text('Đúng theo bài gốc.'), findsOneWidget);
        if (lateError) {
          held.completeError(StateError('PRIVATE LATE'));
        } else {
          held.complete(source(PreviewLevel.n5, 11));
        }
        await tester.pumpAndSettle();
        expect(find.text('Câu 1 / 4'), findsOneWidget);
        expect(find.text('Đúng theo bài gốc.'), findsOneWidget);
        expect(find.textContaining('PRIVATE LATE'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('grammar level ABA reload and disposed callbacks cannot answer', (
    tester,
  ) async {
    var reads = 0;
    final container = await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, level) async {
        reads++;
        return source(level);
      }),
      '/quiz/grammar',
    );
    await tester.pumpAndSettle();
    final choice = find.byKey(const ValueKey('grammar-choice-grammar-0'));
    final answer = tester.widget<OutlinedButton>(choice).onPressed!;
    final reload = tester
        .widget<OutlinedButton>(find.byKey(const Key('grammar-quiz-reload')))
        .onPressed!;
    container.read(previewLevelProvider.notifier).state = PreviewLevel.n4;
    container.read(previewLevelProvider.notifier).state = PreviewLevel.n5;
    answer();
    reload();
    await tester.pumpAndSettle();
    expect(find.text('Đúng theo bài gốc.'), findsNothing);
    final fresh = tester.widget<OutlinedButton>(choice).onPressed!;
    await tap(tester, find.byKey(const Key('grammar-quiz-reload')));
    fresh();
    await tester.pumpAndSettle();
    expect(find.text('Đúng theo bài gốc.'), findsNothing);
    final beforeExit = reads;
    final disposed = tester.widget<OutlinedButton>(choice).onPressed!;
    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    disposed();
    reload();
    await tester.pumpAndSettle();
    expect(reads, beforeExit);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quiz entry opens separate grammar route', (tester) async {
    var grammarReads = 0;
    await mountCurriculum(
      tester,
      FixtureCurriculumRepository((kind, level) async {
        if (kind == CurriculumKind.vocabulary) return [];
        grammarReads++;
        return source(level);
      }),
      '/quiz',
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Luyện quiz ngữ pháp'));
    expect(find.text('Quiz ngữ pháp'), findsOneWidget);
    expect(find.text('Câu 1 / 4'), findsOneWidget);
    expect(grammarReads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replaced grammar source retires old answer before a frame', (
    tester,
  ) async {
    final container = await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, level) async => source(level)),
      '/quiz/grammar',
    );
    await tester.pumpAndSettle();
    final answer = tester
        .widget<OutlinedButton>(
          find.byKey(const ValueKey('grammar-choice-grammar-0')),
        )
        .onPressed!;
    final held = Completer<List<CurriculumEntry>>();
    container.updateOverrides([
      curriculumRepositoryProvider.overrideWithValue(
        FixtureCurriculumRepository((_, _) => held.future),
      ),
    ]);
    answer();
    await tester.pump();
    expect(find.text('Đúng theo bài gốc.'), findsNothing);
    expect(find.text('Đang tải ngữ pháp…'), findsOneWidget);
    held.complete(source(PreviewLevel.n5));
    await tester.pumpAndSettle();
    answer();
    await tester.pumpAndSettle();
    expect(find.text('Đúng theo bài gốc.'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('grammar-quiz-next')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('grammar choices remain usable on narrow large text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, level) async => source(level)),
      '/quiz/grammar',
      size: const Size(320, 900),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('grammar-choice-grammar-0')));
    await tap(tester, find.byKey(const Key('grammar-quiz-next')));
    expect(find.text('Câu 2 / 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
