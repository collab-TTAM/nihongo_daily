// TEST ONLY Auth/readiness/transport. No SDK, hosted identity or provider calls.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const owner = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';
late Map<String, Object?> fixtures;

Object? response(String operation) =>
    jsonDecode(jsonEncode(fixtures['${operation}_response']));

TutorExplainRequest explainRequest() =>
    TutorExplainRequest(level: AiTextLevel.n5, questionVi: 'Cách dùng ます?');

CorrectSentenceRequest correctRequest() =>
    CorrectSentenceRequest(level: AiTextLevel.n5, sentenceJa: '水を飲みます。');

Matcher failure(AiTextErrorCode code, {bool retryable = false}) =>
    isA<AiTextFailure>()
        .having((f) => f.code, 'code', code)
        .having((f) => f.retryable, 'retryable', retryable);

final class _Auth implements ReviewAuth {
  ReviewSession? session = ReviewSession(userId: owner);
  bool broken = false;
  void Function()? onRead;

  @override
  ReviewSession? get currentSession {
    if (broken) throw StateError('TEST_ONLY_AUTH_SECRET');
    onRead?.call();
    return session;
  }
}

final class _Transport implements AiTextTransport {
  final calls =
      <({String operation, ReviewSession session, Map<String, Object> body})>[];
  Object? Function(String)? onCall;

  Future<Object?> invoke(
    String operation,
    ReviewSession session,
    Map<String, Object> body,
  ) {
    calls.add((operation: operation, session: session, body: body));
    final callback = onCall;
    return Future<Object?>.sync(
      () => callback == null ? response(operation) : callback(operation),
    );
  }

  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) => invoke('tutor_explain', capturedSession, body);

  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) => invoke('correct_sentence', capturedSession, body);
}

final class _Harness {
  final auth = _Auth();
  final transport = _Transport();
  bool ready = true;
  bool brokenReady = false;
  late final repository = CapturedAiTextRepository(
    auth: auth,
    transport: transport,
    isReady: () {
      if (brokenReady) throw StateError('TEST_ONLY_READY_SECRET');
      return ready;
    },
  );
}

