import 'japanese_speech_api.dart';

JapaneseSpeechPort createJapaneseSpeech() => _UnsupportedJapaneseSpeech();

final class _UnsupportedJapaneseSpeech implements JapaneseSpeechPort {
  @override
  Future<JapaneseSpeechResult> speak(
    String text, {
    JapaneseSpeechCompletion? onComplete,
  }) async => JapaneseSpeechResult.unsupported;

  @override
  void cancel() {}
}
