import 'dart:convert';
import 'dart:io';

import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const owner = 'a1000000-0000-4000-8000-000000000001';
const other = 'a1000000-0000-4000-8000-000000000002';

Map<String, Object> request(int index) => {
  'client_event_id':
      'b2000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
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

String fingerprint(List<StoredReview> records) => jsonEncode([
  for (final record in records)
    {
      'owner': record.userId,
      'request': record.request,
      'receipt': record.receipt?.toJson(),
      'rejection': record.rejection?.toJson(),
    },
]);

Future<void> verifyCompaction(String scenario) async {
  final directory = await Directory.systemTemp.createTemp('nd-compact-');
  final data = File('${directory.path}/review-journal.ndjson');
  NativeReviewJournal? journal;
  try {
    journal = await NativeReviewJournal.open(directory);
    if (scenario == 'empty') {
      check(await journal.compact() == 0, 'empty compaction changed bytes');
      await journal.stage(owner, request(1));
      check(await journal.compact() == 0, 'pending-only compaction grew bytes');
    } else if (scenario == 'temporary-failure') {
      await journal.stage(owner, request(1));
      await journal.acknowledge(
        owner,
        request(1)['client_event_id']! as String,
        receipt(),
      );
      final original = await data.readAsBytes();
      final blocked = Directory('${data.path}.compact');
      await blocked.create();
      var failed = false;
      try {
        await journal.compact();
      } on ReviewStorageFailure {
        failed = true;
      }
      check(failed, 'failed temporary write accepted');
      check(
        jsonEncode(await data.readAsBytes()) == jsonEncode(original),
        'temporary failure changed authoritative history',
      );
      await journal.stage(other, request(2));
      await blocked.delete();
      check(
        await journal.compact() > 0,
        'temporary failure poisoned usable original',
      );
    } else if (scenario == 'legacy') {
      await journal.close();
      journal = null;
      await data.writeAsString(
        [
          jsonEncode({
            'version': 1,
            'kind': 'pending',
            'user_id': owner,
            'request': request(1),
          }),
          jsonEncode({
            'version': 1,
            'kind': 'receipt',
            'user_id': owner,
            'event_id': request(1)['client_event_id'],
            'receipt': receipt().toJson(),
          }),
          jsonEncode({
            'version': 2,
            'kind': 'pending',
            'user_id': other,
            'request': request(2),
          }),
          jsonEncode({
            'version': 2,
            'kind': 'rejection',
            'user_id': other,
            'event_id': request(2)['client_event_id'],
            'rejection': ReviewFailure(ReviewErrorCode.syncConflict).toJson(),
          }),
        ].map((line) => '$line\n').join(),
        flush: true,
      );
      journal = await NativeReviewJournal.open(directory);
      final before =
          fingerprint(await journal.list(owner)) +
          fingerprint(await journal.list(other));
      check(await journal.compact() > 0, 'legacy compaction reclaimed nothing');
      await journal.close();
      journal = await NativeReviewJournal.open(directory);
      check(
        before ==
            fingerprint(await journal.list(owner)) +
                fingerprint(await journal.list(other)),
        'legacy snapshot changed history',
      );
    } else if (scenario == 'invalid-snapshot') {
      await journal.close();
      journal = null;
      await data.writeAsString(
        '${jsonEncode({'version': 3, 'kind': 'settled', 'user_id': owner, 'request': request(1), 'outcome': ReviewFailure(ReviewErrorCode.internalError).toJson()})}\n',
        flush: true,
      );
      var failed = false;
      try {
        journal = await NativeReviewJournal.open(directory);
      } on ReviewStorageFailure {
        failed = true;
      }
      check(failed, 'uncertain outcome became a terminal snapshot');
    } else if (scenario == 'event-cap') {
      for (var i = 1; i <= NativeReviewJournal.maxEvents; i++) {
        await journal.stage(owner, request(i));
        await journal.acknowledge(
          owner,
          request(i)['client_event_id']! as String,
          receipt(),
        );
      }
      check(await journal.compact() > 0, 'full history reclaimed nothing');
      await journal.close();
      journal = await NativeReviewJournal.open(directory);
      var failed = false;
      try {
        await journal.stage(owner, request(NativeReviewJournal.maxEvents + 1));
      } on ReviewStorageFailure {
        failed = true;
      }
      check(failed, 'compaction silently evicted history/event cap');
      check(
        (await journal.list(owner)).length == NativeReviewJournal.maxEvents,
        'compaction dropped full-cap history',
      );
    } else if (scenario == 'mixed') {
      await journal.stage(owner, request(1));
      await journal.stage(owner, request(2));
      await journal.acknowledge(
        owner,
        request(2)['client_event_id']! as String,
        receipt(),
      );
      await journal.stage(other, request(3));
      await journal.reject(
        other,
        request(3)['client_event_id']! as String,
        ReviewFailure(ReviewErrorCode.syncConflict),
      );
      final beforeA = fingerprint(await journal.list(owner));
      final beforeB = fingerprint(await journal.list(other));
      final size = await data.length();
      // A stale interrupted sibling is never authoritative or promoted.
      await File('${data.path}.compact').writeAsString('{partial', flush: true);
      final reclaimed = await journal.compact();
      check(
        reclaimed > 0 && size - await data.length() == reclaimed,
        'incorrect reclaimed-byte accounting',
      );
      check(await journal.compact() == 0, 'compaction is not idempotent');
      await journal.close();
      journal = await NativeReviewJournal.open(directory);
      check(
        fingerprint(await journal.list(owner)) == beforeA,
        'snapshot changed exact pending/receipt',
      );
      check(
        fingerprint(await journal.list(other)) == beforeB,
        'snapshot changed rejection/account',
      );
      final original = await journal.stage(owner, request(2));
      check(
        original.receipt != null,
        'receipt replay became a new pending event',
      );
      var conflict = false;
      try {
        await journal.stage(owner, {...request(2), 'rating': 3});
      } on ReviewTransportFailure {
        conflict = true;
      }
      check(conflict, 'compaction lost immutable event conflict');
      await Future.wait([
        journal.compact(),
        journal.acknowledge(
          owner,
          request(1)['client_event_id']! as String,
          receipt(),
        ),
        journal.stage(other, request(4)),
      ]);
      await journal.close();
      journal = await NativeReviewJournal.open(directory);
      check(
        (await journal.list(owner)).every((r) => !r.isPending),
        'serialized acknowledge lost',
      );
      check((await journal.list(other)).length == 2, 'serialized stage lost');
    } else {
      throw StateError('Unknown scenario');
    }
  } finally {
    await journal?.close();
    await directory.delete(recursive: true);
  }
}

const scenarios = [
  'empty',
  'mixed',
  'legacy',
  'temporary-failure',
  'invalid-snapshot',
  'event-cap',
];

Future<void> main(List<String> args) async {
  if (args.length == 2) {
    final journal = await NativeReviewJournal.open(Directory(args[1]));
    await journal.compact();
    exit(0); // Flush/rename completed, but no graceful close.
  }
  if (args.length == 1) {
    await verifyCompaction(args.single);
    // Real process exit after flushed compact/reopen checks.
    exit(0);
  }
  for (final scenario in scenarios) {
    final result = await Process.run(Platform.resolvedExecutable, [
      if (Platform.packageConfig != null)
        '--packages=${Platform.packageConfig}',
      Platform.script.toFilePath(),
      scenario,
    ]);
    check(
      result.exitCode == 0,
      'native compaction child failed: $scenario ${result.stderr}',
    );
  }
  final directory = await Directory.systemTemp.createTemp('nd-compact-exit-');
  NativeReviewJournal? journal;
  try {
    journal = await NativeReviewJournal.open(directory);
    await journal.stage(owner, request(1));
    await journal.stage(other, request(2));
    await journal.acknowledge(
      other,
      request(2)['client_event_id']! as String,
      receipt(),
    );
    final before =
        fingerprint(await journal.list(owner)) +
        fingerprint(await journal.list(other));
    await journal.close();
    journal = null;
    final child = await Process.run(Platform.resolvedExecutable, [
      if (Platform.packageConfig != null)
        '--packages=${Platform.packageConfig}',
      Platform.script.toFilePath(),
      'compact-exit',
      directory.path,
    ]);
    check(child.exitCode == 0, 'compact-exit child failed');
    journal = await NativeReviewJournal.open(directory);
    check(
      before ==
          fingerprint(await journal.list(owner)) +
              fingerprint(await journal.list(other)),
      'process exit after compact lost history',
    );
    await journal.stage(owner, request(3));
  } finally {
    await journal?.close();
    await directory.delete(recursive: true);
  }
  stdout.writeln(
    'PASS: six real-file compaction scenarios and child compact/exit/parent reopen. No hosted Auth, automatic retention or hardware-power-loss evidence.',
  );
}
