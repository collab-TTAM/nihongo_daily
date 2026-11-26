import 'dart:io';

import 'japanese_speech_api.dart';
import 'japanese_speech_stub.dart';
import 'japanese_speech_windows.dart';

JapaneseSpeechPort createJapaneseSpeech() {
  if (Platform.isWindows) return WindowsJapaneseSpeech();
  return createUnsupportedJapaneseSpeech();
}
