// TEST ONLY Windows runner/OS lifecycle probe. Auth and mutation port are synthetic;
// there is no network, Supabase session, provider call or learner credential.
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:nihongo_daily/features/ai/application/ai_text_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/application/receipt_ai_runtime_owner.dart';
import 'package:nihongo_daily/features/ai/application/windows_receipt_ai_runtime.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_mutation.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_scenarios.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/data/receipt_guarded_ai_transport.dart';
import 'package:nihongo_daily/features/ai/data/windows_conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/auth/data/windows_session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const receiptLifecyclePhases = {
  'receipt-life-write',
  'receipt-life-reopen',
  'receipt-life-logout',
  'receipt-life-absent',
  'receipt-life-cleanup',
};
const _channel = MethodChannel('nihongo_daily/conversation_receipts_v1');
const _a = 'a1000000-0000-4000-8000-000000000001';
const _b = 'a1000000-0000-4000-8000-000000000002';
const _event = 'b1000000-0000-4000-8000-000000000001';
const _authMarker = 'TEST_ONLY_receipt_lifecycle_auth';
final _request = StartConversationRequest(
  scenarioId: _a,
  level: AiTextLevel.n5,
  clientEventId: _event,
);
void _require(bool value) {
  if (!value) {
    throw const FormatException('Receipt lifecycle verification failed');
  }
}

String _encoded(ConversationReceiptScope scope) =>
    ConversationReceiptReference.fromStart(
      projectUrl: scope.projectOrigin,
      ownerId: scope.ownerId,
      request: _request,
    ).encode();
Future<Object?> _read(
  ConversationReceiptScope scope,
) => _channel.invokeMethod<Object?>('read', {
  'target':
      '${ConversationReceiptStore.targetPrefix}${scope.projectOrigin}|${scope.ownerId}',
});

final class _Auth implements ReviewAuth {
  _Auth(String owner) : currentSession = ReviewSession(userId: owner);
  @override
  final ReviewSession currentSession;
}

