// Real native files, synthetic reports; no hosted/Auth or hardware durability proof.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/data/grammar_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/data/native_grammar_quiz_journal.dart';
import 'package:nihongo_daily/features/quiz/domain/grammar_quiz_attempt.dart';

const ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
String event(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
GrammarQuizAttempt attempt(int n) => GrammarQuizAttempt.fromJson({
  'format_version': 1,
  'quiz_type': 'grammar_meaning',
  'practice_kind': n.isEven ? 'primary' : 'correction',
  'event_id': event(n),
  'level': n.isEven ? 'N5' : 'N4',
  'completed_at': '2026-10-29T22:00:00.000Z',
  'answers': [
    {
      'item_id': event(900),
      'content_version': 1,
      'selected_id': event(n.isEven ? 900 : 901),
      'choices': [for (var i = 900; i < 904; i++) event(i)],
    },
  ],
});
String line(String owner, GrammarQuizAttempt value) =>
    jsonEncode({'version': 1, 'owner_id': owner, 'attempt': value.toJson()});

void main() {
  late Directory directory;
  late NativeGrammarQuizJournal journal;
  late File data;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nd-grammar-journal-');
    journal = await NativeGrammarQuizJournal.open(directory);
    data = File('${directory.path}/grammar-quiz-attempts.ndjson');
  });
  tearDown(() async {
    await journal.close();
    await directory.delete(recursive: true);
  });

  test(
    'grammar journal isolates owners and restores exact primary correction reports',
    () async {
      final primary = attempt(0);
      final correction = attempt(1);
      await journal.append(ownerA, primary);
      await journal.append(ownerA, correction);
      await journal.append(ownerB, primary);
      final before = await data.readAsBytes();
      await journal.close();
      journal = await NativeGrammarQuizJournal.open(directory);
      final a = await journal.list(ownerA);
      final b = await journal.list(ownerB);
      expect(a, hasLength(2));
      expect(b, hasLength(1));
      expect(a.every((r) => r.ownerId == ownerA), isTrue);
      expect(b.single.ownerId, ownerB);
      expect(sameGrammarQuizAttempt(a[0].attempt, primary), isTrue);
      expect(sameGrammarQuizAttempt(a[1].attempt, correction), isTrue);
      expect(a.map((r) => r.attempt.score).toList(), [1, 0]);
      expect(await data.readAsBytes(), before);
      expect(() => a.clear(), throwsUnsupportedError);
    },
  );

  test(
    'grammar journal exact replay writes once and changed record conflicts',
    () async {
      final original = attempt(0);
      await journal.append(ownerA, original);
      final bytes = await data.readAsBytes();
      final replay = await journal.append(
        ownerA,
        GrammarQuizAttempt.fromJson(original.toJson()),
      );
      expect(sameGrammarQuizAttempt(replay.attempt, original), isTrue);
      expect(await data.readAsBytes(), bytes);
      for (final field in ['practice_kind', 'completed_at', 'level']) {
        final json = original.toJson();
        json[field] = switch (field) {
          'practice_kind' => 'correction',
          'completed_at' => '2026-10-29T22:00:01.000Z',
          _ => 'N4',
        };
        await expectLater(
          journal.append(ownerA, GrammarQuizAttempt.fromJson(json)),
          throwsA(isA<GrammarQuizHistoryConflict>()),
        );
        expect(await data.readAsBytes(), bytes);
      }
      expect(await journal.list(ownerA), hasLength(1));
      await journal.append(ownerA, attempt(1));
      expect(await journal.list(ownerA), hasLength(2));
    },
  );

  test(
    'grammar journal drains accepted writes and rejects new work after close',
    () async {
      final writes = [
        for (var i = 0; i < 8; i++) journal.append(ownerA, attempt(i)),
      ];
      final closing = journal.close();
      await expectLater(
        journal.append(ownerA, attempt(9)),
        throwsA(isA<GrammarQuizStorageFailure>()),
      );
      await Future.wait(writes);
      await closing;
      await journal.close();
      await expectLater(
        journal.list(ownerA),
        throwsA(isA<GrammarQuizStorageFailure>()),
      );
      journal = await NativeGrammarQuizJournal.open(directory);
      expect(await journal.list(ownerA), hasLength(8));
    },
  );

  test(
    'grammar journal same-directory lease rejects second writer without damage',
    () async {
      await journal.append(ownerA, attempt(0));
      final bytes = await data.readAsBytes();
      await expectLater(
        NativeGrammarQuizJournal.open(directory),
        throwsA(isA<GrammarQuizStorageFailure>()),
      );
      expect(await data.readAsBytes(), bytes);
      await journal.append(ownerA, attempt(1));
      await journal.close();
      journal = await NativeGrammarQuizJournal.open(directory);
      expect(await journal.list(ownerA), hasLength(2));
    },
  );

  test(
    'grammar journal removes only incomplete EOF after valid committed lines',
    () async {
      await journal.append(ownerA, attempt(0));
      final bytes = await data.readAsBytes();
      await journal.close();
      await data.writeAsString(
        '{TEST ONLY incomplete',
        mode: FileMode.append,
        flush: true,
      );
      journal = await NativeGrammarQuizJournal.open(directory);
      expect(await data.readAsBytes(), bytes);
      expect(await journal.list(ownerA), hasLength(1));
      await journal.append(ownerA, attempt(1));
      expect(await journal.list(ownerA), hasLength(2));
    },
  );

  test(
    'grammar journal preserves corrupt complete lines and releases failed-open lease',
    () async {
      await journal.close();
      final canonical = line(ownerA, attempt(0));
      final vocabulary = attempt(0).toJson()
        ..remove('quiz_type')
        ..remove('practice_kind');
      for (final invalid in [
        '{}',
        ' $canonical',
        jsonEncode({'version': 1, 'owner_id': ownerA, 'attempt': vocabulary}),
        '$canonical\n${line(ownerA, GrammarQuizAttempt.fromJson(attempt(0).toJson()..['practice_kind'] = 'correction'))}',
      ]) {
        await data.writeAsString('$invalid\nTEST ONLY incomplete', flush: true);
        final bytes = await data.readAsBytes();
        await expectLater(
          NativeGrammarQuizJournal.open(directory),
          throwsA(isA<GrammarQuizStorageFailure>()),
        );
        expect(await data.readAsBytes(), bytes);
      }
      await data.writeAsString('$canonical\n', flush: true);
      journal = await NativeGrammarQuizJournal.open(directory);
      expect(await journal.list(ownerA), hasLength(1));
    },
  );

  test(
    'grammar journal enforces file and event caps without modifying committed bytes',
    () async {
      await journal.close();
      await data.writeAsBytes(
        List.filled(NativeGrammarQuizJournal.maxBytes + 1, 32),
        flush: true,
      );
      final oversized = await data.readAsBytes();
      await expectLater(
        NativeGrammarQuizJournal.open(directory),
        throwsA(isA<GrammarQuizStorageFailure>()),
      );
      expect(await data.readAsBytes(), oversized);
      final committed =
          [
            for (var i = 0; i < NativeGrammarQuizJournal.maxEvents; i++)
              line(ownerA, attempt(i)),
          ].join('\n') +
          '\n';
      await data.writeAsString(committed, flush: true);
      journal = await NativeGrammarQuizJournal.open(directory);
      expect(
        await journal.list(ownerA),
        hasLength(NativeGrammarQuizJournal.maxEvents),
      );
      await expectLater(
        journal.append(ownerA, attempt(700)),
        throwsA(isA<GrammarQuizStorageFailure>()),
      );
      expect(await data.readAsString(), committed);
      await journal.close();
      await data.writeAsString(
        '${line(ownerA, attempt(700))}\n',
        mode: FileMode.append,
        flush: true,
      );
      final overflow = await data.readAsBytes();
      await expectLater(
        NativeGrammarQuizJournal.open(directory),
        throwsA(isA<GrammarQuizStorageFailure>()),
      );
      expect(await data.readAsBytes(), overflow);
    },
  );

  test(
    'grammar journal rejects malformed owner without leaking or appending',
    () async {
      final before = await data.readAsBytes();
      for (final owner in [
        'TEST ONLY PRIVATE OWNER',
        ownerA.toUpperCase(),
        '',
      ]) {
        await expectLater(
          journal.list(owner),
          throwsA(isA<GrammarQuizStorageFailure>()),
        );
        await expectLater(
          journal.append(owner, attempt(0)),
          throwsA(isA<GrammarQuizStorageFailure>()),
        );
        expect(await data.readAsBytes(), before);
      }
      expect(
        const GrammarQuizStorageFailure().toString(),
        isNot(contains('TEST ONLY')),
      );
      await journal.append(ownerA, attempt(0));
      expect(await journal.list(ownerA), hasLength(1));
    },
  );
  test(
    'grammar journal rejects data and lock links without changing their targets',
    () async {
      await journal.append(ownerA, attempt(0));
      await journal.close();
      for (final name in [
        'grammar-quiz-attempts.ndjson',
        'grammar-quiz-attempts.lock',
      ]) {
        final path = '${directory.path}/$name';
        final target = File('$path.backup');
        await File(path).rename(target.path);
        final bytes = await target.readAsBytes();
        final link = Link(path);
        await link.create(target.path);
        try {
          await expectLater(
            NativeGrammarQuizJournal.open(directory),
            throwsA(isA<GrammarQuizStorageFailure>()),
          );
          expect(await target.readAsBytes(), bytes);
        } finally {
          await link.delete();
          await target.rename(path);
        }
      }
      journal = await NativeGrammarQuizJournal.open(directory);
      expect(await journal.list(ownerA), hasLength(1));
    },
  );
}
