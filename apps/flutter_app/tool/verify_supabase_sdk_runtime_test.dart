// TEST ONLY: run the caller-owned SDK probe through Flutter's package graph.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'verify_supabase_sdk_runtime.dart' as probe;

void main() {
  test('local Supabase SDK runtime restores and isolates accounts', () async {
    final inputPath =
        Platform.environment['NIHONGO_SUPABASE_SDK_RUNTIME_INPUT_FILE'];
    if (inputPath == null || inputPath.isEmpty) {
      fail('local Supabase SDK runtime input file is required');
    }
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      fail('local Supabase SDK runtime input file is missing');
    }
    final status = await probe.runSupabaseSdkRuntimeProbe(
      await inputFile.readAsString(),
    );
    print(status);
    expect(status, 'LOCAL_SUPABASE_SDK_RUNTIME_OK');
  });
}
