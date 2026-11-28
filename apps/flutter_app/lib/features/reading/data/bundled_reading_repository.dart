import 'package:flutter/services.dart';

import '../../../shared/models/preview_level.dart';
import '../domain/reading_material.dart';
import '../domain/reading_repository.dart';
import 'local_reading_repository.dart';

/// Reads one fixed package asset; no learner-controlled path, URL or writer.
final class BundledReadingRepository implements ReadingRepository {
  BundledReadingRepository({AssetBundle? bundle})
    : _delegate = LocalReadingRepository(
        read: () => (bundle ?? rootBundle).loadString(assetPath),
      );

  static const assetPath = 'assets/reading/catalog.json';

  final LocalReadingRepository _delegate;

  @override
  Future<List<ReadingPassage>> load(PreviewLevel level) =>
      _delegate.load(level);

  @override
  Future<ReadingPassage?> find(
    PreviewLevel level,
    String id,
    int contentVersion,
  ) => _delegate.find(level, id, contentVersion);
}
