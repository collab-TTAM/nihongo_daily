// TEST ONLY lifecycle/transport ports. No SDK, credential, hosted or provider proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const a = '11111111-1111-4111-8111-111111111111';
const b = '22222222-2222-4222-8222-222222222222';
late Object? response;
final request = TutorExplainRequest(
  level: AiTextLevel.n5,
  questionVi: 'TEST ONLY',
);
final unauthorized = isA<AiTextFailure>().having(
  (f) => f.code,
  'code',
  AiTextErrorCode.unauthorized,
);
final internal = isA<AiTextFailure>().having(
  (f) => f.code,
  'code',
  AiTextErrorCode.internalError,
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

final class _Auth implements ReviewAuth {
  ReviewSession? session = ReviewSession(userId: a);
  bool broken = false;
  @override
  ReviewSession? get currentSession {
    if (broken) throw StateError('TEST_ONLY_GETTER_SECRET');
    return session;
  }
}

final class _Transport implements OwnedAiTextTransport {
  _Transport(this.ready);
  final bool Function() ready;
  bool revoked = false;
  bool brokenRevoke = false;
  bool brokenClose = false;
  bool brokenCurrent = false;
  int calls = 0;
  int closes = 0;
  Completer<void>? closeWait;
  Future<Object?> Function()? onCall;
  final pending = <Future<void>>{};
  Future<void>? closing;
  @override
  bool get isCurrent {
    if (brokenCurrent) throw StateError('TEST_ONLY_CURRENT_SECRET');
    return !revoked && ready();
  }

  @override
  void revoke() {
    revoked = true;
    if (brokenRevoke) throw StateError('TEST_ONLY_REVOKE_SECRET');
  }

  @override
  Future<void> close() => closing ??= () async {
    closes++;
    revoked = true;
    await closeWait?.future;
    await Future.wait(pending.toList());
    if (brokenClose) throw StateError('TEST_ONLY_CLOSE_SECRET');
  }();
  Future<Object?> send() {
    if (!isCurrent) throw const AiTextFailure(AiTextErrorCode.unauthorized);
    calls++;
    final operation = Future<Object?>.sync(() => onCall?.call() ?? response);
    final settled = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    pending.add(settled);
    unawaited(settled.then<void>((_) => pending.remove(settled)));
    return operation;
  }

  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) => send();
  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) => send();
}

final class _Harness {
  _Harness() {
    owner = AiTextRuntimeOwner(
      createTransport: ({required auth, required isReady}) {
        builds++;
        onBuild?.call();
        if (failBuild) throw StateError('TEST_ONLY_FACTORY_SECRET');
        final transport = _Transport(isReady);
        transports.add(transport);
        configure?.call(transport);
        return transport;
      },
    );
  }
  late final AiTextRuntimeOwner owner;
  final auth = _Auth();
  var generation = AiTextGeneration();
  bool ready = true;
  bool failBuild = false;
  int builds = 0;
  void Function()? onBuild;
  void Function(_Transport)? configure;
  final transports = <_Transport>[];
  CapturedAiTextRepository? acquire() =>
      owner.acquire(auth: auth, generation: generation, isReady: () => ready);
}

