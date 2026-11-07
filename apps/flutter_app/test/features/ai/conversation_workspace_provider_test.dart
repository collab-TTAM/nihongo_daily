// TEST ONLY combined trusted source and injected ports; no hosted identity proof.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/conversation_workspace_provider.dart';
import 'package:nihongo_daily/features/ai/application/conversation_workspace_binding.dart';
import 'package:nihongo_daily/features/ai/application/ai_conversation_view_binding.dart';
import 'package:nihongo_daily/features/ai/application/ai_conversation_scenario_binding.dart';
import 'package:nihongo_daily/features/ai/data/ai_conversation_source.dart';
import 'package:nihongo_daily/features/ai/data/ai_conversation_scenario_source.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_scenarios.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'conversation_workspace_controller_test.dart' as fixture;

// Match the production owner's cached broadcast stream identity. Raw
// StreamController.stream accesses return equal but nonidentical wrappers.
final class _Hints {
  final _controller = StreamController<void>.broadcast(sync: true);
  late final Stream<void> stream = _controller.stream;
  Stream<void> get uncached => _controller.stream;
  void add(Object? _) => _controller.add(null);
  void addError(Object error) => _controller.addError(error);
  Future<void> close() => _controller.close();
}

final class Source
    implements AiConversationSource, AiConversationScenarioSource {
  final h = fixture.Harness();
  final hints = _Hints();
  final otherHints = _Hints();
  bool split = false, broken = false, available = true, unstable = false;
  int acquisitions = 0;
  @override
  Stream<void> get aiConversationChanges =>
      unstable ? hints.uncached : hints.stream;
  @override
  Stream<void> get aiConversationScenarioChanges =>
      split ? otherHints.stream : (unstable ? hints.uncached : hints.stream);
  @override
  CapturedConversationSession? createAiConversationSession() {
    acquisitions++;
    if (broken) throw StateError('PRIVATE');
    return available ? h.flow : null;
  }

  @override
  CapturedConversationScenarios? createAiConversationScenarios() {
    acquisitions++;
    return available ? h.reader : null;
  }

  Future<void> close() async {
    await hints.close();
    await otherHints.close();
  }
}

ProviderContainer container(Source a, {Source? b, String Function()? events}) =>
    ProviderContainer(
      overrides: [
        aiConversationSourceProvider.overrideWithValue(a),
        aiConversationScenarioSourceProvider.overrideWithValue(b ?? a),
        if (events != null)
          conversationEventFactoryProvider.overrideWithValue(events),
      ],
    );
