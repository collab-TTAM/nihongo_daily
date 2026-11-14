import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/grammar_quiz_attempt.dart';
import 'grammar_quiz_attempt_store.dart';

/// Opt-in native storage; not installed by the public quiz route.
/// One writer isolate owns a trusted private directory and the OS lease.
/// Flush supports process restart, not certified hardware power-loss durability.
final class NativeGrammarQuizJournal implements GrammarQuizAttemptStore {
  NativeGrammarQuizJournal._(this._directory, this._lease, this._file);

  static const maxBytes = 1024 * 1024;
  static const maxEvents = 512;
  static final _owners = <String>{};
  final String _directory;
  final RandomAccessFile _lease;
  final RandomAccessFile _file;
  final _records = <String, OwnedGrammarQuizAttempt>{};
  Future<void> _tail = Future.value();
  Future<void>? _closing;
  bool _accepting = true;
  bool _broken = false;

  static Future<NativeGrammarQuizJournal> open(Directory directory) async {
    String? path;
    RandomAccessFile? lease;
    RandomAccessFile? file;
    var owns = false;
    try {
      await directory.create(recursive: true);
      path = await directory.resolveSymbolicLinks();
      if (!_owners.add(path)) throw const GrammarQuizStorageFailure();
      owns = true;
      final lockPath =
          '$path${Platform.pathSeparator}grammar-quiz-attempts.lock';
      final dataPath =
          '$path${Platform.pathSeparator}grammar-quiz-attempts.ndjson';
      if (await FileSystemEntity.isLink(lockPath) ||
          await FileSystemEntity.isLink(dataPath)) {
        throw const GrammarQuizStorageFailure();
      }
      lease = await File(lockPath).open(mode: FileMode.append);
      await lease.lock(FileLock.exclusive);
      file = await File(dataPath).open(mode: FileMode.append);
      final journal = NativeGrammarQuizJournal._(path, lease, file);
      await journal._restore();
      return journal;
    } on Object {
      await _quietClose(file);
      await _quietClose(lease);
      if (owns) _owners.remove(path);
      throw const GrammarQuizStorageFailure();
    }
  }

  static Future<void> _quietClose(RandomAccessFile? file) async {
    try {
      await file?.close();
    } on Object {
      // Never expose paths or raw filesystem errors during failed open.
    }
  }

  String _key(OwnedGrammarQuizAttempt record) =>
      '${record.ownerId}/${record.attempt.eventId}';

  Map<String, Object> _encode(OwnedGrammarQuizAttempt record) => {
    'version': 1,
    'owner_id': record.ownerId,
    'attempt': record.attempt.toJson(),
  };

  OwnedGrammarQuizAttempt _decode(String line) {
    final raw = jsonDecode(line);
    if (raw is! Map<String, Object?> ||
        raw.length != 3 ||
        !const {'version', 'owner_id', 'attempt'}.every(raw.containsKey) ||
        raw['version'] is! int ||
        raw['version'] != 1) {
      throw const GrammarQuizStorageFailure();
    }
    final record = OwnedGrammarQuizAttempt(
      grammarHistoryUuid(raw['owner_id']),
      GrammarQuizAttempt.fromJson(raw['attempt']),
    );
    // Exact writer encoding rejects duplicate keys and noncanonical complete
    // lines, including reordered/extra fields and alternate whitespace.
    if (jsonEncode(_encode(record)) != line) {
      throw const GrammarQuizStorageFailure();
    }
    return record;
  }

  OwnedGrammarQuizAttempt? _replay(OwnedGrammarQuizAttempt record) {
    final previous = _records[_key(record)];
    if (previous != null &&
        !sameGrammarQuizAttempt(previous.attempt, record.attempt)) {
      throw const GrammarQuizHistoryConflict();
    }
    return previous;
  }

  Future<void> _restore() async {
    final length = await _file.length();
    if (length > maxBytes) throw const GrammarQuizStorageFailure();
    await _file.setPosition(0);
    final bytes = await _file.read(length);
    if (bytes.length != length) throw const GrammarQuizStorageFailure();
    final committed = bytes.lastIndexOf(10) + 1;
    final lines = utf8.decode(bytes.sublist(0, committed)).split('\n');
    for (var i = 0; i < lines.length - 1; i++) {
      final record = _decode(lines[i]);
      if (_replay(record) != null) continue;
      if (_records.length >= maxEvents) {
        throw const GrammarQuizStorageFailure();
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
      return Future<T>.error(const GrammarQuizStorageFailure());
    }
    final result = _tail.then((_) async {
      if (_broken) throw const GrammarQuizStorageFailure();
      try {
        return await action();
      } on GrammarQuizHistoryConflict {
        rethrow;
      } on Object {
        throw const GrammarQuizStorageFailure();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override
  Future<List<OwnedGrammarQuizAttempt>> list(String ownerId) =>
      _serial(() async {
        final owner = grammarHistoryUuid(ownerId);
        return List<OwnedGrammarQuizAttempt>.unmodifiable(
          _records.values.where((record) => record.ownerId == owner),
        );
      });

  @override
  Future<OwnedGrammarQuizAttempt> append(
    String ownerId,
    GrammarQuizAttempt attempt,
  ) => _serial(() async {
    final candidate = OwnedGrammarQuizAttempt(
      ownerId,
      GrammarQuizAttempt.fromJson(attempt.toJson()),
    );
    final previous = _replay(candidate);
    if (previous != null) return previous;
    if (_records.length >= maxEvents) {
      throw const GrammarQuizStorageFailure();
    }
    final bytes = utf8.encode('${jsonEncode(_encode(candidate))}\n');
    final length = await _file.length();
    if (length + bytes.length > maxBytes) {
      throw const GrammarQuizStorageFailure();
    }
    try {
      await _file.setPosition(length);
      await _file.writeFrom(bytes);
      await _file.flush();
    } on Object {
      _broken = true; // Close/reopen before resolving an uncertain append.
      throw const GrammarQuizStorageFailure();
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
      throw const GrammarQuizStorageFailure();
    } finally {
      _owners.remove(_directory);
    }
  }
}
