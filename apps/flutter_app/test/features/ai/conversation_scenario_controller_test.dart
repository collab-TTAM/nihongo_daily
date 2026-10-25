// TEST ONLY read/Auth ports, no provider or default activation.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/conversation_scenario_controller.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_scenarios.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(
    userId: '11111111-1111-4111-8111-111111111111',
  );
}

List<Object> rows(AiTextLevel level) => [
  {
    'id': '22222222-2222-4222-8222-222222222222',
    'jlpt_level': level.wireName,
    'title_vi': 'Tình huống',
    'title_ja': '<b>会話</b>',
    'description_vi': 'Mô tả',
    'content_version': 1,
    'is_active': true,
  },
];

final class Port implements ConversationScenarioReadPort {
  int calls = 0;
  AiTextLevel? level;
  Future<Object?> Function(AiTextLevel)? reply;
  @override
  Future<Object?> read({
    required ReviewSession capturedSession,
    required AiTextLevel level,
  }) async {
    calls++;
    this.level = level;
    return reply?.call(level) ?? rows(level);
  }
}

final class Harness {
  final auth = Auth();
  final port = Port();
  late final reader = CapturedConversationScenarios(
    auth: auth,
    port: port,
    isReady: () => ready,
    timeout: timeout,
  );
  bool ready = true;
  Duration timeout = const Duration(seconds: 1);
  ConversationScenarioController controller({Stream<void>? hints}) =>
      ConversationScenarioController(
        reader: reader,
        availabilityChanges: hints,
      );
}