final class _Inner
    implements
        OwnedAiTextTransport,
        ConversationMutationTransport,
        ConversationScenarioReadPort {
  _Inner(this.scope) {
    unawaited(
      wire.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
  }
  final ConversationReceiptScope scope;
  final entered = Completer<void>();
  final wire = Completer<Object?>();
  bool revoked = false;
  int sends = 0;
  int closes = 0;
  @override
  bool get isCurrent => !revoked;
  @override
  void revoke() => revoked = true;
  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String operation,
    required Map<String, Object> body,
  }) async {
    sends++;
    _require(
      !revoked &&
          capturedSession.userId == scope.ownerId &&
          operation == 'start_conversation',
    );
    _require(
      body.length == 3 &&
          body['client_event_id'] == _event &&
          body['scenario_id'] == _a &&
          body['jlpt_level'] == 'N5',
    );
    // Observe real Credential Manager THROUGH the real channel at port entry.
    _require(await _read(scope) == _encoded(scope));
    entered.complete();
    return wire.future;
  }

  @override
  Future<Object?> tutorExplain({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async => throw const FormatException('Unused test port');
  @override
  Future<Object?> correctSentence({
    required ReviewSession capturedSession,
    required Map<String, Object> body,
  }) async => throw const FormatException('Unused test port');
  @override
  Future<Object?> read({
    required ReviewSession capturedSession,
    required AiTextLevel level,
  }) async => throw const FormatException('Unused test port');
}

ReceiptAiRuntimeOwner _owner(ConversationReceiptScope scope, _Inner inner) =>
    createWindowsReceiptAiRuntimeOwner(
      scope: scope,
      createTransport: ({required auth, required isReady, required store}) =>
          ReceiptGuardedAiTransport(
            inner: inner,
            store: store,
            auth: auth,
            capturedSession: auth.currentSession!,
            isReady: isReady,
          ),
    );
Future<void> _claimed(ConversationReceiptScope scope) async {
  try {
    final unexpected = createWindowsConversationReceiptStore(scope: scope);
    await unexpected.close();
  } on ConversationReceiptStoreFailure catch (error) {
    _require(error.code == ConversationReceiptStoreError.owned);
    return;
  }
  throw const FormatException('Receipt lifecycle ownership released early');
}

Future<void> _pending(
  ConversationReceiptScope scope, {
  required bool clear,
}) async {
  final inner = _Inner(scope);
  final owner = _owner(scope, inner);
  final auth = _Auth(scope.ownerId);
  try {
    _require(await _read(scope) == null);
    final flow = owner.runtime.acquireConversation(
      auth: auth,
      generation: AiTextGeneration(),
      isReady: () => true,
    )!;
    final rejected = flow
        .start(_request)
        .then<void>(
          (_) {
            throw const FormatException('Retired response was accepted');
          },
          onError: (Object error, StackTrace _) {
            _require(
              error is AiTextFailure &&
                  error.code == AiTextErrorCode.unauthorized,
            );
          },
        );
    await Future.any<void>([
      inner.entered.future,
      rejected.then<void>(
        (_) => throw const FormatException('Mutation failed before port entry'),
      ),
    ]);
    _require(inner.sends == 1);
    bool finished = false;
    bool failed = false;
    final closing = (clear ? owner.signOut() : owner.close()).then<void>(
      (_) {
        finished = true;
      },
      onError: (Object _, StackTrace _) {
        failed = true;
        finished = true;
      },
    );
    await Future<void>.delayed(Duration.zero);
    _require(inner.revoked && inner.closes == 0 && !finished);
    await _claimed(scope);
    _require(await _read(scope) == _encoded(scope));
    // Simulated late callback only; no actual HTTP/provider success is claimed.
    if (clear) {
      inner.wire.completeError(StateError('TEST_ONLY_LATE_ERROR'));
    } else {
      inner.wire.complete({'TEST_ONLY': 'late response'});
    }
    await rejected;
    await closing;
    _require(!failed && finished && inner.closes == 1 && inner.sends == 1);
    _require(await _read(scope) == (clear ? null : _encoded(scope)));
  } finally {
    if (!inner.wire.isCompleted) {
      inner.wire.completeError(StateError('TEST_ONLY_CLEANUP'));
    }
    await owner.close();
  }
}

Future<void> _clear(ConversationReceiptScope scope) async {
  final owner = _owner(scope, _Inner(scope));
  await owner.signOut();
}

Future<void> verifyWindowsReceiptLifecyclePhase(
  String phase,
  String runScope,
) async {
  final origin = 'https://$runScope-life.invalid';
  final scopes = [
    ConversationReceiptScope(projectUrl: origin, ownerId: _a),
    ConversationReceiptScope(projectUrl: origin, ownerId: _b),
    ConversationReceiptScope(
      projectUrl: 'https://$runScope-life-other.invalid',
      ownerId: _a,
    ),
  ];
  final auth = createWindowsSessionCredentialVault(origin);
  if (phase == 'receipt-life-cleanup') {
    var failed = false;
    for (final scope in scopes) {
      try {
        await _clear(scope);
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
  switch (phase) {
    case 'receipt-life-write':
      _require(await auth.readRefreshToken() == null);
      await auth.writeRefreshToken(_authMarker);
      for (final scope in scopes) {
        _require(await _read(scope) == null);
      }
      await _pending(scopes.first, clear: false);
      final b = createWindowsConversationReceiptStore(scope: scopes[1]);
      try {
        await b.reserve(
          ConversationReceiptReference.fromStart(
            projectUrl: origin,
            ownerId: _b,
            request: _request,
          ),
        );
      } finally {
        await b.close();
      }
    case 'receipt-life-reopen':
      final inner = _Inner(scopes.first);
      final owner = _owner(scopes.first, inner);
      final identity = _Auth(_a);
      try {
        _require(await _read(scopes.first) == _encoded(scopes.first));
        final flow = owner.runtime.acquireConversation(
          auth: identity,
          generation: AiTextGeneration(),
          isReady: () => true,
        )!;
        bool rejected = false;
        try {
          await flow.start(_request);
        } on AiTextFailure catch (error) {
          rejected = error.code == AiTextErrorCode.syncConflict;
        }
        _require(rejected && inner.sends == 0);
        await owner.close();
        _require(inner.closes == 1);
        _require(await _read(scopes[1]) == _encoded(scopes[1]));
      } finally {
        await owner.close();
      }
    case 'receipt-life-logout':
      // A separate project tests actual pending metadata survives until drain, then
      // real clear; A/B saved by the earlier process must remain untouched.
      await _pending(scopes[2], clear: true);
      _require(await _read(scopes.first) == _encoded(scopes.first));
      _require(await _read(scopes[1]) == _encoded(scopes[1]));
      await _clear(scopes.first);
      _require(await _read(scopes.first) == null);
      _require(await _read(scopes[1]) == _encoded(scopes[1]));
      await _clear(scopes[1]);
    case 'receipt-life-absent':
      for (final scope in scopes) {
        _require(await _read(scope) == null);
        final owner = _owner(scope, _Inner(scope));
        await owner.close();
      }
    default:
      throw const FormatException('Unknown receipt lifecycle phase');
  }
  _require(await auth.readRefreshToken() == _authMarker);
}
