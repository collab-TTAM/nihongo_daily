import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/quiz/application/quiz_report_v2_provider.dart';
import 'package:nihongo_daily/features/quiz/data/quiz_report_v2_adapter.dart';
import 'package:nihongo_daily/features/quiz/data/quiz_report_v2_transport.dart';

final _selectedReaderProvider =
    StateProvider<QuizReportV2HistoryReader?>((ref) => null);

String _uuid(int value) =>
    '00000000-0000-4000-8000-\${value.toString().padLeft(12, '0')}';

String _receivedAt(int value) =>
    '2026-11-16T10:00:\${value.toString().padLeft(2, '0')}.000000Z';

Map<String, Object?> _entry(
  int id, {
  String level = 'N5',
  String quizType = 'vocabulary_reading',
  bool correct = true,
}) {
  final eventId = _uuid(id);
  final itemId = _uuid(1000 + id);
  final choices = [
    itemId,
    _uuid(2000 + id),
    _uuid(3000 + id),
    _uuid(4000 + id),
  ];
  final completedAt = '2026-11-16T09:59:00Z';
  final practiceKind = quizType == 'grammar_meaning' ? 'primary' : null;
  final request = <String, Object?>{
    'client_event_id': eventId,
    'quiz_type': quizType,
    'practice_kind': practiceKind,
    'jlpt_level': level,
    'completed_at': completedAt,
    'answers': [
      {
        'item_id': itemId,
        'content_version': 1,
        'selected_id': correct ? itemId : choices[1],
        'choices': choices,
        'choice_content_versions': [1, 1, 1, 1],
      },
    ],
  };
  return {
    'received_at': _receivedAt(id),
    'request': request,
    'response': {
      'client_event_id': eventId,
      'quiz_type': quizType,
      'practice_kind': practiceKind,
      'jlpt_level': level,
      'completed_at': completedAt,
      'answer_count': 1,
      'correct_count': correct ? 1 : 0,
    },
  };
}

final class _FakeHistoryReader implements QuizReportV2HistoryReader {
  _FakeHistoryReader(this.records);

  final List<Map<String, Object?>> records;
  final queries = <QuizReportV2HistoryQuery>[];
  Completer<QuizReportV2HistoryPage>? wait;
  bool fail = false;

  @override
  Future<QuizReportV2HistoryPage> readHistory(
    QuizReportV2HistoryQuery query,
  ) async {
    queries.add(query);
    final pending = wait;
    if (pending != null) return pending.future;
    if (fail) throw StateError('PRIVATE_SERVER_DETAIL');
    return pageFor(query);
  }

