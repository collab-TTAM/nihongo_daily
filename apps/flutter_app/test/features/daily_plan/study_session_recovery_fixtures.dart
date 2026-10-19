// TEST ONLY server/Auth fixtures; real disposable native files, no hosted proof.
import 'dart:async';
import 'dart:io';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/daily_plan/domain/completed_study_session.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart';
import 'package:nihongo_daily/features/daily_plan/data/native_study_session_journal.dart';

const studyOwner = 'f2000000-0000-4000-8000-000000000001';
const studyOther = 'f2000000-0000-4000-8000-000000000002';
void checkStudy(bool value, String message) {
  if (!value) throw StateError(message);
}

CompletedStudySession studyEvent([int number = 1]) => CompletedStudySession(
  clientEventId:
      'f2100000-0000-4000-8000-${number.toString().padLeft(12, '0')}',
  date: DailyPlanDate('2026-10-20'),
  area: DailyPlanArea.vocabulary,
  startedAt: DateTime.utc(2026, 10, 20, 1),
  endedAt: DateTime.utc(2026, 10, 20, 1, 15),
);
Map<String, Object?> studyPlan(int minutes) => {
  'plan_date': '2026-10-20',
  'target_minutes': 120,
  'completed_minutes': minutes,
  'blocks': <Map<String, Object>>[
    for (var i = 0; i < DailyPlanArea.values.length; i++)
      {
        'type': DailyPlanArea.values[i].wireName,
        'planned_minutes': [20, 15, 20, 15, 15, 25, 10][i],
        'status': 'READY',
        'item_count': 1,
      },
  ],
};

final class StudyAuth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: studyOwner);
}

final class StudyServer {
  final committed = <String>{};
  int writes = 0;
  int reads = 0;
  int latest = 45;
  DailyPlanFailure? writeFailure;
  DailyPlanFailure? readFailure;
  bool commitBeforeFailure = false;
  bool ready = true;
  Completer<void>? writeWait;
  Completer<void>? entered;
  Object? malformed;
}

final class StudyGateway implements DailyPlanStudySessionGateway {
  StudyGateway(this.auth, this.server, this.store)
    : session = auth.currentSession!;
  final StudyAuth auth;
  final StudyServer server;
  final StudySessionStore store;
  final ReviewSession session;
  @override
  bool get isCurrent => server.ready && identical(auth.currentSession, session);
  @override
  Future<Object?> getDailyPlan(Map<String, Object> parameters) async {
    server.reads++;
    if (server.readFailure != null) throw server.readFailure!;
    return studyPlan(server.latest);
  }

  @override
  Future<Object?> submitStudySession(Map<String, Object> parameters) async {
    final event = CompletedStudySession.fromJson(parameters['p_request']);
    final staged = await store.list(session.userId);
    checkStudy(
      staged.any((r) => r.isPending && sameStudyEvent(r.event, event)),
      'RPC dispatched before immutable stage',
    );
    server.writes++;
    if (server.writeFailure == null || server.commitBeforeFailure) {
      server.committed.add('${session.userId}/${event.clientEventId}');
    }
    if (!(server.entered?.isCompleted ?? true)) server.entered!.complete();
    await server.writeWait?.future;
    if (server.writeFailure != null) throw server.writeFailure!;
    return server.malformed ?? studyPlan(15); // Deliberately older receipt.
  }
}

final class StudyFaultStore implements StudySessionStore {
  StudyFaultStore(this.base);
  final StudySessionStore base;
  bool failStage = false;
  bool failAck = false;
  Completer<void>? stageWait;
  Completer<void>? staged;
  @override
  Future<List<StoredStudySession>> list(String userId) => base.list(userId);
  @override
  Future<StoredStudySession> stage(
    String userId,
    CompletedStudySession event,
  ) async {
    if (failStage) throw StateError('PRIVATE DISK PATH');
    final record = await base.stage(userId, event);
    if (!(staged?.isCompleted ?? true)) staged!.complete();
    await stageWait?.future;
    return record;
  }

