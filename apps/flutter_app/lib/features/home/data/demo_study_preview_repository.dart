import '../../../shared/models/preview_level.dart';
import '../domain/study_preview.dart';

class DemoStudyPreviewRepository implements StudyPreviewRepository {
  const DemoStudyPreviewRepository();

  @override
  Future<StudyPreview> load(PreviewLevel level) async {
    return StudyPreview(
      level: level,
      blocks: const [
        StudyPreviewBlock(area: StudyArea.srs, minutes: 20),
        StudyPreviewBlock(area: StudyArea.vocabulary, minutes: 15),
        StudyPreviewBlock(area: StudyArea.kanji, minutes: 20),
        StudyPreviewBlock(area: StudyArea.grammar, minutes: 15),
        StudyPreviewBlock(area: StudyArea.listeningReading, minutes: 15),
        StudyPreviewBlock(area: StudyArea.aiConversation, minutes: 25),
        StudyPreviewBlock(area: StudyArea.quizReview, minutes: 10),
      ],
    );
  }
}
