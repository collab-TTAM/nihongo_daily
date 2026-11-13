import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/daily_plan/data/browser_study_session_store.dart';
import 'package:nihongo_daily/features/daily_plan/data/daily_plan_repository.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart';
import 'package:nihongo_daily/features/daily_plan/domain/completed_study_session.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';

const _ownerA = 'b2000000-0000-4000-8000-000000000001';
const _ownerB = 'b2000000-0000-4000-8000-000000000002';

String _databaseName(String kind, int sequence) =>
    'nd-study-$kind-${DateTime.now().microsecondsSinceEpoch}-$sequence';

String _eventId(int number) =>
    'b2100000-0000-4000-8000-${number.toString().padLeft(12, '0')}';

CompletedStudySession _event(
  int number, {
  DailyPlanArea area = DailyPlanArea.vocabulary,
}) {
  final started = DateTime.utc(2026, 11, 13, 1, number % 50);
  return CompletedStudySession(
    clientEventId: _eventId(number),
    date: DailyPlanDate('2026-11-13'),
    area: area,
    startedAt: started,
    endedAt: started.add(const Duration(minutes: 15)),
  );
}

void main() {
  var sequence = 0;
  String name(String kind) => _databaseName(kind, sequence++);

  test(
    'real IndexedDB two connections serialize duplicate and distinct study writes',
    () async {
      final database = name('concurrent');
      final first = await openBrowserStudySessionStore(databaseName: database);
      final second = await openBrowserStudySessionStore(databaseName: database);
      final original = _event(1);
      try {
        final saved = await Future.wait([
          first.stage(_ownerA, original),
          second.stage(
            _ownerA,
            CompletedStudySession.fromJson(original.toJson()),
          ),
          first.stage(_ownerB, original),
        ]);
        expect(saved, hasLength(3));
        expect(saved.take(2).every((row) => sameStudyEvent(row.event, original)), isTrue);
        expect(await first.list(_ownerA), hasLength(1));
        expect(await second.list(_ownerB), hasLength(1));
        expect(await first.list('b2000000-0000-4000-8000-000000000003'), isEmpty);
        await expectLater(
          second.stage(_ownerA, _event(1, area: DailyPlanArea.kanji)),
          throwsA(
            isA<DailyPlanFailure>().having(
              (failure) => failure.code,
              'code',
              DailyPlanErrorCode.syncConflict,
            ),
          ),
        );
        expect((await first.list(_ownerA)).single.event.area, DailyPlanArea.vocabulary);
      } finally {
        await first.close();
        await second.close();
      }
    },
  );

  test(
    'real IndexedDB reopen preserves exact pending and terminal owner records',
    () async {
      final database = name('reopen');
      var store = await openBrowserStudySessionStore(databaseName: database);
      final pending = _event(2);
      final acknowledged = _event(3);
      final rejected = _event(4);
      await store.stage(_ownerA, acknowledged);
      await store.stage(_ownerA, pending);
      await store.stage(_ownerB, rejected);
      await store.acknowledge(_ownerA, acknowledged.clientEventId);
      await store.reject(
        _ownerB,
        rejected.clientEventId,
        DailyPlanErrorCode.validationFailure,
      );
      await store.close();

      store = await openBrowserStudySessionStore(databaseName: database);
      try {
        final a = await store.list(_ownerA);
        final b = await store.list(_ownerB);
        expect(a, hasLength(2));
        final acknowledgedRecord = a.singleWhere(
          (row) => row.event.clientEventId == acknowledged.clientEventId,
        );
        final pendingRecord = a.singleWhere(
          (row) => row.event.clientEventId == pending.clientEventId,
        );
        expect(acknowledgedRecord.acknowledged, isTrue);
        expect(pendingRecord.isPending, isTrue);
        expect(sameStudyEvent(pendingRecord.event, pending), isTrue);
        expect(b, hasLength(1));
        expect(b.single.rejection, DailyPlanErrorCode.validationFailure);
        expect(await store.list('b2000000-0000-4000-8000-000000000003'), isEmpty);
      } finally {
        await store.close();
      }
    },
  );

  test('terminal transitions are idempotent and pending-only', () async {
    final store = await openBrowserStudySessionStore(databaseName: name('terminal'));
    try {
      final acknowledged = _event(5);
      await store.stage(_ownerA, acknowledged);
      await store.acknowledge(_ownerA, acknowledged.clientEventId);
      await store.acknowledge(_ownerA, acknowledged.clientEventId);
      await expectLater(
        store.reject(
          _ownerA,
          acknowledged.clientEventId,
          DailyPlanErrorCode.validationFailure,
        ),
        throwsA(isA<StudySessionStorageFailure>()),
      );

      final rejected = _event(6);
      await store.stage(_ownerA, rejected);
      await expectLater(
        store.reject(
          _ownerA,
          rejected.clientEventId,
          DailyPlanErrorCode.networkUnavailable,
        ),
        throwsA(isA<StudySessionStorageFailure>()),
      );
      await store.reject(
        _ownerA,
        rejected.clientEventId,
        DailyPlanErrorCode.validationFailure,
      );
      await store.reject(
        _ownerA,
        rejected.clientEventId,
        DailyPlanErrorCode.validationFailure,
      );
      await expectLater(
        store.acknowledge(_ownerA, rejected.clientEventId),
        throwsA(isA<StudySessionStorageFailure>()),
      );
    } finally {
      await store.close();
    }
  });

  test('close drains accepted writes and rejects new operations', () async {
    final database = name('drain');
    final store = await openBrowserStudySessionStore(databaseName: database);
    final accepted = [
      for (var i = 10; i < 13; i++) store.stage(_ownerA, _event(i)),
    ];
    final closing = store.close();
    await expectLater(
      store.list(_ownerA),
      throwsA(isA<StudySessionStorageFailure>()),
    );
    await Future.wait(accepted);
    await closing;

    final reopened = await openBrowserStudySessionStore(databaseName: database);
    try {
      expect(await reopened.list(_ownerA), hasLength(3));
    } finally {
      await reopened.close();
    }
  });

  test('512-event bound and invalid database names fail closed', () async {
    final store = await openBrowserStudySessionStore(databaseName: name('bounds'));
    try {
      await Future.wait([
        for (var i = 1; i <= 512; i++) store.stage(_ownerA, _event(i)),
      ]);
      expect(await store.list(_ownerA), hasLength(512));
      await expectLater(
        store.stage(_ownerA, _event(513)),
        throwsA(isA<StudySessionStorageFailure>()),
      );
      await expectLater(
        openBrowserStudySessionStore(databaseName: '../private'),
        throwsA(isA<StudySessionStorageFailure>()),
      );
    } finally {
      await store.close();
    }
  });
}
