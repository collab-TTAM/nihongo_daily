import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/data/quiz_report_v2_adapter.dart';
import 'package:nihongo_daily/features/quiz/data/quiz_report_v2_transport.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/presentation/quiz_report_v2_action.dart';

String _id(int value) =>
    'a2000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

String _event(int value) =>
    'a3000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

QuizReportV2Request _report() => QuizReportV2Request.fromVocabularyAttempt(
  VocabularyQuizAttempt.fromJson({
    'format_version': 2,
    'event_id': _event(1),
    'level': 'N5',
    'completed_at': '2026-11-14T20:00:00.000Z',
    'answers': [
      {
        'item_id': _id(1),
        'content_version': 1,
        'selected_id': _id(1),
        'choices': [_id(1), _id(2), _id(3), _id(4)],
        'choice_content_versions': [1, 1, 1, 1],
      },
    ],
  }),
);

Map<String, Object?> _response(QuizReportV2Request report) => {
  'client_event_id': report.clientEventId,
  'quiz_type': report.quizType,
  'practice_kind': report.practiceKind,
  'jlpt_level': report.jlptLevel,
  'completed_at': report.completedAt,
  'answer_count': report.answers.length,
  'correct_count': report.answers.where((answer) => answer.isCorrect).length,
};

final class _Submitter implements QuizReportV2Submitter {
  final submissions = <QuizReportV2Request>[];
  final lookups = <QuizReportV2Request>[];
  Future<QuizReportV2Response> Function(QuizReportV2Request)? onSubmit;
  Future<QuizReportV2LookupResult> Function(QuizReportV2Request)? onLookup;

  @override
  Future<QuizReportV2Response> submit(QuizReportV2Request request) {
    submissions.add(request);
    final handler = onSubmit;
    return handler == null
        ? Future.value(request.decodeResponse(_response(request)))
        : handler(request);
  }

  @override
  Future<QuizReportV2LookupResult> lookupReceipt(
    QuizReportV2Request request,
  ) {
    lookups.add(request);
    final handler = onLookup;
    return handler == null
        ? Future.value(
            request.decodeLookupResponse({
              'status': 'unresolved',
              'client_event_id': request.clientEventId,
            }),
          )
        : handler(request);
  }
}

Widget _host({
  required QuizReportV2Request request,
  required _Submitter submitter,
  required bool Function() isCurrent,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: QuizReportV2Action(
        request: request,
        submitter: submitter,
        isCurrent: isCurrent,
      ),
    ),
  ),
);

void main() {
  testWidgets('server report dispatch requires an explicit learner tap', (
    tester,
  ) async {
    final request = _report();
    final submitter = _Submitter();
    await tester.pumpWidget(
      _host(request: request, submitter: submitter, isCurrent: () => true),
    );

    expect(submitter.submissions, isEmpty);
    expect(submitter.lookups, isEmpty);
    expect(find.byKey(const Key('quiz-report-confirmed')), findsNothing);

    await tester.tap(find.byKey(const Key('quiz-report-submit')));
    await tester.pumpAndSettle();

    expect(submitter.submissions, hasLength(1));
    expect(identical(submitter.submissions.single, request), isTrue);
    expect(submitter.lookups, isEmpty);
    expect(find.byKey(const Key('quiz-report-confirmed')), findsOneWidget);
    expect(find.byKey(const Key('quiz-report-saved')), findsNothing);
    expect(
      find.textContaining('không tự xác định mức ghi nhớ'),
      findsOneWidget,
    );
  });

  testWidgets(
    'uncertain submit exposes only replay lookup and never resubmits',
    (tester) async {
      final request = _report();
      final submitter = _Submitter()
        ..onSubmit = (_) async {
          throw const QuizReportV2TransportFailure(
            QuizReportV2TransportCode.networkUnavailable,
          );
        };
      var lookups = 0;
      submitter.onLookup = (original) async {
        lookups++;
        if (lookups == 1) {
          return original.decodeLookupResponse({
            'status': 'unresolved',
            'client_event_id': original.clientEventId,
          });
        }
        return original.decodeLookupResponse({
          'status': 'found',
          'response': _response(original),
        });
      };
      await tester.pumpWidget(
        _host(request: request, submitter: submitter, isCurrent: () => true),
      );

      await tester.tap(find.byKey(const Key('quiz-report-submit')));
      await tester.pumpAndSettle();
      expect(submitter.submissions, hasLength(1));
      expect(find.byKey(const Key('quiz-report-lookup')), findsOneWidget);
      expect(find.byKey(const Key('quiz-report-submit')), findsNothing);
      expect(find.byKey(const Key('quiz-report-retry')), findsNothing);

      await tester.tap(find.byKey(const Key('quiz-report-lookup')));
      await tester.pumpAndSettle();
      expect(submitter.lookups, hasLength(1));
      expect(identical(submitter.lookups.single, request), isTrue);
      expect(submitter.submissions, hasLength(1));
      expect(find.byKey(const Key('quiz-report-unresolved')), findsOneWidget);
      expect(find.byKey(const Key('quiz-report-lookup')), findsOneWidget);

      await tester.tap(find.byKey(const Key('quiz-report-lookup')));
      await tester.pumpAndSettle();
      expect(submitter.lookups, hasLength(2));
      expect(submitter.submissions, hasLength(1));
      expect(find.byKey(const Key('quiz-report-confirmed')), findsOneWidget);
      expect(find.byKey(const Key('quiz-report-lookup')), findsNothing);
    },
  );

  testWidgets('rate limit retry is explicit and reuses the same event', (
    tester,
  ) async {
    final request = _report();
    final submitter = _Submitter()
      ..onSubmit = (_) async {
        throw const QuizReportV2TransportFailure(
          QuizReportV2TransportCode.rateLimited,
        );
      };
    await tester.pumpWidget(
      _host(request: request, submitter: submitter, isCurrent: () => true),
    );

    await tester.tap(find.byKey(const Key('quiz-report-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz-report-retry')), findsOneWidget);
    expect(find.byKey(const Key('quiz-report-lookup')), findsNothing);

    submitter.onSubmit = (original) async =>
        original.decodeResponse(_response(original));
    await tester.tap(find.byKey(const Key('quiz-report-retry')));
    await tester.pumpAndSettle();

    expect(submitter.submissions, hasLength(2));
    expect(identical(submitter.submissions.first, request), isTrue);
    expect(identical(submitter.submissions.last, request), isTrue);
    expect(find.byKey(const Key('quiz-report-confirmed')), findsOneWidget);
  });

  testWidgets('late account change suppresses a completed report response', (
    tester,
  ) async {
    final request = _report();
    final submitter = _Submitter();
    final gate = Completer<QuizReportV2Response>();
    submitter.onSubmit = (_) => gate.future;
    var current = true;
    await tester.pumpWidget(
      _host(request: request, submitter: submitter, isCurrent: () => current),
    );

    await tester.tap(find.byKey(const Key('quiz-report-submit')));
    await tester.pump();
    expect(submitter.submissions, hasLength(1));
    current = false;
    gate.complete(request.decodeResponse(_response(request)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quiz-report-confirmed')), findsNothing);
    expect(find.byKey(const Key('quiz-report-submit-error')), findsNothing);
    expect(find.byKey(const Key('quiz-report-lookup')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit report action fits narrow layout at double text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final request = _report();
    final submitter = _Submitter();
    await tester.pumpWidget(
      _host(request: request, submitter: submitter, isCurrent: () => true),
    );
    await tester.tap(find.byKey(const Key('quiz-report-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quiz-report-confirmed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
