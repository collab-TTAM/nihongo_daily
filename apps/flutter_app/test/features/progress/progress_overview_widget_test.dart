import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/navigation.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/auth/application/account_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/daily_plan_provider.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/quiz/application/grammar_quiz_history_provider.dart';
import 'package:nihongo_daily/features/quiz/application/quiz_history_provider.dart';
import 'package:nihongo_daily/features/quiz/application/quiz_report_v2_provider.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_history_repository.dart';
import 'package:nihongo_daily/features/quiz/data/quiz_report_v2_adapter.dart';
import 'package:nihongo_daily/features/quiz/data/quiz_report_v2_transport.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

import '../srs/account_fixtures.dart' as account;
import '../srs/account_widget_test.dart' show Harness;
import '../daily_plan/study_session_recovery_fixtures.dart' show studyPlan;
import '../quiz/quiz_journal_fixtures.dart' show quizReport;

// TEST ONLY Auth/RPC ports. No hosted learner or multi-device proof.
final class _ProgressSource implements DailyPlanRepositorySource {
  _ProgressSource(this.harness);

  final Harness harness;
  int planReads = 0;
  int dayReads = 0;
  Map<String, Object>? lastPlanParameters;
  Map<String, Object>? lastDayParameters;
  Future<Object?> Function(Map<String, Object>) planResponse = (_) async =>
      studyPlan(45);
  Future<Object?> Function() dayResponse = () async => {
    'date': '2026-10-20',
    'timezone': 'Asia/Tokyo',
  };

  @override
  DailyPlanRepository? createDailyPlanRepository() {
    final ready = harness.runtime.readyRuntime;
    if (ready == null) return null;
    return DailyPlanRepository(
      _ProgressGateway(
        this,
        () => identical(harness.runtime.readyRuntime, ready),
      ),
    );
  }
}

final class _ProgressGateway implements DailyPlanStudyDayGateway {
  _ProgressGateway(this.source, this.current);

  final _ProgressSource source;
  final bool Function() current;

  @override
  bool get isCurrent => current();

  @override
  Future<Object?> getDailyPlan(Map<String, Object> parameters) {
    source.planReads++;
    source.lastPlanParameters = parameters;
    return source.planResponse(parameters);
  }

  @override
  Future<Object?> getStudyDay(Map<String, Object> parameters) {
    source.dayReads++;
    source.lastDayParameters = parameters;
    return source.dayResponse();
  }
}

final class _VocabularyPorts
    implements VocabularyQuizHistorySource, VocabularyQuizAttemptStore {
  _VocabularyPorts(this.harness);

  final Harness harness;
  final operations = VocabularyQuizOperationDrain();
  List<OwnedVocabularyQuizAttempt> records = [];
  Completer<void>? readWait;
  bool failRead = false;
  int reads = 0;
  int writes = 0;

  @override
  VocabularyQuizHistoryRepository? createVocabularyQuizHistoryRepository() {
    final ready = harness.runtime.readyRuntime;
    if (ready == null) return null;
    return VocabularyQuizHistoryRepository(
      auth: harness.access,
      store: this,
      isReady: () => identical(harness.runtime.readyRuntime, ready),
      operations: operations,
    );
  }

  @override
  Future<List<OwnedVocabularyQuizAttempt>> list(String ownerId) async {
    reads++;
    await readWait?.future;
    if (failRead) throw StateError('PRIVATE VOCABULARY HISTORY');
    return records.where((record) => record.ownerId == ownerId).toList();
  }

  @override
  Future<OwnedVocabularyQuizAttempt> append(
    String ownerId,
    VocabularyQuizAttempt attempt,
  ) {
    writes++;
    return Future.error(StateError('Progress overview must never write'));
  }

  Future<void> close() async {
    if (readWait != null && !readWait!.isCompleted) readWait!.complete();
    await operations.revokeAndDrain();
  }
}

