// TEST ONLY executable entrypoint; never packaged as the learner preview.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nihongo_daily/features/auth/data/windows_session_credential_vault.dart';
import 'windows_runtime_fixture.dart';

void require(bool value) {
  if (!value) {
    throw const FormatException('Bridge verification failed');
  }
}

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Display a frame so this exercises the real runner/engine, not mock channels.
  runApp(
    const Directionality(textDirection: TextDirection.ltr, child: SizedBox()),
  );
  try {
    require(Platform.isWindows && arguments.length == 2);
    final phase = arguments[0];
    final scope = arguments[1];
    require(RegExp(r'^bridge-[a-f0-9]{32}$').hasMatch(scope));
    require(
      const {'write', 'reopen', 'rotated', 'clear', 'absent'}.contains(phase) ||
          runtimePhases.contains(phase),
    );
    final vault = createWindowsSessionCredentialVault('https://$scope.invalid');
    final other = createWindowsSessionCredentialVault(
      'https://$scope-other.invalid',
    );
    // Fixed synthetic values only. No service or learner credential is accepted.
    const first = 'TEST_ONLY_bridge_first';
    const rotated = 'TEST_ONLY_bridge_rotated';
    if (runtimePhases.contains(phase)) {
      await verifyWindowsRuntimePhase(phase, scope);
    }
    switch (phase) {
      case 'write':
        require(await vault.readRefreshToken() == null);
        require(await other.readRefreshToken() == null);
        await vault.writeRefreshToken(first);
        require(await vault.readRefreshToken() == first);
        require(await other.readRefreshToken() == null);
      case 'reopen':
        require(await vault.readRefreshToken() == first);
        await vault.writeRefreshToken(rotated);
        require(await vault.readRefreshToken() == rotated);
        require(await other.readRefreshToken() == null);
      case 'rotated':
        require(await vault.readRefreshToken() == rotated);
        require(await other.readRefreshToken() == null);
      case 'clear':
        // Also used by finally cleanup; delete only this invocation's CI scope.
        await vault.clear();
        await other.clear();
        require(await vault.readRefreshToken() == null);
        await vault.clear();
        final directory = runtimeFixtureDirectory(scope);
        if (await directory.exists()) await directory.delete(recursive: true);
      case 'absent':
        require(await vault.readRefreshToken() == null);
        require(await other.readRefreshToken() == null);
    }
    stdout.writeln('Windows Dart/native bridge phase passed');
    exit(0);
  } on Object {
    // Never emit native exception details or credential data.
    stderr.writeln('Windows Dart/native bridge verification failed');
    exit(1);
  }
}
