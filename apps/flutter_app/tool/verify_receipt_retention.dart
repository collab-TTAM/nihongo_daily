import 'dart:io';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/features/srs/data/review_receipt_retention.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import '../test/features/srs/receipt_retention_fixtures.dart' as retention;
import '../test/features/srs/transactional_review_fixtures.dart' as fixture;

Future<void> main(List<String> args) async {
  if (args.length == 1) {
    final journal = await NativeReviewJournal.open(
      Directory(args.single),
      receiptRetention: ReviewReceiptRetention(keepCount: 2),
    );
    await journal.pruneReceipts(fixture.owner);
    exit(0); // Replacement committed without graceful close.
  }
  for (final scenario in retention.scenarios) {
    await retention.verifyTransactionalRetention(scenario);
  }
  final directory = await Directory.systemTemp.createTemp(
    'nd-receipt-retention-',
  );
  NativeReviewJournal? journal;
  try {
    journal = await NativeReviewJournal.open(
      directory,
      receiptRetention: ReviewReceiptRetention(keepCount: 2),
    );
    await retention.verifyRetentionStore(
      journal,
      () => journal!.pruneReceipts(fixture.owner),
    );
    for (var i = 1000; i < 1600; i++) {
      await retention.stageReceipt(journal, i);
    }
    fixture.check(
      (await journal.list(
            fixture.owner,
          )).where((r) => r.receipt != null).length <=
          3,
      'native cache hit 512-event lifetime cap',
    );
    final pending = (await journal.list(
      fixture.owner,
    )).singleWhere((r) => r.isPending).request;
    await journal.close();
    journal = null;
    final child = await Process.run(Platform.resolvedExecutable, [
      if (Platform.packageConfig != null)
        '--packages=${Platform.packageConfig}',
      Platform.script.toFilePath(),
      directory.path,
    ]);
    fixture.check(child.exitCode == 0, 'native retention/exit child failed');
    journal = await NativeReviewJournal.open(
      directory,
      receiptRetention: ReviewReceiptRetention(keepCount: 2),
    );
    fixture.check(
      (await journal.list(
            fixture.owner,
          )).where((r) => r.receipt != null).length ==
          2,
      'restart lost cache limit',
    );
    fixture.check(
      sameReviewRequest(
        (await journal.list(
          fixture.owner,
        )).singleWhere((r) => r.isPending).request,
        pending,
      ),
      'restart changed pending identity/time',
    );
    final temporary = Directory(
      '${directory.path}/review-journal.ndjson.compact',
    );
    await retention.stageReceipt(journal, 2000); // Now three cached successes.
    await temporary.create();
    var failed = false;
    try {
      await journal.pruneReceipts(fixture.owner);
    } on ReviewStorageFailure {
      failed = true;
    }
    fixture.check(failed, 'native temporary failure not reported');
    fixture.check(
      (await journal.list(
            fixture.owner,
          )).where((r) => r.receipt != null).length ==
          3,
      'failed replacement deleted authoritative cache',
    );
    await temporary.delete();
    fixture.check(
      await journal.pruneReceipts(fixture.owner) == 1,
      'native failed-maintenance retry failed',
    );
    stdout.writeln(
      'PASS: opt-in receipt retention beyond 512 reviews, original server-fixture replay, pending/rejection/account isolation, native process restart and temporary-write failure. No hosted server or hardware-power-loss proof.',
    );
  } finally {
    await journal?.close();
    await directory.delete(recursive: true);
  }
}
