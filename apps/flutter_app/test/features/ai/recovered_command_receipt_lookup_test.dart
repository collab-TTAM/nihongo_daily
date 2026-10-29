// TEST ONLY Auth/read ports. No hosted Auth, native storage or replay proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_receipt_lookup.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_snapshot.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/pending_conversation_command_envelope.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const owner = 'a1000000-0000-4000-8000-000000000001';
const other = 'a1000000-0000-4000-8000-000000000002';
const origin = 'https://recovery.test';

final class Auth implements ReviewAuth {
  ReviewSession? session = ReviewSession(userId: owner);
  @override
  ReviewSession? get currentSession => session;
}

final class CallbackAuth implements ReviewAuth {
  final ReviewSession session = ReviewSession(userId: owner);
  void Function()? beforeRead;
  @override
  ReviewSession get currentSession {
    beforeRead?.call();
    return session;
  }
}

class LegacyPort implements ConversationReceiptReadPort {
  int legacyCalls = 0;
  @override
  Future<ConversationReceiptSnapshot> lookupReceipt(
    ConversationReceiptReference reference,
  ) async {
    legacyCalls++;
    throw StateError('PRIVATE_LEGACY');
  }
}

final class OriginalPort extends LegacyPort
    implements ConversationOriginalReceiptReadPort {
  int calls = 0;
  String? operation;
  ConversationReceiptReference? reference;
  Object? request;
  late ConversationReceiptSnapshot result;
  Future<ConversationReceiptSnapshot> Function()? action;
  Future<ConversationReceiptSnapshot> capture(
    String op,
    ConversationReceiptReference ref,
    Object original,
  ) {
    calls++;
    operation = op;
    reference = ref;
    request = original;
    return action?.call() ?? Future.value(result);
  }

  @override
  Future<ConversationReceiptSnapshot> lookupStartReceipt(
    ConversationReceiptReference reference,
    StartConversationRequest original,
  ) => capture('start', reference, original);
  @override
  Future<ConversationReceiptSnapshot> lookupTurnReceipt(
    ConversationReceiptReference reference,
    ConversationTurnRequest original,
  ) => capture('turn', reference, original);
  @override
  Future<ConversationReceiptSnapshot> lookupFinishReceipt(
    ConversationReceiptReference reference,
    FinishConversationRequest original,
  ) => capture('finish', reference, original);
}

Matcher failure(AiTextErrorCode code) {
  return isA<AiTextFailure>().having((error) => error.code, 'code', code);
}

