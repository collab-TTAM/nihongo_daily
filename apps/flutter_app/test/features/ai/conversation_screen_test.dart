// TEST ONLY paired binding/Auth/ports and original frozen responses. Actual App
// and router, but NOT an owned SDK host or hosted learner/provider/voice proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/app.dart';
import 'package:nihongo_daily/app/router.dart';
import 'package:nihongo_daily/features/ai/application/conversation_workspace_binding.dart';
import 'package:nihongo_daily/features/ai/application/conversation_workspace_provider.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'ai_conversation_controller_test.dart' as conversation;
import 'conversation_workspace_controller_test.dart' as workspace;
import 'conversation_workspace_panel_test.dart' as panel;

final _selected = StateProvider<ConversationWorkspaceBinding?>((ref) => null);

Future<ProviderContainer> _mount(
  WidgetTester t, {
  ConversationWorkspaceBinding? binding,
  bool override = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (override)
        conversationWorkspaceBindingProvider.overrideWith(
          (ref) => ref.watch(_selected),
        ),
    ],
  );
  container.read(_selected.notifier).state = binding;
  container.read(routerProvider).go('/conversation');
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NihongoDailyApp(),
    ),
  );
  await t.pumpAndSettle();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    container.dispose();
  });
  return container;
}

Future<void> _go(WidgetTester t, ProviderContainer c, String route) async {
  c.read(routerProvider).go(route);
  await t.pumpAndSettle();
}

Map<String, Object?> _detailed(String operation) {
  final json = conversation.response(operation)! as Map<String, Object?>;
  if (operation == 'finish_conversation') {
    json['scores'] = {'grammar': 0, 'vocabulary': 100, 'fluency': 12.5};
    json['errors'] = [
      {
        'original_text': '元の文',
        'corrected_text': '修正文',
        'explanation_vi': '<script>gợi ý</script>',
        'item_refs': <Object>[],
      },
    ];
    json['strengths_vi'] = ['TEST_ONLY_STRENGTH'];
    json['focus_next_vi'] = ['TEST_ONLY_FOCUS'];
  }
  return json;
}

