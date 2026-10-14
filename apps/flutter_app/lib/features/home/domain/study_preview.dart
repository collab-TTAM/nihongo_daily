import '../../../shared/models/preview_level.dart';

enum StudyArea {
  srs('SRS', 'Ôn tập SRS', '/srs'),
  vocabulary('VOCABULARY', 'Từ vựng', '/vocabulary'),
  kanji('KANJI', 'Luyện Kanji', '/kanji'),
  grammar('GRAMMAR', 'Ngữ pháp', '/grammar'),
  listeningReading('LISTENING_READING', 'Nghe và đọc', '/listening'),
  aiConversation('AI_CONVERSATION', 'Hội thoại AI', '/conversation'),
  quizReview('QUIZ_REVIEW', 'Kiểm tra nhanh', '/quiz');

  const StudyArea(this.wireName, this.label, this.path);

  final String wireName;
  final String label;
  final String path;
}

class StudyPreviewBlock {
  const StudyPreviewBlock({required this.area, required this.minutes});

  final StudyArea area;
  final int minutes;
}

class StudyPreview {
  StudyPreview({required this.level, required List<StudyPreviewBlock> blocks})
    : blocks = List.unmodifiable(blocks);

  final PreviewLevel level;
  final List<StudyPreviewBlock> blocks;

  int get totalMinutes =>
      blocks.fold(0, (total, block) => total + block.minutes);
}

// This interface provides a UI preview, not the authenticated get_daily_plan API.
abstract interface class StudyPreviewRepository {
  Future<StudyPreview> load(PreviewLevel level);
}
