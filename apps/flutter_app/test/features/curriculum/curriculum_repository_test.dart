// Reader/asset tests, not linguistic acceptance or Pro N4 content validation.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/curriculum/data/bundled_curriculum_repository.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> vocabulary;
  setUpAll(() async {
    final source = await File('../../data/n5/vocabulary.json').readAsString();
    final rows = jsonDecode(source) as List<dynamic>;
    vocabulary = rows.first as Map<String, dynamic>;
  });

  test('bundled N5 preserves IDs versions and examples', () async {
    final repository = BundledCurriculumRepository();
    for (final kind in CurriculumKind.values) {
      final path = '../../data/n5/${kind.name}.json';
      final source = await File(path).readAsString();
      expect(await rootBundle.loadString(path), source);
      final rows = jsonDecode(source) as List<dynamic>;
      final first = rows.first as Map<String, dynamic>;
      final entries = await repository.load(kind, PreviewLevel.n5);
      expect(entries.length, rows.length);
      expect(entries.first.id, first['id']);
      expect(entries.first.contentVersion, first['content_version']);
      expect(entries.first.examples.first.japanese, '私は学生です。');
      expect(entries.first.examples.first.reading, 'わたしはがくせいです。');
      expect(entries.first.hasAudioReference, isFalse);
      if (kind == CurriculumKind.vocabulary) {
        expect(entries.first.heading, '私');
        expect(entries.first.reading, 'わたし');
      } else {
        expect(entries.first.reading, isNull);
        expect(entries.first.notes, isNotEmpty);
        expect(entries.first.mistakes, isNotEmpty);
      }
    }
  });

  test('unbundled N4 is empty without reading or substituting N5', () async {
    var reads = 0;
    final repository = BundledCurriculumRepository(
      read: (_) async {
        reads++;
        throw StateError('Must not read N5 for N4');
      },
    );
    expect(
      await repository.load(CurriculumKind.vocabulary, PreviewLevel.n4),
      isEmpty,
    );
    expect(reads, 0);
  });

  test('reader filters level and inactive rows and retains version', () {
    // TEST ONLY metadata variants of one N5 row, not authored N4 content.
    final rows = [
      {...vocabulary},
      {
        ...vocabulary,
        'id': '00000000-0000-4000-8000-000000000002',
        'jlpt_level': 'N4',
        'content_version': 3,
      },
      {
        ...vocabulary,
        'id': '00000000-0000-4000-8000-000000000003',
        'is_active': false,
      },
    ];
    final entries = decodeCurriculum(
      jsonEncode(rows),
      CurriculumKind.vocabulary,
      PreviewLevel.n4,
    );
    expect(entries.length, 1);
    expect(entries.single.level, PreviewLevel.n4);
    expect(entries.single.contentVersion, 3);
    expect(() => entries.clear(), throwsUnsupportedError);
    expect(() => entries.single.examples.clear(), throwsUnsupportedError);
  });

  test('duplicate IDs malformed fields and examples fail closed', () {
    for (final rows in [
      [vocabulary, vocabulary],
      [{...vocabulary, 'content_version': 0}],
      [{...vocabulary, 'is_active': 'true'}],
      [{...vocabulary, 'reading': ''}],
      [{...vocabulary, 'jlpt_level': 'unknown'}],
      [{...vocabulary, 'examples': [{'sentence_ja': '秘密'}]}],
    ]) {
      expect(
        () => decodeCurriculum(
          jsonEncode(rows),
          CurriculumKind.vocabulary,
          PreviewLevel.n5,
        ),
        throwsFormatException,
      );
    }
    for (final source in ['{}', 'null', '[1]', 'not JSON']) {
      expect(
        () => decodeCurriculum(
          source,
          CurriculumKind.vocabulary,
          PreviewLevel.n5,
        ),
        throwsFormatException,
      );
    }
  });

  test('asset read errors propagate for safe UI retry', () async {
    final repository = BundledCurriculumRepository(
      read: (_) => Future.error(StateError('PRIVATE ASSET')),
    );
    await expectLater(
      repository.load(CurriculumKind.grammar, PreviewLevel.n5),
      throwsStateError,
    );
  });
}
