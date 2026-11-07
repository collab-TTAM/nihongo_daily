import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'durable_review_repository.dart';
import 'review_repository.dart';
import 'review_receipt_retention.dart';

/// Opt-in native append journal. The application owns its private data directory
/// and its lifetime; no tokens or display content are written here. Not web.
/// One process lease plus a single-isolate directory guard prevents two writers.
/// The owner must not open this directory from multiple isolates in one process.
/// flush() covers process restart; hardware/filesystem power-loss is not proven.
final class NativeReviewJournal implements DurableReviewStore {
  NativeReviewJournal._(
    this._directory,
    this._lease,
    this._file,
    this.receiptRetention,
  );
  final ReviewReceiptRetention? receiptRetention;
  static const maxBytes = 1024 * 1024;
  static const maxEvents = 512;
  static const formatVersion = 3; // Read v1/v2; v3 adds settled snapshots.
  // Worst-case validated response (4096-character timestamp plus bounded
  // scalar/owner/event fields). Reserve one slot for every unresolved event.
  static const maxReceiptBytes = 8192;
  static final _owners = <String>{};
  final String _directory;
  final RandomAccessFile _lease;
  RandomAccessFile _file;
  final _records = <String, StoredReview>{};
  Future<void> _tail = Future.value();
  bool _closed = false;
  bool _broken = false;

  static Future<NativeReviewJournal> open(
    Directory directory, {
    ReviewReceiptRetention? receiptRetention,
  }) async {
    String? path;
    RandomAccessFile? lease;
    RandomAccessFile? file;
    var owns = false;
    try {
      await directory.create(recursive: true);
      path = await directory.resolveSymbolicLinks();
      if (!_owners.add(path)) throw const ReviewStorageFailure();
      owns = true;
      final lockPath = '$path${Platform.pathSeparator}review-journal.lock';
      final dataPath = '$path${Platform.pathSeparator}review-journal.ndjson';
      if (await FileSystemEntity.isLink(lockPath) ||
          await FileSystemEntity.isLink(dataPath)) {
        throw const ReviewStorageFailure();
      }
      lease = await File(lockPath).open(mode: FileMode.append);
      await lease.lock(FileLock.exclusive);
      file = await File(dataPath).open(mode: FileMode.append);
      final journal = NativeReviewJournal._(
        path,
        lease,
        file,
        receiptRetention,
      );
      await journal._restore();
      return journal;
    } on Object {
      await _quietClose(file);
      // Closing releases a successfully acquired lock. Never truncate/delete
      // the lock file: another process may still hold its original inode.
      await _quietClose(lease);
      if (owns) _owners.remove(path);
      throw const ReviewStorageFailure();
    }
  }

  static Future<void> _quietClose(RandomAccessFile? file) async {
    try {
      await file?.close();
    } on Object {
      // Never expose a filesystem path/raw exception during failed bootstrap.
    }
  }

  String _key(String owner, String event) => '$owner/$event';

  Future<void> _restore() async {
    final length = await _file.length();
    if (length > maxBytes) throw const ReviewStorageFailure();
    await _file.setPosition(0);
    final bytes = await _file.read(length);
    if (bytes.length != length) throw const ReviewStorageFailure();
    final last = bytes.lastIndexOf(10) + 1;
    final complete = utf8.decode(bytes.sublist(0, last));
    for (final line in const LineSplitter().convert(complete)) {
      final raw = jsonDecode(line);
      // The journal has one canonical writer encoding. This also rejects
      // duplicate JSON keys that jsonDecode would otherwise silently overwrite.
      if (raw is! Map<String, Object?> || jsonEncode(raw) != line) {
        throw const ReviewStorageFailure();
      }
      _apply(raw);
    }
    // Interrupted pending writes were never eligible for dispatch. Interrupted
    // receipt writes retain the prior pending record for original-event replay.
    // Complete malformed lines fail closed above; only an incomplete EOF tail
    // is truncated while holding the exclusive lease.
    if (last != length) {
      await _file.truncate(last);
      await _file.flush();
    }
  }

