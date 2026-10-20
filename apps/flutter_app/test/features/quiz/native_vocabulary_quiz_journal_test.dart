import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/quiz/data/native_vocabulary_quiz_journal.dart';
import 'package:nihongo_daily/features/quiz/data/vocabulary_quiz_attempt_store.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_attempt.dart';
import 'package:nihongo_daily/features/quiz/domain/vocabulary_quiz_progress.dart';

import 'quiz_journal_fixtures.dart';

Future<void> quizProbe(String command, Directory directory) async {
  final executable = Platform.resolvedExecutable.replaceAll('\\', '/');
  final marker = executable.indexOf('/bin/cache/');
  final configuredRoot = Platform.environment['FLUTTER_ROOT'];
  final inferredRoot = marker < 0 ? null : executable.substring(0, marker);
  final root = configuredRoot ?? inferredRoot;
  if (root == null) throw StateError('Dart SDK is required for process tests');
  final suffix = Platform.isWindows ? '.exe' : '';
  final dart = '$root/bin/cache/dart-sdk/bin/dart$suffix';
  final child = await Process.start(dart, [
    'run',
    'test/features/quiz/quiz_journal_fixtures.dart',
    command,
    directory.path,
  ]);
  final output = child.stdout.drain<void>();
  final errors = child.stderr.drain<void>();
  try {
    final code = await child.exitCode.timeout(const Duration(seconds: 30));
    await Future.wait([output, errors]);
    expect(code, 0, reason: 'Native child process must verify $command');
  } on Object {
    child.kill();
    await child.exitCode;
    await Future.wait([output, errors]);
    rethrow;
  }
}

