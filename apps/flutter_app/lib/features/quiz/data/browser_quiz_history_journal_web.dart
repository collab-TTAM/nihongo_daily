import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import '../domain/grammar_quiz_attempt.dart';
import '../domain/vocabulary_quiz_attempt.dart';
import '../domain/vocabulary_quiz_progress.dart';
import 'grammar_quiz_attempt_store.dart';
import 'vocabulary_quiz_attempt_store.dart';

@JS('indexedDB')
external _Factory? get _factory;

extension type _Factory(JSObject _) implements JSObject {
  external _OpenRequest open(String name, int version);
}

extension type _Request(JSObject _) implements JSObject {
  external JSAny? get result;
  external set onsuccess(JSFunction listener);
  external set onerror(JSFunction listener);
}

extension type _OpenRequest(JSObject _) implements _Request {
  external _Transaction? get transaction;
  external set onupgradeneeded(JSFunction listener);
  external set onblocked(JSFunction listener);
}

extension type _Database(JSObject _) implements JSObject {
  external _ObjectStore createObjectStore(String name);
  external _Transaction transaction(String store, String mode);
  external set onversionchange(JSFunction listener);
  external set onclose(JSFunction listener);
  external void close();
}

extension type _Transaction(JSObject _) implements JSObject {
  external _ObjectStore objectStore(String name);
  external set oncomplete(JSFunction listener);
  external set onabort(JSFunction listener);
  external set onerror(JSFunction listener);
  external void abort();
}

extension type _ObjectStore(JSObject _) implements JSObject {
  @JS('get')
  external _Request read(JSAny key);
  external _Request put(JSAny value, JSAny key);
}

typedef _DecodeRecord<T> = T Function(Object? value);
typedef _EncodeRecord<T> = Map<String, Object?> Function(T record);
typedef _RecordString<T> = String Function(T record);
typedef _SameRecord<T> = bool Function(T left, T right);
typedef _CompareRecord<T> = int Function(T left, T right);

final class _IndexedDbQuizJournal<T> {
  _IndexedDbQuizJournal(
    this._database, {
    required _DecodeRecord<T> decodeRecord,
    required _EncodeRecord<T> encodeRecord,
    required _RecordString<T> ownerOf,
    required _RecordString<T> eventIdOf,
    required _SameRecord<T> same,
    required _CompareRecord<T> compare,
    required Object Function() storageFailure,
    required Object Function() conflictFailure,
    required bool Function(Object error) isConflict,
  }) : _decodeRecord = decodeRecord,
       _encodeRecord = encodeRecord,
       _ownerOf = ownerOf,
       _eventIdOf = eventIdOf,
       _same = same,
       _compare = compare,
       _storageFailure = storageFailure,
       _conflictFailure = conflictFailure,
       _isConflict = isConflict {
    _database.onversionchange = ((JSAny? _) {
      _closeDatabase();
    }).toJS;
    _database.onclose = ((JSAny? _) {
      _closed = true;
    }).toJS;
  }

  static const maxBytes = 1024 * 1024;
  static const maxEvents = 512;

  final _Database _database;
  final _DecodeRecord<T> _decodeRecord;
  final _EncodeRecord<T> _encodeRecord;
  final _RecordString<T> _ownerOf;
  final _RecordString<T> _eventIdOf;
  final _SameRecord<T> _same;
  final _CompareRecord<T> _compare;
  final Object Function() _storageFailure;
  final Object Function() _conflictFailure;
  final bool Function(Object error) _isConflict;

  Future<void> _tail = Future<void>.value();
  Future<void>? _closing;
  bool _accepting = true;
  bool _closed = false;

  String _key(T record) => _ownerOf(record) + '/' + _eventIdOf(record);

