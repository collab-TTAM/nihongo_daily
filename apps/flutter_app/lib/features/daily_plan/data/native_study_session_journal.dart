import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../srs/data/review_repository.dart';
import '../domain/completed_study_session.dart';
import 'daily_plan_repository.dart';
import 'durable_study_session_repository.dart';

/// Separate opt-in journal; never shares the review journal's files/format.
/// The owner supplies a trusted private project directory and one writer isolate.
/// Flush/process restart is supported; hardware power loss is not certified.
final class NativeStudySessionJournal implements StudySessionStore {
  NativeStudySessionJournal._(this._directory, this._lease, this._file);
  static const maxBytes = 1024 * 1024;
  static const maxEvents = 512;
  static const terminalReservation = 256;
  static final _owners = <String>{};
  final String _directory;
  final RandomAccessFile _lease;
  final RandomAccessFile _file;
  final _records = <String, StoredStudySession>{};
  Future<void> _tail = Future.value();
  Future<void>? _closing;
  bool _closed = false;
  bool _broken = false;

  static Future<NativeStudySessionJournal> open(Directory directory) async {
    String? path;
    RandomAccessFile? lease;
    RandomAccessFile? file;
    var owns = false;
    try {
      await directory.create(recursive: true);
      path = await directory.resolveSymbolicLinks();
      if (!_owners.add(path)) throw const StudySessionStorageFailure();
      owns = true;
      final lockPath = '$path${Platform.pathSeparator}study-sessions.lock';
      final dataPath = '$path${Platform.pathSeparator}study-sessions.ndjson';
      if (await FileSystemEntity.isLink(lockPath) ||
          await FileSystemEntity.isLink(dataPath)) {
        throw const StudySessionStorageFailure();
      }
      lease = await File(lockPath).open(mode: FileMode.append);
      await lease.lock(FileLock.exclusive);
      file = await File(dataPath).open(mode: FileMode.append);
      final journal = NativeStudySessionJournal._(path, lease, file);
      await journal._restore();
      return journal;
    } on Object {
      await _quietClose(file);
      await _quietClose(lease);
      if (owns) _owners.remove(path);
      throw const StudySessionStorageFailure();
    }
  }

  static Future<void> _quietClose(RandomAccessFile? file) async {
    try {
      await file?.close();
    } on Object {
      // No path/raw filesystem exception is published during failed open.
    }
  }

  String _key(String userId, String eventId) => '$userId/$eventId';

  Future<void> _restore() async {
    final length = await _file.length();
    if (length > maxBytes) throw const StudySessionStorageFailure();
    await _file.setPosition(0);
    final bytes = await _file.read(length);
    if (bytes.length != length) throw const StudySessionStorageFailure();
    final last = bytes.lastIndexOf(10) + 1;
    final complete = utf8.decode(bytes.sublist(0, last));
    for (final line in const LineSplitter().convert(complete)) {
      final raw = jsonDecode(line);
      if (raw is! Map<String, Object?> || jsonEncode(raw) != line) {
        throw const StudySessionStorageFailure();
      }
      _apply(raw);
    }
    // Validate reservation after every restored command, before repairing tail.
    final pending = _records.values.where((r) => r.isPending).length;
    if (last + pending * terminalReservation > maxBytes) {
      throw const StudySessionStorageFailure();
    }
    if (last != length) {
      await _file.truncate(last);
      await _file.flush();
    }
  }

