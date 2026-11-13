import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import '../../srs/data/review_repository.dart';
import '../domain/completed_study_session.dart';
import 'daily_plan_repository.dart';
import 'durable_study_session_repository.dart';

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

/// Open a separate, opt-in browser journal. This never configures Auth or the
/// default application runtime; the caller owns and must close the returned store.
Future<BrowserStudySessionStore> openBrowserStudySessionStore({
  String databaseName = 'nihongo-daily-study-sessions-v1',
}) async {
  try {
    final database = await _openDatabase(databaseName);
    return _IndexedDbStudySessionStore(database);
  } on Object {
    throw const StudySessionStorageFailure();
  }
}

final class _IndexedDbStudySessionStore implements BrowserStudySessionStore {
  _IndexedDbStudySessionStore(this._database) {
    _database.onversionchange = ((JSAny? _) {
      _closeDatabase();
    }).toJS;
    _database.onclose = ((JSAny? _) {
      _accepting = false;
      _closed = true;
    }).toJS;
  }

  static const maxBytes = 1024 * 1024;
  static const maxEvents = 512;
  static const terminalReservation = 256;

  final _Database _database;
  Future<void> _tail = Future<void>.value();
  Future<void>? _closing;
  bool _accepting = true;
  bool _closed = false;

  String _key(StoredStudySession record) =>
      '${record.userId}/${record.event.clientEventId}';

  Map<String, StoredStudySession> _decodeState(String? raw) {
    if (raw == null) return <String, StoredStudySession>{};
    if (utf8.encode(raw).length > maxBytes) {
      throw const StudySessionStorageFailure();
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List<Object?> || decoded.length > maxEvents) {
      throw const StudySessionStorageFailure();
    }
    final records = <String, StoredStudySession>{};
    for (final value in decoded) {
      final record = _decodeRecord(value);
      final key = _key(record);
      if (records.containsKey(key)) {
        throw const StudySessionStorageFailure();
      }
      records[key] = record;
    }
    // Canonical re-encoding rejects duplicate JSON members, unknown envelope
    // fields, alternate ordering/whitespace and duplicate owner/event records.
    if (_encodeState(records) != raw) {
      throw const StudySessionStorageFailure();
    }
    return records;
  }

  StoredStudySession _decodeRecord(Object? value) {
    if (value is! Map<String, Object?> ||
        value.length != 4 ||
        !const {
          'user_id',
          'event',
          'acknowledged',
          'rejection',
        }.every(value.containsKey)) {
      throw const StudySessionStorageFailure();
    }
    final rawUser = value['user_id'];
    final acknowledged = value['acknowledged'];
    final rawRejection = value['rejection'];
    if (rawUser is! String ||
        acknowledged is! bool ||
        (rawRejection != null && rawRejection is! String)) {
      throw const StudySessionStorageFailure();
    }
    final user = ReviewSession(userId: rawUser).userId;
    if (user != rawUser) throw const StudySessionStorageFailure();
    final event = CompletedStudySession.fromJson(value['event']);
    final rejection = rawRejection == null
        ? null
        : DailyPlanErrorCode.values.singleWhere(
            (code) => code.wireName == rawRejection,
          );
    return StoredStudySession(
      userId: user,
      event: event,
      acknowledged: acknowledged,
      rejection: rejection,
    );
  }

  Map<String, Object?> _encodeRecord(StoredStudySession record) => {
    'user_id': record.userId,
    'event': record.event.toJson(),
    'acknowledged': record.acknowledged,
    'rejection': record.rejection?.wireName,
  };

  String _encodeState(Map<String, StoredStudySession> records) {
    final entries = records.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return jsonEncode([
      for (final entry in entries) _encodeRecord(entry.value),
    ]);
  }

  void _checkCapacity(
    Map<String, StoredStudySession> records,
    String encoded,
  ) {
    final pending = records.values.where((record) => record.isPending).length;
    if (records.length > maxEvents ||
        utf8.encode(encoded).length + pending * terminalReservation >
            maxBytes) {
      throw const StudySessionStorageFailure();
    }
  }

  @override
  Future<List<StoredStudySession>> list(String userId) => _serial(
    () => _transact(false, (current, _) {
      final owner = ReviewSession(userId: userId).userId;
      final result = _decodeState(current).values
          .where((record) => record.userId == owner)
          .toList()
        ..sort((left, right) {
          final time = left.event.startedAt.compareTo(right.event.startedAt);
          return time != 0
              ? time
              : left.event.clientEventId.compareTo(
                  right.event.clientEventId,
                );
        });
      return List<StoredStudySession>.unmodifiable(result);
    }),
  );

  @override
  Future<StoredStudySession> stage(
    String userId,
    CompletedStudySession event,
  ) => _serial(
    () => _transact(true, (current, replace) {
      final records = _decodeState(current);
      final candidate = StoredStudySession(userId: userId, event: event);
      final key = _key(candidate);
      final previous = records[key];
      if (previous != null) {
        if (!sameStudyEvent(previous.event, event)) {
          throw const DailyPlanFailure(DailyPlanErrorCode.syncConflict);
        }
        return previous;
      }
      final next = Map<String, StoredStudySession>.of(records)
        ..[key] = candidate;
      final encoded = _encodeState(next);
      _checkCapacity(next, encoded);
      replace(encoded);
      return candidate;
    }),
  );

