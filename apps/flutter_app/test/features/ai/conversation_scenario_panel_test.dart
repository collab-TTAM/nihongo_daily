// TEST ONLY read ports. Widget component, not routed/live conversation proof.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_conversation_scenario_binding.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/presentation/conversation_scenario_panel.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'conversation_scenario_controller_test.dart' as fixture;

Future<void> mount(
  WidgetTester t,
  AiConversationScenarioBinding? b, {
  double scale = 1,
}) => t.pumpWidget(
  MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: ConversationScenarioPanel(binding: b)),
    ),
  ),
);
Future<void> load(WidgetTester t) async {
  await t.tap(find.byKey(const Key('scenario-load')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('missing or idle selector never reads until explicit load tap', (
    t,
  ) async {
    await mount(t, null);
    expect(find.byKey(const Key('scenario-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('scenario-load')), findsNothing);
    final h = fixture.Harness();
    await mount(t, AiConversationScenarioBinding(reader: h.reader));
    expect(h.port.calls, 0);
    await load(t);
    expect(h.port.calls, 1);
    expect(find.text('<b>会話</b>'), findsOneWidget);
    expect(find.text('Chọn'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'literal scenario selection and level change clear only local choice',
    (t) async {
      final h = fixture.Harness();
      await mount(t, AiConversationScenarioBinding(reader: h.reader));
      await load(t);
      await t.tap(find.text('Chọn'));
      await t.pump();
      expect(find.byKey(const Key('scenario-selected')), findsOneWidget);
      t
          .widget<DropdownButtonFormField<AiTextLevel>>(
            find.byKey(const Key('scenario-level')),
          )
          .onChanged!(AiTextLevel.n4);
      await t.pump();
      expect(find.byKey(const Key('scenario-selected')), findsNothing);
      expect(find.text('<b>会話</b>'), findsNothing);
      expect(h.port.calls, 1);
      await load(t);
      expect(h.port.level, AiTextLevel.n4);
      expect(h.reader.isCurrent, isTrue);
    },
  );
  testWidgets(
    'empty and safe error show no invented scenarios or private details',
    (t) async {
      final h = fixture.Harness();
      h.port.reply = (_) async => <Object>[];
      await mount(t, AiConversationScenarioBinding(reader: h.reader));
      await load(t);
      expect(find.byKey(const Key('scenario-empty')), findsOneWidget);
      h.port.reply = (_) async => throw StateError('PRIVATE_TOKEN');
      await load(t);
      expect(find.byKey(const Key('scenario-error')), findsOneWidget);
      expect(find.textContaining('PRIVATE_TOKEN'), findsNothing);
      expect(find.text('Chọn'), findsNothing);
      expect(h.port.calls, 2);
    },
  );
  testWidgets(
    'same-user revocation clears visible rows selection and cannot revive',
    (t) async {
      final h = fixture.Harness();
      final hints = StreamController<void>.broadcast(sync: true);
      await mount(
        t,
        AiConversationScenarioBinding(
          reader: h.reader,
          availabilityChanges: hints.stream,
        ),
      );
      await load(t);
      await t.tap(find.text('Chọn'));
      await t.pump();
      final old = h.auth.currentSession;
      h.auth.currentSession = ReviewSession(userId: old!.userId);
      hints.add(null);
      await t.idle();
      await t.pump();
      expect(find.text('<b>会話</b>'), findsNothing);
      expect(find.byKey(const Key('scenario-selected')), findsNothing);
      expect(find.byKey(const Key('scenario-unavailable')), findsOneWidget);
      h.auth.currentSession = old;
      hints.add(null);
      await t.idle();
      await t.pump();
      expect(find.text('<b>会話</b>'), findsNothing);
      expect(h.port.calls, 1);
      await t.pumpWidget(const SizedBox());
      await hints.close();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'replacement fences retained old load callback and preserves borrowed readers',
    (t) async {
      final a = fixture.Harness();
      final b = fixture.Harness();
      await mount(t, AiConversationScenarioBinding(reader: a.reader));
      final callback = t
          .widget<FilledButton>(find.byKey(const Key('scenario-load')))
          .onPressed!;
      await mount(t, AiConversationScenarioBinding(reader: b.reader));
      callback();
      await t.pumpAndSettle();
      expect(a.port.calls, 0);
      expect(b.port.calls, 0);
      await load(t);
      expect(b.port.calls, 1);
      await t.pumpWidget(const SizedBox());
      callback();
      await t.pump();
      expect(a.reader.isCurrent, isTrue);
      expect(b.reader.isCurrent, isTrue);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'unmount pending read consumes late response without publication or retry',
    (t) async {
      final h = fixture.Harness();
      final held = Completer<Object?>();
      h.port.reply = (_) => held.future;
      await mount(t, AiConversationScenarioBinding(reader: h.reader));
      await t.tap(find.byKey(const Key('scenario-load')));
      await t.pump();
      expect(find.byKey(const Key('scenario-loading')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      held.complete(fixture.rows(AiTextLevel.n5));
      await t.pumpAndSettle();
      expect(h.port.calls, 1);
      expect(h.reader.isCurrent, isTrue);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('320px 200 percent text selector scrolls without overflow', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final h = fixture.Harness();
    await mount(t, AiConversationScenarioBinding(reader: h.reader), scale: 2);
    await load(t);
    final choose = find.text('Chọn');
    await t.ensureVisible(choose);
    await t.pump();
    expect(choose.hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
