/// Coalesces an owned shutdown and permits an explicit retry after failure.
///
/// Successful cleanup is memoized. A failed stage clears only the in-flight
/// future, allowing the same owner to retry without replacing its resources.
final class RetryableAsyncClose {
  Future<void>? _attempt;

  Future<void> run(Future<void> Function() close) {
    final active = _attempt;
    if (active != null) return active;

    late final Future<void> attempt;
    attempt = Future<void>.sync(close).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      if (identical(_attempt, attempt)) _attempt = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
    _attempt = attempt;
    return attempt;
  }
}
