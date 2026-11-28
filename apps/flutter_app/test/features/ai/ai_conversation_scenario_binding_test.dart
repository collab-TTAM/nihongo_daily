// TEST ONLY sources/Auth. No hosted identity or provider call.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_conversation_scenario_binding.dart';
import 'package:nihongo_daily/features/ai/data/ai_conversation_scenario_source.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_scenarios.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

final class _Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(
    userId: '11111111-1111-4111-8111-111111111111',
  );
}

final class _Port implements ConversationScenarioReadPort {
  int calls = 0;
  @override
  Future<Object?> read({
    required ReviewSession capturedSession,
    required AiTextLevel level,
  }) async {
    calls++;
    throw StateError('TEST ONLY unexpected dispatch');
  }
}

final class _Source implements AiConversationScenarioSource {
  final events = StreamController<void>.broadcast(sync: true);
  final auth = _Auth();
  final port = _Port();
  int acquisitions = 0;
  void Function()? onAcquire;
  bool broken = false;
  bool brokenStream = false;
  CapturedConversationScenarios? reader;
  CapturedConversationScenarios fresh() => CapturedConversationScenarios(
    auth: auth,
    port: port,
    isReady: () => true,
  );
  @override
  CapturedConversationScenarios? createAiConversationScenarios() {
    acquisitions++;
    onAcquire?.call();
    if (broken) throw StateError('TEST_ONLY_SOURCE_SECRET');
    return reader;
  }

  @override
  Stream<void> get aiConversationScenarioChanges {
    if (brokenStream) throw StateError('TEST_ONLY_STREAM_GETTER_SECRET');
    return events.stream;
  }
}

void main() {
  test('broken stream getter fails closed without dispatch', () async {
    final s = _Source()..brokenStream = true;
    final n = AiConversationScenarioBindingNotifier(s);
    expect(n.state, isNull);
    expect(s.port.calls, 0);
    n.dispose();
    await s.events.close();
  });
  test('null source remains unavailable', () {
    final n = AiConversationScenarioBindingNotifier(null);
    expect(n.state, isNull);
    n.dispose();
  });
  test(
    'same ready reader preserves binding identity without request',
    () async {
      final s = _Source();
      s.reader = s.fresh();
      final n = AiConversationScenarioBindingNotifier(s);
      final binding = n.state;
      expect(binding!.reader, same(s.reader));
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
      final n = AiConversationScenarioBindingNotifier(s);
      expect(n.state, isNull);
      s.reader = s.fresh();
      s.events.add(null);
      final old = n.state;
      expect(old, isNotNull);
      s.reader!.revoke();
      s.reader = null;
      s.events.add(null);
      expect(n.state, isNull);
      s.auth.currentSession = ReviewSession(
        userId: '22222222-2222-4222-8222-222222222222',
      );
      s.reader = s.fresh();
      s.events.add(null);
      expect(n.state, isNot(same(old)));
      expect(n.state!.reader, same(s.reader));
      expect(s.port.calls, 0);
      n.dispose();
      await s.events.close();
    },
  );
  test(
    'revoked capability and source failure expose no binding or raw error',
    () async {
      final s = _Source();
      s.reader = s.fresh();
      s.reader!.revoke();
      final n = AiConversationScenarioBindingNotifier(s);
      expect(n.state, isNull);
      s.broken = true;
      s.events.add(null);
      expect(n.state, isNull);
      s.broken = false;
      s.reader = s.fresh();
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
        s.reader = s.fresh();
        final n = AiConversationScenarioBindingNotifier(s);
        if (error) {
          s.events.addError(StateError('TEST_ONLY_STREAM_SECRET'));
          s.events.add(null);
        } else {
          await s.events.close();
        }
        expect(n.state, isNull);
        expect(s.reader!.isCurrent, isTrue);
        n.dispose();
        if (error) await s.events.close();
      },
    );
  }
  test('dispose preserves borrowed capability and cancels listener', () async {
    final s = _Source();
    s.reader = s.fresh();
    final n = AiConversationScenarioBindingNotifier(s);
    final count = s.acquisitions;
    n.dispose();
    s.events.add(null);
    expect(s.acquisitions, count);
    expect(s.reader!.isCurrent, isTrue);
    expect(s.port.calls, 0);
    await s.events.close();
  });
  test(
    'Riverpod default is unavailable and override replacement stays borrowed',
    () async {
      final defaults = ProviderContainer();
      expect(defaults.read(aiConversationScenarioBindingProvider), isNull);
      defaults.dispose();
      final a = _Source();
      final b = _Source();
      a.reader = a.fresh();
      b.reader = b.fresh();
      final container = ProviderContainer(
        overrides: [aiConversationScenarioSourceProvider.overrideWithValue(a)],
      );
      final listener = container.listen(
        aiConversationScenarioBindingProvider,
        (_, _) {},
      );
      expect(
        container.read(aiConversationScenarioBindingProvider)!.reader,
        same(a.reader),
      );
      container.updateOverrides([
        aiConversationScenarioSourceProvider.overrideWithValue(b),
      ]);
      expect(
        container.read(aiConversationScenarioBindingProvider)!.reader,
        same(b.reader),
      );
      final oldCount = a.acquisitions;
      a.events.add(null);
      expect(a.acquisitions, oldCount);
      listener.close();
      container.dispose();
      expect(a.reader!.isCurrent, isTrue);
      expect(b.reader!.isCurrent, isTrue);
      expect(a.port.calls + b.port.calls, 0);
      await a.events.close();
      await b.events.close();
    },
  );
  test(
    'reentrant source notification does not reacquire or dispatch',
    () async {
      final source = _Source();
      source.reader = source.fresh();
      // Notify while the constructor is acquiring, with its listener installed
      // but no broadcast event currently being delivered. Adding recursively
      // from inside a sync broadcast delivery is forbidden by Dart itself.
      source.onAcquire = () => source.events.add(null);
      final n = AiConversationScenarioBindingNotifier(source);
      final binding = n.state;
      expect(binding, isNotNull);
      expect(source.acquisitions, 1); // Nested hint must not reacquire.
      source.onAcquire = null;
      source.events.add(null);
      expect(
        source.acquisitions,
        2,
      ); // A later ordinary hint still checks ready.
      expect(n.state, same(binding));
      expect(source.port.calls, 0);
      n.dispose();
      await source.events.close();
    },
  );

  test(
    'same-user identity replacement clears binding and A B A never revives old reader',
    () async {
      final source = _Source();
      source.reader = source.fresh();
      final old = source.auth.currentSession!;
      final notifier = AiConversationScenarioBindingNotifier(source);
      expect(notifier.state, isNotNull);
      source.auth.currentSession = ReviewSession(userId: old.userId);
      source.events.add(null);
      expect(notifier.state, isNull);
      expect(source.reader!.isCurrent, isFalse);
      source.auth.currentSession = old;
      source.events.add(null);
      expect(notifier.state, isNull);
      expect(source.port.calls, 0);
      notifier.dispose();
      await source.events.close();
    },
  );
}