final class _GrammarPorts
    implements GrammarQuizHistorySource, GrammarQuizAttemptStore {
  _GrammarPorts(this.harness);

  final Harness harness;
  final operations = GrammarQuizOperationDrain();
  List<OwnedGrammarQuizAttempt> records = [];
  Completer<void>? readWait;
  bool failRead = false;
  int reads = 0;
  int writes = 0;

  @override
  GrammarQuizHistoryRepository? createGrammarQuizHistoryRepository() {
    final ready = harness.runtime.readyRuntime;
    if (ready == null) return null;
    return GrammarQuizHistoryRepository(
      auth: harness.access,
      store: this,
      isReady: () => identical(harness.runtime.readyRuntime, ready),
      operations: operations,
    );
  }

  @override
  Future<List<OwnedGrammarQuizAttempt>> list(String ownerId) async {
    reads++;
    await readWait?.future;
    if (failRead) throw StateError('PRIVATE GRAMMAR HISTORY');
    return records.where((record) => record.ownerId == ownerId).toList();
  }

  @override
  Future<OwnedGrammarQuizAttempt> append(
    String ownerId,
    GrammarQuizAttempt attempt,
  ) {
    writes++;
    return Future.error(StateError('Progress overview must never write'));
  }

  Future<void> close() async {
    if (readWait != null && !readWait!.isCompleted) readWait!.complete();
    await operations.revokeAndDrain();
  }
}

GrammarQuizAttempt _grammarReport(
  int id, {
  required GrammarQuizAttemptKind kind,
  bool correct = false,
  PreviewLevel level = PreviewLevel.n5,
}) {
  final tail = id.toString().padLeft(12, '0');
  const target = 'b6000000-0000-4000-8000-000000000001';
  const wrong = 'b6000000-0000-4000-8000-000000000002';
  return GrammarQuizAttempt.fromJson({
    'format_version': 1,
    'quiz_type': 'grammar_meaning',
    'practice_kind': kind.name,
    'event_id': 'b5000000-0000-4000-8000-$tail',
    'level': level.name.toUpperCase(),
    'completed_at': '2026-10-20T00:02:00.000Z',
    'answers': [
      {
        'item_id': target,
        'content_version': 1,
        'selected_id': correct ? target : wrong,
        'choices': [
          target,
          wrong,
          'b6000000-0000-4000-8000-000000000003',
          'b6000000-0000-4000-8000-000000000004',
        ],
      },
    ],
  });
}

Map<String, Object?> _serverQuizHistoryPage({bool correct = true}) {
  const eventId = '00000000-0000-4000-8000-000000000001';
  const targetId = '10000000-0000-4000-8000-000000000001';
  const choices = [
    targetId,
    '10000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000004',
  ];
  const completedAt = '2026-11-17T09:59:00Z';
  return {
    'items': [
      {
        'received_at': '2026-11-17T10:00:00.000000Z',
        'request': {
          'client_event_id': eventId,
          'quiz_type': 'vocabulary_reading',
          'practice_kind': null,
          'jlpt_level': 'N5',
          'completed_at': completedAt,
          'answers': [
            {
              'item_id': targetId,
              'content_version': 1,
              'selected_id': correct ? targetId : choices[1],
              'choices': choices,
              'choice_content_versions': [1, 1, 1, 1],
            },
          ],
        },
        'response': {
          'client_event_id': eventId,
          'quiz_type': 'vocabulary_reading',
          'practice_kind': null,
          'jlpt_level': 'N5',
          'completed_at': completedAt,
          'answer_count': 1,
          'correct_count': correct ? 1 : 0,
        },
      },
    ],
    'next_cursor': null,
  };
}

final class _ServerHistoryReader implements QuizReportV2HistoryReader {
  int reads = 0;
  QuizReportV2HistoryQuery? lastQuery;
  Map<String, Object?> response = _serverQuizHistoryPage();
  Completer<void>? readWait;
  bool failRead = false;

