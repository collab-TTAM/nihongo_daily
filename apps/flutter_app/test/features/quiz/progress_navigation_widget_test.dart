import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/curriculum/application/curriculum_provider.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import 'vocabulary_quiz_widget_test.dart' show tapQuiz;

// A navigation visit must never request curriculum or manufacture saved results.
final class _UnreadCurriculum implements CurriculumRepository {
  int reads = 0;
  @override
  Future<List<CurriculumEntry>> load(
    CurriculumKind kind,
    PreviewLevel level,
  ) async {
    reads++;
    throw StateError('Navigation must not load curriculum');
  }
}

void main() {
  for (final narrow in [false, true]) {
    testWidgets('progress destinations remain separate narrow=$narrow', (
      tester,
    ) async {
      if (narrow) {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      final source = _UnreadCurriculum();
      final container = ProviderContainer(
        overrides: [curriculumRepositoryProvider.overrideWithValue(source)],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      });
      container.read(routerProvider).go('/progress');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: NihongoDailyApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(narrow ? 2 : 1)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      void unavailable() {
        expect(
          find.text('Tiến độ chưa khả dụng. Hãy mở tài khoản đã cấu hình.'),
          findsOneWidget,
        );
        expect(
          find.text('Từ vựng và ngữ pháp được thống kê riêng.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('quiz-progress-load')), findsNothing);
        expect(find.byKey(const Key('grammar-progress-load')), findsNothing);
        expect(find.byKey(const Key('quiz-progress-summary')), findsNothing);
        expect(find.byKey(const Key('grammar-progress-summary')), findsNothing);
        expect(source.reads, 0);
        expect(tester.takeException(), isNull);
      }

      final vocabulary = find.byKey(const Key('progress-vocabulary'));
      final grammar = find.byKey(const Key('progress-grammar'));
      unavailable();
      expect(tester.widget<OutlinedButton>(vocabulary).onPressed, isNull);
      await tapQuiz(tester, grammar);
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/quiz/grammar/progress',
      );
      expect(find.text('Tiến độ quiz ngữ pháp trên thiết bị'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(grammar).onPressed, isNull);
      unavailable();
      await tapQuiz(tester, vocabulary);
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/progress',
      );
      expect(find.text('Tiến độ luyện quiz trên thiết bị'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(vocabulary).onPressed, isNull);
      unavailable();
    });
  }
}
