import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/curriculum/data/bundled_curriculum_repository.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/quiz/application/vocabulary_quiz_provider.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz.dart';
import 'package:nihongo_daily/features/settings/application/preview_preferences.dart';

import '../curriculum/curriculum_widget_test.dart';
import '../daily_plan/daily_plan_widget_test.dart' show PlanOwner, PlanSource;
import '../srs/account_widget_test.dart' show Harness;

Future<void> tapQuiz(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  final originals = <PreviewLevel, List<CurriculumEntry>>{};
  setUpAll(() async {
    for (final level in PreviewLevel.values) {
      final file = File('../../data/${level.name}/vocabulary.json');
      originals[level] = decodeCurriculum(
        await file.readAsString(),
        CurriculumKind.vocabulary,
        level,
      );
    }
  });

  FixtureCurriculumRepository repository() => FixtureCurriculumRepository(
    (_, level) async => originals[level]!,
  );

  for (final level in PreviewLevel.values) {
    testWidgets('${level.name} answer result restart', (tester) async {
      final container = await mountCurriculum(tester, repository(), '/quiz');
      container.read(previewLevelProvider.notifier).state = level;
      await tester.pumpAndSettle();
      final questions = buildVocabularyQuiz(originals[level]!, level).take(10);
      for (final q in questions) {
        final choice = find.byKey(ValueKey('quiz-choice-${q.target.id}'));
        final staleAnswer = tester.widget<OutlinedButton>(choice).onPressed!;
        await tapQuiz(tester, choice);
        staleAnswer();
        expect(find.text('Đúng theo bài gốc.'), findsOneWidget);
        final next = find.byKey(const Key('quiz-next'));
        final staleNext = tester.widget<FilledButton>(next).onPressed!;
        await tapQuiz(tester, next);
        staleNext();
        await tester.pumpAndSettle();
      }
      expect(find.text('Kết quả bộ này: 10 / 10'), findsOneWidget);
      await tapQuiz(tester, find.text('Làm lại bộ này'));
      expect(find.text('Câu 1 / 10'), findsOneWidget);
      expect(find.byKey(const Key('quiz-feedback')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${level.name} 320px and 200 percent', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await mountCurriculum(
        tester,
        repository(),
        '/quiz',
        size: const Size(320, 640),
      );
      container.read(previewLevelProvider.notifier).state = level;
      await tester.pumpAndSettle();
      final question = buildVocabularyQuiz(originals[level]!, level).first;
      await tapQuiz(
        tester,
        find.byKey(ValueKey('quiz-choice-${question.target.id}')),
      );
      expect(find.text('Đúng theo bài gốc.'), findsOneWidget);
      await tapQuiz(tester, find.byKey(const Key('quiz-next')));
      expect(find.text('Câu 2 / 10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wrong feedback and next batch dedup', (tester) async {
    await mountCurriculum(tester, repository(), '/quiz');
    await tester.pumpAndSettle();
    final deck = buildVocabularyQuiz(
      originals[PreviewLevel.n5]!,
      PreviewLevel.n5,
    );
    for (var i = 0; i < 10; i++) {
      final q = deck[i];
      final choice = i == 0
          ? q.choices.firstWhere((e) => e.id != q.target.id)
          : q.target;
      await tapQuiz(
        tester,
        find.byKey(ValueKey('quiz-choice-${choice.id}')),
      );
      if (i == 0) {
        expect(find.text('Chưa đúng theo bài gốc.'), findsOneWidget);
        expect(find.text(q.target.meaningVi), findsOneWidget);
        expect(find.text(q.target.examples.first.japanese), findsOneWidget);
      }
      await tapQuiz(tester, find.byKey(const Key('quiz-next')));
    }
    expect(find.text('Kết quả bộ này: 9 / 10'), findsOneWidget);
    expect(find.text('Xem lại các từ trả lời sai'), findsOneWidget);
    expect(find.text(deck.first.target.heading), findsOneWidget);
    final button = find.widgetWithText(OutlinedButton, 'Bộ tiếp');
    final stale = tester.widget<OutlinedButton>(button).onPressed!;
    await tapQuiz(tester, button);
    stale();
    await tester.pumpAndSettle();
    expect(find.text(deck[10].target.heading), findsOneWidget);
    expect(find.text('Câu 1 / 10'), findsOneWidget);
    expect(find.byKey(const Key('quiz-feedback')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('redacted error retry insufficient', (tester) async {
    final held = Completer<List<CurriculumEntry>>();
    var calls = 0;
    await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, _) {
        return ++calls == 1 ? held.future : Future.value(<CurriculumEntry>[]);
      }),
      '/quiz',
    );
    await tester.pump();
    expect(find.text('Đang tải câu hỏi…'), findsOneWidget);
    held.completeError(StateError('PRIVATE QUIZ SOURCE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE QUIZ SOURCE'), findsNothing);
    await tapQuiz(tester, find.text('Thử tải câu hỏi'));
    expect(find.textContaining('Chưa đủ từ'), findsOneWidget);
    expect(find.byKey(const Key('quiz-next')), findsNothing);
    expect(calls, 2);
  });

  testWidgets('level change discards old answers', (tester) async {
    final container = await mountCurriculum(tester, repository(), '/quiz');
    await tester.pumpAndSettle();
    final q = buildVocabularyQuiz(originals[PreviewLevel.n5]!, PreviewLevel.n5);
    await tapQuiz(
      tester,
      find.byKey(ValueKey('quiz-choice-${q.first.target.id}')),
    );
    await tapQuiz(tester, find.byKey(const Key('quiz-level')));
    await tester.tap(find.text('N4').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-feedback')), findsNothing);
    expect(find.text('Câu 1 / 10'), findsOneWidget);
    container.read(previewLevelProvider.notifier).state = PreviewLevel.n5;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-feedback')), findsNothing);
    expect(find.text('Câu 1 / 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late old level cannot enter new quiz', (tester) async {
    final held = Completer<List<CurriculumEntry>>();
    addTearDown(() {
      if (!held.isCompleted) held.complete(originals[PreviewLevel.n5]!);
    });
    final container = await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, level) async {
        return level == PreviewLevel.n5
            ? held.future
            : originals[PreviewLevel.n4]!;
      }),
      '/quiz',
    );
    container.read(previewLevelProvider.notifier).state = PreviewLevel.n4;
    await tester.pumpAndSettle();
    final expected = buildVocabularyQuiz(
      originals[PreviewLevel.n4]!,
      PreviewLevel.n4,
    ).first.target.heading;
    held.complete(originals[PreviewLevel.n5]!);
    await tester.pumpAndSettle();
    expect(find.text(expected), findsOneWidget);
    expect(find.text('Câu 1 / 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh fences disposed choice action', (tester) async {
    final held = Completer<List<CurriculumEntry>>();
    addTearDown(() {
      if (!held.isCompleted) held.complete(originals[PreviewLevel.n5]!);
    });
    var calls = 0;
    final container = await mountCurriculum(
      tester,
      FixtureCurriculumRepository((_, _) async {
        return ++calls == 1 ? originals[PreviewLevel.n5]! : held.future;
      }),
      '/quiz',
    );
    await tester.pumpAndSettle();
    final q = buildVocabularyQuiz(originals[PreviewLevel.n5]!, PreviewLevel.n5);
    final choice = find.byKey(ValueKey('quiz-choice-${q.first.target.id}'));
    final stale = tester.widget<OutlinedButton>(choice).onPressed!;
    final loading = container.refresh(vocabularyQuizProvider(PreviewLevel.n5));
    expect(loading.isLoading, isTrue);
    await tester.pump();
    expect(find.byKey(const Key('quiz-prompt')), findsNothing);
    stale();
    held.complete(originals[PreviewLevel.n5]!);
    await tester.pumpAndSettle();
    expect(find.text('Câu 1 / 10'), findsOneWidget);
    expect(find.byKey(const Key('quiz-feedback')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route exit resets local quiz', (tester) async {
    final container = await mountCurriculum(tester, repository(), '/quiz');
    await tester.pumpAndSettle();
    final q = buildVocabularyQuiz(originals[PreviewLevel.n5]!, PreviewLevel.n5);
    await tapQuiz(
      tester,
      find.byKey(ValueKey('quiz-choice-${q.first.target.id}')),
    );
    container.read(routerProvider).go('/study');
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/quiz');
    await tester.pumpAndSettle();
    expect(find.text('Câu 1 / 10'), findsOneWidget);
    expect(find.byKey(const Key('quiz-feedback')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('actual bundled quiz retains owned exit', (tester) async {
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
    final provider = vocabularyQuizProvider(PreviewLevel.n5);
    final loaded = await tester.runAsync(() async {
      final listener = container.listen(provider, (_, _) {});
      try {
        final questions = await container.read(provider.future);
        return (listener, questions);
      } catch (_) {
        listener.close();
        rethrow;
      }
    });
    addTearDown(() => loaded?.$1.close());
    final questions = loaded!.$2;
    final router = container.read(routerProvider);
    router.go('/quiz');
    await tester.pumpAndSettle();
    await tapQuiz(
      tester,
      find.byKey(ValueKey('quiz-choice-${questions.first.target.id}')),
    );
    expect(find.text(questions.first.target.meaningVi), findsOneWidget);
    final before = tester.state(find.byKey(ObjectKey(questions)));
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
    expect(find.byKey(const Key('quiz-prompt')), findsNothing);
    final hidden = find.byKey(ObjectKey(questions), skipOffstage: false);
    expect(identical(tester.state(hidden), before), isTrue);
    owner.closing!.complete();
    expect(await closing, AppExitResponse.exit);
    expect(tester.takeException(), isNull);
  });

}
