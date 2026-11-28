enum JapaneseSpeechResult {
  started,
  unsupported,
  noJapaneseVoice,
  invalidText,
  failed,
}

typedef JapaneseSpeechCompletion = void Function(bool completed);

abstract interface class JapaneseSpeechPort {
  Future<JapaneseSpeechResult> speak(
    String text, {
    JapaneseSpeechCompletion? onComplete,
  });

  void cancel();
}
