// TEST ONLY Auth/RPC/clock/readiness with actual disposable native files.
// Current SQL QUIZ_REVIEW remains BLOCKED; this is gated client composition.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/daily_plan/application/study_session_recorder.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/data/native_study_session_journal.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

import '../daily_plan/srs_session_recorder_fixtures.dart'
    show RecorderFixtureClock;
import '../daily_plan/study_session_recovery_fixtures.dart';

void main() {
  const area = DailyPlanArea.quizReview;
  final date = DailyPlanDate('2026-10-20');
  late Directory directory;
  late NativeStudySessionJournal journal;
  late StudyFaultStore store;
  late StudyAuth auth;
  late StudyServer server;
  late RecorderFixtureClock clock;
  late StudySessionRecorder recorder;
  late Set<DailyPlanArea> ready;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nd-quiz-study-');
    journal = await NativeStudySessionJournal.open(directory);
    store = StudyFaultStore(journal);
    auth = StudyAuth();
    server = StudyServer();
    clock = RecorderFixtureClock();
    ready = {area, DailyPlanArea.srs};
    recorder = StudySessionRecorder(
      service: studyRepository(auth, server, store),
      clock: clock,
      canStudyArea: ready.contains,
    );
  });
  tearDown(() async {
    recorder.dispose();
    if (!(server.readWait?.isCompleted ?? true)) {
      server.readWait!.complete(studyPlan(0));
    }
    if (!(server.writeWait?.isCompleted ?? true)) {
      server.writeWait!.complete();
    }
    await journal.close();
    await directory.delete(recursive: true);
  });

  test(
    'quiz requires readiness and matching nonblocked nonempty server area',
    () async {
      ready.remove(area);
      await recorder.start(date, area: area);
      expect(server.reads, 0);
      ready.add(area);
      final plan = studyPlan(0);
      final block = (plan['blocks']! as List<Map<String, Object>>).singleWhere(
        (b) => b['type'] == 'QUIZ_REVIEW',
      );
      block['status'] = 'BLOCKED';
      server.planOverride = plan;
      await recorder.start(date, area: area);
      expect(recorder.state.phase, StudyRecorderPhase.canceled);
      block['status'] = 'READY';
      block['item_count'] = 0;
      await recorder.start(date, area: area);
      expect(recorder.state.phase, StudyRecorderPhase.canceled);
      expect(server.writes, 0);
      expect(clock.ids, 0);
      block['item_count'] = 1;
      final start = clock.instant;
      await recorder.start(date, area: area);
      clock.advance(const Duration(seconds: 61));
      await recorder.finish();
      final record = (await journal.list(studyOwner)).single;
      expect(record.acknowledged, isTrue);
      expect(record.event.area, area);
      expect(record.event.date.value, date.value);
      expect(record.event.startedAt, start);
      expect(record.event.endedAt, clock.instant);
      expect(server.writes, 1);
      expect(clock.ids, 1);
    },
  );

  test(
    'unstaged quiz report blocks SRS then retries its frozen event',
    () async {
      await recorder.start(date, area: area);
      clock.advance(const Duration(seconds: 61));
      store.failStage = true;
      await recorder.finish();
      final event = recorder.pendingEvent!;
      final reads = server.reads;
      expect(recorder.state.phase, StudyRecorderPhase.uncertain);
      expect(await journal.list(studyOwner), isEmpty);
      await recorder.start(date, area: DailyPlanArea.srs);
      expect(server.reads, reads);
      expect(recorder.pendingEvent, same(event));
      store.failStage = false;
      await recorder.retry();
      final record = (await journal.list(studyOwner)).single;
      expect(record.acknowledged, isTrue);
      expect(sameStudyEvent(record.event, event), isTrue);
      expect(record.event.area, area);
      expect(server.writes, 1);
      expect(clock.ids, 1);
    },
  );

  test(
    'uncertain quiz commit reopens and replays once with original identity',
    () async {
      await recorder.start(date, area: area);
      clock.advance(const Duration(seconds: 61));
      server.writeFailure = const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
        retryable: true,
      );
      server.commitBeforeFailure = true;
      await recorder.finish();
      final event = recorder.pendingEvent!;
      recorder.dispose();
      await journal.close();
      journal = await NativeStudySessionJournal.open(directory);
      store = StudyFaultStore(journal);
      final service = studyRepository(auth, server, store);
      final recovered = (await service.recoverPending()).single;
      expect(sameStudyEvent(recovered, event), isTrue);
      expect(recovered.area, area);
      server.writeFailure = null;
      await service.submit(recovered);
      expect((await journal.list(studyOwner)).single.acknowledged, isTrue);
      expect(server.committed, hasLength(1));
      expect(clock.ids, 1);
      expect(await service.recoverPending(), isEmpty);
    },
  );

  test('late quiz save cannot publish into a replacement account', () async {
    await recorder.start(date, area: area);
    clock.advance(const Duration(seconds: 61));
    server.entered = Completer<void>();
    server.writeWait = Completer<void>();
    final saving = recorder.finish();
    await server.entered!.future;
    auth.currentSession = ReviewSession(userId: studyOther);
    server.writeWait!.complete();
    await saving;
    expect(recorder.state.phase, StudyRecorderPhase.unavailable);
    final record = (await journal.list(studyOwner)).single;
    expect(record.isPending, isTrue);
    expect(record.event.area, area);
    expect(await journal.list(studyOther), isEmpty);
  });
}
