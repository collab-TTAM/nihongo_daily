// TEST ONLY captured repository/strict DTOs with injected Auth and held ports.
// No hosted learner/provider proof and no default/network activation.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_controller.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_view_binding.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/presentation/ai_tutor_screen.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

final selectedBinding = StateProvider<AiTextViewBinding?>((ref) => null);
late Map<String, Object?> fixtures;
Object? response(String method) =>
    jsonDecode(jsonEncode(fixtures['${method}_response']));

final class _Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(
    userId: '11111111-1111-4111-8111-111111111111',
  );
}

final class _Port implements AiTextTransport {
  final calls = <({String method, Map<String, Object> body})>[];
  FutureOr<Object?> Function(String)? onCall;
  Future<Object?> call(String method, Map<String, Object> body) {
    calls.add((method: method, body: body));
    final callback = onCall;
    return Future<Object?>.sync(
      () => callback == null ? response(method) : callback(method),
    );
  }

  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) => call('tutor_explain', body);
  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) => call('correct_sentence', body);
}

final class _Harness {
  final auth = _Auth();
  final port = _Port();
  final changes = StreamController<void>.broadcast(sync: true);
  bool ready = true;
  late final repository = CapturedAiTextRepository(
    auth: auth,
    transport: port,
    isReady: () => ready,
  );
  late final binding = AiTextViewBinding(
    repository: repository,
    availabilityChanges: changes.stream,
  );
}

Future<ProviderContainer> mount(
  WidgetTester tester,
  AiTextViewBinding? binding, {
  List<_Harness> harnesses = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      aiTextViewBindingProvider.overrideWith(
        (ref) => ref.watch(selectedBinding),
      ),
    ],
  );
  container.read(selectedBinding.notifier).state = binding;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: AiTutorScreen())),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    for (final h in harnesses) {
      await h.changes.close();
    }
  });
  return container;
}

Future<void> enter(WidgetTester tester, String value) async {
  await tester.ensureVisible(find.byKey(const Key('ai-draft')));
  await tester.enterText(find.byKey(const Key('ai-draft')), value);
  await tester.pump();
}

Future<void> send(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('ai-send')));
  await tester.tap(find.byKey(const Key('ai-send')));
  await tester.pump();
}

FilledButton sendButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('ai-send')));
void chooseCorrection(WidgetTester tester) => tester
    .widget<DropdownButtonFormField<AiTextOperation>>(
      find.byKey(const Key('ai-operation')),
    )
    .onChanged!(AiTextOperation.correct);