void main() {
  setUpAll(() async {
    fixtures =
        jsonDecode(
              await File('../../contracts/v0.1/fixtures.json').readAsString(),
            )
            as Map<String, Object?>;
  });

  for (final afterRead in [false, true]) {
    for (final replaceSession in [false, true]) {
      test(
        'text final readiness retirement after=$afterRead replace=$replaceSession',
        () async {
          final auth = _Auth();
          final original = auth.session;
          final transport = _Transport();
          late CapturedAiTextRepository repository;
          var armed = false;
          var checks = 0;
          repository = CapturedAiTextRepository(
            auth: auth,
            transport: transport,
            isReady: () {
              if (armed && ++checks == 2) {
                armed = false;
                if (replaceSession) {
                  auth.session = ReviewSession(userId: owner);
                } else {
                  repository.revoke();
                }
              }
              return true;
            },
          );
          if (afterRead) {
            transport.onCall = (operation) {
              checks = 0;
              armed = true;
              return response(operation);
            };
          } else {
            armed = true;
          }
          await expectLater(
            repository.explain(explainRequest()),
            throwsA(failure(AiTextErrorCode.unauthorized)),
          );
          expect(transport.calls, hasLength(afterRead ? 1 : 0));
          expect(repository.isBusy, isFalse);
          auth.session = original;
          expect(repository.isCurrent, isFalse);
          await expectLater(
            repository.correct(correctRequest()),
            throwsA(failure(AiTextErrorCode.unauthorized)),
          );
          expect(transport.calls, hasLength(afterRead ? 1 : 0));
        },
      );
    }
  }

  for (final throughAuth in [false, true]) {
    test('text readiness reentry has no dispatch auth=$throughAuth', () async {
      final auth = _Auth();
      final transport = _Transport();
      late CapturedAiTextRepository repository;
      var armed = false;
      Future<void>? nested;
      void reenter() {
        if (!armed) return;
        armed = false;
        expect(repository.isCurrent, isFalse);
        nested = expectLater(
          repository.correct(correctRequest()),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
      }

      repository = CapturedAiTextRepository(
        auth: auth,
        transport: transport,
        isReady: () {
          if (!throughAuth) {
            reenter();
          }
          return true;
        },
      );
      if (throughAuth) {
        auth.onRead = reenter;
      }
      armed = true;
      final result = await repository.explain(explainRequest());
      expect(nested, isNotNull);
      await nested;
      expect(result.toJson(), fixtures['tutor_explain_response']);
      expect(transport.calls.map((c) => c.operation), ['tutor_explain']);
      expect(repository.isCurrent, isTrue);
      expect(repository.isBusy, isFalse);
      final correction = await repository.correct(correctRequest());
      expect(correction.toJson(), fixtures['correct_sentence_response']);
      expect(transport.calls, hasLength(2));
    });
  }

  test(
    'both fixed text methods preserve frozen bodies and captured identity',
    () async {
      final h = _Harness();
      final tutor = await h.repository.explain(explainRequest());
      final corrected = await h.repository.correct(correctRequest());
      expect(tutor.toJson(), fixtures['tutor_explain_response']);
      expect(corrected.toJson(), fixtures['correct_sentence_response']);
      expect(h.transport.calls.map((c) => c.operation), [
        'tutor_explain',
        'correct_sentence',
      ]);
      expect(h.transport.calls.first.body, fixtures['tutor_explain_request']);
      expect(h.transport.calls.last.body, fixtures['correct_sentence_request']);
      expect(
        h.transport.calls.every((c) => identical(c.session, h.auth.session)),
        isTrue,
      );
      expect(h.repository.isBusy, isFalse);
    },
  );

  test(
    'dispatch body is deeply immutable and contains no owner credential or endpoint',
    () async {
      final h = _Harness();
      await h.repository.explain(
        TutorExplainRequest(
          level: AiTextLevel.n4,
          questionVi: 'TEST ONLY question',
          recentGrammarIds: [owner],
          recentVocabularyIds: [other],
        ),
      );
      final body = h.transport.calls.single.body;
      expect(body.keys, ['jlpt_level', 'question_vi', 'context']);
      expect(() => body['user_id'] = owner, throwsUnsupportedError);
      final context = body['context']! as Map<String, Object>;
      expect(() => context['role'] = 'service_role', throwsUnsupportedError);
      expect(
        () => (context['recent_grammar_ids']! as List<Object>).clear(),
        throwsUnsupportedError,
      );
      expect(
        () => (context['recent_vocabulary_ids']! as List<Object>).clear(),
        throwsUnsupportedError,
      );
      expect(context['recent_grammar_ids'], [owner]);
      expect(context['recent_vocabulary_ids'], [other]);
    },
  );

  test(
    'construction rejects absent session unready and failing getters safely',
    () {
      final absent = _Harness()..auth.session = null;
      expect(
        () => absent.repository,
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      final unready = _Harness()..ready = false;
      expect(
        () => unready.repository,
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      final badAuth = _Harness()..auth.broken = true;
      expect(
        () => badAuth.repository,
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      final badReady = _Harness()..brokenReady = true;
      expect(
        () => badReady.repository,
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      for (final h in [absent, unready, badAuth, badReady]) {
        expect(h.transport.calls, isEmpty);
      }
    },
  );

  test(
    'trusted timeout configuration is positive and at most fifteen seconds',
    () {
      for (final timeout in [
        Duration.zero,
        const Duration(microseconds: -1),
        const Duration(seconds: 16),
      ]) {
        final h = _Harness();
        expect(
          () => CapturedAiTextRepository(
            auth: h.auth,
            transport: h.transport,
            isReady: () => true,
            timeout: timeout,
          ),
          throwsArgumentError,
        );
        expect(h.transport.calls, isEmpty);
      }
    },
  );

  test(
    'same-user session replacement never retargets or revives a captured repository',
    () async {
      final h = _Harness();
      final repo = h.repository;
      final original = h.auth.session;
      h.auth.session = ReviewSession(userId: owner);
      await expectLater(
        repo.explain(explainRequest()),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      h.auth.session = original;
      await expectLater(
        repo.correct(correctRequest()),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(repo.isCurrent, isFalse);
      expect(h.transport.calls, isEmpty);
    },
  );

  test(
    'observed A B A readiness loss and getter errors permanently revoke',
    () async {
      for (final change in [
        'account',
        'readiness',
        'auth-error',
        'ready-error',
      ]) {
        final h = _Harness();
        final repo = h.repository;
        final original = h.auth.session;
        if (change == 'account') h.auth.session = ReviewSession(userId: other);
        if (change == 'readiness') h.ready = false;
        if (change == 'auth-error') h.auth.broken = true;
        if (change == 'ready-error') h.brokenReady = true;
        expect(repo.isCurrent, isFalse);
        h.auth.session = original;
        h.ready = true;
        h.auth.broken = false;
        h.brokenReady = false;
        await expectLater(
          repo.explain(explainRequest()),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        expect(h.transport.calls, isEmpty);
      }
    },
  );

  test(
    'captured owner generation blocks an unobserved profile or refresh barrier',
    () async {
      final h = _Harness();
      var generation = Object();
      final captured = generation;
      final repo = CapturedAiTextRepository(
        auth: h.auth,
        transport: h.transport,
        isReady: () => identical(generation, captured),
      );
      generation = Object();
      await expectLater(
        repo.correct(correctRequest()),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(h.transport.calls, isEmpty);
    },
  );

  for (final sameOwner in [false, true]) {
    test(
      'late success cannot publish after session replacement sameOwner=$sameOwner',
      () async {
        final h = _Harness();
        final pending = Completer<Object?>();
        h.transport.onCall = (_) => pending.future;
        final result = h.repository.explain(explainRequest());
        final rejected = expectLater(
          result,
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        h.auth.session = ReviewSession(userId: sameOwner ? owner : other);
        pending.complete(response('tutor_explain'));
        await rejected;
        expect(h.repository.isCurrent, isFalse);
        expect(h.repository.isBusy, isFalse);
        expect(h.transport.calls, hasLength(1));
      },
    );
  }

  test(
    'logout takes precedence over a late transport error and never exposes details',
    () async {
      final h = _Harness();
      final pending = Completer<Object?>();
      h.transport.onCall = (_) => pending.future;
      final result = h.repository.correct(correctRequest());
      final rejected = expectLater(
        result,
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      h.auth.session = null;
      pending.completeError(StateError('TEST_ONLY_TRANSPORT_SECRET'));
      await rejected;
      expect(h.repository.isCurrent, isFalse);
      expect(h.repository.isBusy, isFalse);
    },
  );

  test(
    'explicit revoke fences pending work without closing the borrowed transport',
    () async {
      final h = _Harness();
      final repo = h.repository;
      final pending = Completer<Object?>();
      h.transport.onCall = (_) => pending.future;
      final result = repo.explain(explainRequest());
      final rejected = expectLater(
        result,
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      repo.revoke();
      pending.complete(response('tutor_explain'));
      await rejected;
      await expectLater(
        repo.correct(correctRequest()),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(h.transport.calls, hasLength(1));
    },
  );

  test(
    'readiness failure during a held result cannot revive after becoming ready',
    () async {
      final h = _Harness();
      final pending = Completer<Object?>();
      h.transport.onCall = (_) => pending.future;
      final result = h.repository.explain(explainRequest());
      final rejected = expectLater(
        result,
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      h.ready = false;
      expect(h.repository.isCurrent, isFalse);
      h.ready = true;
      pending.complete(response('tutor_explain'));
      await rejected;
      expect(h.transport.calls, hasLength(1));
    },
  );

  test(
    'server error codes use fixed messages and only transient retry flags survive',
    () async {
      for (final code in AiTextErrorCode.values) {
        final h = _Harness();
        h.transport.onCall = (_) => {
          'code': code.wireName,
          'message_vi': 'TEST_ONLY_SERVER_SECRET',
          'retryable': true,
        };
        try {
          await h.repository.explain(explainRequest());
          fail('Server error accepted');
        } on AiTextFailure catch (error) {
          final transient = const {
            AiTextErrorCode.networkUnavailable,
            AiTextErrorCode.providerUnavailable,
            AiTextErrorCode.rateLimited,
          }.contains(code);
          expect(error.code, code);
          expect(error.retryable, transient);
          expect(error.messageVi, code.messageVi);
          expect(error.toString(), isNot(contains('TEST_ONLY')));
          expect(error.messageVi, isNot(contains('TEST_ONLY')));
        }
        expect(h.transport.calls, hasLength(1));
      }
    },
  );

  test(
    'server unauthorized permanently revokes even when local hints remain ready',
    () async {
      final h = _Harness();
      h.transport.onCall = (_) => {
        'code': 'UNAUTHORIZED',
        'message_vi': 'TEST_ONLY_SERVER_SECRET',
        'retryable': true,
      };
      await expectLater(
        h.repository.correct(correctRequest()),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      h.transport.onCall = null;
      await expectLater(
        h.repository.explain(explainRequest()),
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(h.transport.calls, hasLength(1));
    },
  );

  test(
    'malformed error objects cannot become success or display raw server text',
    () async {
      final valid = <String, Object?>{
        'code': 'PROVIDER_UNAVAILABLE',
        'message_vi': 'TEST_ONLY_SERVER_SECRET',
        'retryable': true,
      };
      for (final raw in <Object?>[
        {...valid, 'extra': 'TEST_ONLY_PATH'},
        {...valid, 'code': 'UNKNOWN'},
        {...valid, 'retryable': 'true'},
        {...valid, 'message_vi': null},
        {...valid, 'message_vi': ''},
        {...valid, 'message_vi': List.filled(501, '😀').join()},
        {...valid, 'answer_vi': 'TEST ONLY answer'},
        {'code': 'INTERNAL_ERROR'},
      ]) {
        final h = _Harness();
        h.transport.onCall = (_) => raw;
        await expectLater(
          h.repository.explain(explainRequest()),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
        expect(h.transport.calls, hasLength(1));
      }
    },
  );

  test(
    'malformed or swapped success shapes fail without fallback text',
    () async {
      for (final raw in <Object?>[
        null,
        [],
        'TEST_ONLY_SECRET',
        {'answer_vi': 'x'},
        response('correct_sentence'),
      ]) {
        final h = _Harness();
        h.transport.onCall = (_) => raw;
        await expectLater(
          h.repository.explain(explainRequest()),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
      }
      final h = _Harness();
      h.transport.onCall = (_) => response('tutor_explain');
      await expectLater(
        h.repository.correct(correctRequest()),
        throwsA(failure(AiTextErrorCode.internalError)),
      );
    },
  );

  test(
    'typed transport failures are normalized and raw exceptions become fixed internal errors',
    () async {
      for (final error in <Object>[
        const AiTextFailure(
          AiTextErrorCode.networkUnavailable,
          retryable: true,
        ),
        const AiTextFailure(AiTextErrorCode.forbidden, retryable: true),
        StateError('TEST_ONLY_RAW_SECRET'),
      ]) {
        final h = _Harness();
        h.transport.onCall = (_) => throw error;
        final code = error is AiTextFailure
            ? error.code
            : AiTextErrorCode.internalError;
        await expectLater(
          h.repository.correct(correctRequest()),
          throwsA(
            failure(
              code,
              retryable: code == AiTextErrorCode.networkUnavailable,
            ),
          ),
        );
        expect(h.transport.calls, hasLength(1));
      }
    },
  );

  test(
    'one pending operation excludes both duplicates and the other text operation',
    () async {
      final h = _Harness();
      final pending = Completer<Object?>();
      h.transport.onCall = (_) => pending.future;
      final first = h.repository.explain(explainRequest());
      expect(h.repository.isBusy, isTrue);
      await expectLater(
        h.repository.explain(explainRequest()),
        throwsA(isA<AiTextRequestPending>()),
      );
      await expectLater(
        h.repository.correct(correctRequest()),
        throwsA(isA<AiTextRequestPending>()),
      );
      expect(h.transport.calls, hasLength(1));
      pending.complete(response('tutor_explain'));
      await first;
      expect(h.repository.isBusy, isFalse);
      h.transport.onCall = null;
      await h.repository.correct(correctRequest());
      expect(h.transport.calls, hasLength(2));
    },
  );

  test(
    'single-flight registration precedes synchronous transport reentry',
    () async {
      final h = _Harness();
      final repo = h.repository;
      Future<void>? rejected;
      h.transport.onCall = (_) {
        rejected = expectLater(
          repo.correct(correctRequest()),
          throwsA(isA<AiTextRequestPending>()),
        );
        return response('tutor_explain');
      };
      await repo.explain(explainRequest());
      await rejected!;
      expect(h.transport.calls, hasLength(1));
    },
  );

  test(
    'timeout keeps busy through late success and never automatically redispatches',
    () async {
      final h = _Harness();
      final pending = Completer<Object?>();
      h.transport.onCall = (_) => pending.future;
      final repo = CapturedAiTextRepository(
        auth: h.auth,
        transport: h.transport,
        isReady: () => true,
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        repo.explain(explainRequest()),
        throwsA(failure(AiTextErrorCode.networkUnavailable)),
      );
      expect(repo.isBusy, isTrue);
      await expectLater(
        repo.correct(correctRequest()),
        throwsA(isA<AiTextRequestPending>()),
      );
      expect(h.transport.calls, hasLength(1));
      pending.complete(response('tutor_explain'));
      await Future<void>.delayed(Duration.zero);
      expect(repo.isBusy, isFalse);
      expect(h.transport.calls, hasLength(1));
      h.transport.onCall = null;
      await repo.correct(correctRequest());
      expect(h.transport.calls, hasLength(2));
    },
  );

  test(
    'late timeout error is consumed without publication or an unhandled exception',
    () async {
      final h = _Harness();
      final pending = Completer<Object?>();
      h.transport.onCall = (_) => pending.future;
      final repo = CapturedAiTextRepository(
        auth: h.auth,
        transport: h.transport,
        isReady: () => true,
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        repo.correct(correctRequest()),
        throwsA(failure(AiTextErrorCode.networkUnavailable)),
      );
      expect(repo.isBusy, isTrue);
      pending.completeError(StateError('TEST_ONLY_LATE_SECRET'));
      await Future<void>.delayed(Duration.zero);
      expect(repo.isBusy, isFalse);
      expect(h.transport.calls, hasLength(1));
    },
  );

  test(
    'revocation before a timeout reports unauthorized and retains the I/O lock',
    () async {
      final h = _Harness();
      final pending = Completer<Object?>();
      h.transport.onCall = (_) => pending.future;
      final repo = CapturedAiTextRepository(
        auth: h.auth,
        transport: h.transport,
        isReady: () => true,
        timeout: const Duration(milliseconds: 10),
      );
      final result = repo.explain(explainRequest());
      final rejected = expectLater(
        result,
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      h.auth.session = null;
      await rejected;
      expect(repo.isCurrent, isFalse);
      expect(repo.isBusy, isTrue);
      pending.complete(response('tutor_explain'));
      await Future<void>.delayed(Duration.zero);
      expect(repo.isBusy, isFalse);
      expect(h.transport.calls, hasLength(1));
    },
  );
}
