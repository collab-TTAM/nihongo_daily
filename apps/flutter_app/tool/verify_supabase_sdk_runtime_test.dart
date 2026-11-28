// TEST ONLY: run the caller-owned SDK probe through Flutter's package graph.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'verify_supabase_sdk_runtime.dart' as probe;

void main() {
  group('local Supabase SDK probe API origin', () {
    test('accepts a dynamically selected high loopback port', () {
      expect(
        probe.parseLocalSupabaseProbeApiUrl('http://127.0.0.1:39589'),
        Uri.parse('http://127.0.0.1:39589'),
      );
    });

    test('accepts the original default loopback port', () {
      expect(
        probe.parseLocalSupabaseProbeApiUrl('http://127.0.0.1:54321'),
        Uri.parse('http://127.0.0.1:54321'),
      );
    });

    test('normalizes an optional root path', () {
      expect(
        probe.parseLocalSupabaseProbeApiUrl('http://127.0.0.1:39589/'),
        Uri.parse('http://127.0.0.1:39589'),
      );
    });

    for (final invalid in [
      'https://127.0.0.1:39589',
      'http://localhost:39589',
      'http://192.0.2.1:39589',
      'http://user@127.0.0.1:39589',
      'http://127.0.0.1:39589/rest/v1',
      'http://127.0.0.1:39589?query=1',
      'http://127.0.0.1:39589#fragment',
      'http://127.0.0.1:80',
      'http://127.0.0.1:65536',
      'http://127.0.0.1',
    ]) {
      test('rejects untrusted or invalid origin: $invalid', () {
        expect(
          () => probe.parseLocalSupabaseProbeApiUrl(invalid),
          throwsA(isA<FormatException>()),
        );
      });
    }
  });

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
    stdout.writeln(status);
    expect(status, 'LOCAL_SUPABASE_SDK_RUNTIME_OK');
  });
}
