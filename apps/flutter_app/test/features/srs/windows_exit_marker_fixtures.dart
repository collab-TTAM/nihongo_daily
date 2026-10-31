// TEST ONLY real disposable file I/O. Not evidence of actual Windows OS exit.
import 'dart:async';
import 'dart:io';
import '../../../tool/windows_exit_markers.dart';

void checkExitMarker(bool value, String detail) {
  if (!value) throw StateError(detail);
}

final exitMarkerScenarios = <String, Future<void> Function(Directory)>{
  'new': (directory) async {
    final target = File('${directory.path}/ready');
    final created = Completer<File>();
    final finish = Completer<void>();
    final writing = publishExitMarker(
      target,
      writePending: (pending) async {
        await pending.writeAsString('', flush: true);
        created.complete(pending);
        await finish.future;
        await pending.writeAsString(exitMarkerPayload, flush: true);
      },
    );
    try {
      final pending = await created.future;
      checkExitMarker(await pending.exists(), 'Stage not created');
      checkExitMarker(await pending.length() == 0, 'Expected held empty stage');
      checkExitMarker(
        !await target.exists(),
        'Final visible before completed write',
      );
    } finally {
      finish.complete();
      await writing;
    }
    checkExitMarker(
      await target.readAsString() == exitMarkerPayload,
      'Published payload differs',
    );
    checkExitMarker(
      !await File('${target.path}.publishing').exists(),
      'Stage retained after publish',
    );
  },
  'repeat': (directory) async {
    final target = File('${directory.path}/closing');
    await publishExitMarker(target);
    final created = Completer<void>();
    final finish = Completer<void>();
    final writing = publishExitMarker(
      target,
      writePending: (pending) async {
        await pending.writeAsString('TEST_ONLY_', flush: true);
        created.complete();
        await finish.future;
        await pending.writeAsString(exitMarkerPayload, flush: true);
      },
    );
    try {
      await created.future;
      checkExitMarker(
        await target.readAsString() == exitMarkerPayload,
        'Repeat truncated previous marker',
      );
    } finally {
      finish.complete();
      await writing;
    }
    checkExitMarker(
      await target.readAsString() == exitMarkerPayload,
      'Repeat payload differs',
    );
  },
  'invalid': (directory) async {
    final target = File('${directory.path}/canceled');
    var rejected = false;
    try {
      await publishExitMarker(
        target,
        writePending: (pending) async {
          await pending.writeAsString('BAD', flush: true);
        },
      );
    } on FormatException {
      rejected = true;
    }
    checkExitMarker(rejected, 'Invalid marker accepted');
    checkExitMarker(!await target.exists(), 'Invalid final published');
    checkExitMarker(
      !await File('${target.path}.publishing').exists(),
      'Invalid stage retained',
    );
  },
  'failed-write': (directory) async {
    final target = File('${directory.path}/done');
    var rejected = false;
    try {
      await publishExitMarker(
        target,
        writePending: (pending) async {
          await pending.writeAsString('PARTIAL', flush: true);
          throw StateError('TEST ONLY WRITE FAILURE');
        },
      );
    } on StateError {
      rejected = true;
    }
    checkExitMarker(rejected, 'Write failure swallowed');
    checkExitMarker(!await target.exists(), 'Failed write published');
    checkExitMarker(
      !await File('${target.path}.publishing').exists(),
      'Failed stage retained',
    );
  },
};

Future<void> runExitMarkerScenario(String name) async {
  final directory = await Directory.systemTemp.createTemp('nd-exit-marker-');
  try {
    await exitMarkerScenarios[name]!(directory);
  } finally {
    await directory.delete(recursive: true);
  }
}