void main() {
  test('default sources yield no workspace or event generation', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(conversationWorkspaceBindingProvider), isNull);
  });
  test(
    'different source objects rejected before acquisition even for same user',
    () async {
      final a = Source(), b = Source();
      final c = container(a, b: b);
      expect(c.read(conversationWorkspaceBindingProvider), isNull);
      expect(a.acquisitions + b.acquisitions, 0);
      c.dispose();
      await a.close();
      await b.close();
    },
  );
  test(
    'same owner ready pair preserves binding identity and never generates or dispatches',
    () async {
      final s = Source();
      var generated = 0;
      final c = container(
        s,
        events: () {
          generated++;
          return 'TEST ONLY';
        },
      );
      final p = c.read(conversationWorkspaceBindingProvider)!;
      expect(p.reader, same(s.h.reader));
      expect(p.session, same(s.h.flow));
      expect(p.availabilityChanges, same(s.hints.stream));
      s.hints.add(null);
      await c.pump();
      expect(c.read(conversationWorkspaceBindingProvider), same(p));
      expect(generated, 0);
      expect(s.h.port.calls, isEmpty);
      expect(s.h.readPort.calls, 0);
      expect(p.createEventId!(), 'TEST ONLY');
      expect(generated, 1);
      c.dispose();
      expect(s.h.reader.isCurrent, isTrue);
      expect(s.h.flow.isCurrent, isTrue);
      await s.close();
    },
  );
  test('different owner hint streams fail closed', () async {
    final s = Source()..split = true;
    final c = container(s);
    expect(c.read(conversationWorkspaceBindingProvider), isNull);
    expect(s.h.port.calls, isEmpty);
    c.dispose();
    await s.close();
  });
  test(
    'unready source becomes available only after explicit owner readiness hint',
    () async {
      final s = Source()..available = false;
      final c = container(s);
      final sub = c.listen<ConversationWorkspaceBinding?>(
        conversationWorkspaceBindingProvider,
        (_, _) {},
      );
      expect(c.read(conversationWorkspaceBindingProvider), isNull);
      s.available = true;
      s.hints.add(null);
      await c.pump();
      expect(c.read(conversationWorkspaceBindingProvider), isNotNull);
      expect(s.h.port.calls, isEmpty);
      expect(s.h.readPort.calls, 0);
      sub.close();
      c.dispose();
      await s.close();
    },
  );
  test(
    'same user replacement permanently fences old pair and identity return does not revive',
    () async {
      final s = Source();
      final c = container(s);
      final sub = c.listen<ConversationWorkspaceBinding?>(
        conversationWorkspaceBindingProvider,
        (_, _) {},
      );
      final old = c.read(conversationWorkspaceBindingProvider)!;
      final original = s.h.auth.currentSession;
      s.h.auth.currentSession = ReviewSession(userId: original!.userId);
      s.hints.add(null);
      await c.pump();
      expect(c.read(conversationWorkspaceBindingProvider), isNull);
      expect(old.reader.isCurrent, isFalse);
      expect(old.session.isCurrent, isFalse);
      s.h.auth.currentSession = original;
      s.hints.add(null);
      await c.pump();
      expect(c.read(conversationWorkspaceBindingProvider), isNull);
      expect(s.h.port.calls, isEmpty);
      sub.close();
      c.dispose();
      await s.close();
    },
  );
  for (final close in [false, true]) {
    test(
      'stream termination removes pair without revoking borrowed resources close=$close',
      () async {
        final s = Source();
        final c = container(s);
        final sub = c.listen<ConversationWorkspaceBinding?>(
          conversationWorkspaceBindingProvider,
          (_, _) {},
        );
        expect(c.read(conversationWorkspaceBindingProvider), isNotNull);
        if (close) {
          await s.hints.close();
        } else {
          s.hints.addError(StateError('PRIVATE'));
        }
        await c.pump();
        expect(c.read(conversationWorkspaceBindingProvider), isNull);
        expect(s.h.reader.isCurrent, isTrue);
        expect(s.h.flow.isCurrent, isTrue);
        sub.close();
        c.dispose();
        if (!close) await s.hints.close();
        await s.otherHints.close();
      },
    );
  }
  test(
    'factory exception and missing capability never expose partial pair',
    () async {
      final s = Source()..broken = true;
      final c = container(s);
      expect(c.read(conversationWorkspaceBindingProvider), isNull);
      c.dispose();
      expect(s.h.reader.isCurrent, isTrue);
      await s.close();
    },
  );
  test(
    'secure factory emits canonical UUIDv4 with no duplicates in smoke sample',
    () {
      final ids = <String>{};
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      for (var i = 0; i < 256; i++) {
        final id = createConversationEventId();
        expect(pattern.hasMatch(id), isTrue);
        expect(ids.add(id), isTrue);
      }
      // Shape/collision smoke is not a statistical proof of entropy or hosted auth.
    },
  );
  test(
    'uncached equal stream wrappers remain rejected while owner guard is retained',
    () async {
      final s = Source()..unstable = true;
      expect(
        s.aiConversationChanges == s.aiConversationScenarioChanges,
        isTrue,
      );
      expect(
        identical(s.aiConversationChanges, s.aiConversationScenarioChanges),
        isFalse,
      );
      final c = container(s);
      expect(c.read(conversationWorkspaceBindingProvider), isNull);
      expect(s.h.port.calls, isEmpty);
      expect(s.h.readPort.calls, 0);
      c.dispose();
      await s.close();
    },
  );
}
