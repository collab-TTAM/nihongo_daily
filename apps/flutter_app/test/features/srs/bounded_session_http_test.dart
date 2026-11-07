import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nihongo_daily/features/auth/data/bounded_session_http.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

final class TestClient extends http.BaseClient {
  TestClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  var calls = 0;
  var closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    calls++;
    return handler(request);
  }

  @override
  void close() => closed = true;
}

final origin = Uri.parse('https://fixture.supabase.co');
http.Request request() => http.Request('GET', origin.resolve('/auth/v1/user'));
final safeFailure = isA<ReviewTransportFailure>().having(
  (error) => error.code,
  'safe code',
  ReviewErrorCode.networkUnavailable,
);

void main() {
  for (final mode in ['stalled', 'header oversize', 'chunk oversize']) {
    test(
      'session deadline ignores held and rejected cancellation: $mode',
      () async {
        final cancelled = Completer<void>();
        var cancelCalls = 0;
        final stream = StreamController<List<int>>(
          onCancel: () {
            cancelCalls++;
            return cancelled.future;
          },
        );
        final inner = TestClient((_) async {
          if (mode == 'chunk oversize') {
            stream.add(List.filled(1024 * 1024 + 1, 1));
          }
          return http.StreamedResponse(
            stream.stream,
            200,
            contentLength: mode == 'header oversize' ? 1024 * 1024 + 1 : null,
          );
        });
        final client = BoundedSessionHttp(
          inner,
          false,
          origin,
          const Duration(milliseconds: 20),
        );
        try {
          await expectLater(
            client.send(request()).timeout(const Duration(seconds: 1)),
            throwsA(safeFailure),
          );
          expect(cancelCalls, 1);
          expect(cancelled.isCompleted, isFalse);
          cancelled.completeError(StateError('TEST ONLY private cancellation'));
          await Future<void>.delayed(Duration.zero);
          expect(inner.calls, 1);
        } finally {
          if (!cancelled.isCompleted) cancelled.complete();
          unawaited(stream.close());
          client.close();
        }
      },
    );
  }

  test('late session response cancellation errors are consumed', () async {
    final response = Completer<http.StreamedResponse>();
    final cancellation = Completer<void>();
    var cancelCalls = 0;
    final stream = StreamController<List<int>>(
      onCancel: () {
        cancelCalls++;
        return cancellation.future;
      },
    );
    final inner = TestClient((_) => response.future);
    final client = BoundedSessionHttp(
      inner,
      false,
      origin,
      const Duration(milliseconds: 20),
    );
    try {
      await expectLater(client.send(request()), throwsA(safeFailure));
      response.complete(http.StreamedResponse(stream.stream, 200));
      await Future<void>.delayed(Duration.zero);
      expect(cancelCalls, 1);
      cancellation.completeError(StateError('TEST ONLY late private error'));
      await Future<void>.delayed(Duration.zero);
      expect(inner.calls, 1);
    } finally {
      if (!cancellation.isCompleted) cancellation.complete();
      unawaited(stream.close());
      client.close();
    }
  });

  test(
    'session transport preserves bounded bytes and borrowed ownership',
    () async {
      final inner = TestClient((sent) async {
        expect(sent.followRedirects, isFalse);
        return http.StreamedResponse(
          Stream.fromIterable([
            [1, 2],
            [3],
          ]),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = BoundedSessionHttp(
        inner,
        false,
        origin,
        const Duration(seconds: 1),
      );
      final sent = request();
      final response = await client.send(sent);
      expect(await response.stream.toBytes(), [1, 2, 3]);
      expect(response.statusCode, 201);
      expect(response.headers['content-type'], 'application/json');
      expect(response.request, same(sent));
      client.close();
      expect(inner.closed, isFalse);
      BoundedSessionHttp(
        inner,
        true,
        origin,
        const Duration(seconds: 1),
      ).close();
      expect(inner.closed, isTrue);
    },
  );

  test(
    'session transport rejects foreign origin and path before dispatch',
    () async {
      final inner = TestClient(
        (_) async => throw StateError('must not dispatch'),
      );
      final client = BoundedSessionHttp(
        inner,
        false,
        origin,
        const Duration(seconds: 1),
      );
      for (final url in [
        'https://foreign.example/auth/v1/user',
        'https://fixture.supabase.co/storage/v1/object',
      ]) {
        await expectLater(
          client.send(http.Request('GET', Uri.parse(url))),
          throwsA(
            isA<ReviewTransportFailure>().having(
              (error) => error.code,
              'scope failure',
              ReviewErrorCode.unauthorized,
            ),
          ),
        );
      }
      expect(inner.calls, 0);
      client.close();
    },
  );
}
