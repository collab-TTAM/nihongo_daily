// TEST ONLY frozen fixture round trips and malicious payload mutations.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';

const id = 'ABCDEFAB-1234-0000-FFFF-ABCDEFABCDEF';
const nil = '00000000-0000-0000-0000-000000000000';
String repeat(String text, int n) => List.filled(n, text).join();
void main() {
  late Map<String, Object?> fixtures;
  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  test('three requests round trip unchanged frozen fixtures', () {
    expect(
      StartConversationRequest.fromJson(
        fixtures['start_conversation_request'],
      ).toJson(),
      fixtures['start_conversation_request'],
    );
    expect(
      ConversationTurnRequest.fromJson(
        fixtures['conversation_turn_request'],
      ).toJson(),
      fixtures['conversation_turn_request'],
    );
    expect(
      FinishConversationRequest.fromJson(
        fixtures['finish_conversation_request'],
      ).toJson(),
      fixtures['finish_conversation_request'],
    );
  });
  test(
    'all wire levels and nil uppercase identifiers retain exact spelling',
    () {
      for (final level in AiTextLevel.values) {
        final request = StartConversationRequest(
          scenarioId: id,
          level: level,
          clientEventId: nil,
        );
        expect(StartConversationRequest.fromJson(request.toJson()).toJson(), {
          'scenario_id': id,
          'jlpt_level': level.wireName,
          'client_event_id': nil,
        });
      }
    },
  );
  test(
    'retry exports are fresh maps without mutating captured event identity',
    () {
      final request = ConversationTurnRequest(
        sessionId: id,
        clientEventId: nil,
        textJa: '  こんにちは。  ',
      );
      final wire = request.toJson();
      wire['client_event_id'] = id;
      wire['session_id'] = nil;
      wire['text_ja'] = 'changed';
      expect(request.toJson(), {
        'session_id': id,
        'client_event_id': nil,
        'text_ja': '  こんにちは。  ',
      });
      final input = {'session_id': id, 'client_event_id': nil};
      final finish = FinishConversationRequest.fromJson(input);
      input['session_id'] = nil;
      final out = finish.toJson()..['client_event_id'] = id;
      expect(out, isNot(finish.toJson()));
      expect(finish.toJson(), {'session_id': id, 'client_event_id': nil});
      final start = StartConversationRequest(
        scenarioId: id,
        level: AiTextLevel.n4,
        clientEventId: nil,
      );
      start.toJson()['scenario_id'] = nil;
      expect(start.scenarioId, id);
    },
  );
  test(
    'Unicode limits count code points and preserve combining characters and whitespace',
    () {
      for (final text in [
        ' ',
        '  か\u3099  ',
        repeat('日', 5000),
        repeat('😀', 5000),
      ]) {
        expect(
          ConversationTurnRequest(
            sessionId: id,
            clientEventId: nil,
            textJa: text,
          ).textJa,
          text,
        );
      }
      for (final text in [
        '',
        repeat('日', 5001),
        repeat('😀', 5001),
        repeat('か\u3099', 2501),
      ]) {
        expect(
          () => ConversationTurnRequest(
            sessionId: id,
            clientEventId: nil,
            textJa: text,
          ),
          throwsFormatException,
        );
      }
    },
  );
  test('invalid identifiers are rejected in every constructor field', () {
    for (final bad in [
      '',
      ' $id',
      '$id ',
      '00000000-0000-0000-0000-00000000000Z',
      repeat('a', 1000),
    ]) {
      expect(
        () => StartConversationRequest(
          scenarioId: bad,
          level: AiTextLevel.n5,
          clientEventId: nil,
        ),
        throwsFormatException,
      );
      expect(
        () => StartConversationRequest(
          scenarioId: nil,
          level: AiTextLevel.n5,
          clientEventId: bad,
        ),
        throwsFormatException,
      );
      expect(
        () => ConversationTurnRequest(
          sessionId: bad,
          clientEventId: nil,
          textJa: '日',
        ),
        throwsFormatException,
      );
      expect(
        () => ConversationTurnRequest(
          sessionId: nil,
          clientEventId: bad,
          textJa: '日',
        ),
        throwsFormatException,
      );
      expect(
        () => FinishConversationRequest(sessionId: bad, clientEventId: nil),
        throwsFormatException,
      );
      expect(
        () => FinishConversationRequest(sessionId: nil, clientEventId: bad),
        throwsFormatException,
      );
    }
  });
  test(
    'decoders reject missing extra null wrong typed and authority fields',
    () {
      final decoders = <String, Object Function(Object?)>{
        'start_conversation_request': StartConversationRequest.fromJson,
        'conversation_turn_request': ConversationTurnRequest.fromJson,
        'finish_conversation_request': FinishConversationRequest.fromJson,
      };
      for (final entry in decoders.entries) {
        final valid = Map<String, Object?>.from(
          fixtures[entry.key]! as Map<String, Object?>,
        );
        for (final input in [null, true, 1, <Object?>[], 'PRIVATE']) {
          expect(() => entry.value(input), throwsFormatException);
        }
        for (final field in valid.keys) {
          expect(
            () => entry.value(Map<String, Object?>.from(valid)..remove(field)),
            throwsFormatException,
          );
          for (final bad in [null, true, 1, <Object?>[], <String, Object?>{}]) {
            expect(
              () =>
                  entry.value(Map<String, Object?>.from(valid)..[field] = bad),
              throwsFormatException,
            );
          }
        }
        for (final field in [
          'user_id',
          'role',
          'messages',
          'access_token',
          'audio_ref',
          'operation',
        ]) {
          expect(
            () => entry.value({...valid, field: 'PRIVATE'}),
            throwsFormatException,
          );
        }
      }
      for (final bad in ['n5', 'N0', 'N6', ' N4', 'N4 ']) {
        expect(
          () => StartConversationRequest.fromJson({
            'scenario_id': id,
            'jlpt_level': bad,
            'client_event_id': nil,
          }),
          throwsFormatException,
        );
      }
    },
  );
  test('failure exposes no raw input or source payload', () {
    try {
      ConversationTurnRequest.fromJson({
        'session_id': 'PRIVATE_SECRET',
        'client_event_id': nil,
        'text_ja': 'PRIVATE_TEXT',
      });
      fail('expected rejection');
    } on FormatException catch (error) {
      expect(error.message, 'Invalid conversation request');
      expect(error.source, isNull);
      expect(error.toString(), isNot(contains('PRIVATE')));
    }
  });
}
