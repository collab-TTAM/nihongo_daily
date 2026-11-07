import 'dart:io';
import 'package:nihongo_daily/features/srs/application/srs_study_controller.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';
import '../test/features/srs/recovery_fixtures.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> main() async {
  final directory = await Directory.systemTemp.createTemp('nd-study-recovery-');
  NativeReviewJournal? journal;
  RecoveryHarness? harness;
  try {
    journal = await NativeReviewJournal.open(directory);
    harness = RecoveryHarness(journal);
    await harness.stage();
    await harness.stage(2);
    harness.dispose();
    harness = null;
    await journal.close();
    journal = await NativeReviewJournal.open(directory);
    harness = RecoveryHarness(journal);
    await harness.controller.load(PreviewLevel.n5);
    check(
      harness.controller.state.phase == SrsStudyPhase.recoveryReady &&
          harness.base.queue.calls == 0 &&
          harness.base.rpc.requests.isEmpty &&
          harness.newIds == 0,
      'recovery did not block new queue/dispatch',
    );
    await harness.controller.rate(ReviewRating.easy);
    check(harness.newIds == 0, 'recovery generated a new event');
    await harness.controller.retry();
    check(
      harness.base.queue.calls == 0 &&
          harness.controller.state.recoveryRemaining == 1,
      'queue loaded before all pending resolved',
    );
    harness.base.rpc.reply = () async => {
      'code': 'SYNC_CONFLICT',
      'message_vi': 'TEST ONLY stale event',
      'retryable': false,
    };
    await harness.controller.retry();
    check(
      harness.controller.state.canReload,
      'definitive conflict cannot reload',
    );
    await harness.controller.load(PreviewLevel.n5);
    check(
      harness.base.queue.calls == 1 &&
          harness.controller.state.phase == SrsStudyPhase.ready &&
          harness.controller.state.receipt == null &&
          harness.controller.state.confirmed == 0,
      'old receipt replaced authoritative queue/current progress',
    );
    check(
      harness.base.rpc.requests[0]['occurred_at'] ==
          recoveryRequest()['occurred_at'],
      'recovery rounded event time',
    );
    final owner = harness.base.auth.currentSession!.userId;
    harness.dispose();
    harness = null;
    await journal.close();
    journal = await NativeReviewJournal.open(directory);
    final records = await journal.list(owner);
    check(
      records.length == 2 &&
          records.every((r) => !r.isPending) &&
          records.last.rejection?.code == ReviewErrorCode.syncConflict,
      'terminal resolution lost after restart',
    );
    stdout.writeln(
      'PASS: actual disk/controller restart, pending-before-queue, '
      'manual exact retry, durable rejection and authoritative reload. '
      'Auth/RPC/queue are TEST ONLY; not a hosted learner journey.',
    );
  } finally {
    harness?.dispose();
    await journal?.close();
    await directory.delete(recursive: true);
  }
}