void main() {
  late _Harness h;
  setUpAll(() {
    final fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    response = fixtures['tutor_explain_response'];
  });
  setUp(() => h = _Harness());
  tearDown(() async {
    try {
      await h.owner.close();
    } on AiTextFailure {
      expect(h.owner.isFailed, isTrue);
    }
  });

  test(
    'unready missing identity and broken getters never construct a transport',
    () {
      h.ready = false;
      expect(h.acquire(), isNull);
      h.ready = true;
      h.auth.session = null;
      expect(h.acquire(), isNull);
      h.auth.broken = true;
      expect(h.acquire(), isNull);
      expect(h.builds, 0);
    },
  );
  test(
    'repeated ready acquisition returns one repository and performs no request',
    () async {
      final repo = h.acquire();
      expect(repo, isNotNull);
      for (var i = 0; i < 20; i++) {
        expect(identical(h.acquire(), repo), isTrue);
      }
      expect(h.builds, 1);
      expect(h.transports.single.calls, 0);
      expect((await repo!.explain(request)).toJson(), response);
    },
  );
  test(
    'new generation waits for old close and cannot revive the retired generation',
    () async {
      final old = h.generation;
      final repo = h.acquire()!;
      final t = h.transports.single..closeWait = Completer<void>();
      h.generation = AiTextGeneration();
      expect(h.acquire(), isNull);
      expect(t.revoked, isTrue);
      expect(h.owner.isDraining, isTrue);
      await expectLater(repo.explain(request), throwsA(unauthorized));
      expect(h.acquire(), isNull);
      expect(h.builds, 1);
      t.closeWait!.complete();
      await flush();
      final next = h.acquire();
      expect(next, isNotNull);
      expect(identical(next, repo), isFalse);
      h.generation = old;
      expect(h.acquire(), isNull);
      expect(h.builds, 2);
    },
  );
  test(
    'readiness loss revokes synchronously and requires a fresh generation',
    () async {
      final repo = h.acquire()!;
      h.ready = false;
      h.owner.check();
      expect(h.transports.single.revoked, isTrue);
      await expectLater(repo.explain(request), throwsA(unauthorized));
      await flush();
      h.ready = true;
      expect(h.acquire(), isNull);
      h.generation = AiTextGeneration();
      expect(h.acquire(), isNotNull);
    },
  );
  test(
    'same-user identity replacement cannot retarget a cached repository',
    () async {
      final repo = h.acquire()!;
      h.auth.session = ReviewSession(userId: a);
      h.owner.check();
      await expectLater(repo.explain(request), throwsA(unauthorized));
      await flush();
      expect(h.acquire(), isNull);
      expect(h.transports.single.calls, 0);
    },
  );
  test('A B A transitions keep every retired ready token fenced', () async {
    final firstGeneration = h.generation;
    final first = h.acquire()!;
    h.auth.session = ReviewSession(userId: b);
    h.generation = AiTextGeneration();
    expect(h.acquire(), isNull);
    await flush();
    expect(h.acquire(), isNotNull);
    h.auth.session = ReviewSession(userId: a);
    h.owner.invalidate();
    await flush();
    h.generation = firstGeneration;
    expect(h.acquire(), isNull);
    await expectLater(first.explain(request), throwsA(unauthorized));
    h.generation = AiTextGeneration();
    expect(h.acquire(), isNotNull);
  });
  test(
    'revoked transport cannot be recreated under unchanged ready generation',
    () async {
      h.acquire();
      h.transports.single.revoked = true;
      h.owner.check();
      await flush();
      expect(h.acquire(), isNull);
      expect(h.builds, 1);
      h.generation = AiTextGeneration();
      expect(h.acquire(), isNotNull);
    },
  );
  for (final lateError in [false, true]) {
    test(
      'late accepted transport settlement is fenced and drained error=$lateError',
      () async {
        final repo = h.acquire()!;
        final pending = Completer<Object?>();
        h.transports.single.onCall = () => pending.future;
        final rejected = expectLater(
          repo.explain(request),
          throwsA(unauthorized),
        );
        h.owner.invalidate();
        h.generation = AiTextGeneration();
        expect(h.acquire(), isNull);
        expect(h.transports.single.revoked, isTrue);
        if (lateError) {
          pending.completeError(StateError('TEST_ONLY_LATE_SECRET'));
        } else {
          pending.complete(response);
        }
        await rejected;
        await flush();
        expect(h.acquire(), isNotNull);
        expect(h.builds, 2);
        expect(h.transports.first.calls, 1);
        expect(h.transports.last.calls, 0);
      },
    );
  }
  test('factory reentry cannot allocate a second transport', () {
    CapturedAiTextRepository? nested;
    h.onBuild = () {
      nested = h.acquire();
    };
    expect(h.acquire(), isNotNull);
    expect(nested, isNull);
    expect(h.builds, 1);
  });
  test(
    'revocation during construction retires the orphan before another build',
    () async {
      h.onBuild = h.owner.invalidate;
      h.configure = (t) {
        t.closeWait = Completer<void>();
      };
      expect(h.acquire(), isNull);
      expect(h.transports.single.revoked, isTrue);
      h.generation = AiTextGeneration();
      expect(h.acquire(), isNull);
      h.transports.single.closeWait!.complete();
      await flush();
      h.onBuild = null;
      h.configure = null;
      expect(h.acquire(), isNotNull);
    },
  );
  test(
    'close during construction waits for orphan cleanup and is idempotent',
    () async {
      Future<void>? closing;
      h.onBuild = () {
        closing = h.owner.close();
      };
      h.configure = (t) {
        t.closeWait = Completer<void>();
      };
      expect(h.acquire(), isNull);
      expect(identical(closing, h.owner.close()), isTrue);
      var closed = false;
      unawaited(
        closing!.then((_) {
          closed = true;
        }),
      );
      await flush();
      expect(closed, isFalse);
      h.transports.single.closeWait!.complete();
      await closing;
      expect(closed, isTrue);
      expect(h.acquire(), isNull);
    },
  );
  test(
    'close revokes accepted work before returning and drains it before completion',
    () async {
      final repo = h.acquire()!;
      final pending = Completer<Object?>();
      h.transports.single.onCall = () => pending.future;
      final rejected = expectLater(
        repo.explain(request),
        throwsA(unauthorized),
      );
      var closed = false;
      final closing = h.owner.close()
        ..then((_) {
          closed = true;
        });
      expect(repo.isCurrent, isFalse);
      expect(h.acquire(), isNull);
      await flush();
      expect(closed, isFalse);
      pending.complete(response);
      await rejected;
      await closing;
      expect(closed, isTrue);
    },
  );
  test(
    'factory errors expose unavailable and allow explicit retry without fallback',
    () {
      h.failBuild = true;
      expect(h.acquire(), isNull);
      expect(h.transports, isEmpty);
      h.failBuild = false;
      expect(h.acquire(), isNotNull);
      expect(h.builds, 2);
    },
  );
  test('readiness failure after factory return closes its orphan', () async {
    h.onBuild = () {
      h.ready = false;
    };
    expect(h.acquire(), isNull);
    await flush();
    expect(h.transports.single.revoked, isTrue);
    expect(h.transports.single.closes, 1);
    h.ready = true;
    h.onBuild = null;
    expect(h.acquire(), isNull);
  });
  test(
    'transport getter failure revokes and cleans up without raw errors',
    () async {
      h.acquire();
      h.transports.single.brokenCurrent = true;
      h.owner.check();
      await flush();
      expect(h.transports.single.revoked, isTrue);
      expect(h.acquire(), isNull);
    },
  );
  for (final phase in ['revoke', 'close']) {
    test(
      'failed $phase cleanup permanently blocks replacement with safe shutdown',
      () async {
        h.acquire();
        final t = h.transports.single;
        t.brokenRevoke = phase == 'revoke';
        t.brokenClose = phase == 'close';
        h.owner.invalidate();
        await flush();
        expect(h.owner.isFailed, isTrue);
        h.generation = AiTextGeneration();
        expect(h.acquire(), isNull);
        expect(h.builds, 1);
        await expectLater(h.owner.close(), throwsA(internal));
      },
    );
  }
  test('paused availability listeners cannot hold shutdown open', () async {
    final sub = h.owner.changes.listen((_) {});
    sub.pause();
    h.acquire();
    await h.owner.close().timeout(const Duration(seconds: 1));
    await sub.cancel();
    expect(h.acquire(), isNull);
  });
}
