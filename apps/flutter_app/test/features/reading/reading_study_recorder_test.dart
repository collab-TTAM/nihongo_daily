// TEST ONLY Auth/RPC/clock and permissive plan; actual disposable native journal.
// Production SQL still blocks LISTENING_READING until reviewed resources exist.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/daily_plan/application/study_session_recorder.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/data/native_study_session_journal.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart'
    show sameStudyEvent;
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

import '../daily_plan/srs_session_recorder_fixtures.dart'
    show RecorderFixtureClock;
import '../daily_plan/study_session_recovery_fixtures.dart';

void main() {
  late Directory directory;
  late NativeStudySessionJournal journal;
  late StudyFaultStore store;
  late StudyAuth auth;
  late StudyServer server;
  late RecorderFixtureClock clock;
  late StudySessionRecorder recorder;
  late Set<DailyPlanArea> ready;
  final date = DailyPlanDate('2026-10-20');
  const reading = DailyPlanArea.listeningReading;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nd-reading-study-');
    journal = await NativeStudySessionJournal.open(directory);
    store = StudyFaultStore(journal);
    auth = StudyAuth();
    server = StudyServer();
    clock = RecorderFixtureClock();
    ready = {reading, DailyPlanArea.vocabulary};
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
    'reading requires local readiness and its own nonblocked nonempty plan',
    () async {
      ready.remove(reading);
      await recorder.start(date, area: reading);
      expect(server.reads, 0);
      ready.add(reading);
      final blocked = studyPlan(0);
      final blocks = blocked['blocks']! as List<Map<String, Object>>;
      final block = blocks.singleWhere((b) => b['type'] == 'LISTENING_READING');
      block['status'] = 'BLOCKED';
      server.planOverride = blocked;
      await recorder.start(date, area: reading);
      expect(recorder.state.phase, StudyRecorderPhase.canceled);
      expect(server.reads, 1);
      block['status'] = 'READY';
      block['item_count'] = 0;
      await recorder.start(date, area: reading);
      expect(recorder.state.phase, StudyRecorderPhase.canceled);
      expect(server.writes, 0);
      expect(clock.ids, 0);
      block['item_count'] = 1;
      final started = clock.instant;
      await recorder.start(date, area: reading);
      expect(recorder.state.phase, StudyRecorderPhase.running);
      clock.advance(const Duration(seconds: 61));
      await recorder.finish();
      final record = (await journal.list(studyOwner)).single;
      expect(record.acknowledged, isTrue);
      expect(record.event.area, reading);
      expect(record.event.date.value, date.value);
      expect(record.event.startedAt, started);
      expect(record.event.endedAt, clock.instant);
      expect(recorder.state.phase, StudyRecorderPhase.confirmed);
      expect(server.writes, 1);
      expect(clock.ids, 1);
    },
  );

  test(
    'unstaged reading report blocks other areas and retries the identical event',
    () async {
      await recorder.start(date, area: reading);
      clock.advance(const Duration(seconds: 61));
      store.failStage = true;
      await recorder.finish();
      final frozen = recorder.pendingEvent!;
      expect(recorder.state.phase, StudyRecorderPhase.uncertain);
      expect(await journal.list(studyOwner), isEmpty);
      expect(server.writes, 0);
      final reads = server.reads;
      await recorder.start(date, area: DailyPlanArea.vocabulary);
      expect(recorder.pendingEvent, same(frozen));
      expect(server.reads, reads);
      store.failStage = false;
      await recorder.retry();
      final record = (await journal.list(studyOwner)).single;
      expect(sameStudyEvent(record.event, frozen), isTrue);
      expect(record.acknowledged, isTrue);
      expect(recorder.state.phase, StudyRecorderPhase.confirmed);
      expect(clock.ids, 1);
      expect(server.writes, 1);
    },
  );

  test(
    'uncertain reading commit survives journal reopen and exact manual replay',
    () async {
      await recorder.start(date, area: reading);
      clock.advance(const Duration(seconds: 61));
      server.writeFailure = const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
        retryable: true,
      );
      server.commitBeforeFailure = true;
      await recorder.finish();
      final frozen = recorder.pendingEvent!;
      expect(recorder.state.phase, StudyRecorderPhase.uncertain);
      recorder.dispose();
      await journal.close();
      journal = await NativeStudySessionJournal.open(directory);
      store = StudyFaultStore(journal);
      final service = studyRepository(auth, server, store);
      recorder = StudySessionRecorder(
        service: service,
        clock: clock,
        canStudyArea: ready.contains,
      );
      final recovered = (await service.recoverPending()).single;
      expect(sameStudyEvent(recovered, frozen), isTrue);
      await recorder.start(date, area: reading);
      expect(recorder.state.phase, StudyRecorderPhase.recoveryRequired);
      server.writeFailure = null;
      await service.submit(recovered);
      final record = (await journal.list(studyOwner)).single;
      expect(record.acknowledged, isTrue);
      expect(record.event.area, reading);
      expect(sameStudyEvent(record.event, frozen), isTrue);
      expect(server.committed, hasLength(1));
      expect(clock.ids, 1);
      expect(await service.recoverPending(), isEmpty);
    },
  );

  test(
    'reading readiness loss cancels held preflight without replacing a new area',
    () async {
      final held = Completer<Object?>();
      server.readWait = held;
      final starting = recorder.start(date, area: reading);
      await (() async {
        while (server.reads == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      })().timeout(const Duration(seconds: 5));
      ready.remove(reading);
      recorder.interrupt(area: reading);
      server.readWait = null;
      await recorder.start(date, area: DailyPlanArea.vocabulary);
      held.complete(studyPlan(0));
      await starting;
      expect(recorder.state.area, DailyPlanArea.vocabulary);
      expect(recorder.state.phase, StudyRecorderPhase.running);
      recorder.interrupt(area: reading);
      expect(recorder.state.phase, StudyRecorderPhase.running);
      expect(server.writes, 0);
      expect(clock.ids, 0);
    },
  );

  test(
    'late reading save remains pending for original owner after account replacement',
    () async {
      await recorder.start(date, area: reading);
      clock.advance(const Duration(seconds: 61));
      server.entered = Completer<void>();
      server.writeWait = Completer<void>();
      final saving = recorder.finish();
      await server.entered!.future;
      auth.currentSession = ReviewSession(userId: studyOther);
      server.writeWait!.complete();
      await saving;
      expect(recorder.state.phase, StudyRecorderPhase.unavailable);
      expect((await journal.list(studyOwner)).single.isPending, isTrue);
      expect((await journal.list(studyOwner)).single.event.area, reading);
      expect(await journal.list(studyOther), isEmpty);
    },
  );
}