void main() {
  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  testWidgets('null default keeps original unavailable preview and no input', (
    tester,
  ) async {
    await mount(tester, null);
    expect(find.text('Đang xây dựng'), findsOneWidget);
    expect(
      find.text('Giải thích và sửa câu ở trình độ N5–N4.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('ai-result')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'external wire busy offers manual availability check without resend',
    (tester) async {
      final h = _Harness();
      final held = Completer<Object?>();
      h.port.onCall = (_) => held.future;
      final outside = h.repository.explain(
        TutorExplainRequest(
          level: AiTextLevel.n5,
          questionVi: 'TEST ONLY EXTERNAL',
        ),
      );
      await mount(tester, h.binding, harnesses: [h]);
      expect(
        tester.widget<TextField>(find.byKey(const Key('ai-draft'))).enabled,
        isFalse,
      );
      expect(find.text('Yêu cầu AI trước vẫn đang xử lý.'), findsOneWidget);
      expect(find.byKey(const Key('ai-recheck')), findsOneWidget);
      held.complete(response('tutor_explain'));
      await outside;
      await tester.ensureVisible(find.byKey(const Key('ai-recheck')));
      await tester.tap(find.byKey(const Key('ai-recheck')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(const Key('ai-draft'))).enabled,
        isTrue,
      );
      expect(h.port.calls.length, 1);
      expect(find.byKey(const Key('ai-result')), findsNothing);
    },
  );
  testWidgets(
    'explicit explanation renders accepted text examples reading translation and practice',
    (tester) async {
      final h = _Harness();
      await mount(tester, h.binding, harnesses: [h]);
      expect(h.port.calls, isEmpty);
      expect(sendButton(tester).onPressed, isNull);
      await enter(tester, '   ');
      expect(sendButton(tester).onPressed, isNull);
      await enter(tester, '  Cách dùng ます?  ');
      await send(tester);
      await tester.pumpAndSettle();
      expect(h.port.calls.single.body['question_vi'], '  Cách dùng ます?  ');
      expect(find.text('Kết quả N5'), findsOneWidget);
      expect(find.text('  Cách dùng ます?  '), findsWidgets);
      expect(find.text('Đây là thể lịch sự.'), findsOneWidget);
      expect(find.text('みずをのみます。'), findsOneWidget);
      expect(find.text('Tôi uống nước.'), findsOneWidget);
      expect(find.text('Điền động từ thể ます.'), findsOneWidget);
      expect(
        find.text('Kết quả tham khảo. Chưa lưu vào tiến độ.'),
        findsOneWidget,
      );
      expect(find.text('Hội thoại giọng nói chưa khả dụng.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'correction preserves empty errors and uses explicitly chosen N4',
    (tester) async {
      final h = _Harness();
      await mount(tester, h.binding, harnesses: [h]);
      chooseCorrection(tester);
      await tester.pump();
      tester
          .widget<DropdownButtonFormField<AiTextLevel>>(
            find.byKey(const Key('ai-level')),
          )
          .onChanged!(AiTextLevel.n4);
      await tester.pump();
      await enter(tester, '水を飲みます。');
      await send(tester);
      await tester.pumpAndSettle();
      expect(h.port.calls.single.method, 'correct_sentence');
      expect(h.port.calls.single.body['jlpt_level'], 'N4');
      expect(find.text('Kết quả N4'), findsOneWidget);
      expect(find.text('Câu đã sửa'), findsOneWidget);
      expect(find.text('Cách nói tự nhiên'), findsOneWidget);
      expect(find.text('Không có lỗi được dịch vụ trả về.'), findsOneWidget);
    },
  );
  testWidgets(
    'held request disables editing level operation clearing and duplicate send',
    (tester) async {
      final h = _Harness();
      final held = Completer<Object?>();
      h.port.onCall = (_) => held.future;
      await mount(tester, h.binding, harnesses: [h]);
      await enter(tester, 'TEST ONLY');
      final oldSend = sendButton(tester).onPressed!;
      await send(tester);
      oldSend();
      expect(h.port.calls.length, 1);
      expect(find.text('Đang chờ kết quả AI…'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('ai-draft'))).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<AiTextLevel>>(
              find.byKey(const Key('ai-level')),
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<AiTextOperation>>(
              find.byKey(const Key('ai-operation')),
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('ai-clear')))
            .onPressed,
        isNull,
      );
      held.complete(response('tutor_explain'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-result')), findsOneWidget);
      expect(h.port.calls.length, 1);
    },
  );
  testWidgets('safe error and explicit recheck never resend submitted text', (
    tester,
  ) async {
    final h = _Harness();
    h.port.onCall = (_) => throw StateError('TEST_ONLY_PROVIDER_SECRET');
    await mount(tester, h.binding, harnesses: [h]);
    await enter(tester, 'TEST ONLY');
    await send(tester);
    await tester.pumpAndSettle();
    expect(find.text(AiTextErrorCode.internalError.messageVi), findsOneWidget);
    expect(find.textContaining('TEST_ONLY_PROVIDER_SECRET'), findsNothing);
    expect(find.byKey(const Key('ai-result')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('ai-recheck')));
    await tester.tap(find.byKey(const Key('ai-recheck')));
    await tester.pumpAndSettle();
    expect(h.port.calls.length, 1);
    h.port.onCall = response;
    await send(tester);
    await tester.pumpAndSettle();
    expect(h.port.calls.length, 2);
    expect(find.byKey(const Key('ai-result')), findsOneWidget);
  });
  testWidgets(
    'malformed output has no fallback result and model text is rendered literally',
    (tester) async {
      final h = _Harness();
      h.port.onCall = (_) => {'answer_vi': 'TEST_ONLY_MALFORMED'};
      await mount(tester, h.binding, harnesses: [h]);
      await enter(tester, 'TEST ONLY');
      await send(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('TEST_ONLY_MALFORMED'), findsNothing);
      expect(find.byKey(const Key('ai-result')), findsNothing);
      h.port.onCall = (_) => {
        'answer_vi':
            '<script>TEST ONLY</script> [link](https://example.invalid)',
        'examples': <Object>[],
        'practice': <Object>[],
      };
      await send(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('<script>TEST ONLY</script> [link](https://example.invalid)'),
        findsOneWidget,
      );
      expect(h.port.calls.length, 2);
    },
  );
  testWidgets(
    'editing and level or mode changes clear results and fence retained send',
    (tester) async {
      final h = _Harness();
      await mount(tester, h.binding, harnesses: [h]);
      await enter(tester, 'OLD QUESTION');
      final firstSend = sendButton(tester).onPressed!;
      await enter(tester, 'NEW QUESTION');
      firstSend();
      await tester.pump();
      expect(h.port.calls, isEmpty);
      await send(tester);
      await tester.pumpAndSettle();
      final afterSuccess = sendButton(tester).onPressed!;
      chooseCorrection(tester);
      await tester.pump();
      expect(find.byKey(const Key('ai-result')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-draft')))
            .controller!
            .text,
        isEmpty,
      );
      afterSuccess();
      await tester.pump();
      expect(h.port.calls.length, 1);
      await enter(tester, '日本語');
      final oldModeSend = sendButton(tester).onPressed!;
      tester
          .widget<DropdownButtonFormField<AiTextLevel>>(
            find.byKey(const Key('ai-level')),
          )
          .onChanged!(AiTextLevel.n4);
      await tester.pump();
      oldModeSend();
      await tester.pump();
      expect(h.port.calls.length, 1);
      expect(sendButton(tester).onPressed, isNull);
    },
  );
  testWidgets('readiness revocation clears editor and private result', (
    tester,
  ) async {
    final h = _Harness();
    await mount(tester, h.binding, harnesses: [h]);
    await enter(tester, 'PRIVATE OLD DRAFT');
    await send(tester);
    await tester.pumpAndSettle();
    final oldSend = sendButton(tester).onPressed!;
    final editor = tester
        .widget<TextField>(find.byKey(const Key('ai-draft')))
        .controller!;
    h.ready = false;
    h.changes.add(null);
    await tester.pumpAndSettle();
    expect(editor.text, isEmpty);
    expect(
      find.text('Trợ lý chưa khả dụng cho phiên hiện tại.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('PRIVATE OLD DRAFT'), findsNothing);
    oldSend();
    expect(h.port.calls.length, 1);
  });
  for (final error in [false, true]) {
    testWidgets(
      'binding replacement fences retained actions and late old result error=$error',
      (tester) async {
        final a = _Harness();
        final b = _Harness();
        b.auth.currentSession = ReviewSession(
          userId: '22222222-2222-4222-8222-222222222222',
        );
        final held = Completer<Object?>();
        a.port.onCall = (_) => held.future;
        final container = await mount(tester, a.binding, harnesses: [a, b]);
        await enter(tester, 'PRIVATE A');
        final oldSend = sendButton(tester).onPressed!;
        await send(tester);
        container.read(selectedBinding.notifier).state = b.binding;
        await tester.pumpAndSettle();
        expect(find.textContaining('PRIVATE A'), findsNothing);
        expect(b.port.calls, isEmpty);
        await enter(tester, 'NEW B');
        oldSend();
        expect(b.port.calls, isEmpty);
        if (error) {
          held.completeError(StateError('TEST_ONLY_OLD_SECRET'));
        } else {
          held.complete(response('tutor_explain'));
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('ai-result')), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('ai-draft')))
              .controller!
              .text,
          'NEW B',
        );
        await send(tester);
        await tester.pumpAndSettle();
        expect(b.port.calls.single.body['question_vi'], 'NEW B');
        expect(a.port.calls.length, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'source removal clears view and stale callbacks without closing borrowed repository',
    (tester) async {
      final h = _Harness();
      final container = await mount(tester, h.binding, harnesses: [h]);
      await enter(tester, 'PRIVATE DRAFT');
      final oldSend = sendButton(tester).onPressed!;
      container.read(selectedBinding.notifier).state = null;
      await tester.pumpAndSettle();
      oldSend();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Đang xây dựng'), findsOneWidget);
      expect(h.repository.isCurrent, isTrue);
      expect(h.port.calls, isEmpty);
    },
  );
  testWidgets(
    'code point input bound preserves accepted emoji and rejects oversized paste',
    (tester) async {
      final h = _Harness();
      await mount(tester, h.binding, harnesses: [h]);
      await enter(tester, '😀' * 5000);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-draft')))
            .controller!
            .text,
        '😀' * 5000,
      );
      await enter(tester, '😀' * 5001);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-draft')))
            .controller!
            .text,
        '😀' * 5000,
      );
      expect(h.port.calls, isEmpty);
    },
  );
  for (final size in [const Size(320, 640), const Size(375, 812)]) {
    testWidgets('tutor controls results and safe errors fit large text $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = _Harness();
      await mount(tester, h.binding, harnesses: [h]);
      await enter(tester, 'TEST ONLY');
      await send(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-result')), findsOneWidget);
      expect(tester.takeException(), isNull);
      h.port.onCall = (_) => throw const AiTextFailure(
        AiTextErrorCode.rateLimited,
        retryable: true,
      );
      await send(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('ai-recheck')));
      await tester.pump();
      expect(find.text(AiTextErrorCode.rateLimited.messageVi), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