  Future<void> _settle(
    String userId,
    String eventId,
    DailyPlanErrorCode? rejection,
  ) => _serial(
    () => _transact<bool>(true, (current, replace) {
      if (!RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ).hasMatch(eventId)) {
        throw const StudySessionStorageFailure();
      }
      final records = _decodeState(current);
      final owner = ReviewSession(userId: userId).userId;
      final key = '$owner/$eventId';
      final previous = records[key];
      if (previous == null) throw const StudySessionStorageFailure();
      final nextRecord = StoredStudySession(
        userId: owner,
        event: previous.event,
        acknowledged: rejection == null,
        rejection: rejection,
      );
      if (!previous.isPending) {
        if (previous.acknowledged == nextRecord.acknowledged &&
            previous.rejection == nextRecord.rejection) {
          return true;
        }
        throw const StudySessionStorageFailure();
      }
      final next = Map<String, StoredStudySession>.of(records)
        ..[key] = nextRecord;
      final encoded = _encodeState(next);
      _checkCapacity(next, encoded);
      replace(encoded);
      return true;
    }).then<void>((_) {}),
  );

  @override
  Future<void> acknowledge(String userId, String eventId) =>
      _settle(userId, eventId, null);

  @override
  Future<void> reject(
    String userId,
    String eventId,
    DailyPlanErrorCode code,
  ) {
    if (!isDefinitiveStudyRejection(DailyPlanFailure(code))) {
      return Future.error(const StudySessionStorageFailure());
    }
    return _settle(userId, eventId, code);
  }

  Future<R> _serial<R>(Future<R> Function() operation) {
    if (!_accepting || _closed) {
      return Future<R>.error(const StudySessionStorageFailure());
    }
    final result = _tail.then((_) async {
      if (_closed) throw const StudySessionStorageFailure();
      try {
        return await operation();
      } on DailyPlanFailure catch (failure) {
        if (failure.code == DailyPlanErrorCode.syncConflict) rethrow;
        throw const StudySessionStorageFailure();
      } on StudySessionStorageFailure {
        rethrow;
      } on Object {
        throw const StudySessionStorageFailure();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<R> _transact<R>(
    bool write,
    R Function(String? current, void Function(String) replace) operation,
  ) {
    if (_closed) return Future<R>.error(const StudySessionStorageFailure());
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
          done.completeError(
            failure ?? const StudySessionStorageFailure(),
          );
        }
      }

      tx.onabort = ((JSAny? _) {
        fail();
      }).toJS;
      tx.onerror = ((JSAny? _) {
        failure ??= const StudySessionStorageFailure();
        // Browser default aborts; never preventDefault or claim success.
      }).toJS;
      tx.oncomplete = ((JSAny? _) {
        if (done.isCompleted) return;
        if (!ready || failure != null || _closed) {
          fail();
        } else {
          // Only transaction completion commits a study-session write.
          done.complete(value);
        }
      }).toJS;

      final store = tx.objectStore('journal');
      final read = store.read('state'.toJS);
      read.onerror = ((JSAny? _) {
        failure ??= const StudySessionStorageFailure();
      }).toJS;
      read.onsuccess = ((JSAny? _) {
        if (done.isCompleted) return;
        try {
          final raw = read.result;
          if (raw != null && !raw.isA<JSString>()) {
            throw const StudySessionStorageFailure();
          }
          // Queue read/modify/write synchronously inside the request callback;
          // no await/microtask gap can deactivate the IndexedDB transaction.
          value = operation(
            raw == null ? null : (raw as JSString).toDart,
            (next) {
              if (!write || _closed) {
                throw const StudySessionStorageFailure();
              }
              store.put(next.toJS, 'state'.toJS);
            },
          );
          ready = true;
        } on Object catch (error) {
          failure = error is DailyPlanFailure &&
                  error.code == DailyPlanErrorCode.syncConflict
              ? error
              : const StudySessionStorageFailure();
          try {
            tx.abort();
          } on Object {
            fail();
          }
        }
      }).toJS;
    } on Object {
      failure = const StudySessionStorageFailure();
      try {
        transaction?.abort();
      } on Object {
        // The transaction may already have completed or aborted.
      }
      if (!done.isCompleted) {
        done.completeError(const StudySessionStorageFailure());
      }
    }
    return done.future;
  }

  void _closeDatabase() {
    if (_closed) return;
    _accepting = false;
    _closed = true;
    try {
      _database.close();
    } on Object {
      // No raw browser exception crosses the storage boundary.
    }
  }

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _accepting = false;
    await _tail;
    if (!_closed) _closeDatabase();
  }
}

Future<_Database> _openDatabase(String databaseName) async {
  if (!RegExp(r'^[a-z0-9-]{1,80}$').hasMatch(databaseName)) {
    throw const StudySessionStorageFailure();
  }
  final completer = Completer<_Database>();
  try {
    final factory = _factory;
    if (factory == null) throw const StudySessionStorageFailure();
    final request = factory.open(databaseName, 1);
    void fail() {
      if (!completer.isCompleted) {
        completer.completeError(const StudySessionStorageFailure());
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
    throw const StudySessionStorageFailure();
  }
}
