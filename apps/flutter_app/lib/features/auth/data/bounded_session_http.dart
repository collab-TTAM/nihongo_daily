import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../srs/data/review_repository.dart';

/// One bounded attempt; timed-out responses cannot reach the SDK later.
final class BoundedSessionHttp extends http.BaseClient {
  BoundedSessionHttp(this.inner, this.owns, this.origin, this.timeout);
  final http.Client inner;
  final bool owns;
  final Uri origin;
  final Duration timeout;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.origin != origin.origin ||
        !request.url.path.startsWith('/auth/v1/') &&
            !request.url.path.startsWith('/rest/v1/')) {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
    request.followRedirects = false;
    final elapsed = Stopwatch()..start();
    var timedOut = false;
    final pending = inner.send(request);
    unawaited(
      pending.then<void>((response) {
        if (timedOut) _discard(response);
      }, onError: (Object _, StackTrace __) {}),
    );
    try {
      final response = await pending.timeout(
        timeout,
        onTimeout: () {
          timedOut = true;
          throw TimeoutException('Session request unavailable');
        },
      );
      const maximum = 1024 * 1024;
      if ((response.contentLength ?? 0) > maximum) {
        _discard(response);
        throw const ReviewTransportFailure(ReviewErrorCode.internalError);
      }
      final bytes = BytesBuilder(copy: false);
      final iterator = StreamIterator(response.stream);
      try {
        while (await iterator.moveNext().timeout(timeout - elapsed.elapsed)) {
          final chunk = iterator.current;
          if (bytes.length + chunk.length > maximum) {
            throw const ReviewTransportFailure(ReviewErrorCode.internalError);
          }
          bytes.add(chunk);
        }
      } finally {
        _cancel(iterator.cancel);
      }
      return http.StreamedResponse(
        Stream.value(bytes.takeBytes()),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    } on Object {
      throw const ReviewTransportFailure(ReviewErrorCode.networkUnavailable);
    }
  }

  // Cancellation is best-effort cleanup, not part of the request deadline.
  // Consume synchronous and asynchronous cleanup errors without logging secrets.
  static void _cancel(Future<void> Function() cancel) {
    unawaited(
      Future<void>.sync(cancel).catchError((Object _, StackTrace __) {}),
    );
  }

  static void _discard(http.StreamedResponse response) {
    _cancel(() {
      final subscription = response.stream.listen(
        (_) {},
        onError: (Object _, StackTrace __) {},
      );
      return subscription.cancel();
    });
  }

  @override
  void close() {
    if (owns) inner.close();
  }
}
