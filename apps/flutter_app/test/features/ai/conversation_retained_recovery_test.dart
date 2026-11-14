// TEST ONLY actual workspace/flow with fixture Auth/ports. No hosted proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'conversation_workspace_controller_test.dart' as w;
import 'ai_conversation_controller_test.dart' as f;

void main() {
  setUpAll(() {
    f.fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  for (final operation in [
    'start_conversation',
    'conversation_turn',
    'finish_conversation',
  ]) {
    test(
      'workspace explicit retained recovery reuses $operation after old view disposal',
      () async {
        final h = w.Harness();
        final old = h.controller();
        await w.choose(old);
        if (operation != 'start_conversation') await old.startSelected();
        h.port.reply = (_) => {
          'code': 'PROVIDER_UNAVAILABLE',
          'message_vi': 'PRIVATE',
          'retryable': true,
        };
        switch (operation) {
          case 'start_conversation':
            await old.startSelected();
          case 'conversation_turn':
            await old.turn('  日\u3099😀  ');
          case 'finish_conversation':
            await old.finish();
        }
        expect(old.state.canRecoverRetained, isFalse);
        final count = h.port.calls.length;
        final original = h.port.calls.last;
        final ids = h.generated;
        old.dispose();
        final fresh = h.controller(
          factory: () => throw StateError('must not generate'),
        );
        addTearDown(fresh.dispose);
        expect(fresh.state.canRetry, isFalse);
        expect(fresh.state.canRecoverRetained, isTrue);
        expect(fresh.state.canStart, isFalse);
        expect(h.port.calls, hasLength(count));
        h.port.reply = f.response;
        await fresh.recoverRetained();
        expect(h.port.calls, hasLength(count + 1));
        expect(h.port.calls.last, original);
        expect(h.generated, ids);
        expect(fresh.state.canRecoverRetained, isFalse);
        expect(fresh.state.conversation!.hasUnresolvedMutation, isFalse);
        await fresh.recoverRetained();
        expect(h.port.calls, hasLength(count + 1));
      },
    );
  }
  for (final loseReader in [false, true]) {
    test(
      'either capability loss fences retained recovery reader=$loseReader',
      () async {
        final h = w.Harness();
        final first = h.controller();
        h.port.reply = (_) => {
          'code': 'NETWORK_UNAVAILABLE',
          'message_vi': 'PRIVATE',
          'retryable': true,
        };
        await w.start(first);
        first.dispose();
        final c = h.controller();
        expect(c.state.canRecoverRetained, isTrue);
        if (loseReader) {
          h.readerReady = false;
        } else {
          h.flowReady = false;
        }
        await c.recoverRetained();
        expect(c.state.isAvailable, isFalse);
        expect(h.port.calls, hasLength(1));
        c.dispose();
      },
    );
  }
  test(
    'disposed and concurrent recovery controls cannot replay twice',
    () async {
      final h = w.Harness();
      final old = h.controller();
      h.port.reply = (_) => {
        'code': 'NETWORK_UNAVAILABLE',
        'message_vi': 'PRIVATE',
        'retryable': true,
      };
      await w.start(old);
      old.dispose();
      final c = h.controller();
      final held = Completer<Object?>();
      h.port.reply = (_) => held.future;
      final work = c.recoverRetained();
      await c.recoverRetained();
      expect(h.port.calls, hasLength(2));
      c.dispose();
      held.complete(f.response('start_conversation'));
      await work;
      await c.recoverRetained();
      expect(c.state.isAvailable, isFalse);
      expect(h.port.calls, hasLength(2));
      expect(h.flow.isCurrent, isTrue);
    },
  );
}