void main() {
  late Map<String, Object?> fixtures;
  late Auth auth;
  late OriginalPort port;
  late CapturedConversationReceiptLookup reader;
  var ready = true;
  PendingConversationCommandEnvelope command(String operation) =>
      switch (operation) {
        'start' => PendingConversationCommandEnvelope.fromStart(
          projectUrl: origin,
          ownerId: owner,
          request: StartConversationRequest.fromJson(
            fixtures['start_conversation_request'],
          ),
        ),
        'turn' => PendingConversationCommandEnvelope.fromTurn(
          projectUrl: origin,
          ownerId: owner,
          request: ConversationTurnRequest.fromJson(
            fixtures['conversation_turn_request'],
          ),
        ),
        _ => PendingConversationCommandEnvelope.fromFinish(
          projectUrl: origin,
          ownerId: owner,
          request: FinishConversationRequest.fromJson(
            fixtures['finish_conversation_request'],
          ),
        ),
      };
  setUp(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    auth = Auth();
    port = OriginalPort();
    ready = true;
    reader = CapturedConversationReceiptLookup(
      auth: auth,
      port: port,
      isReady: () => ready,
    );
  });

  for (final operation in ['start', 'turn', 'finish']) {
    for (final completed in [false, true]) {
      test('$operation decoded envelope preserves DTO and receipt', () async {
        final original = command(operation);
        final decoded = PendingConversationCommandEnvelope.decode(
          original.encode(),
          expectedScope: original.reference.scope,
        );
        port.result = ConversationReceiptSnapshot.fromRows(decoded.reference, [
          {
            'user_id': owner,
            'operation': decoded.reference.operation.wireName,
            'client_event_id': decoded.reference.clientEventId,
            'status': completed ? 'COMPLETED' : 'PENDING',
            'response_json': completed
                ? fixtures['${decoded.reference.operation.wireName}_response']
                : null,
          },
        ]);
        final result = await reader.lookupCommand(decoded);
        expect(identical(result, port.result), isTrue);
        expect(port.operation, operation);
        expect(identical(port.reference, decoded.reference), isTrue);
        final expected = decoded.start ?? decoded.turn ?? decoded.finish;
        expect(identical(port.request, expected), isTrue);
        expect(decoded.encode(), original.encode());
        expect(port.calls, 1);
        expect(port.legacyCalls, 0);
      });
    }
  }

  test('legacy metadata port is never a fallback', () async {
    final legacy = LegacyPort();
    final legacyReader = CapturedConversationReceiptLookup(
      auth: auth,
      port: legacy,
      isReady: () => true,
    );
    await expectLater(
      legacyReader.lookupCommand(command('start')),
      throwsA(failure(AiTextErrorCode.internalError)),
    );
    expect(legacy.legacyCalls, 0);
  });

  test('foreign account and revoked reader cannot dispatch', () async {
    final foreign = PendingConversationCommandEnvelope.fromStart(
      projectUrl: origin,
      ownerId: other,
      request: StartConversationRequest.fromJson(
        fixtures['start_conversation_request'],
      ),
    );
    await expectLater(
      reader.lookupCommand(foreign),
      throwsA(failure(AiTextErrorCode.unauthorized)),
    );
    reader.revoke();
    await expectLater(
      reader.lookupCommand(command('finish')),
      throwsA(failure(AiTextErrorCode.unauthorized)),
    );
    expect(port.calls, 0);
  });

  for (final lateError in [false, true]) {
    test('late account suppresses result/error $lateError', () async {
      final held = Completer<ConversationReceiptSnapshot>();
      port.action = () => held.future;
      final pending = reader.lookupCommand(command('turn'));
      final checked = expectLater(
        pending,
        throwsA(failure(AiTextErrorCode.unauthorized)),
      );
      expect(port.calls, 1);
      auth.session = ReviewSession(userId: owner);
      if (lateError) {
        held.completeError(StateError('PRIVATE_RESPONSE'));
      } else {
        held.complete(
          ConversationReceiptSnapshot.fromRows(command('turn').reference, []),
        );
      }
      await checked;
      expect(reader.isCurrent, isFalse);
      expect(port.calls, 1);
      expect(port.legacyCalls, 0);
    });
  }

  test('unknown stays unknown; readiness fences', () async {
    port.result = ConversationReceiptSnapshot.fromRows(
      command('start').reference,
      [],
    );
    final result = await reader.lookupCommand(command('start'));
    expect(result.status, ConversationReceiptStatus.unknown);
    ready = false;
    await expectLater(
      reader.lookupCommand(command('start')),
      throwsA(failure(AiTextErrorCode.unauthorized)),
    );
    expect(port.calls, 1);
    expect(port.legacyCalls, 0);
  });

  for (final afterRead in [false, true]) {
    for (final replaceSession in [false, true]) {
      test('last readiness retires $afterRead/$replaceSession', () async {
        final original = command('start');
        final captured = auth.session;
        port.result = ConversationReceiptSnapshot.fromRows(
          original.reference,
          [],
        );
        var armed = false;
        var checks = 0;
        reader = CapturedConversationReceiptLookup(
          auth: auth,
          port: port,
          isReady: () {
            if (armed && ++checks == 2) {
              if (replaceSession) {
                auth.session = ReviewSession(userId: owner);
              } else {
                reader.revoke();
              }
            }
            return true;
          },
        );
        if (afterRead) {
          port.action = () async {
            armed = true;
            return port.result;
          };
        } else {
          armed = true;
        }
        await expectLater(
          reader.lookupCommand(original),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        expect(checks, 2);
        expect(port.calls, afterRead ? 1 : 0);
        expect(port.legacyCalls, 0);
        armed = false;
        auth.session = captured;
        expect(reader.isCurrent, isFalse);
        await expectLater(
          reader.lookupCommand(original),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
        expect(port.calls, afterRead ? 1 : 0);
      });
    }
  }

  for (final authGetter in [false, true]) {
    test('nested readiness cannot dispatch auth=$authGetter', () async {
      final original = command('turn');
      port.result = ConversationReceiptSnapshot.fromRows(
        original.reference,
        [],
      );
      final callbackAuth = CallbackAuth();
      var armed = false;
      var nestedCalls = 0;
      Future<void>? nestedChecked;
      void reenter() {
        if (!armed) return;
        armed = false;
        nestedCalls++;
        expect(reader.isCurrent, isFalse);
        nestedChecked = expectLater(
          reader.lookupCommand(original),
          throwsA(failure(AiTextErrorCode.unauthorized)),
        );
      }

      reader = CapturedConversationReceiptLookup(
        auth: callbackAuth,
        port: port,
        isReady: () {
          if (!authGetter) reenter();
          return true;
        },
      );
      if (authGetter) callbackAuth.beforeRead = reenter;
      armed = true;
      final result = await reader.lookupCommand(original);
      await nestedChecked!;
      expect(nestedCalls, 1);
      expect(result.status, ConversationReceiptStatus.unknown);
      expect(port.calls, 1);
      expect(port.legacyCalls, 0);
      expect(reader.isCurrent, isTrue);
      expect(await reader.lookupCommand(original), same(port.result));
      expect(port.calls, 2);
    });
  }
  for (final status in ['UNKNOWN', 'PENDING', 'COMPLETED']) {
    for (final field in [
      'project_origin',
      'owner_id',
      'operation',
      'client_event_id',
    ]) {
      test('snapshot mismatch $status/$field', () async {
        final original = command('start');
        final changed = <String, Object>{
          ...original.reference.toJson(),
          field: switch (field) {
            'project_origin' => 'https://foreign.test',
            'operation' => 'conversation_turn',
            _ => other,
          },
        };
        final foreign = ConversationReceiptReference.fromJson(changed);
        port.result = ConversationReceiptSnapshot.fromRows(
          foreign,
          status == 'UNKNOWN'
              ? <Object?>[]
              : [
                  {
                    'user_id': foreign.ownerId,
                    'operation': foreign.operation.wireName,
                    'client_event_id': foreign.clientEventId,
                    'status': status,
                    'response_json': status == 'COMPLETED'
                        ? fixtures['${foreign.operation.wireName}_response']
                        : null,
                  },
                ],
        );
        expect(port.result.matchesReference(original.reference), isFalse);
        await expectLater(
          reader.lookupCommand(original),
          throwsA(failure(AiTextErrorCode.internalError)),
        );
        expect(port.calls, 1);
        expect(port.legacyCalls, 0);
        expect(reader.isCurrent, isTrue);
        port.result = ConversationReceiptSnapshot.fromRows(
          original.reference,
          [],
        );
        expect(await reader.lookupCommand(original), same(port.result));
        expect(port.calls, 2);
      });
    }
  }

  test('snapshot binding accepts equivalent UUID spelling', () async {
    final original = command('start');
    final equivalent = ConversationReceiptReference.fromJson({
      ...original.reference.toJson(),
      'owner_id': original.reference.ownerId.toUpperCase(),
      'client_event_id': original.reference.clientEventId.toUpperCase(),
    });
    port.result = ConversationReceiptSnapshot.fromRows(equivalent, []);
    expect(port.result.matchesReference(original.reference), isTrue);
    expect(await reader.lookupCommand(original), same(port.result));
    expect(port.result.status, ConversationReceiptStatus.unknown);
    expect(port.result.toString(), 'ConversationReceiptSnapshot(unknown)');
    expect(port.calls, 1);
    expect(port.legacyCalls, 0);
  });
}
