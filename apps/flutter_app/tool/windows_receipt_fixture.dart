// TEST ONLY real runner/MethodChannel/Credential Manager fixture. No network.
import 'package:flutter/services.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/data/windows_conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/auth/data/windows_session_credential_vault.dart';

const receiptPhases = {
  'receipt-write',
  'receipt-reopen',
  'receipt-clear',
  'receipt-absent',
  'receipt-cleanup',
};
const _channel = MethodChannel('nihongo_daily/conversation_receipts_v1');
const _owner = 'a1000000-0000-4000-8000-000000000001';
const _otherOwner = 'a1000000-0000-4000-8000-000000000002';
const _event = 'b1000000-0000-4000-8000-000000000001';
const _nextEvent = 'b1000000-0000-4000-8000-000000000002';
const _authMarker = 'TEST_ONLY_receipt_auth_isolation';

void _require(bool value) {
  if (!value) {
    throw const FormatException('Receipt bridge verification failed');
  }
}

ConversationReceiptReference _reference(
  ConversationReceiptScope scope, [
  String event = _event,
]) => ConversationReceiptReference.fromStart(
  projectUrl: scope.projectOrigin,
  ownerId: scope.ownerId,
  request: StartConversationRequest(
    scenarioId: _owner,
    level: AiTextLevel.n5,
    clientEventId: event,
  ),
);

String _target(ConversationReceiptScope scope) =>
    '${ConversationReceiptStore.targetPrefix}${scope.projectOrigin}|${scope.ownerId}';

Future<void> _invalid(String method, Object? arguments) async {
  try {
    await _channel.invokeMethod<Object?>(method, arguments);
  } on PlatformException catch (error) {
    _require(
      error.code == 'receipt_storage_unavailable' &&
          error.message == 'Receipt storage unavailable' &&
          error.details == null,
    );
    return;
  }
  throw const FormatException('Invalid receipt operation was accepted');
}

Future<void> _invalidArguments(ConversationReceiptScope scope) async {
  final target = _target(scope);
  final encoded = _reference(scope).encode();
  for (final method in ['read', 'clear', 'write']) {
    for (final value in <Object?>[
      null,
      true,
      <Object?>[target],
      <String, Object?>{},
      {'target': 1, if (method == 'write') 'reference': encoded},
      {'other': target, if (method == 'write') 'reference': encoded},
      <Object, Object>{1: target, if (method == 'write') 'reference': encoded},
      {
        'target': target,
        'extra': true,
        if (method == 'write') 'reference': encoded,
      },
      {
        'target': 'NihongoDaily.Refresh.v1|${scope.projectOrigin}',
        if (method == 'write') 'reference': encoded,
      },
      {
        'target': '${target}PRIVATE',
        if (method == 'write') 'reference': encoded,
      },
    ]) {
      await _invalid(method, value);
    }
  }
  for (final value in <Object?>[
    null,
    true,
    1,
    <String, Object?>{},
    'PRIVATE_TOKEN',
    'x' * 1025,
    '$encoded ',
    encoded.replaceFirst(_owner, _otherOwner),
    encoded.replaceFirst(scope.projectOrigin, '${scope.projectOrigin}-other'),
  ]) {
    await _invalid('write', {'target': target, 'reference': value});
  }
  await _invalid('write', {'target': target, 'token': encoded});
  await _invalid('clear', {'target': target, 'reference': encoded});
  try {
    await _channel.invokeMethod<Object?>('reviewDirectory', {'target': target});
  } on MissingPluginException {
    return;
  }
  throw const FormatException('Unknown receipt method was accepted');
}

Future<void> verifyWindowsReceiptPhase(String phase, String runScope) async {
  final origin = 'https://$runScope-receipt.invalid';
  final scopes = [
    ConversationReceiptScope(projectUrl: origin, ownerId: _owner),
    ConversationReceiptScope(projectUrl: origin, ownerId: _otherOwner),
    ConversationReceiptScope(
      projectUrl: 'https://$runScope-receipt-other.invalid',
      ownerId: _owner,
    ),
  ];
  final auth = createWindowsSessionCredentialVault(origin);
  if (phase == 'receipt-cleanup') {
    // Try every owned synthetic slot even when one OS clear fails. Never hide it.
    var failed = false;
    for (final scope in scopes) {
      try {
        _require(
          await _channel.invokeMethod<Object?>('clear', {
                'target': _target(scope),
              }) ==
              true,
        );
      } on Object {
        failed = true;
      }
    }
    try {
      await auth.clear();
    } on Object {
      failed = true;
    }
    _require(!failed);
    return;
  }
  final stores = scopes
      .map((scope) => createWindowsConversationReceiptStore(scope: scope))
      .toList();
  try {
    if (phase == 'receipt-write') {
      _require(await auth.readRefreshToken() == null);
      await auth.writeRefreshToken(_authMarker);
      for (var i = 0; i < stores.length; i++) {
        _require(await stores[i].read() == null);
        await stores[i].reserve(_reference(scopes[i]));
        await stores[i].reserve(_reference(scopes[i]));
      }
      // Raw receiver rejects bad maps/types/fields/scope without erasing A/B/C.
      await _invalidArguments(scopes.first);
    } else if (phase == 'receipt-reopen') {
      for (var i = 0; i < stores.length; i++) {
        _require(
          (await stores[i].read())?.encode() == _reference(scopes[i]).encode(),
        );
        var conflicted = false;
        try {
          await stores[i].reserve(_reference(scopes[i], _nextEvent));
        } on ConversationReceiptStoreFailure catch (error) {
          conflicted = error.code == ConversationReceiptStoreError.conflict;
        }
        _require(conflicted);
      }
    } else if (phase == 'receipt-clear') {
      await stores.first.clearForSignOut();
      await stores.first.clearForSignOut();
      _require(
        await _channel.invokeMethod<Object?>('read', {
              'target': _target(scopes.first),
            }) ==
            null,
      );
      for (var i = 1; i < stores.length; i++) {
        _require(
          (await stores[i].read())?.encode() == _reference(scopes[i]).encode(),
        );
        await stores[i].clearForSignOut();
      }
    } else {
      _require(phase == 'receipt-absent');
      for (final store in stores) {
        _require(await store.read() == null);
      }
    }
    _require(await auth.readRefreshToken() == _authMarker);
    if (phase == 'receipt-write' || phase == 'receipt-reopen') {
      for (var i = 0; i < stores.length; i++) {
        _require(
          (await stores[i].read())?.encode() == _reference(scopes[i]).encode(),
        );
      }
    }
  } finally {
    // close revokes/drains ownership but preserves metadata for the next process.
    for (final store in stores) {
      await store.close();
    }
  }
}