  void _apply(Map<String, Object?> raw) {
    final kind = raw['kind'];
    final expected = kind == 'pending'
        ? const {'version', 'kind', 'user_id', 'request'}
        : kind == 'settled'
        ? const {'version', 'kind', 'user_id', 'request', 'outcome'}
        : kind == 'rejection'
        ? const {'version', 'kind', 'user_id', 'event_id', 'rejection'}
        : const {'version', 'kind', 'user_id', 'event_id', 'receipt'};
    if (raw.length != expected.length ||
        !expected.every(raw.containsKey) ||
        raw['version'] is! int ||
        !const {1, 2, formatVersion}.contains(raw['version']) ||
        (kind == 'rejection' && raw['version'] == 1) ||
        (kind == 'settled' && raw['version'] != formatVersion) ||
        raw['user_id'] is! String) {
      throw const ReviewStorageFailure();
    }
    final user = raw['user_id']! as String;
    if (ReviewSession(userId: user).userId != user) {
      throw const ReviewStorageFailure();
    }
    if (kind == 'pending' || kind == 'settled') {
      ReviewSuccess? receipt;
      ReviewFailure? rejection;
      if (kind == 'settled') {
        final outcome = decodeReviewOutcome(raw['outcome']);
        if (outcome is ReviewSuccess) {
          receipt = outcome;
        } else if (outcome is ReviewFailure &&
            isDefinitiveReviewRejection(outcome)) {
          rejection = outcome;
        } else {
          throw const ReviewStorageFailure();
        }
      }
      final record = StoredReview(
        userId: user,
        request: raw['request'],
        receipt: receipt,
        rejection: rejection,
      );
      final key = _key(user, record.eventId);
      if (_records.containsKey(key) || _records.length >= maxEvents) {
        throw const ReviewStorageFailure();
      }
      _records[key] = record;
    } else if (kind == 'receipt') {
      final event = raw['event_id'];
      if (event is! String) throw const ReviewStorageFailure();
      final key = _key(user, event);
      final record = _records[key];
      final receipt = decodeReviewOutcome(raw['receipt']);
      if (record == null || !record.isPending || receipt is! ReviewSuccess) {
        throw const ReviewStorageFailure();
      }
      _records[key] = StoredReview(
        userId: user,
        request: record.request,
        receipt: receipt,
      );
    } else if (kind == 'rejection') {
      final event = raw['event_id'];
      if (event is! String) throw const ReviewStorageFailure();
      final key = _key(user, event);
      final record = _records[key];
      final outcome = decodeReviewOutcome(raw['rejection']);
      if (record == null ||
          !record.isPending ||
          outcome is! ReviewFailure ||
          !isDefinitiveReviewRejection(outcome)) {
        throw const ReviewStorageFailure();
      }
      _records[key] = StoredReview(
        userId: user,
        request: record.request,
        rejection: outcome,
      );
    } else {
      throw const ReviewStorageFailure();
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) async {
      if (_closed || _broken) throw const ReviewStorageFailure();
      try {
        return await action();
      } on ReviewTransportFailure {
        rethrow;
      } on Object {
        throw const ReviewStorageFailure();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _append(Map<String, Object> record) async {
    final bytes = utf8.encode('${jsonEncode(record)}\n');
    final length = await _file.length();
    final isReceipt = record['kind'] != 'pending';
    final unresolved =
        _records.values.where((r) => r.isPending).length + (isReceipt ? -1 : 1);
    if ((isReceipt && bytes.length > maxReceiptBytes) ||
        length + bytes.length + unresolved * maxReceiptBytes > maxBytes) {
      throw const ReviewStorageFailure();
    }
    try {
      await _file.setPosition(length);
      await _file.writeFrom(bytes);
      await _file.flush();
    } on Object {
      _broken = true;
      throw const ReviewStorageFailure();
    }
    try {
      _apply(record);
    } on Object {
      _broken = true;
      throw const ReviewStorageFailure();
    }
  }

  @override
  Future<List<StoredReview>> list(String userId) => _serial(() async {
    final owner = ReviewSession(userId: userId).userId;
    return List<StoredReview>.unmodifiable(
      _records.values.where((record) => record.userId == owner),
    );
  });

  /// Explicit lossless maintenance under the existing writer lease. Retains
  /// every owner/event and original outcome; no retention, dispatch or deletion.
  /// A flushed sibling replaces the old path; interruption before rename leaves
  /// the original authoritative. Hardware power-loss durability is not claimed.
  /// Returns reclaimed bytes; event-count capacity is intentionally unchanged.
  Future<int> compact() => _serial(() => _rewrite(_records.values.toList()));

  Future<int> _rewrite(List<StoredReview> records) async {
    final data = File(
      '$_directory${Platform.pathSeparator}review-journal.ndjson',
    );
    final temporary = File('${data.path}.compact');
    if (await FileSystemEntity.isLink(temporary.path) ||
        await FileSystemEntity.isLink(data.path)) {
      throw const ReviewStorageFailure();
    }
    final bytes = utf8.encode(
      [
        for (final record in records)
          jsonEncode({
            'version': formatVersion,
            'kind': record.isPending ? 'pending' : 'settled',
            'user_id': record.userId,
            'request': record.request,
            if (!record.isPending)
              'outcome': record.receipt?.toJson() ?? record.rejection!.toJson(),
          }),
      ].map((line) => '$line\n').join(),
    );
    final oldLength = await _file.length();
    final reserved = records.where((r) => r.isPending).length * maxReceiptBytes;
    if (bytes.length > oldLength || bytes.length + reserved > maxBytes) {
      throw const ReviewStorageFailure();
    }
    if (bytes.length == oldLength) return 0;
    // Until replacement begins, a failed temporary write leaves this instance
    // usable. Never truncate the authoritative file to make room.
    await temporary.writeAsBytes(bytes, flush: true);
    try {
      await _file.close();
      await temporary.rename(data.path);
      _file = await data.open(mode: FileMode.append);
      _records
        ..clear()
        ..addEntries(
          records.map((r) => MapEntry(_key(r.userId, r.eventId), r)),
        );
    } on Object {
      _broken = true; // Close/reopen before any further operation.
      throw const ReviewStorageFailure();
    }
    return oldLength - bytes.length;
  }

  Future<int> _prune(String userId) async {
    final retained = receiptRetention?.retain(_records.values.toList(), userId);
    if (retained == null) return 0;
    final removed = _records.length - retained.length;
    if (removed > 0) await _rewrite(retained);
    return removed;
  }

  /// Explicit opt-in cache maintenance. Pending/rejected/other owners retained.
  Future<int> pruneReceipts(String userId) => _serial(() async {
    final owner = ReviewSession(userId: userId).userId;
    return _prune(owner);
  });

  @override
  Future<StoredReview> stage(String userId, Map<String, Object> request) =>
      _serial(() async {
        final candidate = StoredReview(userId: userId, request: request);
        final previous = _records[_key(candidate.userId, candidate.eventId)];
        if (previous != null) {
          if (!sameReviewRequest(previous.request, candidate.request)) {
            throw const ReviewTransportFailure(ReviewErrorCode.syncConflict);
          }
          return previous;
        }
        await _prune(candidate.userId);
        if (_records.length >= maxEvents) throw const ReviewStorageFailure();
        await _append({
          'version': formatVersion,
          'kind': 'pending',
          'user_id': candidate.userId,
          'request': candidate.request,
        });
        return candidate;
      });

  @override
  Future<void> acknowledge(
    String userId,
    String eventId,
    ReviewSuccess receipt,
  ) => _serial(() async {
    final owner = ReviewSession(userId: userId).userId;
    final record = _records[_key(owner, eventId)];
    if (record == null || record.rejection != null) {
      throw const ReviewStorageFailure();
    }
    if (record.receipt != null) {
      if (jsonEncode(record.receipt!.toJson()) !=
          jsonEncode(receipt.toJson())) {
        throw const ReviewStorageFailure();
      }
      return;
    }
    await _append({
      'version': formatVersion,
      'kind': 'receipt',
      'user_id': owner,
      'event_id': eventId,
      'receipt': receipt.toJson(),
    });
  });

  @override
  Future<void> reject(String userId, String eventId, ReviewFailure rejection) =>
      _serial(() async {
        if (!isDefinitiveReviewRejection(rejection)) {
          throw const ReviewStorageFailure();
        }
        final owner = ReviewSession(userId: userId).userId;
        final record = _records[_key(owner, eventId)];
        if (record == null || record.receipt != null) {
          throw const ReviewStorageFailure();
        }
        if (record.rejection != null) {
          if (record.rejection!.code != rejection.code) {
            throw const ReviewStorageFailure();
          }
          return;
        }
        await _append({
          'version': formatVersion,
          'kind': 'rejection',
          'user_id': owner,
          'event_id': eventId,
          'rejection': rejection.toJson(),
        });
      });

  Future<void> close() async {
    if (_closed) return;
    _closed = true; // Prevent newly queued operations while draining writes.
    await _tail;
    try {
      try {
        await _file.close();
      } finally {
        await _lease.close();
      }
    } on Object {
      throw const ReviewStorageFailure();
    } finally {
      _owners.remove(_directory);
    }
  }
}
