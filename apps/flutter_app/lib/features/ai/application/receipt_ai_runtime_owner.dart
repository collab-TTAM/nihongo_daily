import 'dart:async';
import '../../srs/data/review_repository.dart';
import '../data/captured_ai_text_repository.dart';
import '../data/conversation_receipt_store.dart';
import '../data/receipt_guarded_ai_transport.dart';
import 'ai_text_runtime_owner.dart';

typedef ReceiptAiTransportFactory =
    ReceiptGuardedAiTransport Function({
      required ReviewAuth auth,
      required bool Function() isReady,
      required ConversationReceiptStore store,
    });

/// Owns one account/project receipt store and its AI runtime. Explicit composition
/// only. Factory borrows this store, binds the same trusted project and creates
/// an owned captured transport; no request or Auth success at construction.
final class ReceiptAiRuntimeOwner {
  ReceiptAiRuntimeOwner({
    required ConversationReceiptStore store,
    required ReceiptAiTransportFactory createTransport,
  }) : _store = store {
    runtime = AiTextRuntimeOwner(
      createTransport: ({required auth, required isReady}) =>
          createTransport(auth: auth, isReady: isReady, store: _store),
    );
  }
  final ConversationReceiptStore _store;
  late final AiTextRuntimeOwner runtime;
  bool _preserveChosen = false;
  bool _signOutChosen = false;
  Future<void>? _preserving;
  Future<void>? _signingOut;
  static const _failed = AiTextFailure(AiTextErrorCode.internalError);

  /// Close preserves pending metadata. It cannot bypass a failed sign-out clear
  /// or silently retry it; only explicit signOut can retry a failed clear.
  Future<void> close() {
    if (_signOutChosen) return _signingOut ?? Future.error(_failed);
    if (_preserving != null) return _preserving!;
    _preserveChosen = true;
    final done = Completer<void>();
    _preserving = done.future; // Before runtime revoke/close can reenter.
    unawaited(
      Future<void>.sync(() => _shutdown(clear: false)).then<void>(
        (_) => done.complete(),
        onError: (Object _, StackTrace _) => done.completeError(_failed),
      ),
    );
    return done.future;
  }

  /// Revoke runtime now. Wait actual storage/HTTP before clearing the exact owned
  /// partition, then close/release store ownership. Not remote Auth revocation or
  /// server receipt cancellation. Host still owns the Supabase logout strategy.
  Future<void> signOut() {
    if (_preserveChosen) return Future.error(_failed);
    if (_signingOut != null) return _signingOut!;
    _signOutChosen = true;
    final done = Completer<void>();
    _signingOut =
        done.future; // Before supplied cleanup/backend code can reenter.
    unawaited(
      Future<void>.sync(() => _shutdown(clear: true)).then<void>(
        (_) => done.complete(),
        onError: (Object _, StackTrace _) {
          _signingOut =
              null; // Failed clear keeps store claim; explicit retry only.
          done.completeError(_failed);
        },
      ),
    );
    return done.future;
  }

  Future<void> _shutdown({required bool clear}) async {
    // runtime.close synchronously retires capabilities and waits actual leases.
    await runtime.close();
    if (clear) await _store.clearForSignOut();
    await _store.close(); // Never reached after failed drain/clear.
  }
}
