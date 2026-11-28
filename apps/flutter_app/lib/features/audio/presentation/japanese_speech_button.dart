import 'package:flutter/material.dart';

import '../data/japanese_speech.dart';

class JapaneseSpeechButton extends StatefulWidget {
  const JapaneseSpeechButton({
    super.key,
    required this.text,
    required this.label,
    this.speech,
  });

  final String text;
  final String label;
  final JapaneseSpeechPort? speech;

  @override
  State<JapaneseSpeechButton> createState() => _JapaneseSpeechButtonState();
}

class _JapaneseSpeechButtonState extends State<JapaneseSpeechButton> {
  late final JapaneseSpeechPort _speech =
      widget.speech ?? createJapaneseSpeech();
  bool _speaking = false;
  String? _message;

  Future<void> _start() async {
    if (_speaking) return;
    setState(() {
      _speaking = true;
      _message = null;
    });
    JapaneseSpeechResult result;
    try {
      result = await _speech.speak(
        widget.text,
        onComplete: (completed) {
          if (!mounted) return;
          setState(() {
            _speaking = false;
            _message = completed
                ? 'Đã đọc xong.'
                : 'Đã dừng hoặc không thể hoàn tất phát âm.';
          });
        },
      );
    } on Object {
      result = JapaneseSpeechResult.failed;
    }
    if (!mounted || result == JapaneseSpeechResult.started) return;
    setState(() {
      _speaking = false;
      _message = _messageFor(result);
    });
  }

  void _stop() {
    _speech.cancel();
    if (!mounted) return;
    setState(() {
      _speaking = false;
      _message = 'Đã dừng đọc.';
    });
  }

  String _messageFor(JapaneseSpeechResult result) => switch (result) {
    JapaneseSpeechResult.started => 'Đang đọc bằng giọng máy…',
    JapaneseSpeechResult.unsupported =>
      'Giọng đọc hệ thống chưa khả dụng trên nền tảng này.',
    JapaneseSpeechResult.noJapaneseVoice =>
      'Thiết bị chưa có giọng đọc tiếng Nhật. Hãy cài giọng Nhật rồi thử lại.',
    JapaneseSpeechResult.invalidText =>
      'Nội dung tiếng Nhật trống, có ký tự không hợp lệ hoặc quá dài.',
    JapaneseSpeechResult.failed =>
      'Chưa thể phát giọng đọc trên thiết bị. Vui lòng thử lại.',
  };

  @override
  void dispose() {
    if (_speaking) _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_speaking)
          OutlinedButton(
            key: const Key('japanese-speech-stop'),
            onPressed: _stop,
            child: const Text('Dừng đọc'),
          )
        else
          OutlinedButton(
            key: const Key('japanese-speech-start'),
            onPressed: _start,
            child: Text(widget.label),
          ),
        if (_speaking) const Text('Đang đọc bằng giọng máy…'),
        if (_message != null)
          Text(_message!, key: const Key('japanese-speech-message')),
      ],
    );
  }
}
