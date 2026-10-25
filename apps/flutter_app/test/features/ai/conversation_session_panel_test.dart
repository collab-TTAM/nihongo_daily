// TEST ONLY Auth/port and frozen fixtures. No live service or default activation.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/ai_conversation_view_binding.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_mutation.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_session.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/presentation/conversation_session_panel.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

late Map<String, Object?> fixtures;

final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(
    userId: '11111111-1111-4111-8111-111111111111',
  );
}

final class Port implements ConversationMutationTransport {
  int calls = 0;
  String marker = '<b>日本語</b>';
  bool uncertain = false;
  bool emptySummary = false;
  bool detailed = false;
  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  }) async {
    calls++;
    if (uncertain) {
      return {
        'code': 'PROVIDER_UNAVAILABLE',
        'message_vi': 'PRIVATE_TOKEN_DETAIL',
        'retryable': true,
      };
    }
    final json =
        jsonDecode(jsonEncode(fixtures['${operation}_response']))
            as Map<String, Object?>;
    if (operation == 'start_conversation') {
      final message = json['assistant_message']! as Map<String, Object?>;
      message['text_ja'] = marker;
      message['text_vi'] = null;
      message['audio_ref'] = 'https://private.invalid/never-play';
    }
    if (detailed && operation == 'finish_conversation') {
      json['scores'] = {'grammar': 0, 'vocabulary': 100, 'fluency': 12.5};
      json['errors'] = [
        {
          'original_text': '元の文',
          'corrected_text': '修正文',
          'explanation_vi': '<script>gợi ý</script>',
          'item_refs': <Object>[],
        },
      ];
      json['strengths_vi'] = ['Điểm mạnh từ phản hồi'];
      json['focus_next_vi'] = ['Luyện tiếp từ phản hồi'];
    }
    if (emptySummary && operation == 'finish_conversation') {
      json['errors'] = <Object>[];
      json['strengths_vi'] = <Object>[];
      json['focus_next_vi'] = <Object>[];
      json['srs_recommendations'] = <Object>[];
    }
    return json;
  }
}

CapturedConversationSession flow(Auth auth, Port port) =>
    CapturedConversationSession(
      auth: auth,
      transport: port,
      isReady: () => true,
    );
Future<void> begin(CapturedConversationSession session) => session
    .start(
      StartConversationRequest.fromJson(fixtures['start_conversation_request']),
    )
    .then((_) {});
Future<void> finish(CapturedConversationSession session) => session
    .finish(
      FinishConversationRequest(
        sessionId: session.snapshot.sessionId!,
        clientEventId: '22222222-2222-4222-8222-222222222222',
      ),
    )
    .then((_) {});
Future<void> mount(
  WidgetTester tester,
  AiConversationViewBinding? binding, {
  double scale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: ConversationSessionPanel(binding: binding)),
    ),
  ),
);

