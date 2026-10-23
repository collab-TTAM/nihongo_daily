import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/reading/data/local_reading_repository.dart';
import 'package:nihongo_daily/features/reading/domain/reading_material.dart';
import 'package:nihongo_daily/features/reading/domain/reading_repository.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

// TEST ONLY source fixtures, not reviewed curriculum or a hosted service.
Map<String, Object?> row({
  String id = 'fixture-a',
  String level = 'N5',
  int version = 1,
  String title = '読書',
}) => {
  'id': id,
  'jlpt_level': level,
  'content_version': version,
  'title_ja': title,
  'title_vi': 'Đọc sách',
  'text_ja': '本を読みます。',
  'reading_ja': 'ほんをよみます。',
  'translation_vi': 'Tôi đọc sách.',
  'source_note_vi': 'TEST ONLY',
  'questions': [
    {
      'id': 'q1',
      'prompt_ja': '何を読みますか。',
      'reading_ja': 'なにをよみますか。',
      'prompt_vi': 'Đọc gì?',
      'choices': [
        {'id': 'a', 'text_ja': '本', 'reading_ja': 'ほん', 'text_vi': 'Sách'},
        {'id': 'b', 'text_ja': '新聞', 'reading_ja': 'しんぶん', 'text_vi': 'Báo'},
      ],
      'correct_choice_id': 'a',
      'explanation_vi': 'Câu nói đọc sách.',
    },
  ],
};

String catalog(List<Map<String, Object?>> rows) =>
    jsonEncode({'schema_version': 1, 'passages': rows});

Matcher failure(ReadingLoadFailure kind) => isA<ReadingLoadException>().having(
  (error) => error.failure,
  'failure',
  kind,
);