  @override
  Future<void> acknowledge(String userId, String eventId) {
    if (failAck) throw StateError('PRIVATE DISK PATH');
    return base.acknowledge(userId, eventId);
  }

  @override
  Future<void> reject(String userId, String eventId, DailyPlanErrorCode code) =>
      base.reject(userId, eventId, code);
}

DurableStudySessionRepository studyRepository(
  StudyAuth auth,
  StudyServer server,
  StudySessionStore store,
) => DurableStudySessionRepository(
  auth: auth,
  store: store,
  delegate: DailyPlanRepository(StudyGateway(auth, server, store)),
);
Future<void> studyFailure(
  Future<Object?> pending, {
  DailyPlanErrorCode? code,
  bool storage = false,
}) async {
  Object? failure;
  try {
    await pending;
  } on Object catch (error) {
    failure = error;
  }
  checkStudy(
    storage
        ? failure is StudySessionStorageFailure
        : failure is DailyPlanFailure && failure.code == code,
    'Missing/wrong safe failure',
  );
  checkStudy(!failure.toString().contains('PRIVATE'), 'Raw error leaked');
}

const studyRecoveryScenarios = [
  'replay',
  'ordering',
  'ownership',
  'rejections',
  'integrity',
  'capacity',
];
Future<void> verifyStudyRecovery(String scenario) async {
  final directory = await Directory.systemTemp.createTemp('nd-study-recovery-');
  NativeStudySessionJournal? journal;
  Completer<void>? waiting;
  try {
    journal = await NativeStudySessionJournal.open(directory);
    final auth = StudyAuth();
    final server = StudyServer();
    final fault = StudyFaultStore(journal);
    var repository = studyRepository(auth, server, fault);
    final event = studyEvent();
    if (scenario == 'replay') {
      await journal.stage(studyOwner, event);
      checkStudy(
        (await repository.recoverPending()).length == 1 && server.writes == 0,
        'Recovery dispatched or lost event',
      );
      server.writeFailure = const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
        retryable: true,
      );
      server.commitBeforeFailure = true;
      await studyFailure(
        repository.submit(event),
        code: DailyPlanErrorCode.networkUnavailable,
      );
      checkStudy(
        (await journal.list(studyOwner)).single.isPending &&
            server.committed.length == 1,
        'Uncertain commit lost original event',
      );
      await journal.close();
      journal = await NativeStudySessionJournal.open(directory);
      final restored = (await journal.list(studyOwner)).single.event;
      checkStudy(
        sameStudyEvent(event, restored),
        'Restart changed exact report',
      );
      server.writeFailure = null;
      repository = studyRepository(auth, server, journal);
      final ack = await repository.submit(restored);
      checkStudy(
        server.committed.length == 1 && ack.latestPlan?.completedMinutes == 45,
        'Replay double-counted or published old receipt',
      );
      checkStudy(
        (await repository.recoverPending()).isEmpty,
        'Acknowledged event recovered as pending',
      );
      await journal.close();
      journal = await NativeStudySessionJournal.open(directory);
      repository = studyRepository(auth, server, journal);
      server.latest = 60;
      final again = await repository.submit(event);
      checkStudy(
        server.writes == 2 && again.latestPlan?.completedMinutes == 60,
        'Durable ack repeated mutation or cached progress',
      );
    } else if (scenario == 'ordering') {
      fault.failStage = true;
      await studyFailure(repository.submit(event), storage: true);
      checkStudy(server.writes == 0, 'Stage failure dispatched');
      fault.failStage = false;
      fault.failAck = true;
      await studyFailure(repository.submit(event), storage: true);
      checkStudy(
        (await journal.list(studyOwner)).single.isPending &&
            server.committed.length == 1,
        'Ack failure lost pending commit',
      );
      fault.failAck = false;
      server.readFailure = const DailyPlanFailure(
        DailyPlanErrorCode.networkUnavailable,
        retryable: true,
      );
      final ack = await repository.submit(event);
      checkStudy(
        ack.latestPlan == null &&
            ack.reloadFailure?.code == DailyPlanErrorCode.networkUnavailable,
        'Reload error changed confirmed acknowledgment',
      );
      checkStudy(
        (await repository.recoverPending()).isEmpty,
        'Durable ack not retained',
      );
      server.readFailure = null;
      final writes = server.writes;
      final latest = await repository.submit(event);
      checkStudy(
        server.writes == writes && latest.latestPlan?.completedMinutes == 45,
        'Acknowledged retry performed another write',
      );
      waiting = Completer<void>();
      server.writeWait = waiting;
      server.entered = Completer<void>();
      final next = studyEvent(2);
      final first = repository.submit(next);
      final duplicate = repository.submit(next);
      checkStudy(
        identical(first, duplicate),
        'Concurrent identical dispatch not coalesced',
      );
      await server.entered!.future;
      waiting.complete();
      await first;
    } else if (scenario == 'ownership') {
      waiting = Completer<void>();
      fault.stageWait = waiting;
      fault.staged = Completer<void>();
      final old = studyFailure(
        repository.submit(event),
        code: DailyPlanErrorCode.unauthorized,
      );
      await fault.staged!.future;
      auth.currentSession = ReviewSession(userId: studyOther);
      auth.currentSession = ReviewSession(userId: studyOwner);
      waiting.complete();
      await old;
      checkStudy(
        server.writes == 0 && (await journal.list(studyOwner)).single.isPending,
        'Owner changed during stage dispatched or lost pending',
      );
      await studyFailure(
        repository.submit(studyEvent(3)),
        code: DailyPlanErrorCode.unauthorized,
      );
      checkStudy(
        (await journal.list(studyOwner)).length == 1,
        'Old lease staged for new login',
      );
      fault.stageWait = null;
      repository = studyRepository(auth, server, journal);
      await repository.submit(event);
      await journal.stage(studyOther, event);
      checkStudy(
        (await journal.list(studyOther)).single.isPending &&
            (await journal.list(studyOwner)).single.acknowledged,
        'Owners mixed',
      );
      waiting = Completer<void>();
      server.writeWait = waiting;
      server.entered = Completer<void>();
      final late = studyFailure(
        repository.submit(studyEvent(2)),
        code: DailyPlanErrorCode.unauthorized,
      );
      await server.entered!.future;
      auth.currentSession = ReviewSession(userId: studyOther);
      waiting.complete();
      await late;
      repository = studyRepository(auth, server, journal);
      final recovered = await repository.recoverPending();
      checkStudy(
        recovered.length == 1 && sameStudyEvent(recovered.single, event),
        'Other owner recovered foreign event',
      );
      auth.currentSession = ReviewSession(userId: studyOwner);
      repository = studyRepository(auth, server, journal);
      final ownPending = await repository.recoverPending();
      checkStudy(
        ownPending.length == 1 &&
            ownPending.single.clientEventId == studyEvent(2).clientEventId,
        'Late committed event lost before owner returned',
      );
      await repository.submit(ownPending.single);
      checkStudy(
        server.committed.length == 2 &&
            (await journal.list(studyOther)).single.isPending,
        'Late replay double-counted or removed other owner',
      );
      server.ready = false;
      await studyFailure(
        repository.recoverPending(),
        code: DailyPlanErrorCode.unauthorized,
      );
      server.ready = true;
      await studyFailure(
        repository.recoverPending(),
        code: DailyPlanErrorCode.unauthorized,
      );
      repository = studyRepository(auth, server, journal);
      auth.currentSession = null;
      await studyFailure(
        repository.recoverPending(),
        code: DailyPlanErrorCode.unauthorized,
      );
      final changed = CompletedStudySession.fromJson({
        ...event.toJson(),
        'session_type': 'SRS',
      });
      await studyFailure(
        journal.stage(studyOwner, changed),
        code: DailyPlanErrorCode.syncConflict,
      );
    } else if (scenario == 'rejections') {
      var number = 1;
      for (final code in DailyPlanErrorCode.values) {
        server.writeFailure = DailyPlanFailure(code);
        final report = studyEvent(number++);
        await studyFailure(repository.submit(report), code: code);
        final record = (await journal.list(studyOwner)).last;
        final definitive = isDefinitiveStudyRejection(DailyPlanFailure(code));
        checkStudy(
          record.isPending == !definitive &&
              record.rejection == (definitive ? code : null),
          'Transient/auth error was discarded',
        );
        if (definitive) {
          final writes = server.writes;
          await studyFailure(repository.submit(report), code: code);
          checkStudy(
            server.writes == writes,
            'Terminal rejection dispatched again',
          );
        }
      }
      server.writeFailure = null;
      server.malformed = {'PRIVATE': 'SQL'};
      await studyFailure(
        repository.submit(studyEvent(20)),
        code: DailyPlanErrorCode.internalError,
      );
      checkStudy(
        (await journal.list(studyOwner)).last.isPending,
        'Malformed response acknowledged',
      );
    } else if (scenario == 'integrity') {
      await journal.stage(studyOwner, event);
      await journal.close();
      final file = File(
        '${directory.path}${Platform.pathSeparator}study-sessions.ndjson',
      );
      final valid = await file.readAsBytes();
      await file.writeAsString(
        '{"partial":',
        mode: FileMode.append,
        flush: true,
      );
      journal = await NativeStudySessionJournal.open(directory);
      checkStudy(
        (await journal.list(studyOwner)).single.isPending &&
            await file.length() == valid.length,
        'Partial tail not repaired losslessly',
      );
      await journal.close();
      await file.writeAsString(
        '{"version":1,"version":1}\n',
        mode: FileMode.append,
        flush: true,
      );
      final length = await file.length();
      await studyFailure(
        NativeStudySessionJournal.open(directory),
        storage: true,
      );
      checkStudy(
        await file.length() == length,
        'Complete corruption was deleted',
      );
      for (final invalid in <Object?>[
        {...event.toJson(), 'owner': studyOther},
        {...event.toJson(), 'started_at': '2026-10-20T01:00:00+00:00'},
        {...event.toJson(), 'started_at': '2026-10-20T25:00:00.000Z'},
        {...event.toJson(), 'ended_at': '2026-10-20T01:15:00Z'},
      ]) {
        var rejected = false;
        try {
          CompletedStudySession.fromJson(invalid);
        } on FormatException {
          rejected = true;
        }
        checkStudy(rejected, 'Noncanonical storage event accepted');
      }
    } else if (scenario == 'capacity') {
      await studyFailure(
        NativeStudySessionJournal.open(directory),
        storage: true,
      );
      for (var i = 1; i <= NativeStudySessionJournal.maxEvents; i++) {
        await journal.stage(studyOwner, studyEvent(i));
      }
      await studyFailure(
        journal.stage(studyOwner, studyEvent(513)),
        storage: true,
      );
      for (var i = 1; i <= NativeStudySessionJournal.maxEvents; i++) {
        await journal.acknowledge(studyOwner, studyEvent(i).clientEventId);
      }
      await journal.acknowledge(
        studyOwner,
        event.clientEventId,
      ); // Exact no-op.
      await studyFailure(
        journal.reject(
          studyOwner,
          event.clientEventId,
          DailyPlanErrorCode.syncConflict,
        ),
        storage: true,
      );
      checkStudy(
        (await journal.list(studyOwner)).length == 512,
        'Capacity evicted retained records',
      );
      final first = journal.close();
      checkStudy(
        identical(first, journal.close()),
        'Close did not share drain',
      );
      await first;
      journal = await NativeStudySessionJournal.open(directory);
      checkStudy(
        (await journal.list(studyOwner)).every((r) => r.acknowledged),
        'Reserved terminal writes lost',
      );
      checkStudy(
        await File(
              '${directory.path}${Platform.pathSeparator}study-sessions.ndjson',
            ).length() <=
            NativeStudySessionJournal.maxBytes,
        'Journal exceeded bound',
      );
    } else {
      throw StateError('Unknown recovery scenario');
    }
  } finally {
    if (waiting != null && !waiting.isCompleted) waiting.complete();
    await journal?.close();
    await directory.delete(recursive: true);
  }
}
