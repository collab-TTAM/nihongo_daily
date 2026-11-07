// Reader/asset tests, not linguistic acceptance or Pro N4 content validation.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/curriculum/data/bundled_curriculum_repository.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum.dart';
import 'package:nihongo_daily/features/curriculum/domain/curriculum_search.dart';
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
      final asset = 'assets/curriculum/n5/${kind.name}.json';
      expect(await rootBundle.loadString(asset), source);
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

  test('missing N4 assets fail without reading or substituting N5', () async {
    final reads = <String>[];
    final repository = BundledCurriculumRepository(
      read: (path) async {
        reads.add(path);
        throw StateError('PRIVATE N4 ASSET');
      },
    );
    for (final kind in CurriculumKind.values) {
      await expectLater(
        repository.load(kind, PreviewLevel.n4),
        throwsStateError,
      );
    }
    expect(reads, [
      'assets/curriculum/n4/vocabulary.json',
      'assets/curriculum/n4/grammar.json',
    ]);
  });

  for (final kind in CurriculumKind.values) {
    test(
      'bundled N4 ${kind.name} preserves all original IDs and examples',
      () async {
        final source = await File(
          '../../data/n4/${kind.name}.json',
        ).readAsString();
        final asset = 'assets/curriculum/n4/${kind.name}.json';
        expect(await rootBundle.loadString(asset), source);
        final rows = jsonDecode(source) as List<dynamic>;
        final entries = await BundledCurriculumRepository().load(
          kind,
          PreviewLevel.n4,
        );
        expect(entries.length, kind == CurriculumKind.vocabulary ? 366 : 139);
        expect(entries.map((e) => e.id), rows.map((r) => r['id']));
        expect(entries.every((e) => e.level == PreviewLevel.n4), isTrue);
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i] as Map<String, dynamic>;
          final entry = entries[i];
          expect(entry.contentVersion, row['content_version']);
          expect(entry.meaningVi, row['meaning_vi']);
          expect(entry.hasAudioReference, isFalse);
          final examples = row['examples'] as List<dynamic>;
          expect(entry.examples.length, examples.length);
          for (var j = 0; j < examples.length; j++) {
            expect(entry.examples[j].japanese, examples[j]['sentence_ja']);
            expect(entry.examples[j].reading, examples[j]['reading_ja']);
            expect(entry.examples[j].vietnamese, examples[j]['translation_vi']);
          }
        }
        final matches = searchCurriculum(entries, entries.first.heading);
        expect(matches.any((e) => identical(e, entries.first)), isTrue);
        expect(() => entries.clear(), throwsUnsupportedError);
      },
    );
  }

  test(
    'original vocabulary searches Japanese readings and Vietnamese',
    () async {
      final entries = decodeCurriculum(
        await File('../../data/n5/vocabulary.json').readAsString(),
        CurriculumKind.vocabulary,
        PreviewLevel.n5,
      );
      for (final query in ['学生', 'がくせい', ' HOC SINH ', 'ho\u0323c sinh']) {
        final result = searchCurriculum(entries, query);
        expect(result.map((entry) => entry.heading), ['学生']);
        expect(identical(result.single, entries[1]), isTrue);
        expect(result.single.meaningVi, 'học sinh; sinh viên');
      }
      expect(searchCurriculum(entries, 'ĐỌC').single.heading, '読む');
      expect(searchCurriculum(entries, 'GIAO VIEN').single.heading, '先生');
    },
  );

  test(
    'original grammar searches pattern and accentless title in order',
    () async {
      final entries = decodeCurriculum(
        await File('../../data/n5/grammar.json').readAsString(),
        CurriculumKind.grammar,
        PreviewLevel.n5,
      );
      expect(
        searchCurriculum(entries, 'N1 は').map((entry) => entry.id),
        entries.take(3).map((entry) => entry.id),
      );
      expect(
        searchCurriculum(entries, 'PHU DINH').map((entry) => entry.heading),
        ['N1 は N2 ではありません', 'Vません'],
      );
    },
  );

  test(
    'blank literal and absent searches preserve immutable original data',
    () async {
      final entries = decodeCurriculum(
        await File('../../data/n5/vocabulary.json').readAsString(),
        CurriculumKind.vocabulary,
        PreviewLevel.n5,
      );
      final ids = entries.map((entry) => entry.id).toList();
      final all = searchCurriculum(entries, '  ');
      expect(all.map((entry) => entry.id), ids);
      expect(() => all.clear(), throwsUnsupportedError);
      expect(searchCurriculum(entries, '.*'), isEmpty);
      expect(searchCurriculum(entries, 'not-in-the-original-export'), isEmpty);
      expect(entries.map((entry) => entry.id), ids);
    },
  );

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
      [
        {...vocabulary, 'content_version': 0},
      ],
      [
        {...vocabulary, 'is_active': 'true'},
      ],
      [
        {...vocabulary, 'reading': ''},
      ],
      [
        {...vocabulary, 'jlpt_level': 'unknown'},
      ],
      [
        {
          ...vocabulary,
          'examples': [
            {'sentence_ja': '秘密'},
          ],
        },
      ],
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
