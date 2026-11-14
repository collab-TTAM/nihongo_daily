// TEST ONLY captured capabilities/ports; not a hosted learner or mounted App proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/conversation_workspace_binding.dart';
import 'package:nihongo_daily/features/ai/presentation/conversation_workspace_panel.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'conversation_workspace_controller_test.dart' as workspace;
import 'ai_conversation_controller_test.dart' as conversation;

ConversationWorkspaceBinding binding(
  workspace.Harness h, {
  Stream<void>? hints,
  bool writes = true,
}) => ConversationWorkspaceBinding(
  reader: h.reader,
  session: h.flow,
  availabilityChanges: hints,
  createEventId: writes ? h.event : null,
);
Future<void> mount(
  WidgetTester t,
  ConversationWorkspaceBinding? b, {
  double scale = 1,
}) => t.pumpWidget(
  MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: ConversationWorkspacePanel(binding: b)),
    ),
  ),
);
Finder key(String name) => find.byKey(Key('workspace-$name'));
Future<void> tap(WidgetTester t, String name) async {
  await t.ensureVisible(key(name));
  await t.tap(key(name));
  await t.pumpAndSettle();
}

Future<void> begin(WidgetTester t) async {
  await tap(t, 'load');
  await tap(t, 'scenario-22222222-2222-4222-8222-222222222222');
  await tap(t, 'start');
}

bool enabled(WidgetTester t, String name) =>
    t.widget<ButtonStyleButton>(key(name)).onPressed != null;
void main() {
  setUpAll(() {
    conversation.fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  testWidgets(
    'absent or unconfigured workspace never auto loads generates or sends',
    (t) async {
      await mount(t, null);
      expect(key('unavailable'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      final h = workspace.Harness();
      await mount(t, binding(h, writes: false));
      await t.pump();
      expect(h.readPort.calls, 0);
      expect(h.generated, 0);
      await tap(t, 'load');
      await tap(t, 'scenario-22222222-2222-4222-8222-222222222222');
      expect(enabled(t, 'start'), isFalse);
      expect(h.generated, 0);
      expect(h.port.calls, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'explicit controls send exact draft once then finish without saved or new round claim',
    (t) async {
      final h = workspace.Harness();
      await mount(t, binding(h));
      await t.pump();
      expect(h.port.calls, isEmpty);
      await begin(t);
      expect(h.generated, 1);
      expect(h.readPort.calls, 1);
      expect(enabled(t, 'load'), isFalse);
      await t.enterText(key('editor'), '  日\u3099😀  ');
      expect(h.port.calls, hasLength(1));
      await tap(t, 'send');
      expect(h.port.calls, hasLength(2));
      expect(h.port.calls.last.body['text_ja'], '  日\u3099😀  ');
      expect(t.widget<TextField>(key('editor')).controller!.text, isEmpty);
      await tap(t, 'finish');
      expect(key('finished'), findsOneWidget);
      expect(key('editor'), findsNothing);
      expect(enabled(t, 'start'), isFalse);
      expect(h.generated, 3);
      expect(h.port.calls, hasLength(3));
      expect(find.textContaining('chưa lưu'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'safe retry preserves original request and clears locked draft without edited resend',
    (t) async {
      final h = workspace.Harness();
      await mount(t, binding(h));
      await begin(t);
      h.port.reply = (_) => {
        'code': 'PROVIDER_UNAVAILABLE',
        'message_vi': 'PRIVATE_DETAIL',
        'retryable': true,
      };
      await t.enterText(key('editor'), 'original');
      await tap(t, 'send');
      final original = Map<String, Object>.from(h.port.calls.last.body);
      expect(key('pending'), findsOneWidget);
      expect(enabled(t, 'send'), isFalse);
      expect(enabled(t, 'finish'), isFalse);
      expect(enabled(t, 'retry'), isTrue);
      expect(t.widget<TextField>(key('editor')).controller!.text, isEmpty);
      expect(find.textContaining('PRIVATE_DETAIL'), findsNothing);
      final ids = h.generated;
      h.port.reply = conversation.response;
      await tap(t, 'retry');
      expect(h.generated, ids);
      expect(h.port.calls.last.body, original);
      expect(key('pending'), findsNothing);
      expect(enabled(t, 'send'), isTrue);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'same user identity loss clears editor and assistant output without revival',
    (t) async {
      final h = workspace.Harness();
      final hints = StreamController<void>.broadcast(sync: true);
      final b = binding(h, hints: hints.stream);
      await mount(t, b);
      await begin(t);
      await t.enterText(key('editor'), 'PRIVATE_DRAFT');
      final editor = t.widget<TextField>(key('editor')).controller!;
      final original = h.auth.currentSession;
      h.auth.currentSession = ReviewSession(userId: original!.userId);
      hints.add(null);
      await t.idle();
      await t.pumpAndSettle();
      expect(key('unavailable'), findsOneWidget);
      expect(editor.text, isEmpty);
      expect(find.textContaining('PRIVATE_DRAFT'), findsNothing);
      expect(key('editor'), findsNothing);
      h.auth.currentSession = original;
      hints.add(null);
      await t.idle();
      await t.pumpAndSettle();
      expect(key('unavailable'), findsOneWidget);
      expect(h.port.calls, hasLength(1));
      await t.pumpWidget(const SizedBox());
      await hints.close();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'replacement and unmount fence retained send callback and preserve borrowed flow',
    (t) async {
      final a = workspace.Harness();
      await mount(t, binding(a));
      await begin(t);
      await t.enterText(key('editor'), 'OLD_DRAFT');
      final old = t.widget<FilledButton>(key('send')).onPressed!;
      final b = workspace.Harness();
      await mount(t, binding(b));
      await t.pumpAndSettle();
      old();
      await t.pumpAndSettle();
      expect(a.port.calls, hasLength(1));
      expect(b.port.calls, isEmpty);
      expect(key('editor'), findsNothing);
      expect(find.text('OLD_DRAFT'), findsNothing);
      await t.pumpWidget(const SizedBox());
      old();
      await t.pump();
      expect(a.flow.isCurrent, isTrue);
      expect(a.reader.isCurrent, isTrue);
      expect(b.flow.isCurrent, isTrue);
      expect(a.port.calls, hasLength(1));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'remount with unresolved receipt offers no reset or reconstructed retry',
    (t) async {
      final h = workspace.Harness();
      h.port.reply = (_) => {
        'code': 'PROVIDER_UNAVAILABLE',
        'message_vi': 'PRIVATE',
        'retryable': true,
      };
      final b = binding(h);
      await mount(t, b);
      await tap(t, 'load');
      await tap(t, 'scenario-22222222-2222-4222-8222-222222222222');
      await tap(t, 'start');
      expect(enabled(t, 'retry'), isTrue);
      await t.pumpWidget(const SizedBox());
      await mount(t, b);
      await t.pumpAndSettle();
      expect(key('pending'), findsOneWidget);
      expect(enabled(t, 'retry'), isFalse);
      expect(enabled(t, 'start'), isFalse);
      expect(enabled(t, 'load'), isFalse);
      await tap(t, 'recheck');
      expect(h.port.calls, hasLength(1));
      expect(h.generated, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('320px 200 percent command panel scrolls without overflow', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final h = workspace.Harness();
    await mount(t, binding(h), scale: 2);
    await begin(t);
    await t.ensureVisible(key('finish'));
    await t.pump();
    expect(key('finish').hitTestable(), findsOneWidget);
    expect(h.port.calls, hasLength(1));
    expect(t.takeException(), isNull);
  });
}
