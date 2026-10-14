import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'durable_review_repository.dart';
import 'review_repository.dart';

/// Opt-in native append journal. The application owns its private data directory
/// and its lifetime; no tokens or display content are written here. Not web.
/// One process lease plus a single-isolate directory guard prevents two writers.
/// The owner must not open this directory from multiple isolates in one process.
/// flush() covers process restart; hardware/filesystem power-loss is not proven.
final class NativeReviewJournal implements DurableReviewStore {
  NativeReviewJournal._(this._directory, this._lease, this._file);
  static const maxBytes = 1024 * 1024;
  static const maxEvents = 512;
  // Worst-case validated response (4096-character timestamp plus bounded
  // scalar/owner/event fields). Reserve one slot for every unresolved event.
  static const maxReceiptBytes = 8192;
  static final _owners = <String>{};
  final String _directory;
  final RandomAccessFile _lease;
  final RandomAccessFile _file;
  final _records = <String, StoredReview>{};
  Future<void> _tail = Future.value();
  bool _closed = false;
  bool _broken = false;

  static Future<NativeReviewJournal> open(Directory directory) async {
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
      final journal = NativeReviewJournal._(path, lease, file);
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
        : const {'version', 'kind', 'user_id', 'event_id', 'receipt'};
    if (raw.length != expected.length ||
        !expected.every(raw.containsKey) ||
        raw['version'] is! int ||
        raw['version'] != 1 ||
        raw['user_id'] is! String) {
      throw const ReviewStorageFailure();
    }
    final user = raw['user_id']! as String;
    if (ReviewSession(userId: user).userId != user) {
      throw const ReviewStorageFailure();
    }
    if (kind == 'pending') {
      final record = StoredReview(userId: user, request: raw['request']);
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
      if (record == null ||
          record.receipt != null ||
          receipt is! ReviewSuccess) {
        throw const ReviewStorageFailure();
      }
      _records[key] = StoredReview(
        userId: user,
        request: record.request,
        receipt: receipt,
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
    final isReceipt = record['kind'] == 'receipt';
    final unresolved =
        _records.values.where((r) => r.receipt == null).length +
        (isReceipt ? -1 : 1);
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
        if (_records.length >= maxEvents) throw const ReviewStorageFailure();
        await _append({
          'version': 1,
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
    if (record == null) throw const ReviewStorageFailure();
    if (record.receipt != null) {
      if (jsonEncode(record.receipt!.toJson()) !=
          jsonEncode(receipt.toJson())) {
        throw const ReviewStorageFailure();
      }
      return;
    }
    await _append({
      'version': 1,
      'kind': 'receipt',
      'user_id': owner,
      'event_id': eventId,
      'receipt': receipt.toJson(),
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
