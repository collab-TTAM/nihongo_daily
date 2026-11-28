// TEST ONLY Auth/readiness and held ports; actual captured repository/DTOs.
// No SDK, live provider, hosted learner proof, default activation or stored text.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_controller.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const owner = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';
late Map<String, Object?> fixtures;
Object? response(String operation) =>
    jsonDecode(jsonEncode(fixtures['${operation}_response']));
Future<void> flush() => Future<void>.delayed(Duration.zero);

final class _Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: owner);
}

final class _Port implements AiTextTransport {
  final calls = <({String method, Map<String, Object> body})>[];
  FutureOr<Object?> Function(String)? onCall;
  Future<Object?> call(String method, Map<String, Object> body) {
    calls.add((method: method, body: body));
    final callback = onCall;
    return Future<Object?>.sync(
      () => callback == null ? response(method) : callback(method),
    );
  }

  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) => call('tutor_explain', body);
  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) => call('correct_sentence', body);
}

final class _Harness {
  _Harness({this.timeout = const Duration(seconds: 15)});
  final auth = _Auth();
  final port = _Port();
  final Duration timeout;
  bool ready = true;
  bool broken = false;
  late final repository = CapturedAiTextRepository(
    auth: auth,
    transport: port,
    timeout: timeout,
    isReady: () {
      if (broken) throw StateError('TEST_ONLY_READY_SECRET');
      return ready;
    },
  );
  AiTextController controller({Stream<void>? changes}) =>
      AiTextController(repository: repository, availabilityChanges: changes);
}

Future<void> explain(AiTextController c, [String text = 'Cách dùng ます?']) =>
    c.explain(level: AiTextLevel.n5, questionVi: text);
Future<void> correct(AiTextController c) =>
    c.correct(level: AiTextLevel.n4, sentenceJa: ' 水を飲みます。 ');
void cleared(AiTextController c) {
  expect(c.state.phase, AiTextPhase.unavailable);
  expect(c.state.submittedText, isNull);
  expect(c.state.level, isNull);
  expect(c.state.explanation, isNull);
  expect(c.state.correction, isNull);
  expect(c.state.failure, isNull);
  expect(c.canSubmit, isFalse);
}

