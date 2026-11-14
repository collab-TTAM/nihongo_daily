// TEST ONLY real runner/OS close with an actual empty-vault staging owner.
// Fixed synthetic scope; no Auth HTTP, learner credential or production data.
import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:nihongo_daily/app/staging_bootstrap.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/application/account_startup_controller.dart';
import 'package:nihongo_daily/features/auth/data/windows_review_directory.dart';
import 'package:nihongo_daily/features/auth/data/windows_session_credential_vault.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'package:nihongo_daily/features/srs/application/srs_study_runtime.dart';
import 'package:nihongo_daily/features/srs/data/native_review_journal.dart';
import 'windows_runtime_fixture.dart';

const exitPhases = {'exit-drain', 'exit-cancel'};

void _check(bool value) {
  if (!value) throw const FormatException('Exit fixture verification failed');
}

Future<void> startWindowsExitFixture(String phase, String scope) async {
  _check(Platform.isWindows && exitPhases.contains(phase));
  final directory = runtimeFixtureDirectory(scope);
  await directory.create(recursive: true);
  final origin = 'https://$scope-exit.invalid';
  _check(
    await createWindowsSessionCredentialVault(origin).readRefreshToken() ==
        null,
  );
  final owner = await openWindowsStagingOwner(
    StagingConfiguration(origin, 'sb_publishable_TEST_ONLY_1234567890', false),
  );
  final probe = _ExitProbeOwner(owner, directory, origin, phase);
  final controller = AccountStartupController(() async => probe);
  probe.controller = controller;
  runApp(AccountStartupApp(controller: controller));
}

final class _ExitProbeOwner implements StagingOwner {
  _ExitProbeOwner(this.owner, this.directory, this.origin, this.phase);
  final StagingOwner owner;
  final Directory directory;
  final String origin;
  final String phase;
  late final AccountStartupController<AccountController<SrsStudyRuntime>>
  controller;
  int closes = 0;
  File marker(String name) =>
      File('${directory.path}${Platform.pathSeparator}$phase-$name');
  Future<void> mark(String name) =>
      marker(name).writeAsString('TEST_ONLY_EXIT_MARKER', flush: true);
  @override
  AccountController<SrsStudyRuntime> get account => owner.account;
  @override
  bool get canOfferLogin => owner.canOfferLogin;
  @override
  Future<void> start() async {
    await owner.start();
    _check(account.readyRuntime == null);
    await WidgetsBinding.instance.endOfFrame;
    await mark('ready');
  }

  @override
  Future<void> close() async {
    closes++;
    _check(controller.account == null);
    await mark('closing');
    if (phase == 'exit-cancel' && closes == 1) {
      await mark('canceled');
      throw const FormatException('TEST ONLY PRIVATE EXIT FAILURE');
    }
    while (!await marker('release').exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    await owner.close();
    // Normal close must release the actual native journal lease before exit.
    final appData = await resolveWindowsReviewDirectory(origin);
    final reopened = await NativeReviewJournal.open(appData);
    await reopened.close();
    _check(
      await createWindowsSessionCredentialVault(origin).readRefreshToken() ==
          null,
    );
    await mark('done');
  }
}