  void _apply(Map<String, Object?> raw) {
    final kind = raw['kind'];
    final fields = kind == 'pending'
        ? const {'version', 'kind', 'user_id', 'event'}
        : kind == 'acknowledged'
        ? const {'version', 'kind', 'user_id', 'event_id'}
        : const {'version', 'kind', 'user_id', 'event_id', 'code'};
    if (raw.length != fields.length ||
        !fields.every(raw.containsKey) ||
        raw['version'] is! int ||
        raw['version'] != 1 ||
        raw['user_id'] is! String) {
      throw const StudySessionStorageFailure();
    }
    final user = raw['user_id']! as String;
    if (ReviewSession(userId: user).userId != user) {
      throw const StudySessionStorageFailure();
    }
    if (kind == 'pending') {
      final event = CompletedStudySession.fromJson(raw['event']);
      final key = _key(user, event.clientEventId);
      if (_records.containsKey(key) || _records.length >= maxEvents) {
        throw const StudySessionStorageFailure();
      }
      _records[key] = StoredStudySession(userId: user, event: event);
      return;
    }
    if (kind != 'acknowledged' && kind != 'rejected') {
      throw const StudySessionStorageFailure();
    }
    final eventId = raw['event_id'];
    if (eventId is! String) throw const StudySessionStorageFailure();
    final key = _key(user, eventId);
    final previous = _records[key];
    if (previous == null || !previous.isPending) {
      throw const StudySessionStorageFailure();
    }
    final rejection = kind == 'rejected'
        ? DailyPlanErrorCode.values.singleWhere(
            (code) => code.wireName == raw['code'],
          )
        : null;
    _records[key] = StoredStudySession(
      userId: user,
      event: previous.event,
      acknowledged: kind == 'acknowledged',
      rejection: rejection,
    );
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) async {
      if (_closed || _broken) throw const StudySessionStorageFailure();
      try {
        return await action();
      } on DailyPlanFailure {
        rethrow;
      } on Object {
        throw const StudySessionStorageFailure();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _append(
    Map<String, Object> raw, {
    required bool terminal,
  }) async {
    final bytes = utf8.encode('${jsonEncode(raw)}\n');
    final length = await _file.length();
    final pending =
        _records.values.where((r) => r.isPending).length + (terminal ? -1 : 1);
    if ((terminal && bytes.length > terminalReservation) ||
        length + bytes.length + pending * terminalReservation > maxBytes) {
      throw const StudySessionStorageFailure();
    }
    try {
      await _file.setPosition(length);
      await _file.writeFrom(bytes);
      await _file.flush();
    } on Object {
      _broken = true; // Reopen under lease before reading an uncertain append.
      throw const StudySessionStorageFailure();
    }
  }

  @override
  Future<List<StoredStudySession>> list(String userId) => _serial(() async {
    final user = ReviewSession(userId: userId).userId;
    return List.unmodifiable(_records.values.where((r) => r.userId == user));
  });

  @override
  Future<StoredStudySession> stage(
    String userId,
    CompletedStudySession event,
  ) => _serial(() async {
    final candidate = StoredStudySession(userId: userId, event: event);
    final key = _key(candidate.userId, event.clientEventId);
    final previous = _records[key];
    if (previous != null) {
      if (!sameStudyEvent(previous.event, event)) {
        throw const DailyPlanFailure(DailyPlanErrorCode.syncConflict);
      }
      return previous;
    }
    if (_records.length >= maxEvents) throw const StudySessionStorageFailure();
    await _append({
      'version': 1,
      'kind': 'pending',
      'user_id': candidate.userId,
      'event': event.toJson(),
    }, terminal: false);
    _records[key] = candidate;
    return candidate;
  });

  Future<void> _settle(
    String userId,
    String eventId,
    DailyPlanErrorCode? rejection,
  ) => _serial(() async {
    final user = ReviewSession(userId: userId).userId;
    final key = _key(user, eventId);
    final previous = _records[key];
    if (previous == null) throw const StudySessionStorageFailure();
    final next = StoredStudySession(
      userId: user,
      event: previous.event,
      acknowledged: rejection == null,
      rejection: rejection,
    );
    if (!previous.isPending) {
      if (previous.acknowledged != next.acknowledged ||
          previous.rejection != next.rejection) {
        throw const StudySessionStorageFailure();
      }
      return;
    }
    await _append({
      'version': 1,
      'kind': rejection == null ? 'acknowledged' : 'rejected',
      'user_id': user,
      'event_id': eventId,
      if (rejection != null) 'code': rejection.wireName,
    }, terminal: true);
    _records[key] = next;
  });

  @override
  Future<void> acknowledge(String userId, String eventId) =>
      _settle(userId, eventId, null);
  @override
  Future<void> reject(String userId, String eventId, DailyPlanErrorCode code) {
    if (!isDefinitiveStudyRejection(DailyPlanFailure(code))) {
      return Future.error(const StudySessionStorageFailure());
    }
    return _settle(userId, eventId, code);
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    await _tail;
    try {
      try {
        await _file.close();
      } finally {
        await _lease.close();
      }
    } on Object {
      throw const StudySessionStorageFailure();
    } finally {
      _owners.remove(_directory);
    }
  }
}
