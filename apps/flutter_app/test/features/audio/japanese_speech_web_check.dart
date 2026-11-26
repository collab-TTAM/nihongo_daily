import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/audio/data/japanese_speech.dart';

void main() {
  test('browser speech adapter is bounded and reports explicit capability', () async {
    final speech = createJapaneseSpeech();
    expect(
      await speech.speak('   '),
      JapaneseSpeechResult.invalidText,
    );
    expect(
      await speech.speak('あ' * 8193),
      JapaneseSpeechResult.invalidText,
    );

    final result = await speech.speak('日本語を勉強します。');
    expect(
      {
        JapaneseSpeechResult.started,
        JapaneseSpeechResult.noJapaneseVoice,
        JapaneseSpeechResult.unsupported,
      },
      contains(result),
    );
    speech.cancel();
  });
}
