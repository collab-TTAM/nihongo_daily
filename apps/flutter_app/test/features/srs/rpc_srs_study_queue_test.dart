import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/rpc_srs_study_queue.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

Map<String, Object?> fixtureResponse() => {
  'jlpt_level': 'N5',
  'server_time': '2026-10-14T01:00:00.000000Z',
  'items': [
    {
      'item_type': 'GRAMMAR',
      'item_id': 'd4000000-0000-4000-8000-000000000001',
      'prompt_ja': '～です',
      'reading_ja': '',
      'answer_vi': 'là',
      'next_review_at': '2020-01-02T00:00:00.000000Z',
    },
  ],
};

final class FixtureQueueAuth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(
    userId: 'd1000000-0000-4000-8000-000000000001',
  );
}

final class FixtureQueueTransport implements ReviewRpcTransport {
  int calls = 0;
  Future<Object?> Function()? reply;
  Map<String, Object>? params;
  ReviewSession? session;
  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String function,
    required Map<String, Object> params,
  }) {
    expect(function, 'get_review_queue');
    calls++;
    this.params = params;
    session = capturedSession;
    return reply?.call() ?? Future.value(fixtureResponse());
  }
}

void main() {
  test(
    'strict queue decoder retains canonical and explicitly absent readings',
    () {
      final raw = fixtureResponse();
      final snapshot = ReviewQueueSnapshot.decode(
        raw,
        level: PreviewLevel.n5,
        limit: 100,
      );
      expect(snapshot.toJson(), raw);
      expect(snapshot.items.single.item.reading, '');
      expect(() => snapshot.items.clear(), throwsUnsupportedError);
    },
  );

  test('unknown fields wrong level malformed types or dates fail closed', () {
    for (final raw in [
      null,
      <Object>[],
      {...fixtureResponse(), 'user_id': 'forged'},
      {...fixtureResponse(), 'jlpt_level': 'N4'},
      {...fixtureResponse(), 'items': 'bad'},
      {...fixtureResponse(), 'server_time': '2026-02-30T01:00:00Z'},
      {...fixtureResponse(), 'server_time': '2026-10-14T24:00:00Z'},
      {...fixtureResponse(), 'server_time': '2026-10-14T08:00:00+07:00'},
      {...fixtureResponse(), 'server_time': '2026-10-14T01:00:00.0000001Z'},
    ]) {
      expect(
        () =>
            ReviewQueueSnapshot.decode(raw, level: PreviewLevel.n5, limit: 100),
        throwsA(
          isA<ReviewTransportFailure>().having(
            (e) => e.code,
            'code',
            ReviewErrorCode.internalError,
          ),
        ),
      );
    }
  });

  test('future duplicated unsorted or excess rows never enter study queue', () {
    final row =
        (fixtureResponse()['items']! as List<Map<String, Object?>>).single;
    for (final rows in [
      [row, row],
      [
        {...row, 'next_review_at': '2026-10-14T01:00:00.000001Z'},
      ],
      [
        {...row, 'next_review_at': '2020-01-03T00:00:00Z'},
        {...row, 'item_id': 'd4000000-0000-4000-8000-000000000002'},
      ],
    ]) {
      expect(
        () => ReviewQueueSnapshot.decode(
          {...fixtureResponse(), 'items': rows},
          level: PreviewLevel.n5,
          limit: 100,
        ),
        throwsA(isA<ReviewTransportFailure>()),
      );
    }
    expect(
      () => ReviewQueueSnapshot.decode(
        {
          ...fixtureResponse(),
          'items': [row, row],
        },
        level: PreviewLevel.n5,
        limit: 1,
      ),
      throwsA(isA<ReviewTransportFailure>()),
    );
  });

  test('safe typed server errors never expose original SQL details', () {
    expect(
      () => ReviewQueueSnapshot.decode(
        {
          'code': 'UNAUTHORIZED',
          'message_vi': 'PRIVATE SECRET',
          'retryable': false,
        },
        level: PreviewLevel.n5,
        limit: 100,
      ),
      throwsA(
        isA<ReviewTransportFailure>().having(
          (e) => e.code,
          'code',
          ReviewErrorCode.unauthorized,
        ),
      ),
    );
    expect(
      () => ReviewQueueSnapshot.decode(
        {
          'code': 'UNAUTHORIZED',
          'message_vi': 'PRIVATE SECRET',
          'retryable': true,
        },
        level: PreviewLevel.n5,
        limit: 100,
      ),
      throwsA(
        isA<ReviewTransportFailure>().having(
          (e) => e.code,
          'code',
          ReviewErrorCode.internalError,
        ),
      ),
    );
  });

  late FixtureQueueAuth auth;
  late FixtureQueueTransport transport;
  late RpcSrsStudyQueue queue;
  setUp(() {
    auth = FixtureQueueAuth();
    transport = FixtureQueueTransport();
    queue = RpcSrsStudyQueue(auth: auth, transport: transport);
  });

  test(
    'RPC envelope is immutable ownerless and bound to captured session',
    () async {
      final items = await queue.load(auth.currentSession!, PreviewLevel.n5);
      expect(items.length, 1);
      expect(transport.params, {
        'p_request': {'jlpt_level': 'N5', 'limit': 100},
      });
      expect(transport.session, same(auth.currentSession));
      expect(
        () => transport.params!['user_id'] = 'forged',
        throwsUnsupportedError,
      );
      expect(() => items.clear(), throwsUnsupportedError);
    },
  );

  test(
    'old session is blocked before dispatch and after in-flight read',
    () async {
      final old = auth.currentSession!;
      auth.currentSession = null;
      await expectLater(
        queue.load(old, PreviewLevel.n5),
        throwsA(isA<ReviewTransportFailure>()),
      );
      expect(transport.calls, 0);
      auth.currentSession = old;
      final pending = Completer<Object?>();
      transport.reply = () => pending.future;
      final load = queue.load(old, PreviewLevel.n5);
      auth.currentSession = ReviewSession(userId: old.userId);
      pending.complete(fixtureResponse());
      await expectLater(
        load,
        throwsA(
          isA<ReviewTransportFailure>().having(
            (e) => e.code,
            'code',
            ReviewErrorCode.unauthorized,
          ),
        ),
      );
    },
  );

  test(
    'read timeout is safely retryable but never returns fake empty success',
    () async {
      queue = RpcSrsStudyQueue(
        auth: auth,
        transport: transport,
        timeout: const Duration(milliseconds: 1),
      );
      final pending = Completer<Object?>();
      transport.reply = () => pending.future;
      await expectLater(
        queue.load(auth.currentSession!, PreviewLevel.n5),
        throwsA(
          isA<ReviewTransportFailure>()
              .having((e) => e.code, 'code', ReviewErrorCode.networkUnavailable)
              .having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
      pending.complete(fixtureResponse());
    },
  );

  test(
    'unexpected transport exceptions do not leak or look like empty queue',
    () async {
      transport.reply = () => throw StateError('PRIVATE SECRET');
      await expectLater(
        queue.load(auth.currentSession!, PreviewLevel.n5),
        throwsA(
          isA<ReviewTransportFailure>().having(
            (e) => e.code,
            'code',
            ReviewErrorCode.internalError,
          ),
        ),
      );
    },
  );

  test('queue limit and deadline configuration is bounded', () {
    for (final limit in [0, 101]) {
      expect(
        () => RpcSrsStudyQueue(auth: auth, transport: transport, limit: limit),
        throwsArgumentError,
      );
    }
    expect(
      () => RpcSrsStudyQueue(
        auth: auth,
        transport: transport,
        timeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}
