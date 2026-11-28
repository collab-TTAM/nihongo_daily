import 'dart:js_interop';

import 'japanese_speech_api.dart';

@JS('window.speechSynthesis')
external _SpeechSynthesis? get _speechSynthesis;

@JS()
extension type _SpeechSynthesis._(JSObject _) implements JSObject {
  external JSArray<_SpeechSynthesisVoice> getVoices();
  external void cancel();
  external void speak(_SpeechSynthesisUtterance utterance);
}

@JS()
extension type _SpeechSynthesisVoice._(JSObject _) implements JSObject {
  external String get lang;
}

@JS('SpeechSynthesisUtterance')
extension type _SpeechSynthesisUtterance._(JSObject _) implements JSObject {
  external factory _SpeechSynthesisUtterance(String text);
  external set lang(String value);
  external set voice(_SpeechSynthesisVoice? value);
  external set rate(double value);
  external set onend(JSFunction? listener);
  external set onerror(JSFunction? listener);
}

JapaneseSpeechPort createJapaneseSpeech() => _WebJapaneseSpeech();

final class _WebJapaneseSpeech implements JapaneseSpeechPort {
  int _generation = 0;
  _SpeechSynthesis? _activeSynth;
  JapaneseSpeechCompletion? _completion;

  _SpeechSynthesis? _readSynth() {
    try {
      return _speechSynthesis;
    } on Object {
      return null;
    }
  }

  _SpeechSynthesisVoice? _japaneseVoice(_SpeechSynthesis synth) {
    try {
      for (final voice in synth.getVoices().toDart) {
        final language = voice.lang.toLowerCase().replaceAll('_', '-');
        if (language == 'ja' || language.startsWith('ja-')) return voice;
      }
    } on Object {
      return null;
    }
    return null;
  }

  @override
  Future<JapaneseSpeechResult> speak(
    String text, {
    JapaneseSpeechCompletion? onComplete,
  }) async {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty ||
        normalized.length > 8192 ||
        RegExp(r'[\u0000-\u001f\u007f]').hasMatch(normalized)) {
      return JapaneseSpeechResult.invalidText;
    }

    final synth = _readSynth();
    if (synth == null) return JapaneseSpeechResult.unsupported;
    final voice = _japaneseVoice(synth);
    if (voice == null) return JapaneseSpeechResult.noJapaneseVoice;

    cancel();
    final generation = ++_generation;
    _activeSynth = synth;
    _completion = onComplete;
    try {
      final utterance = _SpeechSynthesisUtterance(normalized)
        ..lang = 'ja-JP'
        ..voice = voice
        ..rate = 0.9;
      utterance.onend = ((JSAny? _) {
        _finish(generation, true);
      }).toJS;
      utterance.onerror = ((JSAny? _) {
        _finish(generation, false);
      }).toJS;
      synth.speak(utterance);
      return JapaneseSpeechResult.started;
    } on Object {
      _finish(generation, false);
      return JapaneseSpeechResult.failed;
    }
  }

  void _finish(int generation, bool completed) {
    if (generation != _generation) return;
    final callback = _completion;
    _completion = null;
    _activeSynth = null;
    callback?.call(completed);
  }

  @override
  void cancel() {
    final synth = _activeSynth ?? _readSynth();
    _generation++;
    try {
      synth?.cancel();
    } on Object {
      // Browser speech is best-effort; never expose a raw platform exception.
    }
    final callback = _completion;
    _completion = null;
    _activeSynth = null;
    callback?.call(false);
  }
}
