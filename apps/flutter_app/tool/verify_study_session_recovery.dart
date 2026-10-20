import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../test/features/daily_plan/study_session_recovery_fixtures.dart';
import '../test/features/daily_plan/srs_session_recorder_fixtures.dart';
import 'package:nihongo_daily/features/daily_plan/data/native_study_session_journal.dart';
import 'package:nihongo_daily/features/daily_plan/data/durable_study_session_repository.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    if (args[0] == 'stage') {
      final journal = await NativeStudySessionJournal.open(Directory(args[1]));
      await journal.stage(studyOwner, studyEvent());
      stdout.writeln('FLUSHED');
      exit(0); // Deliberately no graceful close.
    }
    stdout.writeln('OPENING');
    try {
      final journal = await NativeStudySessionJournal.open(Directory(args[1]));
      stdout.writeln('ACQUIRED');
      await journal.close();
      exit(0);
    } on StudySessionStorageFailure {
      exit(73);
    }
  }
  for (final scenario in studyRecoveryScenarios) {
    await verifyStudyRecovery(scenario);
    stdout.writeln('PASS completed-study $scenario');
  }
  for (final scenario in recorderScenarios) {
    await verifyRecorder(scenario);
    stdout.writeln('PASS SRS session recorder $scenario');
  }
  final directory = await Directory.systemTemp.createTemp('nd-study-process-');
  NativeStudySessionJournal? journal;
  Process? child;
  try {
    final script = Platform.script.toFilePath();
    final staged = await Process.run(Platform.resolvedExecutable, [
      script,
      'stage',
      directory.path,
    ]);
    checkStudy(
      staged.exitCode == 0 && staged.stdout.toString().contains('FLUSHED'),
      'Child did not flush before abrupt exit',
    );
    journal = await NativeStudySessionJournal.open(directory);
    checkStudy(
      sameStudyEvent(
        (await journal.list(studyOwner)).single.event,
        studyEvent(),
      ),
      'Cross-process restart changed pending event',
    );
    child = await Process.start(Platform.resolvedExecutable, [
      script,
      'lock',
      directory.path,
    ]);
    final opening = Completer<void>();
    var acquired = false;
    final output = child.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line == 'OPENING' && !opening.isCompleted) opening.complete();
          if (line == 'ACQUIRED') acquired = true;
        });
    final errors = child.stderr.drain<void>();
    await opening.future.timeout(const Duration(seconds: 10));
    final outcome = await Future.any<int?>([
      child.exitCode.then<int?>((code) => code),
      Future<int?>.delayed(const Duration(milliseconds: 250), () => null),
    ]);
    checkStudy(
      !acquired && (outcome == null || outcome == 73),
      'Second process acquired active lease',
    );
    if (outcome == null) child.kill();
    await child.exitCode;
    await output.cancel();
    await errors;
    child = null;
    await journal.close();
    journal = null;
    final reopened = await Process.run(Platform.resolvedExecutable, [
      script,
      'lock',
      directory.path,
    ]);
    checkStudy(
      reopened.exitCode == 0 && reopened.stdout.toString().contains('ACQUIRED'),
      'Closed lease not released across process',
    );
    stdout.writeln(
      'PASS completed-study abrupt process restart and exclusive lease',
    );
  } finally {
    if (child != null) {
      child.kill();
      await child.exitCode;
    }
    await journal?.close();
    await directory.delete(recursive: true);
  }
}
