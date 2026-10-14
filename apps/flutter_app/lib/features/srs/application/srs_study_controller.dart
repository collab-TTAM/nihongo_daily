import 'dart:async';
import 'dart:math';

import '../../../shared/models/preview_level.dart';
import '../data/review_repository.dart';
import '../domain/srs_models.dart';

/// Application-only projection of an authenticated due queue and curriculum.
/// Not a new wire endpoint or a client-owned learning state.
final class SrsStudyItem {
  SrsStudyItem({
    required this.type,
    required String itemId,
    required this.level,
    required this.prompt,
    required this.reading,
    required this.answerVi,
  }) : itemId = SrsCard(itemType: type, itemId: itemId).itemId {
    for (final text in [prompt, answerVi]) {
      if (text.trim().isEmpty || text.runes.length > 5000) {
        throw ArgumentError('Expected bounded nonempty curriculum text');
      }
    }
    if (reading.runes.length > 5000) {
      throw ArgumentError(
        'Expected bounded canonical reading or explicit absence',
      );
    }
  }
  final LearningItemType type;
  final String itemId;
  final PreviewLevel level;
  final String prompt;
  final String reading;
  final String answerVi;
}

/// Future runtime must read due items/content for the captured authenticated
/// session. No direct UI table access, synthetic due times or local scheduling.
abstract interface class SrsStudyQueue {
  Future<List<SrsStudyItem>> load(ReviewSession session, PreviewLevel level);
}

enum SrsStudyPhase {
  idle,
  unavailable,
  signedOut,
  loading,
  ready,
  saving,
  failed,
  empty,
  complete,
}

final class SrsStudyState {
  const SrsStudyState({
    required this.phase,
    this.item,
    this.answerVisible = false,
    this.total = 0,
    this.confirmed = 0,
    this.failure,
    this.receipt,
    this.hasPendingEvent = false,
  });
  final SrsStudyPhase phase;
  final SrsStudyItem? item;
  final bool answerVisible;
  final int total;
  final int confirmed;
  final ReviewFailure? failure;
  final ReviewSuccess? receipt;
  final bool hasPendingEvent;
  bool get canRate =>
      phase == SrsStudyPhase.ready && answerVisible && !hasPendingEvent;
  bool get canRetry =>
      phase == SrsStudyPhase.failed &&
      hasPendingEvent &&
      (failure?.retryable ?? false);
  bool get canReload =>
      phase != SrsStudyPhase.loading &&
      phase != SrsStudyPhase.saving &&
      (!hasPendingEvent || _definitiveRejection(failure?.code));
}

bool _definitiveRejection(ReviewErrorCode? code) => const {
  ReviewErrorCode.validationFailure,
  ReviewErrorCode.notFound,
  ReviewErrorCode.forbidden,
  ReviewErrorCode.syncConflict,
}.contains(code);

/// Pure controller; injected fixtures never prove a persisted learner journey.
/// Pending events survive route navigation in the provider, but not app restart.
/// Durable recovery/authoritative refresh belongs to #15/#20/#22.
final class SrsStudyController {
  SrsStudyController({
    required this.auth,
    required this.reviews,
    required this.queue,
    DateTime Function()? now,
    String Function()? eventId,
    int Function()? elapsedMs,
    this.loadTimeout = const Duration(seconds: 15),
    this.saveTimeout = const Duration(seconds: 20),
  }) : _now = now ?? DateTime.now,
       _eventId = eventId ?? newReviewEventId,
       _elapsedMs = elapsedMs {
    if (loadTimeout <= Duration.zero ||
        loadTimeout > const Duration(minutes: 2) ||
        saveTimeout <= Duration.zero ||
        saveTimeout > const Duration(minutes: 2)) {
      throw ArgumentError('Invalid queue deadline');
    }
  }
  final ReviewAuth auth;
  final ReviewRepository reviews;
  final SrsStudyQueue queue;
  final Duration loadTimeout;
  final Duration saveTimeout;
  final DateTime Function() _now;
  final String Function() _eventId;
  final int Function()? _elapsedMs;
  final Stopwatch _watch = Stopwatch()..start();
  final _changes = StreamController<SrsStudyState>.broadcast(sync: true);
  Stream<SrsStudyState> get changes => _changes.stream;
  SrsStudyState _state = const SrsStudyState(phase: SrsStudyPhase.idle);
  SrsStudyState get state => _state;
  ReviewSession? _session;
  List<SrsStudyItem> _items = const [];
  int _index = 0;
  int _generation = 0;
  int _shownAt = 0;
  bool _disposed = false;
  PreparedReview? _pending;
  int get _ticks => _elapsedMs?.call() ?? _watch.elapsedMilliseconds;

  void _publish(SrsStudyState value) {
    if (_disposed) return;
    _state = value;
    _changes.add(value);
  }

