import '../../../shared/models/preview_level.dart';

enum CurriculumKind {
  vocabulary('Từ vựng'),
  grammar('Ngữ pháp');

  const CurriculumKind(this.label);
  final String label;
}

final class CurriculumExample {
  const CurriculumExample({
    required this.japanese,
    required this.reading,
    required this.vietnamese,
  });
  final String japanese;
  final String reading;
  final String vietnamese;
}

final class CurriculumEntry {
  CurriculumEntry({
    required this.id,
    required this.kind,
    required this.level,
    required this.contentVersion,
    required this.heading,
    required this.caption,
    required this.reading,
    required this.meaningVi,
    required this.explanationVi,
    required this.hasAudioReference,
    required List<String> notes,
    required List<String> mistakes,
    required List<CurriculumExample> examples,
  }) : notes = List.unmodifiable(notes),
       mistakes = List.unmodifiable(mistakes),
       examples = List.unmodifiable(examples);

  final String id;
  final CurriculumKind kind;
  final PreviewLevel level;
  final int contentVersion;
  final String heading;
  final String caption;
  final String? reading;
  final String meaningVi;
  final String explanationVi;
  final bool hasAudioReference;
  final List<String> notes;
  final List<String> mistakes;
  final List<CurriculumExample> examples;
}

/// Public curriculum reads only. No learner state or write capability.
abstract interface class CurriculumRepository {
  Future<List<CurriculumEntry>> load(CurriculumKind kind, PreviewLevel level);
}