  @override
  Future<QuizReportV2HistoryPage> readHistory(
    QuizReportV2HistoryQuery query,
  ) async {
    reads++;
    lastQuery = query;
    await readWait?.future;
    if (failRead) throw StateError('PRIVATE SERVER HISTORY');
    return query.decodePage(response);
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  Harness harness,
  _ProgressSource source, {
  bool configured = true,
  _VocabularyPorts? vocabularyPorts,
  _GrammarPorts? grammarPorts,
  _ServerHistoryReader? serverHistoryReader,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (configured) accountRuntimeProvider.overrideWithValue(harness.runtime),
      if (configured) dailyPlanSourceProvider.overrideWithValue(source),
      if (configured && vocabularyPorts != null)
        quizHistorySourceProvider.overrideWithValue(vocabularyPorts),
      if (configured && grammarPorts != null)
        grammarQuizHistorySourceProvider.overrideWithValue(grammarPorts),
      if (configured && serverHistoryReader != null)
        quizReportV2HistoryReaderProvider.overrideWithValue(
          serverHistoryReader,
        ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await vocabularyPorts?.close();
    await grammarPorts?.close();
    await harness.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NihongoDailyApp(),
    ),
  );
  if (configured) harness.access.change(account.owner);
  await tester.pumpAndSettle();
  container.read(routerProvider).go('/overview');
  await tester.pumpAndSettle();
  return container;
}

Finder _todayButton() => find.descendant(
  of: find.byKey(const Key('progress-today')),
  matching: find.byType(OutlinedButton),
);

void main() {
  testWidgets('preview overview never fabricates a server plan', (
    tester,
  ) async {
    final harness = Harness();
    final source = _ProgressSource(harness);
    await _mount(tester, harness, source, configured: false);

    expect(find.text('Tiến độ học tập'), findsOneWidget);
    expect(find.text('Mở tài khoản'), findsOneWidget);
    expect(find.byKey(const Key('progress-date')), findsNothing);
    expect(find.byKey(const Key('progress-load-server-quiz')), findsNothing);
    expect(source.planReads, 0);
    expect(source.dayReads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile-local today and plan progress require explicit loads', (
    tester,
  ) async {
    final harness = Harness();
    final source = _ProgressSource(harness);
    await _mount(tester, harness, source);

    expect(source.planReads, 0);
    expect(source.dayReads, 0);
    await tester.ensureVisible(_todayButton());
    await tester.tap(_todayButton());
    await tester.pumpAndSettle();

    expect(source.dayReads, 1);
    expect(source.lastDayParameters, {'p_request': <String, Object>{}});
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('progress-date')))
          .controller!
          .text,
      '2026-10-20',
    );

    await tester.ensureVisible(find.byKey(const Key('progress-load')));
    await tester.tap(find.byKey(const Key('progress-load')));
    await tester.pumpAndSettle();

    expect(source.planReads, 1);
    expect(source.lastPlanParameters, {
      'p_request': {'date': '2026-10-20'},
    });
    expect(find.text('45/120 phút'), findsOneWidget);
    expect(find.byKey(const Key('progress-study-minutes')), findsOneWidget);
    expect(find.textContaining('SRS'), findsOneWidget);
    expect(destinationIndex('/overview'), 4);
    expect(destinationIndex('/progress'), 4);
  });

  testWidgets('safe plan error can be retried explicitly', (tester) async {
    final harness = Harness();
    final source = _ProgressSource(harness)
      ..planResponse = (_) async {
        throw const DailyPlanFailure(DailyPlanErrorCode.networkUnavailable);
      };
    await _mount(tester, harness, source);
    await tester.enterText(
      find.byKey(const Key('progress-date')),
      '2026-10-20',
    );
    await tester.tap(find.byKey(const Key('progress-load')));
    await tester.pumpAndSettle();

    expect(find.text('Không có kết nối mạng.'), findsOneWidget);
    expect(find.byKey(const Key('progress-study-minutes')), findsNothing);
    expect(source.planReads, 1);

    source.planResponse = (_) async => studyPlan(45);
    await tester.tap(find.byKey(const Key('progress-load')));
    await tester.pumpAndSettle();

    expect(source.planReads, 2);
    expect(find.text('45/120 phút'), findsOneWidget);
  });

  testWidgets('late plan response cannot publish after account replacement', (
    tester,
  ) async {
    final harness = Harness();
    final pending = Completer<Object?>();
    final source = _ProgressSource(harness)
      ..planResponse = (_) => pending.future;
    await _mount(tester, harness, source);

    await tester.enterText(
      find.byKey(const Key('progress-date')),
      '2026-10-20',
    );
    await tester.tap(find.byKey(const Key('progress-load')));
    await tester.pump();
    expect(find.text('Đang tải tiến độ…'), findsOneWidget);

    harness.access.change(account.other);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progress-study-minutes')), findsNothing);

    pending.complete(studyPlan(45));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progress-study-minutes')), findsNothing);
    expect(source.planReads, 1);
  });

  testWidgets(
    'overview loads separate local quiz totals with N5/N4 breakdown only on explicit action',
    (tester) async {
      final harness = Harness();
      final source = _ProgressSource(harness);
      final vocabulary = _VocabularyPorts(harness)
        ..records = [
          OwnedVocabularyQuizAttempt(
            account.owner,
            quizReport(1, correct: true),
          ),
          OwnedVocabularyQuizAttempt(account.owner, quizReport(2)),
          OwnedVocabularyQuizAttempt(
            account.owner,
            quizReport(3, correct: true, level: PreviewLevel.n4),
          ),
        ];
      final grammar = _GrammarPorts(harness)
        ..records = [
          OwnedGrammarQuizAttempt(
            account.owner,
            _grammarReport(
              1,
              kind: GrammarQuizAttemptKind.primary,
              correct: true,
            ),
          ),
          OwnedGrammarQuizAttempt(
            account.owner,
            _grammarReport(2, kind: GrammarQuizAttemptKind.correction),
          ),
          OwnedGrammarQuizAttempt(
            account.owner,
            _grammarReport(
              3,
              kind: GrammarQuizAttemptKind.primary,
              level: PreviewLevel.n4,
            ),
          ),
          OwnedGrammarQuizAttempt(
            account.owner,
            _grammarReport(
              4,
              kind: GrammarQuizAttemptKind.correction,
              correct: true,
              level: PreviewLevel.n4,
            ),
          ),
        ];
      await _mount(
        tester,
        harness,
        source,
        vocabularyPorts: vocabulary,
        grammarPorts: grammar,
      );

      expect(vocabulary.reads, 0);
      expect(grammar.reads, 0);
      await tester.ensureVisible(find.byKey(const Key('progress-load-quiz')));
      await tester.tap(find.byKey(const Key('progress-load-quiz')));
      await tester.pumpAndSettle();

      expect(vocabulary.reads, 1);
      expect(grammar.reads, 1);
      expect(
        find.text('Từ vựng (N5 + N4) · 3 lượt · 2/3 câu đúng'),
        findsOneWidget,
      );
      expect(
        find.text('N5 · 2 lượt · 1/2 câu đúng; N4 · 1 lượt · 1/1 câu đúng'),
        findsOneWidget,
      );
      expect(
        find.text('Ngữ pháp chính (N5 + N4) · 2 lượt · 1/2 câu đúng'),
        findsOneWidget,
      );
      expect(
        find.text('N5 · 1 lượt · 1/1 câu đúng; N4 · 1 lượt · 0/1 câu đúng'),
        findsOneWidget,
      );
      expect(
        find.text('Ngữ pháp sửa (N5 + N4) · 2 lượt · 1/2 câu đúng'),
        findsOneWidget,
      );
      expect(
        find.text('N5 · 1 lượt · 0/1 câu đúng; N4 · 1 lượt · 1/1 câu đúng'),
        findsOneWidget,
      );
      expect(vocabulary.writes, 0);
      expect(grammar.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overview quiz history error is redacted and can be retried', (
    tester,
  ) async {
    final harness = Harness();
    final source = _ProgressSource(harness);
    final vocabulary = _VocabularyPorts(harness)..failRead = true;
    final grammar = _GrammarPorts(harness);
    await _mount(
      tester,
      harness,
      source,
      vocabularyPorts: vocabulary,
      grammarPorts: grammar,
    );

    await tester.ensureVisible(find.byKey(const Key('progress-load-quiz')));
    await tester.tap(find.byKey(const Key('progress-load-quiz')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progress-quiz-error')), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(grammar.reads, 0);

    vocabulary.failRead = false;
    await tester.tap(find.byKey(const Key('progress-load-quiz')));
    await tester.pumpAndSettle();
    expect(vocabulary.reads, 2);
    expect(grammar.reads, 1);
    expect(find.byKey(const Key('progress-quiz-error')), findsNothing);
    expect(
      find.text('Ngữ pháp chính (N5 + N4) · 0 lượt · 0/0 câu đúng'),
      findsOneWidget,
    );
    expect(vocabulary.writes, 0);
    expect(grammar.writes, 0);
  });

  testWidgets('late quiz history cannot publish after account replacement', (
    tester,
  ) async {
    final harness = Harness();
    final source = _ProgressSource(harness);
    final vocabulary = _VocabularyPorts(harness)
      ..records = [
        OwnedVocabularyQuizAttempt(account.owner, quizReport(1, correct: true)),
      ]
      ..readWait = Completer<void>();
    final grammar = _GrammarPorts(harness);
    await _mount(
      tester,
      harness,
      source,
      vocabularyPorts: vocabulary,
      grammarPorts: grammar,
    );

    await tester.ensureVisible(find.byKey(const Key('progress-load-quiz')));
    await tester.tap(find.byKey(const Key('progress-load-quiz')));
    await tester.pump();
    expect(vocabulary.reads, 1);

    harness.access.change(account.other);
    await tester.pumpAndSettle();
    vocabulary.readWait!.complete();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('progress-quiz-vocabulary-summary')),
      findsNothing,
    );
    expect(find.textContaining('1 lượt'), findsNothing);
    expect(grammar.reads, 0);
    expect(vocabulary.writes, 0);
    expect(grammar.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'overview server quiz receipts are explicit and separate from local history',
    (tester) async {
      final harness = Harness();
      final source = _ProgressSource(harness);
      final reader = _ServerHistoryReader();
      final vocabulary = _VocabularyPorts(harness);
      final grammar = _GrammarPorts(harness);
      final container = await _mount(
        tester,
        harness,
        source,
        vocabularyPorts: vocabulary,
        grammarPorts: grammar,
        serverHistoryReader: reader,
      );

      expect(reader.reads, 0);
      expect(vocabulary.reads, 0);
      expect(grammar.reads, 0);
      await tester.ensureVisible(
        find.byKey(const Key('progress-load-server-quiz')),
      );
      await tester.tap(find.byKey(const Key('progress-load-server-quiz')));
      await tester.pumpAndSettle();

      expect(reader.reads, 1);
      expect(reader.lastQuery?.limit, 20);
      expect(reader.lastQuery?.jlptLevel, isNull);
      expect(reader.lastQuery?.quizType, isNull);
      expect(reader.lastQuery?.cursor, isNull);
      expect(
        find.text('1 biên nhận trên trang mới nhất · 1/1 câu đúng'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('progress-quiz-vocabulary-summary')),
        findsNothing,
      );
      expect(vocabulary.reads, 0);
      expect(grammar.reads, 0);
      expect(vocabulary.writes, 0);
      expect(grammar.writes, 0);
      expect(
        find.byKey(const Key('progress-open-server-quiz-history')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('progress-open-server-quiz-history')),
      );
      await tester.tap(
        find.byKey(const Key('progress-open-server-quiz-history')),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/quiz/history',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'server receipt read failure is redacted and manually retryable',
    (tester) async {
      final harness = Harness();
      final source = _ProgressSource(harness);
      final reader = _ServerHistoryReader()..failRead = true;
      await _mount(tester, harness, source, serverHistoryReader: reader);

      await tester.ensureVisible(
        find.byKey(const Key('progress-load-server-quiz')),
      );
      await tester.tap(find.byKey(const Key('progress-load-server-quiz')));
      await tester.pumpAndSettle();

      expect(reader.reads, 1);
      expect(
        find.byKey(const Key('progress-server-quiz-error')),
        findsOneWidget,
      );
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(
        find.byKey(const Key('progress-server-quiz-summary')),
        findsNothing,
      );

      reader.failRead = false;
      await tester.tap(find.byKey(const Key('progress-load-server-quiz')));
      await tester.pumpAndSettle();

      expect(reader.reads, 2);
      expect(find.byKey(const Key('progress-server-quiz-error')), findsNothing);
      expect(
        find.text('1 biên nhận trên trang mới nhất · 1/1 câu đúng'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'late server receipt page cannot publish after account replacement',
    (tester) async {
      final harness = Harness();
      final source = _ProgressSource(harness);
      final reader = _ServerHistoryReader()..readWait = Completer<void>();
      await _mount(tester, harness, source, serverHistoryReader: reader);

      await tester.ensureVisible(
        find.byKey(const Key('progress-load-server-quiz')),
      );
      await tester.tap(find.byKey(const Key('progress-load-server-quiz')));
      await tester.pump();
      expect(reader.reads, 1);
      expect(
        find.text('Đang đọc biên nhận quiz trên máy chủ…'),
        findsOneWidget,
      );

      harness.access.change(account.other);
      await tester.pumpAndSettle();
      reader.readWait!.complete();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('progress-server-quiz-summary')),
        findsNothing,
      );
      expect(
        find.textContaining('biên nhận trên trang mới nhất'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overview links keep vocabulary and grammar reports separate', (
    tester,
  ) async {
    final harness = Harness();
    final source = _ProgressSource(harness);
    final container = await _mount(tester, harness, source);

    await tester.ensureVisible(find.byKey(const Key('progress-vocabulary')));
    await tester.tap(find.byKey(const Key('progress-vocabulary')));
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/progress',
    );

    container.read(routerProvider).go('/overview');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('progress-grammar')));
    await tester.tap(find.byKey(const Key('progress-grammar')));
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/quiz/grammar/progress',
    );
  });
}
