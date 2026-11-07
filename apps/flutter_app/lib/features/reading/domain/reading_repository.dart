import '../../../shared/models/preview_level.dart';
import 'reading_material.dart';

/// Public, read-only practice material. No account or learning-write capability.
abstract interface class ReadingRepository {
  Future<List<ReadingPassage>> load(PreviewLevel level);

  /// Returns only the exact current version; never substitutes a newer passage.
  Future<ReadingPassage?> find(
    PreviewLevel level,
    String id,
    int contentVersion,
  );
}

enum ReadingLoadFailure { unavailable, invalidMaterial, versionConflict }

/// Fixed public errors; never retain the loader's exception or source contents.
final class ReadingLoadException implements Exception {
  const ReadingLoadException(this.failure);
  final ReadingLoadFailure failure;

  @override
  String toString() => switch (failure) {
    ReadingLoadFailure.unavailable => 'Reading material unavailable',
    ReadingLoadFailure.invalidMaterial => 'Invalid reading material',
    ReadingLoadFailure.versionConflict => 'Reading material version conflict',
  };
}
