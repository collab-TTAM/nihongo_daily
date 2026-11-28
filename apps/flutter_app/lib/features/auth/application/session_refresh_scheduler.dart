import 'dart:async';

/// Identity/expiry hints only, never credentials or server authorization.
final class RefreshLease {
  const RefreshLease(this.identity, this.expiresAt);
  final Object identity;
  final DateTime expiresAt;
  bool same(RefreshLease? other) =>
      other != null &&
      identical(identity, other.identity) &&
      expiresAt.isAtSameMomentAs(other.expiresAt);
}

enum SessionRefreshPhase { idle, scheduled, refreshing, failed, closed }

/// One attempt per accepted identity/expiry. SDK may internally retry an attempt;
/// this scheduler adds no failure retry loop and never restores an expired lease.
final class SessionRefreshScheduler {
  SessionRefreshScheduler({
    required this.current,
    required this.refresh,
    DateTime Function()? now,
    Timer Function(Duration, void Function())? timer,
  }) : _now = now ?? DateTime.now,
       _timerFactory = timer ?? Timer.new;
  final RefreshLease? Function() current;
  final Future<void> Function() refresh;
  final DateTime Function() _now;
  final Timer Function(Duration, void Function()) _timerFactory;
  static const leadTime = Duration(seconds: 60);
  static const minimumInterval = Duration(seconds: 30);
  Timer? _timer;
  RefreshLease? _attempted;
  DateTime? _lastAttempt;
  bool _closed = false;
  bool _running = false;
  SessionRefreshPhase _phase = SessionRefreshPhase.idle;
  SessionRefreshPhase get phase => _phase;

  RefreshLease? _read() {
    try {
      final value = current();
      if (value == null ||
          value.expiresAt.year < 1 ||
          value.expiresAt.year > 9999 ||
          !value.expiresAt.isAfter(_now().toUtc())) {
        return null;
      }
      return value;
    } on Object {
      return null;
    }
  }

  /// Called on accepted persistence changes and foreground resume. Consult the
  /// current gate each time; stale timer callbacks cannot dispatch old identities.
  void update() {
    _timer?.cancel();
    _timer = null;
    if (_closed || _running) return;
    final lease = _read();
    if (lease == null) {
      _phase = SessionRefreshPhase.idle;
      return;
    }
    if (lease.same(_attempted)) return;
    final now = _now().toUtc();
    var due = lease.expiresAt.subtract(leadTime);
    final last = _lastAttempt;
    if (last != null && due.isBefore(last.add(minimumInterval))) {
      due = last.add(minimumInterval);
    }
    if (!due.isBefore(lease.expiresAt)) {
      _phase = SessionRefreshPhase.idle;
      return;
    }
    var delay = due.difference(now);
    if (delay.isNegative) delay = Duration.zero;
    if (delay > const Duration(hours: 24)) delay = const Duration(hours: 24);
    _phase = SessionRefreshPhase.scheduled;
    _timer = _timerFactory(delay, () {
      if (_closed || _running) return;
      if (!lease.same(_read())) {
        update();
        return;
      }
      final actualDue = lease.expiresAt.subtract(leadTime);
      final earliest = _lastAttempt?.add(minimumInterval);
      if (_now().toUtc().isBefore(actualDue) ||
          earliest != null && _now().toUtc().isBefore(earliest)) {
        update();
        return;
      }
      unawaited(_run(lease));
    });
  }

  Future<void> _run(RefreshLease lease) async {
    if (_closed || _running || lease.same(_attempted) || !lease.same(_read())) {
      return;
    }
    _running = true;
    _attempted = lease;
    _lastAttempt = _now().toUtc();
    _phase = SessionRefreshPhase.refreshing;
    var failed = false;
    try {
      await refresh();
    } on Object {
      failed = true;
    } finally {
      _running = false;
      if (!_closed) {
        _phase = failed ? SessionRefreshPhase.failed : SessionRefreshPhase.idle;
        // New accepted rotation/lifecycle may schedule. The attempted lease
        // cannot retry, even when a foreground resume arrives after failure.
        update();
      }
    }
  }

  void dispose() {
    _closed = true;
    _phase = SessionRefreshPhase.closed;
    _timer?.cancel();
    _timer = null;
  }
}
