import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nihongo_daily/features/daily_plan/application/daily_plan_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/srs_session_recorder_provider.dart';
import 'package:nihongo_daily/features/daily_plan/application/study_session_recorder.dart';
import 'package:nihongo_daily/features/daily_plan/data/native_study_session_journal.dart';
import 'package:nihongo_daily/features/daily_plan/domain/daily_plan.dart';
import 'srs_session_recorder_fixtures.dart' show RecorderFixtureClock;
import 'study_session_recovery_fixtures.dart';
import 'shared_study_recorder_fixtures.dart';

void main() {
  for (final scenario in sharedRecorderScenarios) {
    test(
      'shared foreground recorder $scenario',
      () => verifySharedRecorder(scenario),
    );
  }

  test('legacy and shared consumers retain one unstaged SRS report', () async {
    final directory = await Directory.systemTemp.createTemp(
      'nd-shared-provider-',
    );
    final journal = await NativeStudySessionJournal.open(directory);
    final store = StudyFaultStore(journal);
    final server = StudyServer();
    final clock = RecorderFixtureClock();
    final service = studyRepository(StudyAuth(), server, store);
    final container = ProviderContainer(
      overrides: [
        durableStudyRepositoryProvider.overrideWithValue(service),
        canStartSrsRecorderProvider.overrideWithValue(true),
        studyRecorderClockProvider.overrideWithValue(clock),
      ],
    );
    try {
      final legacy = container.read(srsSessionRecorderProvider.notifier);
      final shared = container.read(studySessionRecorderProvider.notifier);
      expect(identical(legacy, shared), isTrue);
      final date = DailyPlanDate('2026-10-20');
      await legacy.start(date);
      clock.advance(const Duration(seconds: 61));
      store.failStage = true;
      await legacy.finish();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(studySessionRecorderProvider).phase,
        StudyRecorderPhase.uncertain,
      );
      expect(await journal.list(studyOwner), isEmpty);
      final reads = server.reads;
      await shared.start(
        DailyPlanDate('2026-10-21'),
        area: DailyPlanArea.grammar,
      );
      expect(server.reads, reads);
      expect(server.writes, 0);
      expect(clock.ids, 1);
      expect(
        container.read(srsSessionRecorderProvider).area,
        DailyPlanArea.srs,
      );
      store.failStage = false;
      await shared.retry();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(srsSessionRecorderProvider).phase,
        StudyRecorderPhase.confirmed,
      );
      expect(server.writes, 1);
      expect(clock.ids, 1);
      final record = (await journal.list(studyOwner)).single;
      expect(record.acknowledged, isTrue);
      expect(record.event.area, DailyPlanArea.srs);
      expect(record.event.date, date);
    } finally {
      container.dispose();
      await journal.close();
      await directory.delete(recursive: true);
    }
  });
}
