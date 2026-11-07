// TEST ONLY real captured reader/flow, injected Auth/ports; no hosted proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/conversation_workspace_controller.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_scenarios.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'ai_conversation_controller_test.dart' as conversation;
import 'conversation_scenario_controller_test.dart' as scenarios;

final class Harness {
  final auth = conversation.Auth();
  final port = conversation.Port();
  final readPort = scenarios.Port();
  bool readerReady = true, flowReady = true;
  int generated = 0;
  Duration timeout = const Duration(seconds: 1);
  late final reader = CapturedConversationScenarios(
    auth: auth,
    port: readPort,
    isReady: () => readerReady,
    timeout: timeout,
  );
  late final flow = CapturedConversationSession(
    auth: auth,
    transport: port,
    isReady: () => flowReady,
    timeout: timeout,
  );
  String event() => [
    conversation.startId,
    conversation.turnId,
    conversation.finishId,
    conversation.freshId,
  ][generated++];
  ConversationWorkspaceController controller({
    Stream<void>? hints,
    String Function()? factory,
  }) => ConversationWorkspaceController(
    reader: reader,
    session: flow,
    availabilityChanges: hints,
    createEventId: factory ?? event,
  );
}

Future<void> choose(ConversationWorkspaceController c) async {
  await c.loadScenarios();
  expect(c.select(c.state.scenarios!.rows.single), isTrue);
}

Future<void> start(ConversationWorkspaceController c) async {
  await choose(c);
  await c.startSelected();
}