void main() {
  test(
    'level lists and exact version lookup preserve immutable snapshots',
    () async {
      final source = catalog([row(), row(id: 'fixture-b', level: 'N4')]);
      final repository = LocalReadingRepository(read: () async => source);
      final n5 = await repository.load(PreviewLevel.n5);
      final n4 = await repository.load(PreviewLevel.n4);
      expect(n5.single.snapshotKey, 'n5/fixture-a/1');
      expect(n4.single.snapshotKey, 'n4/fixture-b/1');
      expect(() => n5.clear(), throwsUnsupportedError);
      expect(() => n5.single.questions.clear(), throwsUnsupportedError);
      expect(
        await repository.find(PreviewLevel.n5, 'fixture-a', 1),
        same(n5.single),
      );
      expect(await repository.find(PreviewLevel.n4, 'fixture-a', 1), isNull);
      expect(await repository.find(PreviewLevel.n5, 'fixture-a', 2), isNull);
      expect(await repository.find(PreviewLevel.n5, '../private', 1), isNull);
      expect(await repository.find(PreviewLevel.n5, 'fixture-a', 0), isNull);
    },
  );

  test('concurrent levels and lookups share one pending source read', () async {
    final source = Completer<String>();
    var reads = 0;
    final repository = LocalReadingRepository(
      read: () {
        reads++;
        return source.future;
      },
    );
    final n5 = repository.load(PreviewLevel.n5);
    final n4 = repository.load(PreviewLevel.n4);
    final exact = repository.find(PreviewLevel.n5, 'fixture-a', 1);
    expect(reads, 1);
    source.complete(catalog([row(), row(id: 'fixture-b', level: 'N4')]));
    expect((await n5).single.id, 'fixture-a');
    expect((await n4).single.id, 'fixture-b');
    expect((await exact)?.id, 'fixture-a');
    expect(reads, 1);
  });

  test('reentrant source sees the already registered pending read', () async {
    late LocalReadingRepository repository;
    Future<List<ReadingPassage>>? reentrant;
    var reads = 0;
    repository = LocalReadingRepository(
      read: () {
        reads++;
        reentrant = repository.load(PreviewLevel.n4);
        return Future.value(catalog([row()]));
      },
    );
    expect((await repository.load(PreviewLevel.n5)).single.id, 'fixture-a');
    expect(await reentrant, isEmpty);
    expect(reads, 1);
  });

  test(
    'source faults are fixed safe errors and only explicit loads retry',
    () async {
      var reads = 0;
      final repository = LocalReadingRepository(
        read: () {
          reads++;
          if (reads == 1) throw StateError('PRIVATE path/token/source');
          return Future.value(catalog([row()]));
        },
      );
      await expectLater(
        repository.load(PreviewLevel.n5),
        throwsA(failure(ReadingLoadFailure.unavailable)),
      );
      expect(reads, 1);
      expect(
        const ReadingLoadException(ReadingLoadFailure.unavailable).toString(),
        'Reading material unavailable',
      );
      expect((await repository.load(PreviewLevel.n5)).single.id, 'fixture-a');
      expect(reads, 2);
    },
  );

  test(
    'malformed hidden level and oversized source are safely rejected',
    () async {
      var source = catalog([
        row(),
        {...row(id: 'hidden', level: 'N4'), 'questions': []},
      ]);
      final repository = LocalReadingRepository(read: () async => source);
      await expectLater(
        repository.load(PreviewLevel.n5),
        throwsA(failure(ReadingLoadFailure.invalidMaterial)),
      );
      source = 'PRIVATE invalid JSON';
      await expectLater(
        repository.load(PreviewLevel.n5),
        throwsA(failure(ReadingLoadFailure.invalidMaterial)),
      );
      source = 'あ' * 90000;
      await expectLater(
        repository.load(PreviewLevel.n5),
        throwsA(failure(ReadingLoadFailure.invalidMaterial)),
      );
      source = catalog([row()]);
      expect((await repository.load(PreviewLevel.n5)).single.id, 'fixture-a');
    },
  );

  test(
    'JSON formatting and member order keep the identical accepted object',
    () async {
      final original = row();
      var source = catalog([original]);
      final repository = LocalReadingRepository(read: () async => source);
      final first = (await repository.load(PreviewLevel.n5)).single;
      final reversed = Map<String, Object?>.fromEntries(
        original.entries.toList().reversed,
      );
      source = const JsonEncoder.withIndent('  ').convert({
        'passages': [reversed],
        'schema_version': 1,
      });
      expect((await repository.load(PreviewLevel.n5)).single, same(first));
    },
  );

  test(
    'every displayed and answer field is fenced for the same version',
    () async {
      final mutations = <void Function(Map<String, Object?>)>[
        (r) => r['title_ja'] = '勉強',
        (r) => r['title_vi'] = 'Đã thay đổi',
        (r) => r['text_ja'] = '新聞を読みます。',
        (r) => r['reading_ja'] = 'しんぶんをよみます。',
        (r) => r['translation_vi'] = 'Tôi đọc báo.',
        (r) => r['source_note_vi'] = 'Changed attribution',
        (r) => question(r)['id'] = 'q2',
        (r) => question(r)['prompt_ja'] = 'いつ読みますか。',
        (r) => question(r)['reading_ja'] = 'いつよみますか。',
        (r) => question(r)['prompt_vi'] = 'Đọc khi nào?',
        (r) => question(r)['correct_choice_id'] = 'b',
        (r) => question(r)['explanation_vi'] = 'Changed explanation',
        (r) => choices(r).first['id'] = 'c',
        (r) => choices(r).last['text_ja'] = '手紙',
        (r) => choices(r).last['reading_ja'] = 'てがみ',
        (r) => choices(r).last['text_vi'] = 'Thư',
        (r) => question(r)['choices'] = choices(r).reversed.toList(),
      ];
      for (final mutate in mutations) {
        var source = catalog([row()]);
        final repository = LocalReadingRepository(read: () async => source);
        final first = (await repository.load(PreviewLevel.n5)).single;
        final changed = row();
        mutate(changed);
        // Keep the changed choice-ID case structurally valid.
        if (choices(changed).first['id'] == 'c') {
          question(changed)['correct_choice_id'] = 'c';
        }
        source = catalog([changed]);
        await expectLater(
          repository.load(PreviewLevel.n5),
          throwsA(failure(ReadingLoadFailure.versionConflict)),
        );
        source = catalog([row()]);
        expect((await repository.load(PreviewLevel.n5)).single, same(first));
      }
    },
  );

  test(
    'new versions are accepted without changing a captured old round',
    () async {
      var source = catalog([row()]);
      final repository = LocalReadingRepository(read: () async => source);
      final first = (await repository.load(PreviewLevel.n5)).single;
      final round = ReadingRound(first);
      source = catalog([row(version: 2, title: '勉強')]);
      final second = (await repository.load(PreviewLevel.n5)).single;
      expect(second.snapshotKey, 'n5/fixture-a/2');
      expect(round.passage, same(first));
      expect(round.passage.titleJa, '読書');
      expect(round.answer(second.snapshotKey, 'q1', 'a'), isFalse);
      expect(round.answer(first.snapshotKey, 'q1', 'a'), isTrue);
      expect(await repository.find(PreviewLevel.n5, 'fixture-a', 1), isNull);
      source = catalog([row()]);
      await expectLater(
        repository.load(PreviewLevel.n5),
        throwsA(failure(ReadingLoadFailure.versionConflict)),
      );
    },
  );

  test(
    'passage order may change but question order needs a new version',
    () async {
      final original = row();
      original['questions'] = [
        question(original),
        {...question(original), 'id': 'q2'},
      ];
      final other = row(id: 'fixture-b');
      var source = catalog([original, other]);
      final repository = LocalReadingRepository(read: () async => source);
      final first = await repository.load(PreviewLevel.n5);
      source = catalog([other, original]);
      final reordered = await repository.load(PreviewLevel.n5);
      expect(reordered.first, same(first.last));
      expect(reordered.last, same(first.first));
      final changed = {
        ...original,
        'questions': (original['questions']! as List<Map<String, Object?>>)
            .reversed
            .toList(),
      };
      source = catalog([changed, other]);
      await expectLater(
        repository.load(PreviewLevel.n5),
        throwsA(failure(ReadingLoadFailure.versionConflict)),
      );
    },
  );

  test('ID cannot move levels even with an increased version', () async {
    var source = catalog([row()]);
    final repository = LocalReadingRepository(read: () async => source);
    await repository.load(PreviewLevel.n5);
    source = catalog([row(level: 'N4', version: 2)]);
    await expectLater(
      repository.load(PreviewLevel.n4),
      throwsA(failure(ReadingLoadFailure.versionConflict)),
    );
  });

  test(
    'rejected catalogs publish none of their otherwise valid changes',
    () async {
      var source = catalog([row(), row(id: 'fixture-b', level: 'N4')]);
      final repository = LocalReadingRepository(read: () async => source);
      final first = (await repository.load(PreviewLevel.n5)).single;
      source = catalog([
        row(version: 2),
        row(id: 'fixture-b', level: 'N4', title: '勉強'),
      ]);
      await expectLater(
        repository.load(PreviewLevel.n5),
        throwsA(failure(ReadingLoadFailure.versionConflict)),
      );
      source = catalog([row(), row(id: 'fixture-b', level: 'N4')]);
      expect((await repository.load(PreviewLevel.n5)).single, same(first));
    },
  );

  test(
    'empty or removed entries are not returned as stale offline success',
    () async {
      var source = catalog([row(version: 2)]);
      final repository = LocalReadingRepository(read: () async => source);
      final first = (await repository.load(PreviewLevel.n5)).single;
      source = catalog([]);
      expect(await repository.load(PreviewLevel.n5), isEmpty);
      expect(await repository.find(PreviewLevel.n5, 'fixture-a', 2), isNull);
      source = catalog([row()]);
      await expectLater(
        repository.load(PreviewLevel.n5),
        throwsA(failure(ReadingLoadFailure.versionConflict)),
      );
      source = catalog([row(version: 2)]);
      expect((await repository.load(PreviewLevel.n5)).single, same(first));
    },
  );

  test(
    'lifetime identity bound rejects churn without evicting old fences',
    () async {
      final rows = List.generate(50, (i) => row(id: 'fixture-$i'));
      var source = catalog(rows);
      final repository = LocalReadingRepository(read: () async => source);
      final first = await repository.load(PreviewLevel.n5);
      expect(first, hasLength(50));
      source = catalog([row(id: 'new-id')]);
      await expectLater(
        repository.load(PreviewLevel.n5),
        throwsA(failure(ReadingLoadFailure.versionConflict)),
      );
      source = catalog(rows);
      expect((await repository.load(PreviewLevel.n5)).first, same(first.first));
    },
  );

  test(
    'timed out source cannot publish late results over a later load',
    () async {
      final lateSource = Completer<String>();
      var reads = 0;
      final repository = LocalReadingRepository(
        read: () =>
            ++reads == 1 ? lateSource.future : Future.value(catalog([row()])),
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        repository.load(PreviewLevel.n5),
        throwsA(failure(ReadingLoadFailure.unavailable)),
      );
      final first = (await repository.load(PreviewLevel.n5)).single;
      lateSource.complete(catalog([row(version: 10)]));
      // The source future has settled before the next explicit read starts.
      await lateSource.future;
      expect((await repository.load(PreviewLevel.n5)).single, same(first));
      expect(reads, 3);
    },
  );

  test(
    'late loader errors are consumed and never expose raw exceptions',
    () async {
      final lateSource = Completer<String>();
      var reads = 0;
      final repository = LocalReadingRepository(
        read: () =>
            ++reads == 1 ? lateSource.future : Future.value(catalog([])),
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        repository.load(PreviewLevel.n5),
        throwsA(failure(ReadingLoadFailure.unavailable)),
      );
      lateSource.completeError(StateError('PRIVATE'));
      expect(await repository.load(PreviewLevel.n5), isEmpty);
    },
  );

  test('timeout policy rejects invalid bounds', () {
    for (final timeout in [
      Duration.zero,
      const Duration(milliseconds: -1),
      const Duration(seconds: 16),
    ]) {
      expect(
        () => LocalReadingRepository(
          read: () async => catalog([]),
          timeout: timeout,
        ),
        throwsArgumentError,
      );
    }
  });
}

Map<String, Object?> question(Map<String, Object?> value) =>
    (value['questions']! as List<Map<String, Object?>>).single;
List<Map<String, Object?>> choices(Map<String, Object?> value) =>
    question(value)['choices']! as List<Map<String, Object?>>;