void main() {
  test(
    'missing capability unavailable and construction read recheck never dispatch',
    () {
      final absent = ConversationScenarioController();
      expect(absent.state.phase, ScenarioLoadPhase.unavailable);
      absent.dispose();
      final h = Harness();
      final c = h.controller();
      expect(c.state.phase, ScenarioLoadPhase.idle);
      c.recheck();
      expect(h.port.calls, 0);
      c.dispose();
    },
  );
  test(
    'explicit load selects exact immutable row then level change clears without request',
    () async {
      final h = Harness();
      final c = h.controller();
      await c.load();
      expect(h.port.calls, 1);
      final row = c.state.rows.single;
      expect(c.select(row), isTrue);
      expect(c.state.selected, same(row));
      expect(() => c.state.rows.clear(), throwsUnsupportedError);
      expect(c.chooseLevel(AiTextLevel.n4), isTrue);
      expect(c.state.rows, isEmpty);
      expect(c.state.selected, isNull);
      expect(c.select(row), isFalse);
      expect(h.port.calls, 1);
      await c.load();
      expect(h.port.level, AiTextLevel.n4);
      expect(c.chooseLevel(AiTextLevel.n3), isFalse);
      c.dispose();
    },
  );
  test(
    'reload clears selection and rejects stale equal-ID row without optimistic success',
    () async {
      final h = Harness();
      final c = h.controller();
      await c.load();
      final old = c.state.rows.single;
      c.select(old);
      final held = Completer<Object?>();
      h.port.reply = (_) => held.future;
      final work = c.load();
      expect(c.state.phase, ScenarioLoadPhase.loading);
      expect(c.state.rows, isEmpty);
      expect(c.state.selected, isNull);
      expect(c.chooseLevel(AiTextLevel.n4), isFalse);
      await c.load();
      expect(h.port.calls, 2);
      held.complete(rows(AiTextLevel.n5));
      await work;
      expect(c.select(old), isFalse);
      expect(c.select(c.state.rows.single), isTrue);
      c.dispose();
    },
  );
  test(
    'empty and malformed results stay honest with safe error and explicit reload only',
    () async {
      final h = Harness();
      final c = h.controller();
      h.port.reply = (_) async => <Object>[];
      await c.load();
      expect(c.state.phase, ScenarioLoadPhase.ready);
      expect(c.state.rows, isEmpty);
      h.port.reply = (_) async => {'PRIVATE': 'DETAIL'};
      await c.load();
      expect(c.state.phase, ScenarioLoadPhase.error);
      expect(c.state.failure!.code, AiTextErrorCode.internalError);
      expect(c.state.rows, isEmpty);
      c.recheck();
      expect(h.port.calls, 2);
      c.dispose();
    },
  );
  for (final lateError in [false, true]) {
    test(
      'timed out read cannot reload or select until real drain error=$lateError',
      () async {
        final h = Harness()..timeout = const Duration(milliseconds: 5);
        final held = Completer<Object?>();
        h.port.reply = (_) => held.future;
        final c = h.controller();
        await c.load();
        expect(c.state.phase, ScenarioLoadPhase.error);
        expect(c.state.canLoad, isFalse);
        await c.load();
        expect(h.port.calls, 1);
        if (lateError) {
          held.completeError(StateError('PRIVATE'));
        } else {
          held.complete(rows(AiTextLevel.n5));
        }
        await Future<void>.delayed(Duration.zero);
        c.recheck();
        expect(c.state.canLoad, isTrue);
        expect(c.state.rows, isEmpty);
        h.port.reply = (l) async => rows(l);
        await c.load();
        expect(h.port.calls, 2);
        c.dispose();
      },
    );
  }
  for (final mode in ['same-user', 'ready', 'dispose']) {
    test(
      'late read never republishes after $mode including identity return',
      () async {
        final h = Harness();
        final c = h.controller();
        final original = h.auth.currentSession;
        final held = Completer<Object?>();
        h.port.reply = (_) => held.future;
        final work = c.load();
        if (mode == 'same-user') {
          h.auth.currentSession = ReviewSession(userId: original!.userId);
        } else if (mode == 'ready') {
          h.ready = false;
        } else {
          c.dispose();
        }
        expect(c.state.phase, ScenarioLoadPhase.unavailable);
        h.auth.currentSession = original;
        h.ready = true;
        held.complete(rows(AiTextLevel.n5));
        await work;
        expect(c.state.rows, isEmpty);
        expect(c.state.selected, isNull);
        expect(c.state.canLoad, isFalse);
        expect(h.port.calls, 1);
        c.dispose();
      },
    );
  }
  for (final close in [false, true]) {
    test(
      'stream error or closure clears view without revoking borrowed reader close=$close',
      () async {
        final h = Harness();
        final hints = StreamController<void>.broadcast(sync: true);
        final c = h.controller(hints: hints.stream);
        await c.load();
        c.select(c.state.rows.single);
        if (close) {
          await hints.close();
        } else {
          hints.addError(StateError('PRIVATE'));
        }
        expect(c.state.phase, ScenarioLoadPhase.unavailable);
        expect(c.state.rows, isEmpty);
        expect(h.reader.isCurrent, isTrue);
        c.dispose();
        if (!close) await hints.close();
      },
    );
  }
  test(
    'dispose preserves borrowed reader and queued hints contain no old rows',
    () async {
      final h = Harness();
      final hints = StreamController<void>.broadcast();
      final c = h.controller(hints: hints.stream);
      await c.load();
      hints.add(null);
      c.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.rows, isEmpty);
      expect(h.reader.isCurrent, isTrue);
      expect(await h.reader.load(AiTextLevel.n5), hasLength(1));
      await hints.close();
    },
  );

  test(
    'readiness getter reentry redacts nested view without dispatch or revoking healthy reader',
    () {
      final auth = Auth();
      final port = Port();
      late ConversationScenarioController controller;
      var armed = false;
      var entered = false;
      final reader = CapturedConversationScenarios(
        auth: auth,
        port: port,
        isReady: () {
          if (armed && !entered) {
            entered = true;
            expect(controller.state.phase, ScenarioLoadPhase.unavailable);
          }
          return true;
        },
      );
      controller = ConversationScenarioController(reader: reader);
      armed = true;
      expect(controller.state.phase, ScenarioLoadPhase.idle);
      expect(entered, isTrue);
      expect(reader.isCurrent, isTrue);
      expect(port.calls, 0);
      controller.dispose();
    },
  );
}
