// TEST ONLY sources/Auth. No hosted identity or provider call.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_conversation_view_binding.dart';
import 'package:nihongo_daily/features/ai/data/ai_conversation_source.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_mutation.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

final class _Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(
    userId: '11111111-1111-4111-8111-111111111111',
  );
}

final class _Port implements ConversationMutationTransport {
  int calls = 0;
  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  }) async {
    calls++;
    throw StateError('TEST ONLY unexpected dispatch');
  }
}

final class _Source implements AiConversationSource {
  final events = StreamController<void>.broadcast(sync: true);
  final auth = _Auth();
  final port = _Port();
  int acquisitions = 0;
  void Function()? onAcquire;
  bool broken = false;
  bool brokenStream = false;
  CapturedConversationSession? session;
  CapturedConversationSession fresh() => CapturedConversationSession(
    auth: auth,
    transport: port,
    isReady: () => true,
  );
  @override
  CapturedConversationSession? createAiConversationSession() {
    acquisitions++;
    onAcquire?.call();
    if (broken) throw StateError('TEST_ONLY_SOURCE_SECRET');
    return session;
  }

  @override
  Stream<void> get aiConversationChanges {
    if (brokenStream) throw StateError('TEST_ONLY_STREAM_GETTER_SECRET');
    return events.stream;
  }
}

void main() {
  test('broken stream getter fails closed without dispatch', () async {
    final s = _Source()..brokenStream = true;
    final n = AiConversationBindingNotifier(s);
    expect(n.state, isNull);
    expect(s.port.calls, 0);
    n.dispose();
    await s.events.close();
  });
  test('null source remains unavailable', () {
    final n = AiConversationBindingNotifier(null);
    expect(n.state, isNull);
    n.dispose();
  });
  test(
    'same ready session preserves binding identity without request',
    () async {
      final s = _Source();
      s.session = s.fresh();
      final n = AiConversationBindingNotifier(s);
      final binding = n.state;
      expect(binding!.session, same(s.session));
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
      final n = AiConversationBindingNotifier(s);
      expect(n.state, isNull);
      s.session = s.fresh();
      s.events.add(null);
      final old = n.state;
      expect(old, isNotNull);
      s.session!.revoke();
      s.session = null;
      s.events.add(null);
      expect(n.state, isNull);
      s.auth.currentSession = ReviewSession(
        userId: '22222222-2222-4222-8222-222222222222',
      );
      s.session = s.fresh();
      s.events.add(null);
      expect(n.state, isNot(same(old)));
      expect(n.state!.session, same(s.session));
      expect(s.port.calls, 0);
      n.dispose();
      await s.events.close();
    },
  );
  test(
    'revoked capability and source failure expose no binding or raw error',
    () async {
      final s = _Source();
      s.session = s.fresh();
      s.session!.revoke();
      final n = AiConversationBindingNotifier(s);
      expect(n.state, isNull);
      s.broken = true;
      s.events.add(null);
      expect(n.state, isNull);
      s.broken = false;
      s.session = s.fresh();
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
        s.session = s.fresh();
        final n = AiConversationBindingNotifier(s);
        if (error) {
          s.events.addError(StateError('TEST_ONLY_STREAM_SECRET'));
          s.events.add(null);
        } else {
          await s.events.close();
        }
        expect(n.state, isNull);
        expect(s.session!.isCurrent, isTrue);
        n.dispose();
        if (error) await s.events.close();
      },
    );
  }
  test('dispose preserves borrowed capability and cancels listener', () async {
    final s = _Source();
    s.session = s.fresh();
    final n = AiConversationBindingNotifier(s);
    final count = s.acquisitions;
    n.dispose();
    s.events.add(null);
    expect(s.acquisitions, count);
    expect(s.session!.isCurrent, isTrue);
    expect(s.port.calls, 0);
    await s.events.close();
  });
  test(
    'Riverpod default is unavailable and override replacement stays borrowed',
    () async {
      final defaults = ProviderContainer();
      expect(defaults.read(aiConversationViewBindingProvider), isNull);
      defaults.dispose();
      final a = _Source();
      final b = _Source();
      a.session = a.fresh();
      b.session = b.fresh();
      final container = ProviderContainer(
        overrides: [aiConversationSourceProvider.overrideWithValue(a)],
      );
      final listener = container.listen(
        aiConversationViewBindingProvider,
        (_, _) {},
      );
      expect(
        container.read(aiConversationViewBindingProvider)!.session,
        same(a.session),
      );
      container.updateOverrides([
        aiConversationSourceProvider.overrideWithValue(b),
      ]);
      expect(
        container.read(aiConversationViewBindingProvider)!.session,
        same(b.session),
      );
      final oldCount = a.acquisitions;
      a.events.add(null);
      expect(a.acquisitions, oldCount);
      listener.close();
      container.dispose();
      expect(a.session!.isCurrent, isTrue);
      expect(b.session!.isCurrent, isTrue);
      expect(a.port.calls + b.port.calls, 0);
      await a.events.close();
      await b.events.close();
    },
  );
  test(
    'reentrant source notification does not reacquire or dispatch',
    () async {
      final source = _Source();
      source.session = source.fresh();
      final n = AiConversationBindingNotifier(source);
      final binding = n.state;
      source.onAcquire = () => source.events.add(null);
      source.events.add(null);
      expect(n.state, same(binding));
      expect(source.port.calls, 0);
      n.dispose();
      await source.events.close();
    },
  );
}
