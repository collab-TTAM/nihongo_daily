// TEST ONLY sources/Auth. No hosted identity or provider call.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_view_binding.dart';
import 'package:nihongo_daily/features/ai/data/ai_text_repository_source.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

final class _Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(
    userId: '11111111-1111-4111-8111-111111111111',
  );
}

final class _Port implements AiTextTransport {
  int calls = 0;
  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async {
    calls++;
    throw StateError('TEST ONLY unexpected dispatch');
  }

  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async {
    calls++;
    throw StateError('TEST ONLY unexpected dispatch');
  }
}

final class _Source
    implements AiTextRepositorySource, AccountStartupRuntime<Object> {
  final events = StreamController<void>.broadcast(sync: true);
  final auth = _Auth();
  final port = _Port();
  int acquisitions = 0;
  bool broken = false;
  bool brokenStream = false;
  Completer<void>? starting;
  CapturedAiTextRepository? repository;
  CapturedAiTextRepository fresh() => CapturedAiTextRepository(
    auth: auth,
    transport: port,
    isReady: () => true,
  );
  @override
  CapturedAiTextRepository? createAiTextRepository() {
    acquisitions++;
    if (broken) throw StateError('TEST_ONLY_SOURCE_SECRET');
    return repository;
  }

  @override
  Stream<void> get aiTextChanges {
    if (brokenStream) throw StateError('TEST_ONLY_STREAM_GETTER_SECRET');
    return events.stream;
  }

  @override
  Object get account => this;
  @override
  bool get canOfferLogin => false;
  @override
  Future<void> start() async {
    await starting?.future;
  }

  @override
  Future<void> close() async {}
}

void main() {
  test('broken stream getter fails closed without dispatch', () async {
    final s = _Source()..brokenStream = true;
    final n = AiTextBindingNotifier(s);
    expect(n.state, isNull);
    expect(s.port.calls, 0);
    n.dispose();
    await s.events.close();
  });
  test('null source remains unavailable', () {
    final n = AiTextBindingNotifier(null);
    expect(n.state, isNull);
    n.dispose();
  });
  test(
    'same ready repository preserves binding identity without request',
    () async {
      final s = _Source();
      s.repository = s.fresh();
      final n = AiTextBindingNotifier(s);
      final binding = n.state;
      expect(binding!.repository, same(s.repository));
      s.events.add(null);
      expect(n.state, same(binding));
      expect(s.port.calls, 0);
      n.dispose();
      await s.events.close();
    },
  );
  test(
    'readiness null and fresh capability replace binding without replay',
    () async {
      final s = _Source();
      final n = AiTextBindingNotifier(s);
      expect(n.state, isNull);
      s.repository = s.fresh();
      s.events.add(null);
      final old = n.state;
      expect(old, isNotNull);
      s.repository!.revoke();
      s.repository = null;
      s.events.add(null);
      expect(n.state, isNull);
      s.auth.currentSession = ReviewSession(
        userId: '22222222-2222-4222-8222-222222222222',
      );
      s.repository = s.fresh();
      s.events.add(null);
      expect(n.state, isNot(same(old)));
      expect(n.state!.repository, same(s.repository));
      expect(s.port.calls, 0);
      n.dispose();
      await s.events.close();
    },
  );
  test(
    'revoked capability and source failure expose no binding or raw error',
    () async {
      final s = _Source();
      s.repository = s.fresh();
      s.repository!.revoke();
      final n = AiTextBindingNotifier(s);
      expect(n.state, isNull);
      s.broken = true;
      s.events.add(null);
      expect(n.state, isNull);
      s.broken = false;
      s.repository = s.fresh();
      s.events.add(null);
      expect(n.state, isNotNull);
      expect(s.port.calls, 0);
      n.dispose();
      await s.events.close();
    },
  );
  for (final error in [false, true]) {
    test(
      'stream termination fails closed and never revives error=$error',
      () async {
        final s = _Source();
        s.repository = s.fresh();
        final n = AiTextBindingNotifier(s);
        if (error) {
          s.events.addError(StateError('TEST_ONLY_STREAM_SECRET'));
          s.events.add(null);
        } else {
          await s.events.close();
        }
        expect(n.state, isNull);
        expect(s.repository!.isCurrent, isTrue);
        n.dispose();
        if (error) await s.events.close();
      },
    );
  }
  test('dispose preserves borrowed capability and cancels listener', () async {
    final s = _Source();
    s.repository = s.fresh();
    final n = AiTextBindingNotifier(s);
    final count = s.acquisitions;
    n.dispose();
    s.events.add(null);
    expect(s.acquisitions, count);
    expect(s.repository!.isCurrent, isTrue);
    expect(s.port.calls, 0);
    await s.events.close();
  });
  test(
    'startup exposes source only after start and hides it before close',
    () async {
      final s = _Source()..starting = Completer<void>();
      final c = AccountStartupController<Object>(() async => s);
      expect(c.aiTextSource, isNull);
      final work = c.start();
      await Future<void>.delayed(Duration.zero);
      expect(c.aiTextSource, isNull);
      s.starting!.complete();
      await work;
      expect(c.aiTextSource, same(s));
      expect(s.acquisitions, 0);
      final closing = c.close();
      expect(c.aiTextSource, isNull);
      await closing;
      await s.events.close();
    },
  );
}