void main() {
  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  testWidgets(
    'unavailable and idle panel never dispatches or offers mutation controls',
    (tester) async {
      await mount(tester, null);
      expect(find.byKey(const Key('conversation-unavailable')), findsOneWidget);
      expect(find.textContaining('giọng nói'), findsOneWidget);
      final port = Port();
      final session = flow(Auth(), port);
      await mount(tester, AiConversationViewBinding(session: session));
      await tester.pump();
      expect(find.text('Chưa bắt đầu hội thoại.'), findsOneWidget);
      expect(find.text('Chưa có phản hồi từ trợ lý.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(port.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'accepted assistant text renders literally with absent translation and no audio fetch',
    (tester) async {
      final port = Port();
      final session = flow(Auth(), port);
      await tester.runAsync(() => begin(session));
      await mount(tester, AiConversationViewBinding(session: session));
      await tester.pump();
      expect(find.text(port.marker), findsOneWidget);
      expect(find.text('Chưa có bản dịch.'), findsOneWidget);
      expect(find.textContaining('never-play'), findsNothing);
      expect(port.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'finished summary keeps empty lists honest and never claims saved progress',
    (tester) async {
      final port = Port()..emptySummary = true;
      final session = flow(Auth(), port);
      await tester.runAsync(() async {
        await begin(session);
        await finish(session);
      });
      await mount(tester, AiConversationViewBinding(session: session));
      await tester.pump();
      expect(find.byKey(const Key('conversation-summary')), findsOneWidget);
      expect(find.text('Chưa lưu vào tiến độ hoặc SRS.'), findsOneWidget);
      expect(
        find.text('Không có gợi ý sửa câu trong phản hồi này.'),
        findsOneWidget,
      );
      expect(find.text('Chưa có nhận xét điểm mạnh.'), findsOneWidget);
      expect(find.text('Chưa có gợi ý luyện tiếp.'), findsOneWidget);
      expect(find.text('Gợi ý SRS: 0. Chưa lưu.'), findsOneWidget);
      expect(port.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'owner revocation redacts retained text and queued hints cannot restore it',
    (tester) async {
      final auth = Auth();
      final port = Port();
      final session = flow(auth, port);
      final hints = StreamController<void>.broadcast(sync: true);
      await tester.runAsync(() => begin(session));
      await mount(
        tester,
        AiConversationViewBinding(
          session: session,
          availabilityChanges: hints.stream,
        ),
      );
      await tester.pump();
      expect(find.text(port.marker), findsOneWidget);
      final original = auth.currentSession;
      auth.currentSession = ReviewSession(userId: original!.userId);
      hints.add(null);
      // The async controller hint schedules the frame in a microtask. Flush it
      // before pump checks hasScheduledFrame; do not inspect the old render tree.
      await tester.idle();
      await tester.pump();
      expect(find.text(port.marker), findsNothing);
      expect(find.byKey(const Key('conversation-unavailable')), findsOneWidget);
      auth.currentSession = original;
      hints.add(null);
      // The async controller hint schedules the frame in a microtask. Flush it
      // before pump checks hasScheduledFrame; do not inspect the old render tree.
      await tester.idle();
      await tester.pump();
      expect(find.text(port.marker), findsNothing);
      expect(port.calls, 1);
      await tester.pumpWidget(const SizedBox());
      await hints.close();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'binding replacement and disposal preserve borrowed flows without stale publication',
    (tester) async {
      final a = Port()..marker = 'OLD_PRIVATE';
      final b = Port()..marker = 'NEW_ACCEPTED';
      final first = flow(Auth(), a);
      final second = flow(Auth(), b);
      await tester.runAsync(() async {
        await begin(first);
        await begin(second);
      });
      await mount(tester, AiConversationViewBinding(session: first));
      await tester.pump();
      expect(find.text('OLD_PRIVATE'), findsOneWidget);
      await mount(tester, AiConversationViewBinding(session: second));
      await tester.pump();
      expect(find.text('OLD_PRIVATE'), findsNothing);
      expect(find.text('NEW_ACCEPTED'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(first.isCurrent, isTrue);
      expect(second.isCurrent, isTrue);
      expect(first.snapshot.messages, hasLength(1));
      expect(a.calls + b.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'uncertain borrowed event stays blocked without raw error or automatic retry',
    (tester) async {
      final port = Port()..uncertain = true;
      final session = flow(Auth(), port);
      await tester.runAsync(() async {
        await expectLater(
          begin(session),
          throwsA(
            isA<AiTextFailure>().having(
              (e) => e.code,
              'code',
              AiTextErrorCode.providerUnavailable,
            ),
          ),
        );
      });
      await mount(tester, AiConversationViewBinding(session: session));
      await tester.pump();
      expect(find.byKey(const Key('conversation-uncertain')), findsOneWidget);
      expect(find.textContaining('PRIVATE_TOKEN_DETAIL'), findsNothing);
      expect(port.calls, 1);
      expect(session.hasUnresolvedMutation, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('320px large text summary scrolls without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final port = Port()..emptySummary = true;
    final session = flow(Auth(), port);
    await tester.runAsync(() async {
      await begin(session);
      await finish(session);
    });
    await mount(tester, AiConversationViewBinding(session: session), scale: 2);
    await tester.pump();
    final end = find.text('Gợi ý SRS: 0. Chưa lưu.');
    await tester.ensureVisible(end);
    await tester.pump();
    expect(end.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(port.calls, 2);
  });
  testWidgets(
    'validated score bounds and correction text render without markup interpretation',
    (tester) async {
      final port = Port()..detailed = true;
      final session = flow(Auth(), port);
      await tester.runAsync(() async {
        await begin(session);
        await finish(session);
      });
      await mount(tester, AiConversationViewBinding(session: session));
      await tester.pump();
      for (final text in [
        'Ngữ pháp: 0/100',
        'Từ vựng: 100/100',
        'Lưu loát: 12.5/100',
        '元の文',
        '修正文',
        '<script>gợi ý</script>',
        'Điểm mạnh từ phản hồi',
        'Luyện tiếp từ phản hồi',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(port.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
