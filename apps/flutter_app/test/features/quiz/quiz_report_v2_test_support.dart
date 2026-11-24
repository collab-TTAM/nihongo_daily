import 'package:nihongo_daily/features/quiz/data/quiz_report_v2_adapter.dart';
import 'package:nihongo_daily/features/quiz/data/quiz_report_v2_transport.dart';

final class TestQuizReportSubmitter implements QuizReportV2Submitter {
  final submissions = <QuizReportV2Request>[];
  final lookups = <QuizReportV2Request>[];
  Future<QuizReportV2Response> Function(QuizReportV2Request)? onSubmit;
  Future<QuizReportV2LookupResult> Function(QuizReportV2Request)? onLookup;

  @override
  Future<QuizReportV2Response> submit(QuizReportV2Request request) {
    submissions.add(request);
    final handler = onSubmit;
    if (handler != null) return handler(request);
    return Future.value(
      request.decodeResponse({
        'client_event_id': request.clientEventId,
        'quiz_type': request.quizType,
        'practice_kind': request.practiceKind,
        'jlpt_level': request.jlptLevel,
        'completed_at': request.completedAt,
        'answer_count': request.answers.length,
        'correct_count': request.answers
            .where((answer) => answer.isCorrect)
            .length,
      }),
    );
  }

  @override
  Future<QuizReportV2LookupResult> lookupReceipt(
    QuizReportV2Request request,
  ) {
    lookups.add(request);
    final handler = onLookup;
    if (handler != null) return handler(request);
    return Future.value(
      request.decodeLookupResponse({
        'status': 'unresolved',
        'client_event_id': request.clientEventId,
      }),
    );
  }
}