void main() {
  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  test(
    'missing capability stays unavailable and never simulates success',
    () async {
      final c = AiTextController();
      cleared(c);
      await explain(c);
      await correct(c);
      cleared(c);
      expect(c.clearResult(), isFalse);
      c.dispose();
    },
  );
  test(
    'explicit methods publish typed results with exact submitted text and no save',
    () async {
      final h = _Harness();
      final c = h.controller();
      expect(c.state.phase, AiTextPhase.idle);
      expect(c.canSubmit, isTrue);
      expect(h.port.calls, isEmpty);
      await explain(c, '  Cách dùng ます?\n');
      expect(h.port.calls.single.body['question_vi'], '  Cách dùng ます?\n');
      expect(c.state.submittedText, '  Cách dùng ます?\n');
      expect(c.state.phase, AiTextPhase.success);
      expect(c.state.operation, AiTextOperation.explain);
      expect(c.state.level, AiTextLevel.n5);
      expect(c.state.explanation!.toJson(), fixtures['tutor_explain_response']);
      expect(c.state.correction, isNull);
      expect(c.clearResult(), isTrue);
      expect(c.state.phase, AiTextPhase.idle);
      expect(c.state.submittedText, isNull);
      await correct(c);
      expect(c.state.operation, AiTextOperation.correct);
      expect(c.state.level, AiTextLevel.n4);
      expect(c.state.submittedText, ' 水を飲みます。 ');
      expect(
        c.state.correction!.toJson(),
        fixtures['correct_sentence_response'],
      );
      expect(c.state.correction!.grammarErrors, isEmpty);
      expect(c.state.correction!.vocabularyErrors, isEmpty);
      expect(c.state.explanation, isNull);
      expect(h.port.calls.last.body['jlpt_level'], 'N4');
      expect(h.port.calls.length, 2);
      c.dispose();
    },
  );
  test(
    'loading blocks cross-method duplicate taps and clearing without resending',
    () async {
      final h = _Harness();
      final held = Completer<Object?>();
      h.port.onCall = (_) => held.future;
      final c = h.controller();
      final work = explain(c);
      expect(c.state.phase, AiTextPhase.loading);
      expect(c.state.submittedText, isNull);
      expect(c.canSubmit, isFalse);
      expect(c.clearResult(), isFalse);
      await correct(c);
      await explain(c);
      expect(c.state.phase, AiTextPhase.loading);
      expect(h.port.calls.length, 1);
      held.complete(response('tutor_explain'));
      await work;
      expect(c.canSubmit, isTrue);
      expect(c.state.phase, AiTextPhase.success);
      c.dispose();
    },
  );
  test(
    'synchronous transport reentry cannot dispatch another method',
    () async {
      final h = _Harness();
      final c = h.controller();
      h.port.onCall = (method) {
        unawaited(correct(c));
        return response(method);
      };
      await explain(c);
      expect(h.port.calls.length, 1);
      expect(c.state.operation, AiTextOperation.explain);
      c.dispose();
    },
  );
  for (final text in ['', ' ' * 5001]) {
    test(
      'invalid input rejected with safe validation error length=${text.length}',
      () async {
        final h = _Harness();
        final c = h.controller();
        await explain(c, text);
        expect(c.state.phase, AiTextPhase.error);
        expect(c.state.failure!.code, AiTextErrorCode.validationFailure);
        expect(c.state.submittedText, isNull);
        expect(h.port.calls, isEmpty);
        c.dispose();
      },
    );
  }
  test(
    'N5 N4 view scope rejects higher levels without changing wire models',
    () async {
      final h = _Harness();
      final c = h.controller();
      for (final level in [AiTextLevel.n3, AiTextLevel.n2, AiTextLevel.n1]) {
        await c.correct(level: level, sentenceJa: '日本語');
        expect(c.state.failure!.code, AiTextErrorCode.validationFailure);
      }
      expect(h.port.calls, isEmpty);
      await c.explain(level: AiTextLevel.n4, questionVi: '😀' * 5000);
      expect(c.state.phase, AiTextPhase.success);
      expect(h.port.calls.single.body['question_vi'], '😀' * 5000);
      c.dispose();
    },
  );
  test(
    'new request removes prior result and malformed output never becomes success',
    () async {
      final h = _Harness();
      final c = h.controller();
      await explain(c);
      final held = Completer<Object?>();
      h.port.onCall = (_) => held.future;
      final work = correct(c);
      expect(c.state.phase, AiTextPhase.loading);
      expect(c.state.explanation, isNull);
      expect(c.state.submittedText, isNull);
      held.complete({'TEST_ONLY_PROVIDER_SECRET': true});
      await work;
      expect(c.state.phase, AiTextPhase.error);
      expect(c.state.failure!.code, AiTextErrorCode.internalError);
      expect(c.state.correction, isNull);
      expect(
        c.state.failure.toString(),
        isNot(contains('TEST_ONLY_PROVIDER_SECRET')),
      );
      c.dispose();
    },
  );
  test('safe retryable error never automatically replays input', () async {
    final h = _Harness();
    final c = h.controller();
    h.port.onCall = (_) => {
      'code': 'PROVIDER_UNAVAILABLE',
      'message_vi': 'TEST_ONLY_PROVIDER_SECRET',
      'retryable': true,
    };
    await explain(c);
    expect(c.state.phase, AiTextPhase.error);
    expect(c.state.failure!.retryable, isTrue);
    expect(
      c.state.failure!.messageVi,
      AiTextErrorCode.providerUnavailable.messageVi,
    );
    expect(c.state.submittedText, isNull);
    c.checkAvailability();
    await flush();
    expect(h.port.calls.length, 1);
    expect(c.clearResult(), isTrue);
    expect(h.port.calls.length, 1);
    h.port.onCall = response;
    await correct(c);
    expect(h.port.calls.length, 2);
    expect(h.port.calls.last.method, 'correct_sentence');
    c.dispose();
  });
  test(
    'externally busy borrowed repository reports pending without overlap',
    () async {
      final h = _Harness();
      final held = Completer<Object?>();
      h.port.onCall = (_) => held.future;
      final outside = h.repository.explain(
        TutorExplainRequest(level: AiTextLevel.n5, questionVi: 'TEST ONLY'),
      );
      final c = h.controller();
      expect(c.canSubmit, isFalse);
      await correct(c);
      expect(c.state.phase, AiTextPhase.pending);
      expect(h.port.calls.length, 1);
      held.complete(response('tutor_explain'));
      await outside;
      expect(c.canSubmit, isTrue);
      expect(h.port.calls.length, 1);
      h.port.onCall = response;
      await correct(c);
      expect(h.port.calls.length, 2);
      c.dispose();
    },
  );
  test(
    'timeout retains wire busy until late error settles then requires manual submit',
    () async {
      final h = _Harness(timeout: const Duration(milliseconds: 10));
      final held = Completer<Object?>();
      h.port.onCall = (_) => held.future;
      final c = h.controller();
      await explain(c);
      expect(c.state.failure!.code, AiTextErrorCode.networkUnavailable);
      expect(c.canSubmit, isFalse);
      await correct(c);
      expect(c.state.phase, AiTextPhase.pending);
      expect(h.port.calls.length, 1);
      held.completeError(StateError('TEST_ONLY_LATE_SECRET'));
      await flush();
      final availability = <bool>[];
      final listener = c.changes.listen((_) => availability.add(c.canSubmit));
      c.recheck();
      await flush();
      expect(availability, [true]);
      expect(c.state.phase, AiTextPhase.pending);
      expect(c.canSubmit, isTrue);
      expect(h.port.calls.length, 1);
      h.port.onCall = response;
      await correct(c);
      expect(c.state.phase, AiTextPhase.success);
      expect(h.port.calls.length, 2);
      c.dispose();
      await listener.cancel();
    },
  );
  for (final error in [false, true]) {
    test(
      'logout clears immediately and ignores late old response error=$error',
      () async {
        final h = _Harness();
        final c = h.controller();
        await explain(c);
        final held = Completer<Object?>();
        h.port.onCall = (_) => held.future;
        final work = correct(c);
        h.auth.currentSession = ReviewSession(userId: other);
        cleared(c); // No stream notification is needed for the read-time fence.
        h.auth.currentSession = ReviewSession(userId: owner);
        cleared(c);
        if (error) {
          held.completeError(StateError('TEST_ONLY_OLD_ACCOUNT_SECRET'));
        } else {
          held.complete(response('correct_sentence'));
        }
        await work;
        cleared(c);
        await explain(c);
        expect(h.port.calls.length, 2);
        c.dispose();
      },
    );
  }
  for (final broken in [false, true]) {
    test(
      'readiness loss or getter failure permanently clears view broken=$broken',
      () async {
        final h = _Harness();
        final c = h.controller();
        await correct(c);
        if (broken) {
          h.broken = true;
        } else {
          h.ready = false;
        }
        c.checkAvailability();
        cleared(c);
        h.broken = false;
        h.ready = true;
        await explain(c);
        cleared(c);
        expect(h.port.calls.length, 1);
        c.dispose();
      },
    );
  }
  test(
    'unauthorized clears success and cannot recreate a capability',
    () async {
      final h = _Harness();
      final c = h.controller();
      await correct(c);
      h.port.onCall = (_) =>
          throw const AiTextFailure(AiTextErrorCode.unauthorized);
      await explain(c);
      cleared(c);
      h.port.onCall = response;
      await correct(c);
      expect(h.port.calls.length, 2);
      c.dispose();
    },
  );
  test(
    'notifications carry no stale snapshot and stream error revokes permanently',
    () async {
      final h = _Harness();
      final source = StreamController<void>.broadcast(sync: true);
      final c = h.controller(changes: source.stream);
      final observed = <AiTextState>[];
      final subscription = c.changes.listen((_) => observed.add(c.state));
      await explain(c);
      observed.clear();
      h.ready = false;
      source.add(null);
      cleared(c);
      await flush();
      expect(observed, isNotEmpty);
      expect(observed.every((s) => s.phase == AiTextPhase.unavailable), isTrue);
      c.dispose();
      await subscription.cancel();
      await source.close();
      final fresh = _Harness();
      final errors = StreamController<void>.broadcast(sync: true);
      final second = fresh.controller(changes: errors.stream);
      await explain(second);
      errors.addError(StateError('TEST_ONLY_STREAM_SECRET'));
      cleared(second);
      second.dispose();
      await errors.close();
    },
  );
  test(
    'source closure disables an otherwise current captured repository',
    () async {
      final h = _Harness();
      final source = StreamController<void>.broadcast();
      final c = h.controller(changes: source.stream);
      await explain(c);
      await source.close();
      cleared(c);
      expect(h.repository.isCurrent, isTrue); // Borrowed lifetime is preserved.
      c.dispose();
    },
  );
  test(
    'dispose clears synchronously with held work and paused notification listener',
    () async {
      final h = _Harness();
      final c = h.controller();
      final subscription = c.changes.listen((_) {});
      subscription.pause();
      final held = Completer<Object?>();
      h.port.onCall = (_) => held.future;
      final work = explain(c);
      c.dispose();
      c.dispose();
      cleared(c);
      expect(h.repository.isCurrent, isTrue);
      held.complete(response('tutor_explain'));
      await work;
      cleared(c);
      expect(h.repository.isBusy, isFalse);
      expect(h.port.calls.length, 1);
      await subscription.cancel();
    },
  );
  test(
    'fresh view requires a fresh captured capability after account replacement',
    () async {
      final h = _Harness();
      final old = h.controller();
      await explain(old);
      h.auth.currentSession = ReviewSession(userId: other);
      old.invalidate();
      cleared(old);
      final freshRepository = CapturedAiTextRepository(
        auth: h.auth,
        transport: h.port,
        isReady: () => h.ready,
      );
      final fresh = AiTextController(repository: freshRepository);
      expect(fresh.state.phase, AiTextPhase.idle);
      expect(h.port.calls.length, 1);
      await correct(fresh);
      expect(fresh.state.phase, AiTextPhase.success);
      cleared(old);
      old.dispose();
      fresh.dispose();
    },
  );
}
