// TEST ONLY source lifetime; no Auth/HTTP or hosted proof.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/ai/data/ai_conversation_scenario_source.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_scenarios.dart';

class Runtime implements AccountStartupRuntime<int> {
  Completer<void>? hold;
  int closes = 0;
  @override
  int get account => 1;
  @override
  bool get canOfferLogin => false;
  @override
  Future<void> start() async {
    await hold?.future;
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

final class Source extends Runtime implements AiConversationScenarioSource {
  int calls = 0;
  final events = StreamController<void>.broadcast();
  @override
  CapturedConversationScenarios? createAiConversationScenarios() {
    calls++;
    return null;
  }

  @override
  Stream<void> get aiConversationScenarioChanges => events.stream;
  @override
  Future<void> close() async {
    await super.close();
    await events.close();
  }
}

void main() {
  test(
    'optional scenario source hidden before during and after active startup',
    () async {
      final r = Source()..hold = Completer<void>();
      final c = AccountStartupController(() async => r);
      expect(c.aiConversationScenarioSource, isNull);
      final starting = c.start();
      expect(c.aiConversationScenarioSource, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(c.aiConversationScenarioSource, isNull);
      r.hold!.complete();
      await starting;
      expect(identical(c.aiConversationScenarioSource, r), isTrue);
      expect(r.calls, 0);
      expect(
        c.aiConversationScenarioSource!.createAiConversationScenarios(),
        isNull,
      );
      expect(r.calls, 1);
      final closing = c.close();
      expect(c.aiConversationScenarioSource, isNull);
      await closing;
      expect(r.closes, 1);
    },
  );
  test('legacy startup does not invent optional scenario source', () async {
    final r = Runtime();
    final c = AccountStartupController(() async => r);
    await c.start();
    expect(c.aiConversationScenarioSource, isNull);
    expect(c.account, 1);
    await c.close();
    expect(r.closes, 1);
  });
}