  QuizReportV2HistoryPage pageFor(QuizReportV2HistoryQuery query) {
    final filtered = records.where((record) {
      final request = record['request']! as Map<String, Object?>;
      final receivedAt = record['received_at']! as String;
      final eventId = request['client_event_id']! as String;
      final levelMatches =
          query.jlptLevel == null || request['jlpt_level'] == query.jlptLevel;
      final typeMatches =
          query.quizType == null || request['quiz_type'] == query.quizType;
      final cursor = query.cursor;
      final cursorMatches =
          cursor == null ||
          receivedAt.compareTo(cursor.receivedAt) < 0 ||
          (receivedAt == cursor.receivedAt &&
              eventId.compareTo(cursor.clientEventId) < 0);
      return levelMatches && typeMatches && cursorMatches;
    }).toList()..sort(
      (left, right) => (right['received_at']! as String).compareTo(
        left['received_at']! as String,
      ),
    );
    final items = filtered.take(query.limit).toList(growable: false);
    Map<String, Object?>? nextCursor;
    if (filtered.length > items.length && items.isNotEmpty) {
      final last = items.last;
      final request = last['request']! as Map<String, Object?>;
      nextCursor = {
        'received_at': last['received_at'],
        'client_event_id': request['client_event_id'],
      };
    }
    return query.decodePage({'items': items, 'next_cursor': nextCursor});
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _FakeHistoryReader reader,
) async {
  final container = ProviderContainer(
    overrides: [
      quizReportV2HistoryReaderProvider.overrideWith(
        (ref) => ref.watch(_selectedReaderProvider),
      ),
    ],
  );
  container.read(_selectedReaderProvider.notifier).state = reader;
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
  container.read(routerProvider).go('/quiz/history');
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final button = find.byKey(Key(key));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _select(
  WidgetTester tester,
  String key,
  String label,
) async {
  final selector = find.byKey(Key(key));
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'server history filters and keyset pages use only the server cursor',
    (tester) async {
      final records = [
        for (var id = 1; id <= 22; id++)
          _entry(
            id,
            level: id.isEven ? 'N4' : 'N5',
            quizType: id % 3 == 0
                ? 'grammar_meaning'
                : 'vocabulary_reading',
            correct: id.isOdd,
          ),
      ];
      final reader = _FakeHistoryReader(records);
      await _mount(tester, reader);

      await _tap(tester, 'server-quiz-history-load');
      expect(reader.queries, hasLength(1));
      expect(reader.queries.first.jlptLevel, isNull);
      expect(reader.queries.first.quizType, isNull);
      expect(find.text('20 kết quả trên trang 1'), findsOneWidget);
      expect(
        find.byKey(ValueKey('server-quiz-history-\${_uuid(22)}')),
        findsOneWidget,
      );

      await _tap(tester, 'server-quiz-history-older');
      expect(reader.queries, hasLength(2));
      expect(reader.queries.last.cursor?.receivedAt, _receivedAt(3));
      expect(find.text('2 kết quả trên trang 2'), findsOneWidget);
      expect(
        find.byKey(ValueKey('server-quiz-history-\${_uuid(2)}')),
        findsOneWidget,
      );

      await _tap(tester, 'server-quiz-history-newer');
      expect(reader.queries.last.cursor, isNull);
      expect(find.text('20 kết quả trên trang 1'), findsOneWidget);

      await _select(tester, 'server-quiz-history-level', 'N4');
      await _select(tester, 'server-quiz-history-type', 'Ngữ pháp');
      expect(reader.queries.last.jlptLevel, 'N4');
      expect(reader.queries.last.quizType, 'grammar_meaning');
      expect(reader.queries.last.cursor, isNull);
      expect(find.text('3 kết quả trên trang 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('server history errors are redacted and empty state retries', (
    tester,
  ) async {
    final reader = _FakeHistoryReader([])..fail = true;
    await _mount(tester, reader);

    await _tap(tester, 'server-quiz-history-load');
    expect(find.byKey(const Key('server-quiz-history-error')), findsOneWidget);
    expect(find.textContaining('PRIVATE_SERVER_DETAIL'), findsNothing);

    reader.fail = false;
    await _tap(tester, 'server-quiz-history-retry');
    expect(find.byKey(const Key('server-quiz-history-empty')), findsOneWidget);
    expect(find.text('0 kết quả trên trang 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late page is discarded after the caller replaces the reader', (
    tester,
  ) async {
    final first = _FakeHistoryReader([_entry(22)])
      ..wait = Completer<QuizReportV2HistoryPage>();
    final replacement = _FakeHistoryReader([_entry(1)]);
    final container = await _mount(tester, first);

    await _tap(tester, 'server-quiz-history-load');
    expect(first.queries, hasLength(1));
    container.read(_selectedReaderProvider.notifier).state = null;
    await tester.pumpAndSettle();

    first.wait!.complete(first.pageFor(first.queries.single));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('server-quiz-history-\${_uuid(22)}')),
      findsNothing,
    );

    container.read(_selectedReaderProvider.notifier).state = replacement;
    await tester.pumpAndSettle();
    await _tap(tester, 'server-quiz-history-load');
    expect(
      find.byKey(ValueKey('server-quiz-history-\${_uuid(1)}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('server-quiz-history-\${_uuid(22)}')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
