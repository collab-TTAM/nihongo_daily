import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/audio/data/japanese_speech.dart';
import 'package:nihongo_daily/features/audio/presentation/japanese_speech_button.dart';

final class _FakeJapaneseSpeech implements JapaneseSpeechPort {
  _FakeJapaneseSpeech(this.result);

  final JapaneseSpeechResult result;
  JapaneseSpeechCompletion? completion;
  String? receivedText;
  int cancelCount = 0;

  @override
  Future<JapaneseSpeechResult> speak(
    String text, {
    JapaneseSpeechCompletion? onComplete,
  }) async {
    receivedText = text;
    completion = onComplete;
    return result;
  }

  @override
  void cancel() {
    cancelCount++;
    final callback = completion;
    completion = null;
    callback?.call(false);
  }

  void complete(bool completed) {
    final callback = completion;
    completion = null;
    callback?.call(completed);
  }
}

void main() {
  testWidgets('speaks the supplied Japanese text and supports stop', (
    tester,
  ) async {
    final speech = _FakeJapaneseSpeech(JapaneseSpeechResult.started);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JapaneseSpeechButton(
            text: 'にほんご',
            label: 'Nghe cách đọc (giọng máy)',
            speech: speech,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('japanese-speech-start')));
    await tester.pump();
    expect(speech.receivedText, 'にほんご');
    expect(find.text('Đang đọc bằng giọng máy…'), findsOneWidget);
    expect(find.byKey(const Key('japanese-speech-stop')), findsOneWidget);

    await tester.tap(find.byKey(const Key('japanese-speech-stop')));
    await tester.pump();
    expect(speech.cancelCount, 1);
    expect(find.text('Đã dừng đọc.'), findsOneWidget);
  });

  testWidgets('reports missing Japanese voice without platform details', (
    tester,
  ) async {
    final speech = _FakeJapaneseSpeech(JapaneseSpeechResult.noJapaneseVoice);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JapaneseSpeechButton(
            text: '日本語',
            label: 'Nghe',
            speech: speech,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('japanese-speech-start')));
    await tester.pump();
    expect(
      find.text(
        'Thiết bị chưa có giọng đọc tiếng Nhật. Hãy cài giọng Nhật rồi thử lại.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('reports unsupported platform explicitly', (tester) async {
    final speech = _FakeJapaneseSpeech(JapaneseSpeechResult.unsupported);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JapaneseSpeechButton(
            text: '日本語',
            label: 'Nghe',
            speech: speech,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('japanese-speech-start')));
    await tester.pump();
    expect(
      find.text('Giọng đọc hệ thống chưa khả dụng trên nền tảng này.'),
      findsOneWidget,
    );
  });

  testWidgets('completion resets the button and shows a short result', (
    tester,
  ) async {
    final speech = _FakeJapaneseSpeech(JapaneseSpeechResult.started);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JapaneseSpeechButton(
            text: 'ありがとう',
            label: 'Nghe',
            speech: speech,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('japanese-speech-start')));
    await tester.pump();
    speech.complete(true);
    await tester.pump();

    expect(find.text('Đã đọc xong.'), findsOneWidget);
    expect(find.byKey(const Key('japanese-speech-start')), findsOneWidget);
  });
}