  /// Runtime must notify synchronously on logout/switch/re-auth (including A/B/A),
  /// not merely on the next HTTP reply, to remove old user's visible curriculum.
  void sessionChanged() {
    if (_disposed) return;
    _generation++;
    _session = null;
    _items = const [];
    _pending = null;
    _index = 0;
    _publish(const SrsStudyState(phase: SrsStudyPhase.signedOut));
  }

  bool _sameSession() {
    if (_session != null && identical(_session, auth.currentSession)) {
      return true;
    }
    sessionChanged();
    return false;
  }

  Future<void> load(PreviewLevel level) async {
    if (_disposed || !state.canReload) return;
    final session = auth.currentSession;
    sessionChanged();
    if (session == null) return;
    _session = session;
    final generation = _generation;
    _publish(const SrsStudyState(phase: SrsStudyPhase.loading));
    try {
      final items = await queue.load(session, level).timeout(loadTimeout);
      if (_disposed || generation != _generation || !_sameSession()) return;
      if (items.length > 100 ||
          items.any((item) => item.level != level) ||
          items
                  .map((item) => '${item.type.wireName}/${item.itemId}')
                  .toSet()
                  .length !=
              items.length) {
        throw const FormatException('Invalid due queue projection');
      }
      _items = List<SrsStudyItem>.unmodifiable(items);
      _shownAt = _ticks;
      _publish(_current());
    } on Object catch (error) {
      if (_disposed || generation != _generation || !_sameSession()) return;
      final failure = error is TimeoutException
          ? ReviewFailure(ReviewErrorCode.networkUnavailable, retryable: true)
          : error is ReviewTransportFailure
          ? ReviewFailure(error.code, retryable: error.retryable)
          : ReviewFailure(ReviewErrorCode.internalError);
      _publish(SrsStudyState(phase: SrsStudyPhase.failed, failure: failure));
    }
  }

  SrsStudyState _current({ReviewSuccess? receipt}) => SrsStudyState(
    phase: _items.isEmpty
        ? SrsStudyPhase.empty
        : _index == _items.length
        ? SrsStudyPhase.complete
        : SrsStudyPhase.ready,
    item: _index < _items.length ? _items[_index] : null,
    total: _items.length,
    confirmed: _index,
    receipt: receipt,
  );

  void reveal() {
    if (_disposed || !_sameSession() || state.phase != SrsStudyPhase.ready) {
      return;
    }
    _publish(
      SrsStudyState(
        phase: state.phase,
        item: state.item,
        answerVisible: true,
        total: state.total,
        confirmed: state.confirmed,
        receipt: state.receipt,
      ),
    );
  }

  Future<void> rate(ReviewRating rating) async {
    if (_disposed || !_sameSession() || !state.canRate) return;
    final item = state.item!;
    try {
      final elapsed = (_ticks - _shownAt).clamp(0, 3600000);
      _pending = reviews.prepare(
        SrsReview(
          clientEventId: _eventId(),
          itemType: item.type,
          itemId: item.itemId,
          rating: rating,
          isCorrect: rating.isCorrect,
          responseMs: elapsed,
          occurredAt: _now(),
        ),
      );
      if (_pending == null || !identical(_pending!.session, _session)) {
        sessionChanged();
        return;
      }
    } on Object {
      _publish(
        SrsStudyState(
          phase: SrsStudyPhase.failed,
          item: item,
          answerVisible: true,
          total: state.total,
          confirmed: state.confirmed,
          failure: ReviewFailure(ReviewErrorCode.internalError),
        ),
      );
      return;
    }
    await _submit();
  }

  Future<void> retry() async {
    if (_disposed || !_sameSession() || !state.canRetry) return;
    await _submit();
  }

  Future<void> _submit() async {
    final pending = _pending!;
    final generation = _generation;
    final item = state.item;
    _publish(
      SrsStudyState(
        phase: SrsStudyPhase.saving,
        item: item,
        answerVisible: true,
        total: _items.length,
        confirmed: _index,
        hasPendingEvent: true,
      ),
    );
    ReviewOutcome result;
    try {
      result = await reviews.submit(pending).timeout(saveTimeout);
    } on TimeoutException {
      result = ReviewFailure(
        ReviewErrorCode.networkUnavailable,
        retryable: true,
      );
    } on Object {
      result = ReviewFailure(ReviewErrorCode.internalError);
    }
    if (_disposed || generation != _generation || !_sameSession()) return;
    if (result is ReviewSuccess) {
      _pending = null;
      _index++;
      _shownAt = _ticks;
      _publish(_current(receipt: result));
    } else {
      _publish(
        SrsStudyState(
          phase: SrsStudyPhase.failed,
          item: item,
          answerVisible: true,
          total: _items.length,
          confirmed: _index,
          hasPendingEvent: true,
          failure: result as ReviewFailure,
        ),
      );
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _state = const SrsStudyState(phase: SrsStudyPhase.unavailable);
    _generation++;
    _items = const [];
    _pending = null;
    _watch.stop();
    unawaited(_changes.close());
  }
}

/// RFC4122 v4 randomness only, never a credential. Injected IDs belong to tests.
String newReviewEventId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
