import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/audio/data/japanese_speech_api.dart';
import 'package:nihongo_daily/features/audio/data/japanese_speech_windows.dart';

void main() {
  test('rejects empty, control and oversized text before process launch', () async {
    final launcher = _FakeLauncher([]);
    final speech = WindowsJapaneseSpeech(launcher: launcher.call);

    expect(await speech.speak('   '), JapaneseSpeechResult.invalidText);
    expect(
      await speech.speak('日本語\u0000です'),
      JapaneseSpeechResult.invalidText,
    );
    expect(
      await speech.speak(List.filled(8193, 'あ').join()),
      JapaneseSpeechResult.invalidText,
    );
    expect(launcher.calls, 0);
  });

  test('reports no installed Japanese voice without claiming playback', () async {
    final process = _FakeSpeechProcess();
    final launcher = _FakeLauncher([process]);
    final completions = <bool>[];
    final speech = WindowsJapaneseSpeech(launcher: launcher.call);

    final result = speech.speak('日本語を勉強します。', onComplete: completions.add);
    await process.inputWritten.future;
    process.emit('NO_VOICE');
    process.finish(3);

    expect(await result, JapaneseSpeechResult.noJapaneseVoice);
    await Future<void>.delayed(Duration.zero);
    expect(process.sentText, '日本語を勉強します。');
    expect(completions, isEmpty);
  });

  test('completed speech reports its terminal callback once', () async {
    final process = _FakeSpeechProcess();
    final speech = WindowsJapaneseSpeech(
      launcher: _FakeLauncher([process]).call,
    );
    final completion = Completer<bool>();

    final result = speech.speak(
      'ひらがなを読みます。',
      onComplete: completion.complete,
    );
    await process.inputWritten.future;
    process.emit('STARTED');

    expect(await result, JapaneseSpeechResult.started);
    expect(completion.isCompleted, isFalse);
    process.finish(0);

    expect(await completion.future, isTrue);
  });

  test('cancelling kills the process and fences late completion', () async {
    final process = _FakeSpeechProcess();
    final speech = WindowsJapaneseSpeech(
      launcher: _FakeLauncher([process]).call,
    );
    final completions = <bool>[];

    final result = speech.speak('日本語を練習します。', onComplete: completions.add);
    await process.inputWritten.future;
    process.emit('STARTED');
    expect(await result, JapaneseSpeechResult.started);

    speech.cancel();
    expect(process.killed, isTrue);
    expect(completions, [false]);
    process.finish(0);
    await Future<void>.delayed(Duration.zero);
    expect(completions, [false]);
  });

  test('late completion from an older utterance cannot complete a newer one', () async {
    final first = _FakeSpeechProcess();
    final second = _FakeSpeechProcess();
    final speech = WindowsJapaneseSpeech(
      launcher: _FakeLauncher([first, second]).call,
    );
    final firstCompletions = <bool>[];
    final secondCompletion = Completer<bool>();

    final firstResult = speech.speak('一つ目。', onComplete: firstCompletions.add);
    await first.inputWritten.future;
    first.emit('STARTED');
    expect(await firstResult, JapaneseSpeechResult.started);

    speech.cancel();
    final secondResult = speech.speak(
      '二つ目。',
      onComplete: secondCompletion.complete,
    );
    await second.inputWritten.future;
    second.emit('STARTED');
    expect(await secondResult, JapaneseSpeechResult.started);

    first.finish(0);
    second.finish(0);

    expect(await secondCompletion.future, isTrue);
    expect(firstCompletions, [false]);
  });

  test('PowerShell launch failure is reported as unsupported', () async {
    final speech = WindowsJapaneseSpeech(
      launcher: () async =>
          throw ProcessException('powershell.exe', const <String>[]),
    );

    expect(await speech.speak('日本語'), JapaneseSpeechResult.unsupported);
  });

  test('unexpected process exit before the start marker fails closed', () async {
    final process = _FakeSpeechProcess();
    final speech = WindowsJapaneseSpeech(
      launcher: _FakeLauncher([process]).call,
    );

    final result = speech.speak('日本語');
    await process.inputWritten.future;
    process.finish(4);

    expect(await result, JapaneseSpeechResult.failed);
  });
}

final class _FakeLauncher {
  _FakeLauncher(List<JapaneseSpeechProcess> processes)
    : _processes = Queue.of(processes);

  final Queue<JapaneseSpeechProcess> _processes;
  int calls = 0;

  Future<JapaneseSpeechProcess> call() async {
    calls++;
    return _processes.removeFirst();
  }
}

final class _FakeSpeechProcess implements JapaneseSpeechProcess {
  final StreamController<String> _output = StreamController<String>();
  final Completer<int> _exit = Completer<int>();
  final Completer<void> inputWritten = Completer<void>();

  String? sentText;
  bool killed = false;

  @override
  Stream<String> get outputLines => _output.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Future<void> writeText(String text) async {
    sentText = text;
    if (!inputWritten.isCompleted) inputWritten.complete();
  }

  @override
  bool kill() {
    killed = true;
    return true;
  }

  void emit(String line) => _output.add(line);

  void finish(int code) {
    if (!_output.isClosed) _output.close();
    if (!_exit.isCompleted) _exit.complete(code);
  }
}