void main() {
  late Directory directory;
  NativeVocabularyQuizJournal? journal;

  Future<NativeVocabularyQuizJournal> open() async {
    final result = await NativeVocabularyQuizJournal.open(directory);
    journal = result;
    return result;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nihongo-quiz-');
  });

  tearDown(() async {
    await journal?.close();
    journal = null;
    await directory.delete(recursive: true);
  });

  test('flushed immutable reports survive close and reopen', () async {
    final store = await open();
    final first = quizReport(1);
    final saved = await store.append(quizOwner, first);
    final snapshot = await store.list(quizOwner);
    expect(sameVocabularyQuizAttempt(saved.attempt, first), isTrue);
    expect(snapshot.single.ownerId, quizOwner);
    expect(() => snapshot.clear(), throwsUnsupportedError);
    expect(
      () => snapshot.single.attempt.answers.clear(),
      throwsUnsupportedError,
    );
    await store.append(quizOwner, quizReport(2, correct: true));
    expect(snapshot, hasLength(1));
    await store.close();
    final restored = await open();
    final history = await restored.list(quizOwner);
    expect(history.map((r) => r.attempt.score), [0, 1]);
    expect(sameVocabularyQuizAttempt(history.first.attempt, first), isTrue);
    expect(await quizData(directory).readAsLines(), hasLength(2));
  });

  test('equal event IDs stay isolated across interleaved owners', () async {
    final store = await open();
    await store.append(quizOwner, quizReport(1));
    await store.append(quizOther, quizReport(1, correct: true));
    await store.append(quizOwner, quizReport(2));
    await store.close();
    final restored = await open();
    final first = await restored.list(quizOwner);
    final other = await restored.list(quizOther);
    expect(first, hasLength(2));
    expect(first.every((r) => r.ownerId == quizOwner), isTrue);
    expect(other.single.ownerId, quizOther);
    expect(other.single.attempt.score, 1);
    expect(first.first.attempt.score, 0);
    expect(
      () => deriveVocabularyQuizProgress(
        ownerId: quizOwner,
        level: first.first.attempt.level,
        source: [],
        history: [...first, ...other],
      ),
      throwsFormatException,
    );
  });

  test('concurrent identical replay writes one original record', () async {
    final store = await open();
    final event = quizReport(1);
    final saved = await Future.wait([
      for (var i = 0; i < 12; i++) store.append(quizOwner, event),
    ]);
    expect(saved.every((record) => identical(record, saved.first)), isTrue);
    expect(await store.list(quizOwner), hasLength(1));
    expect(await quizData(directory).readAsLines(), hasLength(1));
    final size = await quizData(directory).length();
    await store.close();
    final restored = await open();
    await restored.append(quizOwner, event);
    expect(await quizData(directory).length(), size);
  });

  test('conflicting queued replay preserves original and later work', () async {
    final store = await open();
    final first = store.append(quizOwner, quizReport(1));
    final conflict = expectLater(
      store.append(quizOwner, quizReport(1, correct: true)),
      throwsA(isA<VocabularyQuizHistoryConflict>()),
    );
    final next = store.append(quizOwner, quizReport(2));
    await first;
    await conflict;
    await next;
    expect(await store.list(quizOwner), hasLength(2));
    expect((await store.list(quizOwner)).first.attempt.score, 0);
    await store.close();
    final restored = await open();
    expect(await restored.list(quizOwner), hasLength(2));
    expect(await quizData(directory).readAsLines(), hasLength(2));
  });

  test('close drains accepted work and immediately rejects new work', () async {
    final store = await open();
    final first = store.append(quizOwner, quizReport(1));
    final second = store.append(quizOwner, quizReport(2));
    final listed = store.list(quizOwner);
    final closing = store.close();
    expect(identical(closing, store.close()), isTrue);
    await expectLater(
      store.append(quizOwner, quizReport(3)),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    await expectLater(
      store.list(quizOwner),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    await first;
    await second;
    expect(await listed, hasLength(2));
    await closing;
    final restored = await open();
    expect(await restored.list(quizOwner), hasLength(2));
  });

  test('only incomplete EOF bytes are repaired after validation', () async {
    final store = await open();
    final original = quizReport(1);
    await store.append(quizOwner, original);
    await store.close();
    final file = quizData(directory);
    final committed = await file.readAsBytes();
    await file.writeAsBytes(
      [123, 34, 112, 97, 114, 116, 105, 97, 108, 34, 58, 255],
      mode: FileMode.append,
      flush: true,
    );
    final restored = await open();
    final recovered = (await restored.list(quizOwner)).single;
    expect(recovered.attempt.eventId, original.eventId);
    expect(await file.readAsBytes(), committed);
    await restored.close();
    await file.writeAsString('{"incomplete":', flush: true);
    final empty = await open();
    expect(await empty.list(quizOwner), isEmpty);
    expect(await file.length(), 0);
  });

  test('complete corruption never deletes bytes or leaks raw errors', () async {
    final store = await open();
    await store.append(quizOwner, quizReport(1));
    await store.close();
    final file = quizData(directory);
    final good = await file.readAsString();
    final raw = jsonDecode(good.trim()) as Map<String, Object?>;
    final report = raw['attempt']! as Map<String, Object?>;
    final duplicated = jsonEncode(
      raw,
    ).replaceFirst('"version":1', '"version":1,"version":1');
    final invalid = <String>[
      '{"version":1,"version":1}\n',
      '${jsonEncode({...raw, 'version': 2})}\n',
      '${jsonEncode({...raw, 'version': 1.0})}\n',
      '${jsonEncode({...raw, 'owner_id': 'PRIVATE OWNER'})}\n',
      '${jsonEncode({...raw, 'extra': true})}\n',
      '${jsonEncode({...raw}..remove('owner_id'))}\n',
      '${jsonEncode({
        ...raw,
        'attempt': {...report, 'score': 99},
      })}\n',
      '${jsonEncode({...raw, 'attempt': null})}\n',
      '$duplicated\n',
      ' ${good.trim()}\n',
      '${good.trim()}\r\n',
      '\n',
      'PRIVATE CORRUPTION\n{"partial":',
    ];
    for (final bad in invalid) {
      await file.writeAsString('$good$bad', flush: true);
      final before = await file.readAsBytes();
      Object? failure;
      try {
        final unexpected = await NativeVocabularyQuizJournal.open(directory);
        await unexpected.close();
      } on Object catch (error) {
        failure = error;
      }
      expect(failure, isA<VocabularyQuizStorageFailure>());
      expect(failure.toString(), isNot(contains('PRIVATE')));
      expect(failure.toString(), isNot(contains(directory.path)));
      expect(await file.readAsBytes(), before);
    }
    // Failed restore must release both the OS lease and local ownership guard.
    await file.writeAsString(good, flush: true);
    expect(await (await open()).list(quizOwner), hasLength(1));
  });

  test('restore handles identical and conflicting disk replay', () async {
    final store = await open();
    await store.append(quizOwner, quizReport(1));
    await store.close();
    final file = quizData(directory);
    final good = await file.readAsString();
    await file.writeAsString('$good$good', flush: true);
    final restored = await open();
    expect(await restored.list(quizOwner), hasLength(1));
    await restored.close();
    final changed = jsonDecode(good.trim()) as Map<String, Object?>;
    changed['attempt'] = quizReport(1, correct: true).toJson();
    final bytes = '$good${jsonEncode(changed)}\n';
    await file.writeAsString(bytes, flush: true);
    await expectLater(
      NativeVocabularyQuizJournal.open(directory),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    expect(await file.readAsString(), bytes);
  });

  test('event capacity keeps every owner and permits exact replay', () async {
    final store = await open();
    for (var i = 1; i <= NativeVocabularyQuizJournal.maxEvents; i++) {
      await store.append(i.isEven ? quizOther : quizOwner, quizReport(i));
    }
    final file = quizData(directory);
    final before = await file.readAsBytes();
    await expectLater(
      store.append(quizOwner, quizReport(513)),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    await store.append(quizOwner, quizReport(1));
    await expectLater(
      store.append(quizOwner, quizReport(1, correct: true)),
      throwsA(isA<VocabularyQuizHistoryConflict>()),
    );
    expect(await file.readAsBytes(), before);
    await store.close();
    final restored = await open();
    expect(await restored.list(quizOwner), hasLength(256));
    expect(await restored.list(quizOther), hasLength(256));
    await restored.close();
    final extra = jsonEncode({
      'version': 1,
      'owner_id': quizOwner,
      'attempt': quizReport(513).toJson(),
    });
    await file.writeAsString('$extra\n', mode: FileMode.append, flush: true);
    final overflow = await file.readAsBytes();
    await expectLater(
      NativeVocabularyQuizJournal.open(directory),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    expect(await file.readAsBytes(), overflow);
  });

  test('byte bound keeps records on append or restore failure', () async {
    final store = await open();
    await store.append(quizOwner, quizReport(1));
    await store.close();
    final file = quizData(directory);
    final line = await file.readAsString();
    final rowBytes = utf8.encode(line).length;
    final count = NativeVocabularyQuizJournal.maxBytes ~/ rowBytes;
    await file.writeAsString(List.filled(count, line).join(), flush: true);
    final near = await file.readAsBytes();
    final restored = await open();
    await expectLater(
      restored.append(quizOwner, quizReport(2)),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    await restored.append(quizOwner, quizReport(1));
    expect(await restored.list(quizOwner), hasLength(1));
    expect(await file.readAsBytes(), near);
    await restored.close();
    await file.writeAsBytes(
      List.filled(NativeVocabularyQuizJournal.maxBytes + 1, 32),
      flush: true,
    );
    await expectLater(
      NativeVocabularyQuizJournal.open(directory),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    expect(await file.length(), NativeVocabularyQuizJournal.maxBytes + 1);
  });

  test('invalid owners and duplicate open preserve the writer', () async {
    final store = await open();
    await expectLater(
      NativeVocabularyQuizJournal.open(Directory('${directory.path}/.')),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    await expectLater(
      store.append('PRIVATE OWNER', quizReport(1)),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    await expectLater(
      store.list('PRIVATE OWNER'),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    await store.append(quizOwner, quizReport(1));
    expect(await store.list(quizOwner), hasLength(1));
    expect(await quizData(directory).readAsLines(), hasLength(1));
  });

  test('failed directory bootstrap is safe and recoverable', () async {
    final blocker = File('${directory.path}/blocked');
    await blocker.writeAsString('PRIVATE DATA', flush: true);
    final invalid = Directory(blocker.path);
    await expectLater(
      NativeVocabularyQuizJournal.open(invalid),
      throwsA(isA<VocabularyQuizStorageFailure>()),
    );
    expect(await blocker.readAsString(), 'PRIVATE DATA');
    await blocker.delete();
    final recovered = await NativeVocabularyQuizJournal.open(invalid);
    try {
      await recovered.append(quizOwner, quizReport(1));
      expect(await recovered.list(quizOwner), hasLength(1));
    } finally {
      await recovered.close();
    }
  });

  test(
    'separate processes retain flushed data and enforce active lease',
    () async {
      await quizProbe('stage', directory);
      final store = await open();
      final records = await store.list(quizOwner);
      expect(records.single.attempt.eventId, quizReport(1).eventId);
      await quizProbe('locked', directory);
      await store.append(quizOwner, quizReport(2));
      await store.close();
      await quizProbe(
        'stage',
        directory,
      ); // Exact restart replay does not append.
      final restored = await open();
      expect(await restored.list(quizOwner), hasLength(2));
      expect(await quizData(directory).readAsLines(), hasLength(2));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
