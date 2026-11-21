// TEST ONLY Auth/RPC/clock. Actual disposable journal, no hosted identity proof.
import 'dart:async';
import 'dart:io';
import 'package:nihongo_daily/features/daily_plan/application/srs_session_recorder.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/data/native_study_session_journal.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';
import 'study_session_recovery_fixtures.dart';

final class RecorderFixtureClock implements StudyRecorderClock {
  DateTime instant = DateTime.utc(2026, 10, 20, 1);
  int ticks = 0;
  int ids = 0;
  @override
  DateTime now() => instant;
  @override
  int get elapsedMs => ticks;
  @override
  String eventId() =>
      'f3100000-0000-4000-8000-${(++ids).toString().padLeft(12, '0')}';
  void advance(Duration duration) {
    ticks += duration.inMilliseconds;
    instant = instant.add(duration);
  }
}

const recorderScenarios = [
  'elapsed',
  'preflight',
  'clock',
  'immutable-retry',
  'reload',
  'lifecycle',
  'late-check',
  'rejected',
];
Future<void> verifyRecorder(String scenario) async {
  final directory = await Directory.systemTemp.createTemp('nd-recorder-');
  final journal = await NativeStudySessionJournal.open(directory);
  final store = StudyFaultStore(journal);
  final auth = StudyAuth();
  final server = StudyServer();
  final clock = RecorderFixtureClock();
  var ready = true;
  final recorder = SrsSessionRecorder(
    service: studyRepository(auth, server, store),
    clock: clock,
    canStudy: () => ready,
  );
  final date = DailyPlanDate('2026-10-20');
  try {
    if (scenario == 'elapsed') {
      ready = false;
      await recorder.start(date);
      checkStudy(
        server.reads == 0 &&
            recorder.state.phase == StudyRecorderPhase.canceled,
        'No-card preflight dispatched',
      );
      ready = true;
      await recorder.start(date);
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.running &&
            server.reads == 1 &&
            server.writes == 0,
        'Start did not read/only time real ready SRS',
      );
      clock.advance(const Duration(seconds: 59));
      await recorder.finish();
      checkStudy(
        clock.ids == 0 &&
            server.writes == 0 &&
            recorder.state.phase == StudyRecorderPhase.canceled,
        'Subminute session dispatched',
      );
      await recorder.start(date);
      final start = clock.instant;
      clock.advance(const Duration(seconds: 61));
      await recorder.finish();
      final record = (await journal.list(studyOwner)).single;
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.confirmed &&
            record.acknowledged &&
            record.event.area == DailyPlanArea.srs &&
            record.event.startedAt == start &&
            record.event.endedAt == clock.instant &&
            record.event.date == date,
        'Finished interval/ack incorrect',
      );
      checkStudy(
        recorder.state.acknowledgment!.latestPlan!.completedMinutes == 45 &&
            clock.ids == 1 &&
            server.writes == 1,
        'Confirmed stale receipt instead of fresh progress',
      );
    } else if (scenario == 'preflight') {
      await journal.stage(studyOwner, studyEvent());
      await recorder.start(date);
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.recoveryRequired &&
            server.reads == 0 &&
            server.writes == 0,
        'Pending event did not block new interval',
      );
      await journal.reject(
        studyOwner,
        studyEvent().clientEventId,
        DailyPlanErrorCode.forbidden,
      );
      final plan = studyPlan(0);
      final blocks = plan['blocks']! as List<Map<String, Object>>;
      blocks.first['status'] = 'BLOCKED';
      blocks.first['item_count'] = 0;
      server.planOverride = plan;
      await recorder.start(date);
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.canceled && clock.ids == 0,
        'Blocked SRS timed',
      );
      server.planOverride = null;
      store.failList = true;
      await recorder.start(date);
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.canceled &&
            !recorder.state.message!.contains('PRIVATE'),
        'Storage preflight unsafe/ignored',
      );
    } else if (scenario == 'clock') {
      for (final skew in [
        const Duration(minutes: -2),
        const Duration(minutes: 2),
      ]) {
        await recorder.start(date);
        clock.advance(const Duration(minutes: 1));
        clock.instant = clock.instant.add(skew);
        await recorder.finish();
        checkStudy(
          recorder.state.phase == StudyRecorderPhase.canceled,
          'Wall clock jump accepted',
        );
      }
      await recorder.start(date);
      clock.advance(const Duration(hours: 25, seconds: 1));
      await recorder.finish();
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.canceled &&
            clock.ids == 0 &&
            server.writes == 0,
        'Invalid interval sent',
      );
      await recorder.start(date);
      clock.ticks -= 1;
      await recorder.finish();
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.canceled && clock.ids == 0,
        'Monotonic rollback accepted',
      );
    } else if (scenario == 'immutable-retry') {
      await recorder.start(date);
      clock.advance(const Duration(minutes: 2));
      final originalEnd = clock.instant;
      store.failStage = true;
      await recorder.finish();
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.uncertain &&
            clock.ids == 1 &&
            server.writes == 0,
        'Failed stage claimed saved/dispatched',
      );
      await recorder.start(date);
      checkStudy(
        clock.ids == 1 && recorder.state.phase == StudyRecorderPhase.uncertain,
        'Uncertain report replaced',
      );
      store.failStage = false;
      server.writeFailure = const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
        retryable: true,
      );
      server.commitBeforeFailure = true;
      clock.advance(const Duration(minutes: 5));
      await recorder.retry();
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.uncertain &&
            (await journal.list(studyOwner)).single.event.endedAt ==
                originalEnd,
        'Retry changed frozen interval',
      );
      server.writeFailure = null;
      server.writeWait = Completer<void>();
      server.entered = Completer<void>();
      final saving = recorder.retry();
      await server.entered!.future;
      final duplicate = recorder.retry();
      final duplicateFinish = recorder.finish();
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.saving &&
            clock.ids == 1 &&
            server.writes == 2,
        'Duplicate timer submit',
      );
      server.writeWait!.complete();
      await saving;
      await duplicate;
      await duplicateFinish;
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.confirmed &&
            server.committed.length == 1 &&
            (await journal.list(studyOwner)).single.acknowledged,
        'Exact reconciliation double-credited',
      );
    } else if (scenario == 'reload') {
      await recorder.start(date);
      server.readFailure = const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
      );
      clock.advance(const Duration(minutes: 1));
      await recorder.finish();
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.confirmed &&
            recorder.state.acknowledgment!.reloadFailure != null &&
            recorder.state.acknowledgment!.latestPlan == null &&
            (await journal.list(studyOwner)).single.acknowledged,
        'Reload failure lost durable confirmation',
      );
    } else if (scenario == 'lifecycle') {
      await recorder.start(date);
      clock.advance(const Duration(minutes: 2));
      recorder.interrupt();
      await recorder.finish();
      checkStudy(
        server.writes == 0 &&
            clock.ids == 0 &&
            recorder.state.phase == StudyRecorderPhase.canceled,
        'Interrupted foreground timer sent',
      );
      await recorder.start(date);
      clock.advance(const Duration(minutes: 1));
      server.writeWait = Completer<void>();
      server.entered = Completer<void>();
      final saving = recorder.finish();
      await server.entered!.future;
      auth.currentSession = null;
      server.writeWait!.complete();
      await saving;
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.unavailable &&
            (await journal.list(studyOwner)).single.isPending,
        'Old owner published or lost uncertain report',
      );
    } else if (scenario == 'late-check') {
      server.readWait = Completer<Object?>();
      final starting = recorder.start(date);
      while (server.reads == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      recorder.interrupt();
      server.readWait!.complete(studyPlan(0));
      await starting;
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.canceled &&
            server.writes == 0,
        'Late plan started timer after navigation',
      );
      server.readWait = null;
      await recorder.start(date);
      clock.advance(const Duration(minutes: 1));
      server.writeWait = Completer<void>();
      server.entered = Completer<void>();
      final saving = recorder.finish();
      await server.entered!.future;
      recorder.dispose();
      server.writeWait!.complete();
      await saving;
      checkStudy(
        (await journal.list(studyOwner)).single.acknowledged,
        'Disposal interrupted accepted durable operation',
      );
    } else if (scenario == 'rejected') {
      await recorder.start(date);
      clock.advance(const Duration(minutes: 1));
      server.writeFailure = const DailyPlanFailure(
        DailyPlanErrorCode.validationFailure,
      );
      await recorder.finish();
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.rejected &&
            (await journal.list(studyOwner)).single.rejection ==
                DailyPlanErrorCode.validationFailure,
        'Definitive rejection not retained',
      );
      await recorder.retry();
      checkStudy(server.writes == 1, 'Definitive report automatically retried');
      server.writeFailure = null;
      await recorder.start(date);
      checkStudy(
        recorder.state.phase == StudyRecorderPhase.running,
        'Explicit fresh interval blocked by terminal report',
      );
    } else {
      throw StateError('Unknown recorder scenario');
    }
  } finally {
    final wait = server.writeWait;
    if (wait != null && !wait.isCompleted) wait.complete();
    final read = server.readWait;
    if (read != null && !read.isCompleted) read.complete(studyPlan(0));
    recorder.dispose();
    await journal.close();
    await directory.delete(recursive: true);
  }
}