void main() {
  setUpAll(() {
    conversation.fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });

  testWidgets(
    'actual conversation route default remains unavailable without input',
    (t) async {
      final c = await _mount(t, override: false);
      expect(c.read(conversationWorkspaceBindingProvider), isNull);
      expect(find.text('Đang xây dựng'), findsOneWidget);
      expect(find.text('Luyện hội thoại theo tình huống.'), findsOneWidget);
      expect(panel.key('load'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await _go(t, c, '/ai');
      expect(
        find.text('Giải thích và sửa câu ở trình độ N5–N4.'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'actual route explicit commands render shared summary and finished remount never resets',
    (t) async {
      final h = workspace.Harness();
      h.port.reply = _detailed;
      final c = await _mount(t, binding: panel.binding(h));
      expect(h.readPort.calls, 0);
      expect(h.port.calls, isEmpty);
      expect(h.generated, 0);
      await panel.begin(t);
      await t.ensureVisible(panel.key('editor'));
      await t.enterText(panel.key('editor'), '  日\u3099😀  ');
      expect(h.port.calls, hasLength(1));
      await panel.tap(t, 'send');
      expect(h.port.calls.last.body, {
        'session_id': conversation.sessionId,
        'client_event_id': conversation.turnId,
        'text_ja': '  日\u3099😀  ',
      });
      await panel.tap(t, 'finish');
      expect(find.byKey(const Key('conversation-summary')), findsOneWidget);
      for (final text in [
        'Ngữ pháp: 0/100',
        'Từ vựng: 100/100',
        'Lưu loát: 12.5/100',
        '元の文',
        '修正文',
        '<script>gợi ý</script>',
        'TEST_ONLY_STRENGTH',
        'TEST_ONLY_FOCUS',
        'Chưa lưu vào tiến độ hoặc SRS.',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(panel.key('finished'), findsOneWidget);
      expect(panel.enabled(t, 'start'), isFalse);
      expect(h.generated, 3);
      expect(h.port.calls, hasLength(3));
      await _go(t, c, '/ai');
      expect(h.flow.isCurrent, isTrue);
      expect(h.reader.isCurrent, isTrue);
      await _go(t, c, '/conversation');
      expect(find.byKey(const Key('conversation-summary')), findsOneWidget);
      expect(panel.key('finished'), findsOneWidget);
      expect(panel.enabled(t, 'start'), isFalse);
      expect(panel.enabled(t, 'load'), isFalse);
      expect(panel.enabled(t, 'retry'), isFalse);
      expect(panel.key('editor'), findsNothing);
      await panel.tap(t, 'recheck');
      expect(h.readPort.calls, 1);
      expect(h.port.calls, hasLength(3));
      expect(h.generated, 3);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'route active remount drops draft and stale send but retains accepted flow',
    (t) async {
      final h = workspace.Harness();
      final c = await _mount(t, binding: panel.binding(h));
      await panel.begin(t);
      await t.ensureVisible(panel.key('editor'));
      await t.enterText(panel.key('editor'), 'TEST_ONLY_OLD_DRAFT');
      final old = t.widget<FilledButton>(panel.key('send')).onPressed!;
      await _go(t, c, '/ai');
      old();
      await _go(t, c, '/conversation');
      expect(
        t.widget<TextField>(panel.key('editor')).controller!.text,
        isEmpty,
      );
      expect(panel.enabled(t, 'send'), isTrue);
      expect(panel.enabled(t, 'start'), isFalse);
      expect(panel.enabled(t, 'load'), isFalse);
      expect(h.flow.snapshot.phase, ConversationSessionPhase.active);
      expect(h.flow.isCurrent, isTrue);
      expect(h.reader.isCurrent, isTrue);
      expect(h.port.calls, hasLength(1));
      expect(h.readPort.calls, 1);
      expect(h.generated, 1);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'route pending remount cannot reconstruct retry or abandon receipt',
    (t) async {
      final h = workspace.Harness();
      h.port.reply = (_) => {
        'code': 'PROVIDER_UNAVAILABLE',
        'message_vi': 'TEST_ONLY_SECRET',
        'retryable': true,
      };
      final c = await _mount(t, binding: panel.binding(h));
      await panel.begin(t);
      expect(panel.key('pending'), findsOneWidget);
      expect(panel.enabled(t, 'retry'), isTrue);
      expect(find.textContaining('TEST_ONLY_SECRET'), findsNothing);
      await _go(t, c, '/ai');
      await _go(t, c, '/conversation');
      expect(panel.key('pending'), findsOneWidget);
      expect(panel.enabled(t, 'retry'), isFalse);
      expect(panel.enabled(t, 'start'), isFalse);
      expect(panel.enabled(t, 'load'), isFalse);
      expect(h.flow.hasUnresolvedMutation, isTrue);
      await panel.tap(t, 'recheck');
      expect(h.port.calls, hasLength(1));
      expect(h.generated, 1);
      expect(h.readPort.calls, 1);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'route same-user loss redacts accepted summary and cannot revive on A B A',
    (t) async {
      final h = workspace.Harness();
      h.port.reply = _detailed;
      final hints = StreamController<void>.broadcast(sync: true);
      final c = await _mount(t, binding: panel.binding(h, hints: hints.stream));
      await panel.begin(t);
      await panel.tap(t, 'finish');
      expect(find.text('TEST_ONLY_STRENGTH'), findsOneWidget);
      final original = h.auth.currentSession;
      h.auth.currentSession = ReviewSession(userId: original!.userId);
      hints.add(null);
      await t.idle();
      await t.pumpAndSettle();
      expect(panel.key('unavailable'), findsOneWidget);
      expect(find.byKey(const Key('conversation-summary')), findsNothing);
      expect(find.text('TEST_ONLY_STRENGTH'), findsNothing);
      h.auth.currentSession = original;
      hints.add(null);
      await t.idle();
      await t.pumpAndSettle();
      expect(panel.key('unavailable'), findsOneWidget);
      await _go(t, c, '/ai');
      await _go(t, c, '/conversation');
      expect(panel.key('unavailable'), findsOneWidget);
      expect(find.text('TEST_ONLY_STRENGTH'), findsNothing);
      expect(h.port.calls, hasLength(2));
      expect(h.generated, 2);
      await t.pumpWidget(const SizedBox());
      await hints.close();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'route replacement fences held finish summary and retired callbacks',
    (t) async {
      final a = workspace.Harness();
      final b = workspace.Harness();
      final c = await _mount(t, binding: panel.binding(a));
      await panel.begin(t);
      final held = Completer<Object?>();
      a.port.reply = (_) => held.future;
      await t.ensureVisible(panel.key('editor'));
      await t.enterText(panel.key('editor'), 'TEST_ONLY_RETIRED');
      final oldSend = t.widget<FilledButton>(panel.key('send')).onPressed!;
      await panel.tap(t, 'finish');
      expect(a.port.calls, hasLength(2));
      c.read(_selected.notifier).state = panel.binding(b);
      await t.pumpAndSettle();
      oldSend();
      held.complete(_detailed('finish_conversation'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('conversation-summary')), findsNothing);
      expect(find.text('TEST_ONLY_STRENGTH'), findsNothing);
      expect(find.textContaining('TEST_ONLY_RETIRED'), findsNothing);
      expect(b.port.calls, isEmpty);
      expect(b.readPort.calls, 0);
      expect(b.generated, 0);
      expect(a.port.calls, hasLength(2));
      expect(a.flow.isCurrent, isTrue);
      expect(a.reader.isCurrent, isTrue);
      c.read(_selected.notifier).state = null;
      await t.pumpAndSettle();
      expect(find.text('Đang xây dựng'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      oldSend();
      expect(b.port.calls, isEmpty);
      expect(b.flow.isCurrent, isTrue);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('actual route empty summary fits 320px at 200 percent text', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final h = workspace.Harness();
    h.port.reply = (operation) {
      final json = conversation.response(operation)! as Map<String, Object?>;
      if (operation == 'finish_conversation') {
        json['errors'] = <Object>[];
        json['strengths_vi'] = <Object>[];
        json['focus_next_vi'] = <Object>[];
        json['srs_recommendations'] = <Object>[];
      }
      return json;
    };
    await _mount(t, binding: panel.binding(h));
    await panel.begin(t);
    await panel.tap(t, 'finish');
    for (final text in [
      'Không có gợi ý sửa câu trong phản hồi này.',
      'Chưa có nhận xét điểm mạnh.',
      'Chưa có gợi ý luyện tiếp.',
      'Gợi ý SRS: 0. Chưa lưu.',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    final end = find.text('Gợi ý SRS: 0. Chưa lưu.');
    await t.ensureVisible(end);
    await t.pump();
    expect(end.hitTestable(), findsOneWidget);
    expect(h.port.calls, hasLength(2));
    expect(t.takeException(), isNull);
  });
}