  Map<String, T> _decodeState(String? raw) {
    if (raw == null) return <String, T>{};
    if (utf8.encode(raw).length > maxBytes) throw _storageFailure();
    final decoded = jsonDecode(raw);
    if (decoded is! List<Object?> || decoded.length > maxEvents) {
      throw _storageFailure();
    }
    final records = <String, T>{};
    for (final value in decoded) {
      final record = _decodeRecord(value);
      final key = _key(record);
      if (records.containsKey(key)) throw _storageFailure();
      records[key] = record;
    }
    // Canonical re-encoding rejects duplicate JSON keys, unknown envelope
    // fields, alternate whitespace/order and duplicate owner/event records.
    if (_encodeState(records) != raw) throw _storageFailure();
    return records;
  }

  String _encodeState(Map<String, T> records) {
    final keys = records.keys.toList()..sort();
    return jsonEncode([for (final key in keys) _encodeRecord(records[key]!)]);
  }

  Future<List<T>> list(String ownerId) => _serial(
    () => _transact(false, (current, _) {
      final records = _decodeState(current);
      final result = records.values
          .where((record) => _ownerOf(record) == ownerId)
          .toList();
      result.sort(_compare);
      return List<T>.unmodifiable(result);
    }),
  );

  Future<T> append(T candidate) => _serial(
    () => _transact(true, (current, replace) {
      final records = _decodeState(current);
      final key = _key(candidate);
      final previous = records[key];
      if (previous != null) {
        if (!_same(previous, candidate)) throw _conflictFailure();
        return previous;
      }
      if (records.length >= maxEvents) throw _storageFailure();
      final next = Map<String, T>.of(records)..[key] = candidate;
      final encoded = _encodeState(next);
      if (utf8.encode(encoded).length > maxBytes) throw _storageFailure();
      replace(encoded);
      return candidate;
    }),
  );

