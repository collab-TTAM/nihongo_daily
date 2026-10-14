import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/preview_preferences.dart';
import '../data/demo_study_preview_repository.dart';
import '../domain/study_preview.dart';

final studyPreviewRepositoryProvider = Provider<StudyPreviewRepository>(
  (ref) => const DemoStudyPreviewRepository(),
);

final studyPreviewProvider = FutureProvider<StudyPreview>((ref) {
  return ref
      .watch(studyPreviewRepositoryProvider)
      .load(ref.watch(previewLevelProvider));
});
