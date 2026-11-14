import 'dart:convert';

/// Preflight bounded JSON nesting and duplicate (including escaped) keys before
/// dart:convert can overwrite them. dart:convert still validates full grammar.
Object? decodeStrictJson(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 239 &&
      bytes[1] == 187 &&
      bytes[2] == 191) {
    throw const FormatException();
  }
  final text = utf8.decode(bytes, allowMalformed: false);
  final stack = <_JsonFrame>[];
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c == 34) {
      final start = i++;
      while (i < text.length && text.codeUnitAt(i) != 34) {
        if (text.codeUnitAt(i) == 92) i++;
        i++;
      }
      if (i >= text.length) throw const FormatException();
      if (stack.isNotEmpty && stack.last.expectKey) {
        final key = jsonDecode(text.substring(start, i + 1)) as String;
        if (!stack.last.keys.add(key)) throw const FormatException();
        stack.last.expectKey = false;
      }
    } else if (c == 123 || c == 91) {
      if (stack.length >= 16) throw const FormatException();
      stack.add(_JsonFrame(c == 123));
    } else if (c == 125 || c == 93) {
      if (stack.isEmpty) throw const FormatException();
      stack.removeLast();
    } else if (c == 44 && stack.isNotEmpty) {
      stack.last.expectKey = stack.last.object;
    }
  }
  if (stack.isNotEmpty) throw const FormatException();
  return jsonDecode(text);
}

final class _JsonFrame {
  _JsonFrame(this.object) : expectKey = object;
  final bool object;
  bool expectKey;
  final keys = <String>{};
}
