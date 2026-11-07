import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/kanji/data/bundled_kanji_repository.dart';
import 'package:nihongo_daily/features/kanji/domain/kanji_catalog.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> first;
  setUpAll(() async {
    first =
        (jsonDecode(await File('../../data/n5/kanji.json').readAsString())
                    as List<dynamic>)
                .first
            as Map<String, dynamic>;
  });
  for (final level in PreviewLevel.values) {
    test(
      'original ${level.name} Kanji assets preserve every display field',
      () async {
        final source = await File(
          '../../data/${level.name}/kanji.json',
        ).readAsString();
        expect(
          await rootBundle.loadString(
            'assets/curriculum/${level.name}/kanji.json',
          ),
          source,
        );
        final rows = jsonDecode(source) as List<dynamic>;
        final entries = await BundledKanjiRepository().load(level);
        expect(entries.length, level == PreviewLevel.n5 ? 8 : 95);
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i] as Map<String, dynamic>;
          final entry = entries[i];
          expect(entry.id, row['id']);
          expect(entry.level, level);
          expect(entry.contentVersion, row['content_version']);
          expect(entry.character, row['character']);
          expect(entry.meaningVi, row['meaning_vi']);
          expect(entry.onyomi, row['onyomi']);
          expect(entry.kunyomi, row['kunyomi']);
          expect(entry.strokeCount, row['stroke_count']);
          expect(entry.radical, row['radical']);
          expect(entry.hasStrokeReference, isFalse);
        }
        expect(() => entries.clear(), throwsUnsupportedError);
        expect(() => entries.first.onyomi.clear(), throwsUnsupportedError);
        expect(
          () => entries.first.kunyomi.add('wrong'),
          throwsUnsupportedError,
        );
      },
    );
  }
  test('fixed paths fail explicitly without another-level fallback', () async {
    final reads = <String>[];
    final repo = BundledKanjiRepository(
      read: (path) async {
        reads.add(path);
        throw StateError('PRIVATE ASSET PATH');
      },
    );
    for (final level in PreviewLevel.values) {
      await expectLater(repo.load(level), throwsStateError);
    }
    expect(reads, [
      'assets/curriculum/n5/kanji.json',
      'assets/curriculum/n4/kanji.json',
    ]);
  });
  test('filter inactive/other level but retain ordered versions', () {
    final inactive = {
      ...first,
      'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'is_active': false,
    };
    final other = {
      ...first,
      'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'jlpt_level': 'N4',
    };
    final current = {...first, 'content_version': 3};
    final source = jsonEncode([inactive, other, current]);
    final entries = decodeKanjiCatalog(source, PreviewLevel.n5);
    expect(entries.length, 1);
    expect(entries.single.id, first['id']);
    expect(entries.single.contentVersion, 3);
    expect(decodeKanjiCatalog(source, PreviewLevel.n4).single.id, other['id']);
  });
  final invalid = <String, Object?>{
    'id': '../bad',
    'jlpt_level': 'N3',
    'content_version': 0,
    'is_active': 'yes',
    'character': '日本',
    'meaning_vi': '',
    'onyomi': ['ニチ', 'ニチ'],
    'kunyomi': [null],
    'stroke_count': 65,
    'radical': 2,
    'stroke_data_ref': {},
  };
  for (final entry in invalid.entries) {
    test('invalid ${entry.key} rejects the whole projection', () {
      expect(
        () => decodeKanjiCatalog(
          jsonEncode([
            {...first, entry.key: entry.value},
          ]),
          PreviewLevel.n5,
        ),
        throwsFormatException,
      );
    });
  }
  test('duplicate ID/list/size bounds and missing metadata reject', () {
    for (final source in [
      jsonEncode([first, first]),
      '{}',
      jsonEncode([<String, Object?>{}]),
      jsonEncode(List.filled(5001, first)),
      ' ' * (8 * 1024 * 1024 + 1),
    ]) {
      expect(
        () => decodeKanjiCatalog(source, PreviewLevel.n5),
        throwsFormatException,
      );
    }
  });
  test(
    'literal local search preserves Japanese and folds Vietnamese accents',
    () async {
      final entries = decodeKanjiCatalog(
        await File('../../data/n5/kanji.json').readAsString(),
        PreviewLevel.n5,
      );
      final original = entries.map((e) => e.id).toList();
      for (final query in [
        '日',
        'ニチ',
        'MAT TROI',
        'MẶT TRỜI',
        'ma\u0323t tro\u031b\u0300i',
      ]) {
        expect(searchKanjiCatalog(entries, query).single.id, first['id']);
      }
      expect(searchKanjiCatalog(entries, 'ひ').map((e) => e.character), [
        '日',
        '人',
        '火',
      ]);
      expect(searchKanjiCatalog(entries, '['), isEmpty);
      expect(searchKanjiCatalog(entries, '  ').length, 8);
      expect(
        () => searchKanjiCatalog(entries, '').clear(),
        throwsUnsupportedError,
      );
      expect(entries.map((e) => e.id), original);
    },
  );
  test('a reference string is display metadata, never loaded geometry', () {
    final entries = decodeKanjiCatalog(
      jsonEncode([
        {...first, 'stroke_data_ref': 'https://invalid.example/ref.svg'},
      ]),
      PreviewLevel.n5,
    );
    expect(entries.single.hasStrokeReference, isTrue);
  });
}
