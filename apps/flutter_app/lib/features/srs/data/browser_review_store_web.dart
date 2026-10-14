import 'dart:async';
import 'dart:js_interop';

import 'durable_review_repository.dart';
import 'review_repository.dart';
import 'transactional_review_store.dart';

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

Future<TransactionalReviewStore> openBrowserReviewStore({
  String databaseName = 'nihongo-daily-review-v1',
}) async {
  if (!RegExp(r'^[a-z0-9-]{1,80}$').hasMatch(databaseName)) {
    throw const ReviewStorageFailure();
  }
  final completer = Completer<_Database>();
  try {
    final factory = _factory;
    if (factory == null) throw const ReviewStorageFailure();
    final request = factory.open(databaseName, 1);
    void fail() {
      if (!completer.isCompleted) {
        completer.completeError(const ReviewStorageFailure());
      }
    }

    request.onupgradeneeded = ((JSAny? _) {
      try {
        _Database(request.result! as JSObject).createObjectStore('journal');
      } on Object {
        try {
          request.transaction?.abort();
        } on Object {
          /* Already aborted. */
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
          database
              .close(); // Late blocked/failed open cannot leak a connection.
        } else {
          completer.complete(database);
        }
      } on Object {
        fail();
      }
    }).toJS;
    final database = await completer.future;
    return TransactionalReviewStore(_IndexedDbTransactions(database));
  } on Object {
    throw const ReviewStorageFailure();
  }
}

final class _IndexedDbTransactions implements ReviewLedgerTransactions {
  _IndexedDbTransactions(this.database) {
    database.onversionchange = ((JSAny? _) {
      _close();
    }).toJS;
    database.onclose = ((JSAny? _) {
      _closed = true;
    }).toJS;
  }
  final _Database database;
  bool _closed = false;

  @override
  Future<T> transact<T>(
    bool write,
    T Function(String? current, void Function(String) replace) operation,
  ) async {
    if (_closed) throw const ReviewStorageFailure();
    final done = Completer<T>();
    Object? failure;
    late T value;
    var ready = false;
    try {
      final tx = database.transaction(
        'journal',
        write ? 'readwrite' : 'readonly',
      );
      void fail() {
        if (!done.isCompleted) {
          done.completeError(failure ?? const ReviewStorageFailure());
        }
      }

      tx.onabort = ((JSAny? _) {
        fail();
      }).toJS;
      tx.onerror = ((JSAny? _) {
        failure ??= const ReviewStorageFailure();
        // Default browser handling aborts; never preventDefault/claim success.
      }).toJS;
      tx.oncomplete = ((JSAny? _) {
        if (done.isCompleted) return;
        if (!ready || failure != null || _closed) {
          fail();
        } else {
          done.complete(
            value,
          ); // Commit, not request success, acknowledges disk.
        }
      }).toJS;
      final store = tx.objectStore('journal');
      final read = store.read('state'.toJS);
      read.onerror = ((JSAny? _) {
        failure ??= const ReviewStorageFailure();
      }).toJS;
      read.onsuccess = ((JSAny? _) {
        try {
          final raw = read.result;
          if (raw != null && !raw.isA<JSString>()) {
            throw const ReviewStorageFailure();
          }
          // No await/microtask gap: the entire mutation is queued while this
          // IDB request callback keeps the transaction active.
          value = operation(raw == null ? null : (raw as JSString).toDart, (
            next,
          ) {
            if (!write || _closed) throw const ReviewStorageFailure();
            store.put(next.toJS, 'state'.toJS);
          });
          ready = true;
        } on Object catch (error) {
          failure = error is ReviewTransportFailure
              ? error
              : const ReviewStorageFailure();
          try {
            tx.abort();
          } on Object {
            fail();
          }
        }
      }).toJS;
    } on Object {
      failure = const ReviewStorageFailure();
      if (!done.isCompleted) done.completeError(const ReviewStorageFailure());
    }
    return done.future;
  }

  void _close() {
    _closed = true;
    database.close();
  }

  @override
  Future<void> close() async {
    if (!_closed) _close();
  }
}
