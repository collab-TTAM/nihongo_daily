// TEST ONLY payload codec; no encrypted storage, Auth or recovery proof.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/domain/pending_conversation_command_envelope.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';

const project = 'https://command-codec.test';
const owner = 'ABCDEFAB-1234-0000-FFFF-ABCDEFABCDEF';
const other = '00000000-0000-0000-0000-000000000000';
void main() {
  late Map<String, Object?> fixtures;
  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  ConversationReceiptScope scope({String url = project, String id = owner}) =>
      ConversationReceiptScope(projectUrl: url, ownerId: id);
  PendingConversationCommandEnvelope envelope(String op) {
    final body = Map<String, Object?>.from(
      fixtures['${op}_request']! as Map<String, Object?>,
    )..['client_event_id'] = owner;
    return switch (op) {
      'start_conversation' => PendingConversationCommandEnvelope.fromStart(
        projectUrl: project,
        ownerId: owner,
        request: StartConversationRequest.fromJson(body),
      ),
      'conversation_turn' => PendingConversationCommandEnvelope.fromTurn(
        projectUrl: project,
        ownerId: owner,
        request: ConversationTurnRequest.fromJson(body),
      ),
      'finish_conversation' => PendingConversationCommandEnvelope.fromFinish(
        projectUrl: project,
        ownerId: owner,
        request: FinishConversationRequest.fromJson(body),
      ),
      _ => throw StateError('TEST ONLY operation'),
    };
  }

  PendingConversationCommandEnvelope decode(String s) =>
      PendingConversationCommandEnvelope.decode(s, expectedScope: scope());
  Map<String, Object?> json(String op) =>
      jsonDecode(envelope(op).encode()) as Map<String, Object?>;
  const ops = [
    'start_conversation',
    'conversation_turn',
    'finish_conversation',
  ];
  test(
    'all three canonical commands preserve exact reference and original DTO',
    () {
      for (final op in ops) {
        final e = envelope(op);
        final result = decode(e.encode());
        expect(result.reference.encode(), e.reference.encode());
        expect(result.encode(), e.encode());
        expect(result.start != null, op == ops[0]);
        expect(result.turn != null, op == ops[1]);
        expect(result.finish != null, op == ops[2]);
        expect(
          utf8.encode(e.encode()).length,
          lessThanOrEqualTo(PendingConversationCommandEnvelope.maxEncodedBytes),
        );
      }
    },
  );
  test('text code points whitespace and UUID spelling remain original', () {
    final r = ConversationTurnRequest(
      sessionId: owner,
      clientEventId: owner,
      textJa: '  か\u3099😀\n ',
    );
    final e = PendingConversationCommandEnvelope.fromTurn(
      projectUrl: project,
      ownerId: owner,
      request: r,
    );
    final result = decode(e.encode());
    expect(result.turn!.toJson(), r.toJson());
    expect(result.turn!.textJa, '  か\u3099😀\n ');
    expect(result.reference.clientEventId, owner);
  });
  test('maximal escaped or multibyte original text fits bounded envelope', () {
    for (final unit in ['😀', '界', '\u0001']) {
      final text = List.filled(5000, unit).join();
      final e = PendingConversationCommandEnvelope.fromTurn(
        projectUrl: project,
        ownerId: owner,
        request: ConversationTurnRequest(
          sessionId: owner,
          clientEventId: owner,
          textJa: text,
        ),
      );
      expect(decode(e.encode()).turn!.textJa, text);
      expect(utf8.encode(e.encode()).length, lessThanOrEqualTo(32768));
    }
  });
  test(
    'trusted local scope is mandatory and foreign partitions fail closed',
    () {
      for (final op in ops) {
        for (final foreign in [
          scope(url: 'https://foreign.test'),
          scope(id: other),
        ]) {
          expect(
            () => PendingConversationCommandEnvelope.decode(
              envelope(op).encode(),
              expectedScope: foreign,
            ),
            throwsFormatException,
          );
        }
        expect(
          PendingConversationCommandEnvelope.decode(
            envelope(op).encode(),
            expectedScope: scope(
              url: 'https://COMMAND-CODEC.test/',
              id: owner.toLowerCase(),
            ),
          ).encode(),
          envelope(op).encode(),
        );
      }
    },
  );
  test('exact schema rejects missing extra and noninteger format versions', () {
    for (final op in ops) {
      for (final field in ['version', 'reference', 'request']) {
        expect(
          () => decode(jsonEncode(json(op)..remove(field))),
          throwsFormatException,
        );
      }
      expect(
        () => decode(jsonEncode(json(op)..['token'] = 'PRIVATE_TEST')),
        throwsFormatException,
      );
      for (final v in [null, 0, 2, 1.0, '1', true]) {
        expect(
          () => decode(jsonEncode(json(op)..['version'] = v)),
          throwsFormatException,
        );
      }
    }
  });
  test(
    'reference operation event and original event casing cannot diverge',
    () {
      for (final op in ops) {
        for (final event in [other, owner.toLowerCase()]) {
          final j = json(op);
          (j['request']! as Map<String, Object?>)['client_event_id'] = event;
          expect(() => decode(jsonEncode(j)), throwsFormatException);
        }
        final j = json(op);
        (j['reference']! as Map<String, Object?>)['operation'] = op == ops[0]
            ? ops[2]
            : ops[0];
        expect(() => decode(jsonEncode(j)), throwsFormatException);
      }
    },
  );
  test(
    'strict request and reference decoders are not bypassed by envelope',
    () {
      for (final op in ops) {
        final good = json(op);
        for (final field in (good['request']! as Map<String, Object?>).keys) {
          final j = json(op);
          (j['request']! as Map<String, Object?>).remove(field);
          expect(() => decode(jsonEncode(j)), throwsFormatException);
        }
        final j = json(op);
        (j['reference']! as Map<String, Object?>)['dispatch_token'] =
            'PRIVATE_TEST';
        expect(() => decode(jsonEncode(j)), throwsFormatException);
        final k = json(op);
        (k['request']! as Map<String, Object?>)['user_id'] = owner;
        expect(() => decode(jsonEncode(k)), throwsFormatException);
      }
    },
  );
  test(
    'duplicates key order whitespace and escape aliases are noncanonical',
    () {
      for (final op in ops) {
        final e = envelope(op).encode();
        final j = json(op);
        for (final alias in [
          ' $e',
          '$e\n',
          e.replaceFirst('"version":1', '"version":1,"version":1'),
          e.replaceFirst('"request":', '"request":{},"request":'),
          e.replaceFirst('"version"', '"versi\\u006fn"'),
          jsonEncode(
            Map<String, Object?>.fromEntries(j.entries.toList().reversed),
          ),
        ]) {
          expect(() => decode(alias), throwsFormatException);
        }
      }
    },
  );
  test('oversized malformed inputs emit fixed safe error without source', () {
    for (final input in [
      'PRIVATE_TEST',
      '[]',
      'null',
      List.filled(32769, 'x').join(),
      List.filled(12000, '界').join(),
    ]) {
      try {
        decode(input);
        fail('Expected rejection');
      } on FormatException catch (e) {
        expect(e.message, 'Invalid pending command envelope');
        expect(e.source, isNull);
        expect(e.offset, isNull);
        expect(e.toString(), isNot(contains('PRIVATE_TEST')));
      }
    }
  });
  test('decoded values and safe display retain no mutable input maps', () {
    final e = envelope(ops[1]);
    final j = json(ops[1]);
    final result = decode(jsonEncode(j));
    (j['request']! as Map<String, Object?>).clear();
    j.clear();
    result.turn!.toJson().clear();
    result.reference.toJson().clear();
    expect(result.encode(), e.encode());
    expect(result.toString(), 'PendingConversationCommandEnvelope');
    expect(result.toString(), isNot(contains(owner)));
  });
}
