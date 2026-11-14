import 'dart:convert';
import 'dart:js_interop';

import 'package:nihongo_daily/features/srs/data/browser_review_store.dart';
import 'package:nihongo_daily/features/srs/data/durable_review_repository.dart';

import 'verify_transactional_review.dart' as fixture;

@JS('document.body.textContent')
external set _status(String status);

/// TEST ONLY page loaded/refreshed by a real WebDriver session. Keep the actual
/// DB connection open; refresh discards all Dart memory without graceful close.
Future<void> main() async {
  try {
    final store = await openBrowserReviewStore(
      databaseName: 'nd-browser-reload-test',
    );
    final records = await store.list(fixture.owner);
    if (records.isEmpty) {
      await store.stage(fixture.owner, fixture.request(1));
      _status = 'PENDING_COMMITTED';
    } else {
      final original = records.single;
      fixture.check(
        sameReviewRequest(original.request, fixture.request(1)),
        'page reload changed exact event/time',
      );
      fixture.check(
        (await store.list(fixture.other)).isEmpty,
        'page reload crossed owner',
      );
      if (original.isPending) {
        await store.acknowledge(
          fixture.owner,
          original.eventId,
          fixture.receipt(),
        );
        _status = 'RECEIPT_COMMITTED';
      } else {
        fixture.check(
          jsonEncode(original.receipt?.toJson()) ==
              jsonEncode(fixture.receipt().toJson()),
          'page reload changed original receipt',
        );
        fixture.check(
          (await store.stage(fixture.owner, fixture.request(1))).receipt !=
              null,
          'page reload replay became pending',
        );
        _status = 'PASS';
      }
    }
  } on Object {
    _status = 'FAIL'; // No local data/raw browser errors are exposed.
    rethrow;
  }
}
