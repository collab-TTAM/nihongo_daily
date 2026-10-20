// TEST ONLY clock/Auth/RPC with actual disposable native study journals.
import 'dart:async';
import 'dart:io';
import 'package:nihongo_daily/features/daily_plan/application/study_session_recorder.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/data/native_study_session_journal.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'srs_session_recorder_fixtures.dart' show RecorderFixtureClock;
import 'study_session_recovery_fixtures.dart';

const sharedRecorderScenarios = [
  'areas',
  'unstaged-frozen',
  'uncertain-frozen',
  'area-preflight',
  'scoped-interruption',
  'held-save-owner',
];

Future<void> _until(bool Function() ready) async {
  await (() async {
    while (!ready()) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  })().timeout(const Duration(seconds: 5));
}

Future<void> verifySharedRecorder(String scenario) async {
  final directory = await Directory.systemTemp.createTemp(
    'nd-shared-recorder-',
  );
  final journal = await NativeStudySessionJournal.open(directory);
  final store = StudyFaultStore(journal);
  final auth = StudyAuth();
  final server = StudyServer();
  final clock = RecorderFixtureClock();
  final ready = {
    DailyPlanArea.srs,
    DailyPlanArea.vocabulary,
    DailyPlanArea.grammar,
  };
  final recorder = StudySessionRecorder(
    service: studyRepository(auth, server, store),
    clock: clock,
    canStudyArea: ready.contains,
  );
  final date = DailyPlanDate('2026-10-20');
  try {
    if (scenario == 'areas') {
      for (final area in ready) {
        final before = clock.instant;
        await recorder.start(date, area: area);
        checkStudy(
          recorder.state.phase == StudyRecorderPhase.running &&
              recorder.state.area == area,
          'Shared recorder did not capture selected area',
        );
        clock.advance(const Duration(seconds: 61));
        await recorder.finish();
        checkStudy(
          recorder.state.phase == StudyRecorderPhase.confirmed &&
              recorder.state.area == area &&
              recorder.state.acknowledgment!.latestPlan!.completedMinutes == 45,
          'Area acknowledgment did not retain area/fresh progress',
        );
        final record = (await journal.list(
          studyOwner,
        )).singleWhere((r) => r.event.area == area);
        checkStudy(
          record.acknowledged &&
              record.event.date == date &&
              record.event.startedAt == before &&
              record.event.endedAt == clock.instant,
          'Area event changed its immutable interval',
        );
      }
      checkStudy(
        clock.ids == 3 && server.writes == 3 && server.committed.length == 3,
        'Area reports duplicated or were not dispatched',
      );
    } else if (scenario == 'unstaged-frozen') {
      await recorder.start(date, area: DailyPlanArea.vocabulary);
      final start = clock.instant;
      clock.advance(const Duration(seconds: 61));
      final end = clock.instant;
      store.failStage = true;
      await recorder.finish();
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.uncertain &&
            recorder.state.area == DailyPlanArea.vocabulary &&
            (await journal.list(studyOwner)).isEmpty &&
            server.writes == 0,
        'Failed stage lost frozen state or fabricated durable success',
      );
      final reads = server.reads;
      for (final area in [DailyPlanArea.grammar, DailyPlanArea.srs]) {
        await recorder.start(DailyPlanDate('2026-10-21'), area: area);
        recorder.interrupt(area: area);
      }
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.uncertain &&
            recorder.state.area == DailyPlanArea.vocabulary &&
            clock.ids == 1 &&
            server.reads == reads &&
            server.writes == 0,
        'Another area replaced a frozen event before successful local stage',
      );
      store.failStage = false;
      await recorder.retry();
      final event = (await journal.list(studyOwner)).single.event;
      checkStudy(
        event.area == DailyPlanArea.vocabulary &&
            event.date == date &&
            event.startedAt == start &&
            event.endedAt == end &&
            clock.ids == 1 &&
            server.writes == 1 &&
            recorder.state.phase == StudyRecorderPhase.confirmed,
        'Retry changed frozen area/date/interval/identity',
      );
      await recorder.start(date, area: DailyPlanArea.grammar);
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.running &&
            recorder.state.area == DailyPlanArea.grammar,
        'Resolved report prevented a later explicit different-area interval',
      );
    } else if (scenario == 'uncertain-frozen') {
      server.writeFailure = const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
      );
      server.commitBeforeFailure = true;
      await recorder.start(date, area: DailyPlanArea.grammar);
      clock.advance(const Duration(seconds: 61));
      await recorder.finish();
      final original = (await journal.list(studyOwner)).single.event;
      final reads = server.reads;
      await recorder.start(date, area: DailyPlanArea.vocabulary);
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.uncertain &&
            recorder.state.area == DailyPlanArea.grammar &&
            server.reads == reads &&
            clock.ids == 1 &&
            server.writes == 1,
        'Cross-area start replaced uncertain committed grammar report',
      );
      server.writeFailure = null;
      await recorder.retry();
      final record = (await journal.list(studyOwner)).single;
      checkStudy(
        sameStudyEvent(record.event, original) &&
            record.acknowledged &&
            server.writes == 2 &&
            server.committed.length == 1 &&
            clock.ids == 1,
        'Uncertain retry changed event or duplicated unique receipt',
      );
    } else if (scenario == 'area-preflight') {
      ready.remove(DailyPlanArea.vocabulary);
      await recorder.start(date, area: DailyPlanArea.vocabulary);
      checkStudy(server.reads == 0, 'Unavailable content performed preflight');
      ready.add(DailyPlanArea.vocabulary);
      final blocked = studyPlan(0);
      final blocks = blocked['blocks']! as List<Map<String, Object>>;
      final vocabulary = blocks.singleWhere((b) => b['type'] == 'VOCABULARY');
      vocabulary['status'] = 'BLOCKED';
      vocabulary['item_count'] = 0;
      server.planOverride = blocked;
      await recorder.start(date, area: DailyPlanArea.vocabulary);
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.canceled && clock.ids == 0,
        'Available SRS block substituted for blocked vocabulary area',
      );
      server.planOverride = null;
      final held = server.readWait = Completer<Object?>();
      final reads = server.reads;
      final starting = recorder.start(date, area: DailyPlanArea.grammar);
      await _until(() => server.reads > reads);
      ready.remove(DailyPlanArea.grammar);
      held.complete(studyPlan(0));
      await starting;
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.canceled &&
            recorder.state.area == DailyPlanArea.grammar &&
            clock.ids == 0,
        'Content readiness was not rechecked after awaited preflight',
      );
      final count = server.reads;
      await recorder.start(date, area: DailyPlanArea.kanji);
      checkStudy(server.reads == count, 'Unsupported activity was activated');
      checkStudy(
        (await journal.list(studyOwner)).isEmpty,
        'Preflight wrote event',
      );
    } else if (scenario == 'scoped-interruption') {
      final held = server.readWait = Completer<Object?>();
      final first = recorder.start(date, area: DailyPlanArea.grammar);
      await _until(() => server.reads == 1);
      recorder.interrupt(area: DailyPlanArea.srs);
      await recorder.start(date, area: DailyPlanArea.vocabulary);
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.checking &&
            recorder.state.area == DailyPlanArea.grammar &&
            server.reads == 1,
        'Other-area host canceled or replaced a pending preflight',
      );
      recorder.interrupt(area: DailyPlanArea.grammar);
      server.readWait = null;
      await recorder.start(date, area: DailyPlanArea.vocabulary);
      held.complete(studyPlan(0));
      await first;
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.running &&
            recorder.state.area == DailyPlanArea.vocabulary &&
            server.reads == 2,
        'Late canceled preflight revoked the newer area',
      );
      recorder.interrupt(area: DailyPlanArea.grammar);
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.running,
        'Disposal of old-area host canceled a newer foreground interval',
      );
      clock.advance(const Duration(seconds: 61));
      await recorder.finish();
      checkStudy(
        (await journal.list(studyOwner)).single.event.area ==
            DailyPlanArea.vocabulary,
        'Canceled old preflight changed the finished report area',
      );
    } else if (scenario == 'held-save-owner') {
      await recorder.start(date, area: DailyPlanArea.grammar);
      clock.advance(const Duration(seconds: 61));
      server.entered = Completer();
      server.writeWait = Completer();
      final saving = recorder.finish();
      await server.entered!.future;
      final reads = server.reads;
      await recorder.start(date, area: DailyPlanArea.vocabulary);
      recorder.interrupt(area: DailyPlanArea.grammar);
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.saving &&
            recorder.state.area == DailyPlanArea.grammar &&
            server.reads == reads &&
            server.writes == 1 &&
            clock.ids == 1,
        'Another area canceled or replaced an accepted immutable save',
      );
      auth.currentSession = ReviewSession(userId: studyOther);
      server.writeWait!.complete();
      await saving;
      final record = (await journal.list(studyOwner)).single;
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.unavailable &&
            recorder.state.area == null &&
            record.isPending &&
            record.event.area == DailyPlanArea.grammar &&
            (await journal.list(studyOther)).isEmpty,
        'Late save published to a replacement owner or changed pending report',
      );
    } else {
      throw ArgumentError.value(scenario);
    }
  } finally {
    recorder.dispose();
    if (!(server.readWait?.isCompleted ?? true)) {
      server.readWait!.complete(studyPlan(0));
    }
    if (!(server.writeWait?.isCompleted ?? true)) {
      server.writeWait!.complete();
    }
    await journal.close();
    await directory.delete(recursive: true);
  }
}
