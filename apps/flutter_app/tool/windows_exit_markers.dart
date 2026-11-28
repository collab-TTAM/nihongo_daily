// TEST ONLY fixture IPC. Never used by the application or learner persistence.
import 'dart:io';

const exitMarkerPayload = 'TEST_ONLY_EXIT_MARKER';

/// Publish only a closed, flushed, exact marker in the same directory.
/// One fixture writer per target; not a general concurrent journal/CAS primitive.
Future<void> publishExitMarker(
  File target, {
  Future<void> Function(File)? writePending,
}) async {
  final pending = File('${target.path}.publishing');
  try {
    if (writePending == null) {
      await pending.writeAsString(exitMarkerPayload, flush: true);
    } else {
      await writePending(pending);
    }
    if (await pending.readAsString() != exitMarkerPayload) {
      throw const FormatException('Exit fixture marker payload invalid');
    }
    await pending.rename(target.path);
  } finally {
    if (await pending.exists()) {
      await pending.delete();
    }
  }
}
