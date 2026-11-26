import 'japanese_speech_api.dart';
import 'japanese_speech_stub.dart'
    if (dart.library.js_interop) 'japanese_speech_web.dart'
    as platform;

export 'japanese_speech_api.dart';

JapaneseSpeechPort createJapaneseSpeech() => platform.createJapaneseSpeech();
