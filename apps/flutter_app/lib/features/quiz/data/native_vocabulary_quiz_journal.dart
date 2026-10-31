import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/vocabulary_quiz_attempt.dart';
import '../domain/vocabulary_quiz_progress.dart';
import 'vocabulary_quiz_attempt_store.dart';

/// Opt-in native storage; not installed by the public quiz route.
/// One writer isolate owns a trusted private directory and the OS lease.
/// Flush supports process restart, not certified hardware power-loss durability.
final class NativeVocabularyQuizJournal implements VocabularyQuizAttemptStore {
  NativeVocabularyQuizJournal._(this._directory, this._lease, this._file);

  static const maxBytes = 1024 * 1024;
  static const maxEvents = 512;
  static final _owners = <String>{};
  final String _directory;
  final RandomAccessFile _lease;
  final RandomAccessFile _file;
  final _records = <String, OwnedVocabularyQuizAttempt>{};
  Future<void> _tail = Future.value();
  Future<void>? _closing;
  bool _accepting = true;
  bool _broken = false;

  static Future<NativeVocabularyQuizJournal> open(Directory directory) async {
    String? path;
    RandomAccessFile? lease;
    RandomAccessFile? file;
    var owns = false;
    try {
      await directory.create(recursive: true);
      path = await directory.resolveSymbolicLinks();
      if (!_owners.add(path)) throw const VocabularyQuizStorageFailure();
      owns = true;
      final lockPath = '$path${Platform.pathSeparator}quiz-attempts.lock';
      final dataPath = '$path${Platform.pathSeparator}quiz-attempts.ndjson';
      if (await FileSystemEntity.isLink(lockPath) ||
          await FileSystemEntity.isLink(dataPath)) {
        throw const VocabularyQuizStorageFailure();
      }
      lease = await File(lockPath).open(mode: FileMode.append);
      await lease.lock(FileLock.exclusive);
      file = await File(dataPath).open(mode: FileMode.append);
      final journal = NativeVocabularyQuizJournal._(path, lease, file);
      await journal._restore();
      return journal;
    } on Object {
      await _quietClose(file);
      await _quietClose(lease);
      if (owns) _owners.remove(path);
      throw const VocabularyQuizStorageFailure();
    }
  }

  static Future<void> _quietClose(RandomAccessFile? file) async {
    try {
      await file?.close();
    } on Object {
      // Never expose paths or raw filesystem errors during failed open.
    }
  }

  String _key(OwnedVocabularyQuizAttempt record) =>
      '${record.ownerId}/${record.attempt.eventId}';

  Map<String, Object> _encode(OwnedVocabularyQuizAttempt record) => {
    'version': 1,
    'owner_id': record.ownerId,
    'attempt': record.attempt.toJson(),
  };

  OwnedVocabularyQuizAttempt _decode(String line) {
    final raw = jsonDecode(line);
    if (raw is! Map<String, Object?> ||
        raw.length != 3 ||
        !const {'version', 'owner_id', 'attempt'}.every(raw.containsKey) ||
        raw['version'] is! int ||
        raw['version'] != 1) {
      throw const VocabularyQuizStorageFailure();
    }
    final record = OwnedVocabularyQuizAttempt(
      quizHistoryUuid(raw['owner_id']),
      VocabularyQuizAttempt.fromJson(raw['attempt']),
    );
    // Exact writer encoding rejects duplicate keys and noncanonical complete
    // lines, including reordered/extra fields and alternate whitespace.
    if (jsonEncode(_encode(record)) != line) {
      throw const VocabularyQuizStorageFailure();
    }
    return record;
  }

  OwnedVocabularyQuizAttempt? _replay(OwnedVocabularyQuizAttempt record) {
    final previous = _records[_key(record)];
    if (previous != null &&
        !sameVocabularyQuizAttempt(previous.attempt, record.attempt)) {
      throw const VocabularyQuizHistoryConflict();
    }
    return previous;
  }

  Future<void> _restore() async {
    final length = await _file.length();
    if (length > maxBytes) throw const VocabularyQuizStorageFailure();
    await _file.setPosition(0);
    final bytes = await _file.read(length);
    if (bytes.length != length) throw const VocabularyQuizStorageFailure();
    final committed = bytes.lastIndexOf(10) + 1;
    final lines = utf8.decode(bytes.sublist(0, committed)).split('\n');
    for (var i = 0; i < lines.length - 1; i++) {
      final record = _decode(lines[i]);
      if (_replay(record) != null) continue;
      if (_records.length >= maxEvents) {
        throw const VocabularyQuizStorageFailure();
      }
      _records[_key(record)] = record;
    }
    // Validate every complete line before modifying an incomplete EOF tail.
    // A write without its newline was never reported as committed.
    if (committed != length) {
      await _file.truncate(committed);
      await _file.flush();
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    if (!_accepting) {
      return Future<T>.error(const VocabularyQuizStorageFailure());
    }
    final result = _tail.then((_) async {
      if (_broken) throw const VocabularyQuizStorageFailure();
      try {
        return await action();
      } on VocabularyQuizHistoryConflict {
        rethrow;
      } on Object {
        throw const VocabularyQuizStorageFailure();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override
  Future<List<OwnedVocabularyQuizAttempt>> list(String ownerId) =>
      _serial(() async {
        final owner = quizHistoryUuid(ownerId);
        return List<OwnedVocabularyQuizAttempt>.unmodifiable(
          _records.values.where((record) => record.ownerId == owner),
        );
      });

  @override
  Future<OwnedVocabularyQuizAttempt> append(
    String ownerId,
    VocabularyQuizAttempt attempt,
  ) => _serial(() async {
    final candidate = OwnedVocabularyQuizAttempt(
      ownerId,
      VocabularyQuizAttempt.fromJson(attempt.toJson()),
    );
    final previous = _replay(candidate);
    if (previous != null) return previous;
    if (_records.length >= maxEvents) {
      throw const VocabularyQuizStorageFailure();
    }
    final bytes = utf8.encode('${jsonEncode(_encode(candidate))}\n');
    final length = await _file.length();
    if (length + bytes.length > maxBytes) {
      throw const VocabularyQuizStorageFailure();
    }
    try {
      await _file.setPosition(length);
      await _file.writeFrom(bytes);
      await _file.flush();
    } on Object {
      _broken = true; // Close/reopen before resolving an uncertain append.
      throw const VocabularyQuizStorageFailure();
    }
    _records[_key(candidate)] = candidate;
    return candidate;
  });

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _accepting =
        false; // Drain accepted operations; reject new ones immediately.
    await _tail;
    try {
      try {
        await _file.close();
      } finally {
        await _lease.close();
      }
    } on Object {
      throw const VocabularyQuizStorageFailure();
    } finally {
      _owners.remove(_directory);
    }
  }
}
