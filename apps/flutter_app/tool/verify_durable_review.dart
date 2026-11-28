import 'dart:io';

import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/domain/srs_models.dart';

const owner = 'a1000000-0000-4000-8000-000000000001';
const other = 'a1000000-0000-4000-8000-000000000002';

Map<String, Object> request() => {
  'client_event_id': 'b2000000-0000-4000-8000-000000000001',
  'item_type': 'VOCABULARY',
  'item_id': 'b3000000-0000-4000-8000-000000000001',
  'rating': 2,
  'is_correct': true,
  'response_ms': 123,
  'occurred_at': '2026-10-14T02:00:00.123456789+07:00',
};

ReviewSuccess receipt() =>
    decodeReviewOutcome({
          'srs_state': 'REVIEW',
          'next_review_at': '2026-10-15T02:00:00.123456789Z',
          'interval_days': 1,
          'difficulty': 0.5,
          'review_count': 2,
        })
        as ReviewSuccess;

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

final class _Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: owner);
}

// TEST ONLY delegate. The journal/process checks use real files, not hosted RPC.
final class _Reviews implements ReviewRepository {
  _Reviews(this.auth);
  final _Auth auth;
  int calls = 0;
  @override
  PreparedReview? prepare(SrsReview review) =>
      PreparedReview.restore(auth.currentSession!, review.toJson());
  @override
  Future<ReviewOutcome> submit(PreparedReview review) async {
    calls++;
    check(
      sameReviewRequest(review.request, request()),
      'retry changed request',
    );
    return receipt();
  }
}

Future<void> main(List<String> args) async {
  if (args.length == 2) {
    NativeReviewJournal? journal;
    try {
      journal = await NativeReviewJournal.open(Directory(args[1]));
      if (args[0] == 'stage') {
        await journal.stage(owner, request());
        // Simulate process exit after flush without graceful close.
        exit(0);
      }
      if (args[0] == 'lock-probe') {
        await journal.close();
        exit(2); // Holding parent lease should reject this second process.
      }
      throw StateError('Unknown verifier mode');
    } on ReviewStorageFailure {
      if (args[0] == 'lock-probe') exit(0);
      rethrow;
    } finally {
      await journal?.close();
    }
  }
  final directory = await Directory.systemTemp.createTemp('nd-review-restart-');
  NativeReviewJournal? journal;
  Future<ProcessResult> child(String mode) =>
      Process.run(Platform.resolvedExecutable, [
        if (Platform.packageConfig != null)
          '--packages=${Platform.packageConfig}',
        Platform.script.toFilePath(),
        mode,
        directory.path,
      ]);
  try {
    final staged = await child('stage');
    check(staged.exitCode == 0, 'child pending write failed');
    journal = await NativeReviewJournal.open(directory);
    final records = await journal.list(owner);
    check(
      records.length == 1 && records.single.receipt == null,
      'process restart lost pending',
    );
    check(
      sameReviewRequest(records.single.request, request()),
      'process restart changed exact identity/time',
    );
    check((await journal.list(other)).isEmpty, 'other owner saw pending');
    final blocked = await child('lock-probe');
    check(blocked.exitCode == 0, 'second writer lease was accepted');

    final auth = _Auth();
    final delegate = _Reviews(auth);
    final durable = DurableReviewRepository(
      auth: auth,
      delegate: delegate,
      store: journal,
    );
    final pending = await durable.recoverPending();
    check(pending.length == 1, 'recovery did not produce manual retry');
    check(
      await durable.submit(pending.single) is ReviewSuccess,
      'manual replay did not acknowledge',
    );
    check(delegate.calls == 1, 'unexpected RPC count');
    await journal.close();
    journal = await NativeReviewJournal.open(directory);
    final restored = await journal.list(owner);
    check(restored.single.receipt != null, 'restart lost original receipt');
    final replay = DurableReviewRepository(
      auth: auth,
      delegate: delegate,
      store: journal,
    );
    check(
      (await replay.recoverPending()).isEmpty,
      'acknowledged event was still pending',
    );
    check(
      await replay.submit(
            PreparedReview.restore(auth.currentSession!, request()),
          )
          is ReviewSuccess,
      'original receipt replay failed',
    );
    check(delegate.calls == 1, 'receipt replay called RPC twice');
    await journal.close();
    journal = null;
    final file = File(
      '${directory.path}${Platform.pathSeparator}review-journal.ndjson',
    );
    await file.writeAsString(
      '{"incomplete"',
      mode: FileMode.append,
      flush: true,
    );
    journal = await NativeReviewJournal.open(directory);
    check(
      (await journal.list(owner)).single.receipt != null,
      'interrupted tail discarded confirmed history',
    );
    await journal.close();
    journal = null;
    await file.writeAsString(
      '{"invalid":true}\n',
      mode: FileMode.append,
      flush: true,
    );
    var rejected = false;
    try {
      journal = await NativeReviewJournal.open(directory);
    } on ReviewStorageFailure {
      rejected = true;
    }
    check(rejected, 'complete corrupted record was accepted');
    stdout.writeln(
      'PASS: native subprocess restart/lease, exact pending retry, '
      'account isolation, durable receipt and incomplete-tail recovery. '
      'RPC delegate is TEST ONLY; not hosted Auth or multi-device evidence.',
    );
  } finally {
    await journal?.close();
    await directory.delete(recursive: true);
  }
}
