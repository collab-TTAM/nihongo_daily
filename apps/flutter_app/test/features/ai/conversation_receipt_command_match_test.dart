// TEST ONLY stored JSON association; no Auth, HTTP, storage or release proof.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_command_match.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_snapshot.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';

const owner = 'ABCDEFAB-1234-0000-FFFF-ABCDEFABCDEF';
const other = '00000000-0000-0000-0000-000000000000';
const project = 'https://receipt-command.test';

void main() {
  late Map<String, Object?> fixtures;
  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });

  Map<String, Object?> request(ConversationReceiptOperation op) =>
      Map<String, Object?>.from(
        fixtures['${op.wireName}_request']! as Map<String, Object?>,
      )..['client_event_id'] = owner;

  ConversationReceiptReference reference(ConversationReceiptOperation op) =>
      ConversationReceiptReference.fromJson({
        'version': 1,
        'project_origin': project,
        'owner_id': owner,
        'operation': op.wireName,
        'client_event_id': owner,
      });

  Map<String, Object?> row(ConversationReceiptOperation op) => {
    'user_id': owner,
    'operation': op.wireName,
    'client_event_id': owner,
    'request_json': request(op),
    'status': 'COMPLETED',
    'response_json': jsonDecode(
      jsonEncode(fixtures['${op.wireName}_response']),
    ),
  };

  ConversationReceiptSnapshot read(
    ConversationReceiptOperation op,
    Object? rows, {
    Map<String, Object?>? original,
    ConversationReceiptReference? ref,
  }) {
    final r = ref ?? reference(op);
    final body = original ?? request(op);
    return switch (op) {
      ConversationReceiptOperation.start =>
        ConversationReceiptCommandMatch.forStart(
          r,
          StartConversationRequest.fromJson(body),
          rows,
        ),
      ConversationReceiptOperation.turn =>
        ConversationReceiptCommandMatch.forTurn(
          r,
          ConversationTurnRequest.fromJson(body),
          rows,
        ),
      ConversationReceiptOperation.finish =>
        ConversationReceiptCommandMatch.forFinish(
          r,
          FinishConversationRequest.fromJson(body),
          rows,
        ),
    };
  }

  test('all three exact original commands decode typed completed receipts', () {
    for (final op in ConversationReceiptOperation.values) {
      final result = read(op, [row(op)]);
      expect(result.status, ConversationReceiptStatus.completed);
      final encoded = switch (op) {
        ConversationReceiptOperation.start => result.start!.toJson(),
        ConversationReceiptOperation.turn => result.turn!.toJson(),
        ConversationReceiptOperation.finish => result.finish!.toJson(),
      };
      expect(encoded, fixtures['${op.wireName}_response']);
      expect(result.start != null, op == ConversationReceiptOperation.start);
      expect(result.turn != null, op == ConversationReceiptOperation.turn);
      expect(result.finish != null, op == ConversationReceiptOperation.finish);
    }
  });

  test('unknown is ambiguous and pending still requires the full original', () {
    for (final op in ConversationReceiptOperation.values) {
      expect(read(op, []).status, ConversationReceiptStatus.unknown);
      final pending = row(op)
        ..['status'] = 'PENDING'
        ..['response_json'] = null;
      expect(read(op, [pending]).status, ConversationReceiptStatus.pending);
      expect(
        () => read(op, [pending..remove('request_json')]),
        throwsFormatException,
      );
    }
  });

  test('JSON field order changes do not change the original command', () {
    for (final op in ConversationReceiptOperation.values) {
      final reordered = Map<String, Object?>.fromEntries(
        request(op).entries.toList().reversed,
      );
      expect(
        read(op, [row(op)..['request_json'] = reordered]).status,
        ConversationReceiptStatus.completed,
      );
    }
  });

  test(
    'changed original scenario level session event and text fail closed',
    () {
      for (final op in ConversationReceiptOperation.values) {
        for (final field in request(op).keys) {
          final changed = request(op);
          changed[field] = switch (field) {
            'jlpt_level' => changed[field] == 'N5' ? 'N4' : 'N5',
            'text_ja' => '${changed[field]} ',
            _ => other,
          };
          expect(
            () => read(op, [row(op)..['request_json'] = changed]),
            throwsFormatException,
            reason: '${op.name}/$field',
          );
        }
      }
    },
  );

  test('exact text keeps whitespace and distinct Unicode representations', () {
    const op = ConversationReceiptOperation.turn;
    final original = request(op)..['text_ja'] = '  か\u3099😀\n ';
    final saved = row(op)..['request_json'] = Map.of(original);
    expect(
      read(op, [saved], original: original).status,
      ConversationReceiptStatus.completed,
    );
    for (final text in ['か\u3099😀', '  が😀\n ', '  か\u3099😀\n  ']) {
      expect(
        () => read(op, [
          saved..['request_json'] = {...original, 'text_ja': text},
        ], original: original),
        throwsFormatException,
      );
    }
  });

  test(
    'row UUID association ignores case but original DTO spelling does not',
    () {
      for (final op in ConversationReceiptOperation.values) {
        final lowerRow = row(op)
          ..['user_id'] = owner.toLowerCase()
          ..['client_event_id'] = owner.toLowerCase();
        expect(
          read(op, [lowerRow]).status,
          ConversationReceiptStatus.completed,
        );
        expect(
          () => read(op, [
            lowerRow
              ..['request_json'] = {
                ...request(op),
                'client_event_id': owner.toLowerCase(),
              },
          ]),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'foreign reference operation or event is rejected even without a row',
    () {
      for (final op in ConversationReceiptOperation.values) {
        for (final foreign in [
          reference(ConversationReceiptOperation.values[(op.index + 1) % 3]),
          ConversationReceiptReference.fromJson({
            ...reference(op).toJson(),
            'client_event_id': other,
          }),
        ]) {
          for (final rows in [
            <Object?>[],
            [row(op)],
          ]) {
            expect(() => read(op, rows, ref: foreign), throwsFormatException);
          }
        }
      }
    },
  );

  test('stored request requires every exact field type and no extras', () {
    for (final op in ConversationReceiptOperation.values) {
      final bad = <Object?>[
        null,
        [],
        'private-invalid',
        {...request(op), 'user_id': owner},
        for (final field in request(op).keys) request(op)..remove(field),
        for (final field in request(op).keys) request(op)..[field] = null,
        for (final field in request(op).keys) request(op)..[field] = true,
      ];
      for (final saved in bad) {
        expect(
          () => read(op, [row(op)..['request_json'] = saved]),
          throwsFormatException,
        );
      }
    }
  });

  test('foreign owner operation event extra row keys and duplicates fail', () {
    for (final op in ConversationReceiptOperation.values) {
      for (final changed in [
        row(op)..['user_id'] = other,
        row(op)..['operation'] = 'tutor_explain',
        row(op)..['client_event_id'] = other,
        row(op)..['dispatch_token'] = 'private-invalid',
        for (final field in row(op).keys) row(op)..remove(field),
      ]) {
        expect(() => read(op, [changed]), throwsFormatException);
      }
      expect(() => read(op, [row(op), row(op)]), throwsFormatException);
    }
  });

  test(
    'matched command cannot bypass status or strict response validation',
    () {
      for (final op in ConversationReceiptOperation.values) {
        for (final changed in [
          row(op)..['status'] = 'UNKNOWN',
          row(op)..['status'] = 'PENDING',
          row(op)..['response_json'] = null,
          row(op)..['response_json'] = {'private-invalid': true},
          row(op)..['response_json'] = {'code': 'INTERNAL_ERROR'},
        ]) {
          expect(() => read(op, [changed]), throwsFormatException);
        }
      }
    },
  );

  test('bounded malformed projections expose fixed safe errors only', () {
    const op = ConversationReceiptOperation.start;
    for (final rows in <Object?>[
      null,
      {},
      'private-invalid',
      [null],
      [row(op)..['request_json'] = List.filled(1024 * 1024, '界').join()],
    ]) {
      try {
        read(op, rows);
        fail('Expected rejection');
      } on FormatException catch (error) {
        expect(error.message, 'Invalid receipt command projection');
        expect(error.source, isNull);
        expect(error.offset, isNull);
        expect(error.toString(), isNot(contains('private-invalid')));
      }
    }
  });

  test(
    'returned immutable snapshot does not retain mutable request or rows',
    () {
      const op = ConversationReceiptOperation.finish;
      final saved = row(op);
      final before = jsonEncode(saved);
      final result = read(op, [saved]);
      expect(jsonEncode(saved), before);
      (saved['request_json']! as Map<String, Object?>).clear();
      (saved['response_json']! as Map<String, Object?>).clear();
      saved.clear();
      expect(result.finish!.toJson(), fixtures['finish_conversation_response']);
      expect(
        () => result.finish!.strengthsVi.add('changed'),
        throwsUnsupportedError,
      );
      final exported = result.finish!.toJson()..clear();
      expect(exported, isEmpty);
      expect(result.finish!.toJson(), fixtures['finish_conversation_response']);
      expect(result.toString(), 'ConversationReceiptSnapshot(completed)');
    },
  );
}
