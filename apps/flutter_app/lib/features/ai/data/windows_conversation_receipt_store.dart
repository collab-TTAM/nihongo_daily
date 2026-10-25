import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/conversation_receipt_reference.dart';
import 'conversation_receipt_store.dart';

/// Optional facade only. The native receiver is not yet installed; missing
/// support fails unavailable. No default wiring, Auth channel or fallback.
ConversationReceiptStore createWindowsConversationReceiptStore({
  required ConversationReceiptScope scope,
}) => ConversationReceiptStore(
  scope: scope,
  backend: _WindowsReceiptBackend(scope),
);

final class _WindowsReceiptBackend implements SecureConversationReceiptBackend {
  _WindowsReceiptBackend(this.scope)
    : target =
          '${ConversationReceiptStore.targetPrefix}${scope.projectOrigin}|${scope.ownerId}';
  final ConversationReceiptScope scope;
  final String target;
  static const channel = MethodChannel(
    'nihongo_daily/conversation_receipts_v1',
  );
  static const unavailable = ConversationReceiptStoreFailure(
    ConversationReceiptStoreError.unavailable,
  );
  static const corrupt = ConversationReceiptStoreFailure(
    ConversationReceiptStoreError.corrupt,
  );

  Future<Object?> _invoke(
    String method,
    String requested, [
    String? encoded,
  ]) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.windows ||
        requested != target) {
      throw unavailable;
    }
    try {
      return await channel.invokeMethod<Object?>(method, {
        'target': target,
        if (encoded != null) 'reference': encoded,
      });
    } on Object {
      throw unavailable; // No platform message/details, owner IDs or payloads.
    }
  }

  String _validate(Object? value) {
    try {
      if (value is! String) throw const FormatException();
      final reference = ConversationReceiptReference.decode(value);
      if (!scope.contains(reference)) throw const FormatException();
      return value;
    } on FormatException {
      throw corrupt;
    }
  }

  @override
  Future<Object?> read(String target) async {
    final value = await _invoke('read', target);
    return value == null ? null : _validate(value);
  }

  @override
  Future<void> write(String target, String encoded) async {
    final validated = _validate(encoded);
    if (await _invoke('write', target, validated) != true) throw corrupt;
  }

  @override
  Future<void> clear(String target) async {
    if (await _invoke('clear', target) != true) throw corrupt;
  }
}
