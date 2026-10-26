// TEST ONLY executable entrypoint; never packaged as the learner preview.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nihongo_daily/features/auth/data/windows_session_credential_vault.dart';
import 'windows_runtime_fixture.dart';
import 'windows_exit_fixture.dart';
import 'windows_receipt_fixture.dart';
import 'windows_receipt_lifecycle_fixture.dart';
import 'windows_sdk_receipt_fixture.dart';
import 'package:nihongo_daily/features/auth/data/windows_review_directory.dart';
import 'package:nihongo_daily/app/staging_bootstrap.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';

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
      const {
            'write',
            'reopen',
            'rotated',
            'clear',
            'absent',
            'directory-write',
            'directory-reopen',
            'directory-clear',
          }.contains(phase) ||
          runtimePhases.contains(phase) ||
          exitPhases.contains(phase) ||
          receiptPhases.contains(phase) ||
          receiptLifecyclePhases.contains(phase) ||
          sdkReceiptPhases.contains(phase),
    );
    if (exitPhases.contains(phase)) {
      await startWindowsExitFixture(phase, scope);
      return; // OS/framework close decides exit; no dart:io exit shortcut.
    }
    if (receiptPhases.contains(phase)) {
      await verifyWindowsReceiptPhase(phase, scope);
      stdout.writeln('Windows receipt Dart/native bridge phase passed');
      exit(0);
    }
    if (receiptLifecyclePhases.contains(phase)) {
      await verifyWindowsReceiptLifecyclePhase(phase, scope);
      stdout.writeln('Windows receipt lifecycle phase passed (TEST ONLY)');
      exit(0);
    }
    if (sdkReceiptPhases.contains(phase)) {
      await verifyWindowsSdkReceiptPhase(phase, scope);
      stdout.writeln(
        'Windows same SDK/profile receipt phase passed (TEST ONLY Auth/HTTP)',
      );
      exit(0);
    }
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
      case 'directory-write':
        final directory = await resolveWindowsReviewDirectory(
          'https://$scope.invalid',
        );
        final same = await resolveWindowsReviewDirectory(
          'https://$scope.invalid',
        );
        final isolated = await resolveWindowsReviewDirectory(
          'https://$scope-other.invalid',
        );
        require(directory.path == same.path && directory.path != isolated.path);
        require(!await directory.exists());
        await directory.create(recursive: true);
        await File(
          '${directory.path}${Platform.pathSeparator}probe.txt',
        ).writeAsString('TEST_ONLY_DIRECTORY_MARKER', flush: true);
        final owner = await openWindowsStagingOwner(
          StagingConfiguration(
            'https://$scope.invalid',
            'sb_publishable_TEST_ONLY_1234567890',
            false,
          ),
        );
        await owner.start();
        require(owner.account.readyRuntime == null);
        await owner.close();
        final reopened = await NativeReviewJournal.open(directory);
        await reopened.close();
      case 'directory-reopen':
        final directory = await resolveWindowsReviewDirectory(
          'https://$scope.invalid',
        );
        require(
          await File(
                '${directory.path}${Platform.pathSeparator}probe.txt',
              ).readAsString() ==
              'TEST_ONLY_DIRECTORY_MARKER',
        );
      case 'directory-clear':
        final directory = await resolveWindowsReviewDirectory(
          'https://$scope.invalid',
        );
        if (await directory.exists()) await directory.delete(recursive: true);
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
        final local = await resolveWindowsReviewDirectory(
          'https://$scope.invalid',
        );
        if (await local.exists()) await local.delete(recursive: true);
        final exitLocal = await resolveWindowsReviewDirectory(
          'https://$scope-exit.invalid',
        );
        if (await exitLocal.exists()) await exitLocal.delete(recursive: true);
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
