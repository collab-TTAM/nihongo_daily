import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'session_credential_vault.dart';

/// Explicit assembly only. Web/mobile/Linux/macOS fail closed without fallback.
SessionCredentialVault createWindowsSessionCredentialVault(String projectUrl) =>
    SessionCredentialVault(
      projectUrl: projectUrl,
      backend: const _WindowsCredentialBackend(),
    );

final class _WindowsCredentialBackend implements SessionCredentialBackend {
  const _WindowsCredentialBackend();
  static const _channel = MethodChannel('nihongo_daily/session_vault_v1');
  @override
  Future<Object?> invoke(String method, Map<String, Object> arguments) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      throw const SessionVaultFailure(SessionVaultError.unavailable);
    }
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on Object {
      // Never forward platform exception messages/details or secret arguments.
      throw const SessionVaultFailure(SessionVaultError.unavailable);
    }
  }
}
