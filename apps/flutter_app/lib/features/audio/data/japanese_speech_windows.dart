import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'japanese_speech_api.dart';

abstract interface class JapaneseSpeechProcess {
  Stream<String> get outputLines;
  Future<int> get exitCode;
  Future<void> writeText(String text);
  bool kill();
}

typedef JapaneseSpeechProcessLauncher =
    Future<JapaneseSpeechProcess> Function();

final class WindowsJapaneseSpeech implements JapaneseSpeechPort {
  WindowsJapaneseSpeech({JapaneseSpeechProcessLauncher? launcher})
    : _launcher = launcher ?? _launchPowerShell;

  final JapaneseSpeechProcessLauncher _launcher;
  int _generation = 0;
  JapaneseSpeechProcess? _activeProcess;
  JapaneseSpeechCompletion? _completion;

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

    cancel();
    final generation = ++_generation;
    final handshake = Completer<JapaneseSpeechResult>();
    late final JapaneseSpeechProcess process;
    try {
      process = await _launcher();
    } on ProcessException {
      return generation == _generation
          ? JapaneseSpeechResult.unsupported
          : JapaneseSpeechResult.started;
    } on Object {
      return generation == _generation
          ? JapaneseSpeechResult.failed
          : JapaneseSpeechResult.started;
    }

    if (generation != _generation) {
      process.kill();
      return JapaneseSpeechResult.started;
    }

    _activeProcess = process;
    _completion = onComplete;
    var speechStarted = false;
    late final StreamSubscription<String> outputSubscription;
    outputSubscription = process.outputLines.listen(
      (line) {
        if (generation != _generation || handshake.isCompleted) return;
        switch (line) {
          case 'STARTED':
            speechStarted = true;
            handshake.complete(JapaneseSpeechResult.started);
          case 'NO_VOICE':
            handshake.complete(JapaneseSpeechResult.noJapaneseVoice);
          case 'INVALID':
            handshake.complete(JapaneseSpeechResult.invalidText);
          case 'FAILED':
            handshake.complete(JapaneseSpeechResult.failed);
        }
      },
      onError: (Object _) {
        if (!handshake.isCompleted) {
          handshake.complete(JapaneseSpeechResult.failed);
        }
        process.kill();
      },
    );

    unawaited(
      process.exitCode.then(
        (code) async {
          await outputSubscription.cancel();
          if (generation != _generation) return;
          if (!handshake.isCompleted) {
            handshake.complete(_resultForExit(code));
          }
          if (identical(_activeProcess, process)) _activeProcess = null;
          final callback = _completion;
          _completion = null;
          if (speechStarted) _notify(callback, code == 0);
        },
        onError: (Object _) {
          if (generation != _generation) return;
          if (!handshake.isCompleted) {
            handshake.complete(JapaneseSpeechResult.failed);
          }
          _finish(generation, false);
        },
      ),
    );

    try {
      await process.writeText(normalized);
    } on Object {
      process.kill();
      _finish(generation, false);
      return JapaneseSpeechResult.failed;
    }

    final result = await handshake.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => JapaneseSpeechResult.failed,
    );
    if (generation != _generation) return JapaneseSpeechResult.started;
    if (result != JapaneseSpeechResult.started) {
      if (identical(_activeProcess, process)) _activeProcess = null;
      _completion = null;
      process.kill();
    }
    return result;
  }

  JapaneseSpeechResult _resultForExit(int code) => switch (code) {
    2 => JapaneseSpeechResult.invalidText,
    3 => JapaneseSpeechResult.noJapaneseVoice,
    _ => JapaneseSpeechResult.failed,
  };

  void _finish(int generation, bool completed) {
    if (generation != _generation) return;
    if (_activeProcess != null) _activeProcess = null;
    final callback = _completion;
    _completion = null;
    _notify(callback, completed);
  }

  void _notify(JapaneseSpeechCompletion? callback, bool completed) {
    try {
      callback?.call(completed);
    } on Object {
      // A presentation callback must not leak a platform failure.
    }
  }

  @override
  void cancel() {
    _generation++;
    final process = _activeProcess;
    _activeProcess = null;
    final callback = _completion;
    _completion = null;
    process?.kill();
    _notify(callback, false);
  }
}

Future<JapaneseSpeechProcess> _launchPowerShell() async {
  final process = await Process.start(
    'powershell.exe',
    [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      _encodeUtf16LeBase64(_windowsSpeechScript),
    ],
    runInShell: false,
  );
  return _PowerShellJapaneseSpeechProcess(process);
}

String _encodeUtf16LeBase64(String value) {
  final bytes = <int>[];
  for (final codeUnit in value.codeUnits) {
    bytes
      ..add(codeUnit & 0xff)
      ..add((codeUnit >> 8) & 0xff);
  }
  return base64Encode(bytes);
}

final class _PowerShellJapaneseSpeechProcess
    implements JapaneseSpeechProcess {
  _PowerShellJapaneseSpeechProcess(this._process) {
    _process.stderr.listen((_) {});
  }

  final Process _process;

  @override
  Stream<String> get outputLines =>
      _process.stdout.transform(utf8.decoder).transform(const LineSplitter());

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<void> writeText(String text) async {
    _process.stdin.add(utf8.encode(text));
    await _process.stdin.flush();
    await _process.stdin.close();
  }

  @override
  bool kill() => _process.kill();
}

const _windowsSpeechScript = r'''
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$synth = $null
$markerSent = $false
$exitCode = 4
try {
  $text = [Console]::In.ReadToEnd()
  if ([string]::IsNullOrWhiteSpace($text) -or
      $text.Length -gt 8192 -or
      $text -match '[\x00-\x1F\x7F]') {
    [Console]::Out.WriteLine('INVALID')
    [Console]::Out.Flush()
    $markerSent = $true
    $exitCode = 2
  } else {
    Add-Type -AssemblyName System.Speech
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $voice = $synth.GetInstalledVoices() | Where-Object {
      $_.Enabled -and $_.VoiceInfo.Culture.Name -match '^ja(?:-|$)'
    } | Select-Object -First 1
    if ($null -eq $voice) {
      [Console]::Out.WriteLine('NO_VOICE')
      [Console]::Out.Flush()
      $markerSent = $true
      $exitCode = 3
    } else {
      $synth.SelectVoice($voice.VoiceInfo.Name)
      $synth.Rate = -1
      [Console]::Out.WriteLine('STARTED')
      [Console]::Out.Flush()
      $markerSent = $true
      $synth.Speak($text)
      $exitCode = 0
    }
  }
} catch {
  if (-not $markerSent) {
    [Console]::Out.WriteLine('FAILED')
    [Console]::Out.Flush()
  }
  $exitCode = 4
} finally {
  if ($null -ne $synth) {
    $synth.Dispose()
  }
}
exit $exitCode
''';
