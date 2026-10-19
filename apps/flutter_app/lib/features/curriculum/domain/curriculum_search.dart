import 'curriculum.dart';

/// Local display search only. Original entries, IDs, versions and order remain
/// unchanged; this does not enroll items or publish study progress.
List<CurriculumEntry> searchCurriculum(
  List<CurriculumEntry> entries,
  String query,
) {
  final needle = _fold(query).trim();
  return List.unmodifiable([
    for (final entry in entries)
      if (needle.isEmpty ||
          [
            entry.heading,
            entry.reading ?? '',
            entry.meaningVi,
            entry.caption,
          ].any((value) => _fold(value).contains(needle)))
        entry,
  ]);
}

final _combiningMarks = RegExp(r'[\u0300-\u036f]');
final _vietnameseLetters = <RegExp, String>{
  RegExp('[àáảãạăằắẳẵặâầấẩẫậ]'): 'a',
  RegExp('[èéẻẽẹêềếểễệ]'): 'e',
  RegExp('[ìíỉĩị]'): 'i',
  RegExp('[òóỏõọôồốổỗộơờớởỡợ]'): 'o',
  RegExp('[ùúủũụưừứửữự]'): 'u',
  RegExp('[ỳýỷỹỵ]'): 'y',
  RegExp('đ'): 'd',
};

String _fold(String value) {
  var folded = value.toLowerCase().replaceAll(_combiningMarks, '');
  for (final group in _vietnameseLetters.entries) {
    folded = folded.replaceAll(group.key, group.value);
  }
  return folded;
}
