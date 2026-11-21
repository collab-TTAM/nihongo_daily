import 'dart:async';
import 'dart:convert';

import '../../../shared/models/preview_level.dart';
import '../domain/reading_material.dart';
import '../domain/reading_repository.dart';

/// The host supplies a trusted, bounded local/packaged source, never a path or URL
/// from the learner. This class does not authenticate an arbitrary remote source.
/// No default material or network/storage writer is installed.
final class LocalReadingRepository implements ReadingRepository {
  LocalReadingRepository({
    required Future<String> Function() read,
    Duration timeout = const Duration(seconds: 5),
  }) : _read = read,
       _timeout = timeout {
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 15)) {
      throw ArgumentError('Invalid reading load timeout');
    }
  }

  final Future<String> Function() _read;
  final Duration _timeout;
  Future<List<ReadingPassage>>? _inFlight;
  Map<String, _KnownPassage> _known = {};

  @override
  Future<List<ReadingPassage>> load(PreviewLevel level) async {
    final passages = await _loadCatalog();
    return List.unmodifiable(passages.where((entry) => entry.level == level));
  }

  @override
  Future<ReadingPassage?> find(
    PreviewLevel level,
    String id,
    int contentVersion,
  ) async {
    final passages = await load(level);
    for (final passage in passages) {
      if (passage.id == id && passage.contentVersion == contentVersion) {
        return passage;
      }
    }
    return null;
  }

  Future<List<ReadingPassage>> _loadCatalog() {
    final pending = _inFlight;
    if (pending != null) return pending;
    // Register before invoking the source, including synchronous/reentrant reads.
    final completion = Completer<List<ReadingPassage>>();
    _inFlight = completion.future;
    unawaited(_readCatalog(completion));
    return completion.future;
  }

  Future<void> _readCatalog(Completer<List<ReadingPassage>> completion) async {
    try {
      final String source;
      try {
        source = await Future<String>.sync(_read).timeout(_timeout);
      } catch (_) {
        throw const ReadingLoadException(ReadingLoadFailure.unavailable);
      }
      final List<ReadingPassage> decoded;
      try {
        // The parser validates the entire catalog before either level is exposed.
        decoded = [
          ...decodeReadingMaterial(source, PreviewLevel.n5),
          ...decodeReadingMaterial(source, PreviewLevel.n4),
        ];
      } on FormatException {
        throw const ReadingLoadException(ReadingLoadFailure.invalidMaterial);
      }
      final next = Map<String, _KnownPassage>.of(_known);
      final current = <ReadingPassage>[];
      for (final passage in decoded) {
        final signature = _signature(passage);
        final previous = next[passage.id];
        if (previous != null &&
            (previous.passage.level != passage.level ||
                previous.passage.contentVersion > passage.contentVersion ||
                (previous.passage.contentVersion == passage.contentVersion &&
                    previous.signature != signature))) {
          throw const ReadingLoadException(ReadingLoadFailure.versionConflict);
        }
        if (previous != null &&
            previous.passage.contentVersion == passage.contentVersion) {
          current.add(previous.passage);
        } else {
          next[passage.id] = _KnownPassage(passage, signature);
          current.add(passage);
        }
      }
      // Remember retired IDs to reject rollback/reassignment on reappearance.
      // At most 50 latest snapshots in this repository lifetime; never evict a
      // version fence silently. A larger reviewed catalog needs a new repository.
      if (next.length > 50) {
        throw const ReadingLoadException(ReadingLoadFailure.versionConflict);
      }
      final result = List<ReadingPassage>.unmodifiable(current);
      // Publish fences only after validating all entries, including hidden levels.
      _known = next;
      completion.complete(result);
    } catch (error) {
      completion.completeError(
        error is ReadingLoadException
            ? error
            : const ReadingLoadException(ReadingLoadFailure.invalidMaterial),
      );
    } finally {
      _inFlight = null;
    }
  }
}

final class _KnownPassage {
  const _KnownPassage(this.passage, this.signature);
  final ReadingPassage passage;
  final String signature;
}

// Fixed field order ignores JSON whitespace/member order, while preserving all
// study-visible text, question/choice order, answer keys and attribution exactly.
// This is bounded semantic equality, not a cryptographic authenticity check.
String _signature(ReadingPassage p) => jsonEncode([
  p.id,
  p.level.name,
  p.contentVersion,
  p.titleJa,
  p.titleVi,
  p.japanese,
  p.reading,
  p.vietnamese,
  p.sourceNoteVi,
  [
    for (final q in p.questions)
      [
        q.id,
        q.japanese,
        q.reading,
        q.vietnamese,
        q.correctChoiceId,
        q.explanationVi,
        [
          for (final c in q.choices)
            [c.id, c.japanese, c.reading, c.vietnamese],
        ],
      ],
  ],
]);