void main() {
  setUpAll(() {
    conversation.fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  test(
    'missing pair and missing event factory never invent availability or writes',
    () async {
      final absent = ConversationWorkspaceController();
      expect(absent.state.isAvailable, isFalse);
      await absent.loadScenarios();
      await absent.startSelected();
      absent.dispose();
      final h = Harness();
      final readOnly = ConversationWorkspaceController(
        reader: h.reader,
        session: h.flow,
      );
      await choose(readOnly);
      expect(readOnly.state.canStart, isFalse);
      await readOnly.startSelected();
      await readOnly.turn('日');
      await readOnly.finish();
      expect(h.generated, 0);
      expect(h.port.calls, isEmpty);
      readOnly.dispose();
      final one = ConversationWorkspaceController(reader: h.reader);
      expect(one.state.isAvailable, isFalse);
      await one.loadScenarios();
      expect(h.readPort.calls, 1);
      one.dispose();
      expect(h.reader.isCurrent, isTrue);
      expect(h.flow.isCurrent, isTrue);
    },
  );
  test(
    'only explicit current selection starts exact level and captured session progression',
    () async {
      final h = Harness();
      final c = h.controller();
      addTearDown(c.dispose);
      c.recheck();
      await c.startSelected();
      await c.retryPending();
      expect(h.readPort.calls, 0);
      expect(h.generated, 0);
      expect(c.chooseLevel(AiTextLevel.n4), isTrue);
      await choose(c);
      final row = c.state.scenarios!.selected!;
      expect(c.state.canStart, isTrue);
      await c.startSelected();
      expect(h.port.calls.single.body, {
        'scenario_id': row.id,
        'jlpt_level': 'N4',
        'client_event_id': conversation.startId,
      });
      expect(c.state.canChoose, isFalse);
      expect(c.state.canLoad, isFalse);
      expect(c.chooseLevel(AiTextLevel.n5), isFalse);
      await c.loadScenarios();
      await c.startSelected();
      expect(h.readPort.calls, 1);
      expect(h.generated, 1);
      const text = '  日\u3099😀  ';
      await c.turn(text);
      expect(h.port.calls.last.body, {
        'session_id': conversation.sessionId,
        'client_event_id': conversation.turnId,
        'text_ja': text,
      });
      expect(c.state.conversation!.conversation!.messages, hasLength(2));
      await c.finish();
      expect(h.port.calls.last.body, {
        'session_id': conversation.sessionId,
        'client_event_id': conversation.finishId,
      });
      expect(
        c.state.conversation!.conversation!.phase,
        ConversationSessionPhase.finished,
      );
      expect(c.state.conversation!.conversation!.summary, isNotNull);
      expect(
        c.state.canStart ||
            c.state.canTurn ||
            c.state.canFinish ||
            c.state.canChoose,
        isFalse,
      );
      await c.startSelected();
      await c.turn('new');
      await c.finish();
      await c.loadScenarios();
      expect(h.generated, 3);
      expect(h.port.calls, hasLength(3));
      expect(h.readPort.calls, 1);
      c.dispose();
      final remount = h.controller();
      addTearDown(remount.dispose);
      expect(
        remount.state.conversation!.conversation!.phase,
        ConversationSessionPhase.finished,
      );
      await remount.startSelected();
      await remount.loadScenarios();
      expect(h.port.calls, hasLength(3));
      expect(h.generated, 3);
      expect(h.readPort.calls, 1);
    },
  );
  test(
    'foreign and previous equal-ID rows cannot start after reload or level change',
    () async {
      final h = Harness();
      final c = h.controller();
      addTearDown(c.dispose);
      await choose(c);
      final old = c.state.scenarios!.selected!;
      final foreign = await h.reader.load(AiTextLevel.n5);
      expect(c.select(foreign.single), isFalse);
      await c.loadScenarios();
      expect(c.state.scenarios!.selected, isNull);
      expect(c.select(old), isFalse);
      await c.startSelected();
      expect(h.generated, 0);
      expect(c.select(c.state.scenarios!.rows.single), isTrue);
      expect(c.chooseLevel(AiTextLevel.n4), isTrue);
      expect(c.state.scenarios!.rows, isEmpty);
      await c.startSelected();
      expect(h.port.calls, isEmpty);
      expect(h.generated, 0);
    },
  );
  for (final op in ['start', 'turn', 'finish']) {
    for (final lateError in [false, true]) {
      test(
        'uncertain $op lateError=$lateError retains exact event and blocks all replacement actions',
        () async {
          final h = Harness()..timeout = const Duration(milliseconds: 20);
          final c = h.controller();
          addTearDown(c.dispose);
          await choose(c);
          if (op != 'start') await c.startSelected();
          final held = Completer<Object?>();
          h.port.reply = (_) => held.future;
          final first = switch (op) {
            'start' => c.startSelected(),
            'turn' => c.turn('  exact 日\u3099😀  '),
            _ => c.finish(),
          };
          await first;
          final before = Map<String, Object>.from(h.port.calls.last.body);
          final count = h.port.calls.length;
          final ids = h.generated;
          expect(c.state.conversation!.hasUnresolvedMutation, isTrue);
          expect(c.state.canRetry, isFalse);
          await c.startSelected();
          await c.turn('edited');
          await c.finish();
          await c.retryPending();
          await c.loadScenarios();
          expect(c.chooseLevel(AiTextLevel.n4), isFalse);
          expect(h.generated, ids);
          expect(h.port.calls, hasLength(count));
          if (lateError) {
            held.completeError(StateError('PRIVATE token/detail'));
          } else {
            held.complete(conversation.response(h.port.calls.last.operation));
          }
          await conversation.settle();
          c.recheck();
          expect(c.state.canRetry, isTrue);
          expect(c.state.conversation!.hasUnresolvedMutation, isTrue);
          expect(h.port.calls, hasLength(count));
          h.port.reply = conversation.response;
          await c.retryPending();
          expect(h.generated, ids);
          expect(h.port.calls, hasLength(count + 1));
          expect(h.port.calls.last.body, before);
          expect(c.state.conversation!.hasUnresolvedMutation, isFalse);
          expect(c.state.canRetry, isFalse);
          expect(h.readPort.calls, 1);
        },
      );
    }
  }
  test(
    'disposed uncertain workspace cannot recover its event by remount or reset',
    () async {
      final h = Harness()..timeout = const Duration(milliseconds: 20);
      final c = h.controller();
      await choose(c);
      final held = Completer<Object?>();
      h.port.reply = (_) => held.future;
      await c.startSelected();
      c.dispose();
      final remount = h.controller();
      addTearDown(remount.dispose);
      held.complete(conversation.response('start_conversation'));
      await conversation.settle();
      remount.recheck();
      expect(c.state.isAvailable, isFalse);
      expect(remount.state.conversation!.hasUnresolvedMutation, isTrue);
      expect(remount.state.canRetry, isFalse);
      expect(remount.state.canStart, isFalse);
      await remount.retryPending();
      await remount.loadScenarios();
      await remount.startSelected();
      expect(h.generated, 1);
      expect(h.port.calls, hasLength(1));
      expect(h.readPort.calls, 1);
      expect(h.flow.isCurrent, isTrue);
    },
  );
  test(
    'invalid text and event factory failures are safe local failures with no dispatch',
    () async {
      final h = Harness();
      final c = h.controller();
      addTearDown(c.dispose);
      await start(c);
      for (final text in ['', List.filled(5001, '😀').join()]) {
        await c.turn(text);
        expect(c.state.failure!.code, AiTextErrorCode.validationFailure);
        expect(c.state.canTurn, isTrue);
      }
      expect(h.generated, 1);
      expect(h.port.calls, hasLength(1));
      for (final malformed in [false, true]) {
        final fresh = Harness();
        final v = fresh.controller(
          factory: () {
            if (malformed) return 'PRIVATE invalid ID';
            throw StateError('PRIVATE provider token');
          },
        );
        await choose(v);
        await v.startSelected();
        final failure = v.state.failure ?? v.state.conversation!.failure;
        expect(
          failure!.code,
          malformed
              ? AiTextErrorCode.validationFailure
              : AiTextErrorCode.internalError,
        );
        expect(failure.messageVi, isNot(contains('PRIVATE')));
        expect(fresh.port.calls, isEmpty);
        expect(v.state.canStart, isTrue);
        v.dispose();
      }
    },
  );
  for (final loss in ['reader', 'flow', 'same-user']) {
    test(
      '$loss loss redacts both views and rejects late result even after identity return',
      () async {
        final h = Harness();
        final c = h.controller();
        addTearDown(c.dispose);
        await choose(c);
        final original = h.auth.currentSession;
        final held = Completer<Object?>();
        h.port.reply = (_) => held.future;
        final work = c.startSelected();
        await conversation.settle();
        if (loss == 'reader') h.readerReady = false;
        if (loss == 'flow') h.flowReady = false;
        if (loss == 'same-user') {
          h.auth.currentSession = ReviewSession(userId: original!.userId);
        }
        expect(c.state.isAvailable, isFalse);
        expect(c.state.scenarios, isNull);
        expect(c.state.conversation, isNull);
        h.readerReady = true;
        h.flowReady = true;
        h.auth.currentSession = original;
        held.complete(conversation.response('start_conversation'));
        await work;
        expect(c.state.isAvailable, isFalse);
        await c.turn('new');
        await c.startSelected();
        expect(h.port.calls, hasLength(1));
        expect(h.generated, 1);
      },
    );
  }
  for (final close in [false, true]) {
    test(
      'hint error or closure redacts pair without closing borrowed capabilities close=$close',
      () async {
        final h = Harness();
        final hints = StreamController<void>.broadcast(sync: true);
        final c = h.controller(hints: hints.stream);
        await choose(c);
        if (close) {
          await hints.close();
        } else {
          hints.addError(StateError('PRIVATE'));
        }
        await conversation.settle();
        expect(c.state.isAvailable, isFalse);
        expect(h.reader.isCurrent, isTrue);
        expect(h.flow.isCurrent, isTrue);
        c.dispose();
        if (!close) await hints.close();
        expect(h.generated, 0);
        expect(h.port.calls, isEmpty);
      },
    );
  }
  test(
    'event factory synchronous reentry cannot dispatch twice or replace selected scenario',
    () async {
      final h = Harness();
      late ConversationWorkspaceController c;
      final nested = <Future<void>>[];
      c = h.controller(
        factory: () {
          expect(c.state.canStart, isFalse);
          expect(c.chooseLevel(AiTextLevel.n4), isFalse);
          nested.add(c.startSelected());
          nested.add(c.finish());
          nested.add(c.loadScenarios());
          return h.event();
        },
      );
      addTearDown(c.dispose);
      await start(c);
      await Future.wait(nested);
      expect(h.generated, 1);
      expect(h.readPort.calls, 1);
      expect(h.port.calls, hasLength(1));
      expect(h.port.calls.single.body['jlpt_level'], 'N5');
    },
  );
  test(
    'event factory losing owner or disposing view cannot dispatch after generating ID',
    () async {
      for (final dispose in [false, true]) {
        final h = Harness();
        late ConversationWorkspaceController c;
        c = h.controller(
          factory: () {
            if (dispose) {
              c.dispose();
            } else {
              h.auth.currentSession = null;
            }
            return h.event();
          },
        );
        await start(c);
        expect(h.generated, 1);
        expect(h.port.calls, isEmpty);
        expect(c.state.isAvailable, isFalse);
        c.dispose();
      }
    },
  );
  test(
    'nested workspace reads from either borrowed readiness getter redact without retiring healthy pair',
    () async {
      for (final inReader in [false, true]) {
        final h = Harness();
        ConversationWorkspaceController? view;
        var armed = false;
        var entered = 0;
        bool ready() {
          if (armed) {
            entered++;
            expect(view!.state.isAvailable, isFalse);
            expect(view.chooseLevel(AiTextLevel.n4), isFalse);
          }
          return true;
        }

        final reader = CapturedConversationScenarios(
          auth: h.auth,
          port: h.readPort,
          isReady: inReader ? ready : () => true,
        );
        final flow = CapturedConversationSession(
          auth: h.auth,
          transport: h.port,
          isReady: inReader ? () => true : ready,
        );
        view = ConversationWorkspaceController(
          reader: reader,
          session: flow,
          createEventId: h.event,
        );
        armed = true;
        // External raw capability check also invokes the getter, outside view._read.
        expect(inReader ? reader.isCurrent : flow.isCurrent, isTrue);
        expect(view.state.isAvailable, isTrue);
        expect(entered, greaterThan(0));
        expect(h.port.calls, isEmpty);
        expect(h.readPort.calls, 0);
        armed = false;
        view.dispose();
        expect(reader.isCurrent, isTrue);
        expect(flow.isCurrent, isTrue);
      }
    },
  );
  test(
    'held scenario load excludes mutations and late read after disposal never publishes',
    () async {
      final h = Harness();
      final c = h.controller();
      final held = Completer<Object?>();
      h.readPort.reply = (_) => held.future;
      final work = c.loadScenarios();
      expect(c.state.canLoad || c.state.canStart || c.state.canTurn, isFalse);
      await c.startSelected();
      await c.loadScenarios();
      expect(h.generated, 0);
      c.dispose();
      held.complete(scenarios.rows(AiTextLevel.n5));
      await work;
      expect(c.state.isAvailable, isFalse);
      expect(h.readPort.calls, 1);
      expect(h.reader.isCurrent, isTrue);
      expect(h.flow.isCurrent, isTrue);
    },
  );
  test(
    'readiness loss in later capability checks cannot expose an earlier projection',
    () {
      for (var failAt = 1; failAt <= 30; failAt++) {
        final h = Harness();
        var armed = false;
        var checks = 0;
        var lost = false;
        final flow = CapturedConversationSession(
          auth: h.auth,
          transport: h.port,
          isReady: () {
            if (armed && ++checks == failAt) lost = true;
            return !lost;
          },
        );
        final c = ConversationWorkspaceController(
          reader: h.reader,
          session: flow,
          createEventId: h.event,
        );
        armed = true;
        final state = c.state;
        if (lost) {
          expect(
            state.isAvailable,
            isFalse,
            reason: 'loss at readiness check $failAt',
          );
          expect(state.scenarios, isNull);
          expect(state.conversation, isNull);
        }
        c.dispose();
        expect(h.port.calls, isEmpty);
        expect(h.readPort.calls, 0);
      }
    },
  );
  test(
    'active remount borrows accepted session without reloading or restarting a scenario',
    () async {
      final h = Harness();
      final first = h.controller();
      expect(first.chooseLevel(AiTextLevel.n4), isTrue);
      await start(first);
      first.dispose();
      final second = h.controller();
      addTearDown(second.dispose);
      expect(second.state.scenarios!.selected, isNull);
      expect(
        second.state.conversation!.conversation!.sessionId,
        conversation.sessionId,
      );
      expect(second.state.canTurn, isTrue);
      expect(second.state.canChoose, isFalse);
      await second.loadScenarios();
      await second.startSelected();
      await second.turn('  続き  ');
      expect(h.readPort.calls, 1);
      expect(h.generated, 2);
      expect(h.port.calls, hasLength(2));
      expect(h.port.calls.last.body, {
        'session_id': conversation.sessionId,
        'client_event_id': conversation.turnId,
        'text_ja': '  続き  ',
      });
      expect(h.flow.isCurrent, isTrue);
      expect(h.reader.isCurrent, isTrue);
    },
  );
}
