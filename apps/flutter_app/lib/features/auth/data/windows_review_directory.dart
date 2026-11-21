import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'session_credential_vault.dart';
import 'windows_session_credential_vault.dart';

Future<Directory> resolveWindowsReviewDirectory(String projectUrl) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
    throw const SessionVaultFailure(SessionVaultError.unavailable);
  }
  final target = createWindowsSessionCredentialVault(projectUrl).target;
  try {
    const channel = MethodChannel('nihongo_daily/session_vault_v1');
    final raw = await channel.invokeMethod<Object?>('reviewDirectory', {
      'target': target,
    });
    if (raw is! String ||
        raw.length > 1024 ||
        raw.contains('\u0000') ||
        !RegExp(r'^[A-Za-z]:\\').hasMatch(raw) ||
        raw.split('\\').contains('..') ||
        !RegExp(
          r'\\NihongoDaily\\ReviewJournal\\v1\\[a-f0-9]{64}$',
        ).hasMatch(raw)) {
      throw const SessionVaultFailure(SessionVaultError.corrupt);
    }
    return Directory(raw);
  } on Object {
    throw const SessionVaultFailure(SessionVaultError.unavailable);
  }
}