  Future<R> _serial<R>(Future<R> Function() operation) {
    if (!_accepting || _closed) {
      return Future<R>.error(_storageFailure());
    }
    final result = _tail.then((_) async {
      if (_closed) throw _storageFailure();
      try {
        return await operation();
      } on Object catch (error) {
        if (_isConflict(error)) rethrow;
        throw _storageFailure();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<R> _transact<R>(
    bool write,
    R Function(String? current, void Function(String) replace) operation,
  ) {
    if (_closed) return Future<R>.error(_storageFailure());
    final done = Completer<R>();
    Object? failure;
    late R value;
    var ready = false;
    _Transaction? transaction;
    try {
      final tx = _database.transaction(
        'journal',
        write ? 'readwrite' : 'readonly',
      );
      transaction = tx;
      void fail() {
        if (!done.isCompleted) {
          done.completeError(failure ?? _storageFailure());
        }
      }

      tx.onabort = ((JSAny? _) {
        fail();
      }).toJS;
      tx.onerror = ((JSAny? _) {
        failure ??= _storageFailure();
        // Browser default aborts; never preventDefault or claim success.
      }).toJS;
      tx.oncomplete = ((JSAny? _) {
        if (done.isCompleted) return;
        if (!ready || failure != null || _closed) {
          fail();
        } else {
          // Only transaction completion acknowledges a committed write.
          done.complete(value);
        }
      }).toJS;

      final store = tx.objectStore('journal');
      final read = store.read('state'.toJS);
      read.onerror = ((JSAny? _) {
        failure ??= _storageFailure();
      }).toJS;
      read.onsuccess = ((JSAny? _) {
        if (done.isCompleted) return;
        try {
          final raw = read.result;
          if (raw != null && !raw.isA<JSString>()) {
            throw _storageFailure();
          }
          // No await/microtask gap: queue the read/modify/write while this
          // IndexedDB request callback keeps the transaction active.
          value = operation(raw == null ? null : (raw as JSString).toDart, (
            next,
          ) {
            if (!write || _closed) throw _storageFailure();
            store.put(next.toJS, 'state'.toJS);
          });
          ready = true;
        } on Object catch (error) {
          failure = _isConflict(error) ? error : _storageFailure();
          try {
            tx.abort();
          } on Object {
            fail();
          }
        }
      }).toJS;
    } on Object {
      failure = _storageFailure();
      try {
        transaction?.abort();
      } on Object {
        // The transaction may already be complete or aborted.
      }
      if (!done.isCompleted) done.completeError(failure);
    }
    return done.future;
  }

  void _closeDatabase() {
    _closed = true;
    try {
      _database.close();
    } on Object {
      // No raw browser exception crosses the storage boundary.
    }
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _accepting = false;
    await _tail;
    if (!_closed) _closeDatabase();
  }
}

Future<_Database> _openDatabase(String databaseName) async {
  if (!RegExp(r'^[a-z0-9-]{1,80}$').hasMatch(databaseName)) {
    throw const _IndexedDbOpenFailure();
  }
  final completer = Completer<_Database>();
  try {
    final factory = _factory;
    if (factory == null) throw const _IndexedDbOpenFailure();
    final request = factory.open(databaseName, 1);
    void fail() {
      if (!completer.isCompleted) {
        completer.completeError(const _IndexedDbOpenFailure());
      }
    }

    request.onupgradeneeded = ((JSAny? _) {
      try {
        _Database(request.result! as JSObject).createObjectStore('journal');
      } on Object {
        try {
          request.transaction?.abort();
        } on Object {
          // The browser may already have aborted the upgrade.
        }
        fail();
      }
    }).toJS;
    request.onerror = ((JSAny? _) {
      fail();
    }).toJS;
    request.onblocked = ((JSAny? _) {
      fail();
    }).toJS;
    request.onsuccess = ((JSAny? _) {
      try {
        final database = _Database(request.result! as JSObject);
        if (completer.isCompleted) {
          database.close(); // A late success cannot leak a connection.
        } else {
          completer.complete(database);
        }
      } on Object {
        fail();
      }
    }).toJS;
    return await completer.future;
  } on Object {
    throw const _IndexedDbOpenFailure();
  }
}

final class _IndexedDbOpenFailure implements Exception {
  const _IndexedDbOpenFailure();
}

OwnedVocabularyQuizAttempt _decodeVocabularyRecord(Object? value) {
  if (value is! Map<String, Object?> ||
      value.length != 3 ||
      !const {'version', 'owner_id', 'attempt'}.every(value.containsKey) ||
      value['version'] is! int ||
      value['version'] != 1) {
    throw const VocabularyQuizStorageFailure();
  }
  return OwnedVocabularyQuizAttempt(
    quizHistoryUuid(value['owner_id']),
    VocabularyQuizAttempt.fromJson(value['attempt']),
  );
}

Map<String, Object?> _encodeVocabularyRecord(
  OwnedVocabularyQuizAttempt record,
) => {
  'version': 1,
  'owner_id': record.ownerId,
  'attempt': record.attempt.toJson(),
};

int _compareVocabularyRecords(
  OwnedVocabularyQuizAttempt left,
  OwnedVocabularyQuizAttempt right,
) {
  final time = left.attempt.completedAt.compareTo(right.attempt.completedAt);
  return time == 0
      ? left.attempt.eventId.compareTo(right.attempt.eventId)
      : time;
}

OwnedGrammarQuizAttempt _decodeGrammarRecord(Object? value) {
  if (value is! Map<String, Object?> ||
      value.length != 3 ||
      !const {'version', 'owner_id', 'attempt'}.every(value.containsKey) ||
      value['version'] is! int ||
      value['version'] != 1) {
    throw const GrammarQuizStorageFailure();
  }
  return OwnedGrammarQuizAttempt(
    grammarHistoryUuid(value['owner_id']),
    GrammarQuizAttempt.fromJson(value['attempt']),
  );
}

Map<String, Object?> _encodeGrammarRecord(OwnedGrammarQuizAttempt record) => {
  'version': 1,
  'owner_id': record.ownerId,
  'attempt': record.attempt.toJson(),
};

int _compareGrammarRecords(
  OwnedGrammarQuizAttempt left,
  OwnedGrammarQuizAttempt right,
) {
  final time = left.attempt.completedAt.compareTo(right.attempt.completedAt);
  return time == 0
      ? left.attempt.eventId.compareTo(right.attempt.eventId)
      : time;
}

final class BrowserVocabularyQuizJournal implements VocabularyQuizAttemptStore {
  BrowserVocabularyQuizJournal._(this._journal);

  final _IndexedDbQuizJournal<OwnedVocabularyQuizAttempt> _journal;

  @override
  Future<List<OwnedVocabularyQuizAttempt>> list(String ownerId) {
    try {
      return _journal.list(quizHistoryUuid(ownerId));
    } on Object {
      return Future<List<OwnedVocabularyQuizAttempt>>.error(
        const VocabularyQuizStorageFailure(),
      );
    }
  }

  @override
  Future<OwnedVocabularyQuizAttempt> append(
    String ownerId,
    VocabularyQuizAttempt attempt,
  ) {
    try {
      return _journal.append(
        OwnedVocabularyQuizAttempt(
          quizHistoryUuid(ownerId),
          VocabularyQuizAttempt.fromJson(attempt.toJson()),
        ),
      );
    } on Object {
      return Future<OwnedVocabularyQuizAttempt>.error(
        const VocabularyQuizStorageFailure(),
      );
    }
  }

  Future<void> close() => _journal.close();
}

final class BrowserGrammarQuizJournal implements GrammarQuizAttemptStore {
  BrowserGrammarQuizJournal._(this._journal);

  final _IndexedDbQuizJournal<OwnedGrammarQuizAttempt> _journal;

  @override
  Future<List<OwnedGrammarQuizAttempt>> list(String ownerId) {
    try {
      return _journal.list(grammarHistoryUuid(ownerId));
    } on Object {
      return Future<List<OwnedGrammarQuizAttempt>>.error(
        const GrammarQuizStorageFailure(),
      );
    }
  }

  @override
  Future<OwnedGrammarQuizAttempt> append(
    String ownerId,
    GrammarQuizAttempt attempt,
  ) {
    try {
      return _journal.append(
        OwnedGrammarQuizAttempt(
          grammarHistoryUuid(ownerId),
          GrammarQuizAttempt.fromJson(attempt.toJson()),
        ),
      );
    } on Object {
      return Future<OwnedGrammarQuizAttempt>.error(
        const GrammarQuizStorageFailure(),
      );
    }
  }

  Future<void> close() => _journal.close();
}

Future<BrowserVocabularyQuizJournal> openBrowserVocabularyQuizJournal({
  String databaseName = 'nd-vocabulary-quiz-history-v1',
}) async {
  try {
    final database = await _openDatabase(databaseName);
    return BrowserVocabularyQuizJournal._(
      _IndexedDbQuizJournal<OwnedVocabularyQuizAttempt>(
        database,
        decodeRecord: _decodeVocabularyRecord,
        encodeRecord: _encodeVocabularyRecord,
        ownerOf: (record) => record.ownerId,
        eventIdOf: (record) => record.attempt.eventId,
        same: (left, right) =>
            sameVocabularyQuizAttempt(left.attempt, right.attempt),
        compare: _compareVocabularyRecords,
        storageFailure: () => const VocabularyQuizStorageFailure(),
        conflictFailure: () => const VocabularyQuizHistoryConflict(),
        isConflict: (error) => error is VocabularyQuizHistoryConflict,
      ),
    );
  } on Object {
    throw const VocabularyQuizStorageFailure();
  }
}

Future<BrowserGrammarQuizJournal> openBrowserGrammarQuizJournal({
  String databaseName = 'nd-grammar-quiz-history-v1',
}) async {
  try {
    final database = await _openDatabase(databaseName);
    return BrowserGrammarQuizJournal._(
      _IndexedDbQuizJournal<OwnedGrammarQuizAttempt>(
        database,
        decodeRecord: _decodeGrammarRecord,
        encodeRecord: _encodeGrammarRecord,
        ownerOf: (record) => record.ownerId,
        eventIdOf: (record) => record.attempt.eventId,
        same: (left, right) =>
            sameGrammarQuizAttempt(left.attempt, right.attempt),
        compare: _compareGrammarRecords,
        storageFailure: () => const GrammarQuizStorageFailure(),
        conflictFailure: () => const GrammarQuizHistoryConflict(),
        isConflict: (error) => error is GrammarQuizHistoryConflict,
      ),
    );
  } on Object {
    throw const GrammarQuizStorageFailure();
  }
}
