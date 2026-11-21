// TEST ONLY frozen fixtures and bounded malformed/aliasing mutations.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_responses.dart';

const id = 'ABCDEFAB-1234-0000-FFFF-ABCDEFABCDEF';
const nil = '00000000-0000-0000-0000-000000000000';
String repeat(String text, int n) => List.filled(n, text).join();
Map<String, Object?> message() => {
  'id': id,
  'role': 'assistant',
  'text_ja': '  か\u3099  ',
  'text_vi': null,
  'audio_ref': null,
  'sequence_no': 0,
};
Map<String, Object?> ref() => {'item_type': 'GRAMMAR', 'item_id': nil};
Map<String, Object?> correction() => {
  'original_text': '原文',
  'corrected_text': '修正',
  'explanation_vi': 'TEST ONLY',
  'item_refs': [ref()],
};
Map<String, Object?> finish() => {
  'scores': {'grammar': 0, 'vocabulary': 50.5, 'fluency': 100},
  'errors': [correction()],
  'strengths_vi': ['TEST ONLY strength'],
  'focus_next_vi': ['TEST ONLY focus'],
  'srs_recommendations': [ref()],
};
void main() {
  late Map<String, Object?> fixtures;
  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  test('three strict responses round trip unchanged frozen fixtures', () {
    expect(
      StartConversationResponse.fromJson(
        fixtures['start_conversation_response'],
      ).toJson(),
      fixtures['start_conversation_response'],
    );
    expect(
      ConversationTurnResponse.fromJson(
        fixtures['conversation_turn_response'],
      ).toJson(),
      fixtures['conversation_turn_response'],
    );
    expect(
      FinishConversationResponse.fromJson(
        fixtures['finish_conversation_response'],
      ).toJson(),
      fixtures['finish_conversation_response'],
    );
  });
  test(
    'optional feedback omitted and empty remain distinct and null is invalid',
    () {
      final absent = ConversationTurnResponse.fromJson({
        'assistant_message': message(),
      });
      expect(absent.liveFeedback, isNull);
      expect(absent.toJson().containsKey('live_feedback'), isFalse);
      final empty = ConversationTurnResponse.fromJson({
        'assistant_message': message(),
        'live_feedback': <Object?>[],
      });
      expect(empty.liveFeedback, isEmpty);
      expect(empty.toJson()['live_feedback'], isEmpty);
      expect(
        () => ConversationTurnResponse.fromJson({
          'assistant_message': message(),
          'live_feedback': null,
        }),
        throwsFormatException,
      );
      final m = ConversationAssistantMessage.fromJson(message());
      expect(m.id, id);
      expect(m.textVi, isNull);
      expect(m.audioRef, isNull);
      expect(m.toJson(), message());
      expect(
        StartConversationResponse.fromJson({
          'session_id': nil,
          'assistant_message': message(),
        }).sessionId,
        nil,
      );
    },
  );
  test(
    'message exact keys role identity nullable fields and integer sequence are enforced',
    () {
      for (final field in message().keys) {
        expect(
          () => ConversationAssistantMessage.fromJson(message()..remove(field)),
          throwsFormatException,
        );
      }
      for (final role in ['user', 'system', 'Assistant', null]) {
        expect(
          () =>
              ConversationAssistantMessage.fromJson(message()..['role'] = role),
          throwsFormatException,
        );
      }
      for (final seq in [-1, 1.5, 1.0, true, '1', null]) {
        expect(
          () => ConversationAssistantMessage.fromJson(
            message()..['sequence_no'] = seq,
          ),
          throwsFormatException,
        );
      }
      for (final field in ['text_ja', 'text_vi', 'audio_ref']) {
        for (final bad in ['', true, 42, <Object?>[]]) {
          expect(
            () =>
                ConversationAssistantMessage.fromJson(message()..[field] = bad),
            throwsFormatException,
          );
        }
      }
      for (final bad in ['bad', ' $id', '$id ', null]) {
        expect(
          () => ConversationAssistantMessage.fromJson(message()..['id'] = bad),
          throwsFormatException,
        );
        expect(
          () => StartConversationResponse.fromJson({
            'session_id': bad,
            'assistant_message': message(),
          }),
          throwsFormatException,
        );
      }
      expect(
        () =>
            ConversationAssistantMessage.fromJson(message()..['user_id'] = nil),
        throwsFormatException,
      );
    },
  );
  test(
    'message Unicode bounds opaque audio and exact sequence are preserved',
    () {
      final valid = message()
        ..['text_ja'] = repeat('😀', 5000)
        ..['text_vi'] = repeat('日', 5000)
        ..['audio_ref'] = repeat('😀', 1000)
        ..['sequence_no'] = 123456789;
      expect(ConversationAssistantMessage.fromJson(valid).toJson(), valid);
      for (final field in ['text_ja', 'text_vi', 'audio_ref']) {
        expect(
          () => ConversationAssistantMessage.fromJson(
            message()
              ..[field] = repeat('😀', field == 'audio_ref' ? 1001 : 5001),
          ),
          throwsFormatException,
        );
      }
      final opaque = message()..['audio_ref'] = 'javascript:TEST_ONLY_OPAQUE';
      expect(
        ConversationAssistantMessage.fromJson(opaque).audioRef,
        opaque['audio_ref'],
      );
    },
  );
  test('scores preserve finite inclusive integer and fractional values', () {
    final values = {'grammar': 0, 'vocabulary': 50.5, 'fluency': 100};
    expect(ConversationScores.fromJson(values).toJson(), values);
    for (final key in values.keys) {
      expect(
        () => ConversationScores.fromJson(
          Map<String, Object?>.from(values)..remove(key),
        ),
        throwsFormatException,
      );
      for (final bad in [
        -0.1,
        100.1,
        double.nan,
        double.infinity,
        double.negativeInfinity,
        true,
        '50',
        null,
      ]) {
        expect(
          () => ConversationScores.fromJson(
            Map<String, Object?>.from(values)..[key] = bad,
          ),
          throwsFormatException,
        );
      }
    }
    expect(
      () => ConversationScores.fromJson({...values, 'total': 50}),
      throwsFormatException,
    );
  });
  test(
    'all feedback summary and recommendation arrays accept 100 reject 101 and retain empties',
    () {
      final empty = finish()
        ..['errors'] = <Object?>[]
        ..['strengths_vi'] = <Object?>[]
        ..['focus_next_vi'] = <Object?>[]
        ..['srs_recommendations'] = <Object?>[];
      expect(FinishConversationResponse.fromJson(empty).toJson(), empty);
      final turn = {
        'assistant_message': message(),
        'live_feedback': List.generate(100, (_) => correction()),
      };
      expect(
        ConversationTurnResponse.fromJson(turn).liveFeedback,
        hasLength(100),
      );
      expect(
        () => ConversationTurnResponse.fromJson({
          ...turn,
          'live_feedback': List.generate(101, (_) => correction()),
        }),
        throwsFormatException,
      );
      for (final field in [
        'errors',
        'strengths_vi',
        'focus_next_vi',
        'srs_recommendations',
      ]) {
        final item = field == 'errors'
            ? correction()
            : field == 'srs_recommendations'
            ? ref()
            : 'TEST ONLY';
        final input = finish()..[field] = List.filled(100, item);
        expect(
          FinishConversationResponse.fromJson(input).toJson()[field],
          hasLength(100),
        );
        expect(
          () => FinishConversationResponse.fromJson(
            finish()..[field] = List.filled(101, item),
          ),
          throwsFormatException,
        );
        expect(
          () => FinishConversationResponse.fromJson(finish()..[field] = null),
          throwsFormatException,
        );
      }
      expect(
        () => FinishConversationResponse.fromJson(
          finish()..['strengths_vi'] = [''],
        ),
        throwsFormatException,
      );
      expect(
        () => FinishConversationResponse.fromJson(
          finish()..['focus_next_vi'] = [repeat('日', 2001)],
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'input aliases exports and every nested list cannot mutate captured responses',
    () {
      final input = finish();
      final captured = FinishConversationResponse.fromJson(input);
      final expected = captured.toJson();
      (input['errors']! as List<Object?>).clear();
      (input['scores']! as Map<String, Object?>)['grammar'] = 99;
      final out = captured.toJson();
      (out['strengths_vi']! as List<String>).clear();
      (out['srs_recommendations']! as List<Map<String, Object>>).clear();
      expect(captured.toJson(), expected);
      expect(() => captured.errors.clear(), throwsUnsupportedError);
      expect(() => captured.strengthsVi.clear(), throwsUnsupportedError);
      expect(() => captured.focusNextVi.clear(), throwsUnsupportedError);
      expect(() => captured.srsRecommendations.clear(), throwsUnsupportedError);
      expect(
        () => captured.errors.single.itemRefs.clear(),
        throwsUnsupportedError,
      );
      final errors = [correction()];
      final turn = ConversationTurnResponse.fromJson({
        'assistant_message': message(),
        'live_feedback': errors,
      });
      errors.clear();
      expect(turn.liveFeedback, hasLength(1));
      expect(() => turn.liveFeedback!.clear(), throwsUnsupportedError);
      final exported = turn.toJson();
      (exported['assistant_message']! as Map<String, Object?>)['text_ja'] =
          'changed';
      (exported['live_feedback']! as List<Map<String, Object>>).clear();
      expect(turn.assistantMessage.textJa, message()['text_ja']);
      expect(turn.liveFeedback, hasLength(1));
      final start = StartConversationResponse.fromJson({
        'session_id': nil,
        'assistant_message': message(),
      });
      (start.toJson()['assistant_message']! as Map<String, Object?>)['id'] =
          nil;
      expect(start.assistantMessage.id, id);
    },
  );
  test(
    'nested corrections references and mixed error success fail closed without echo',
    () {
      final decoders = <String, Object Function(Object?)>{
        'start_conversation_response': StartConversationResponse.fromJson,
        'conversation_turn_response': ConversationTurnResponse.fromJson,
        'finish_conversation_response': FinishConversationResponse.fromJson,
      };
      for (final entry in decoders.entries) {
        final valid = Map<String, Object?>.from(
          fixtures[entry.key]! as Map<String, Object?>,
        );
        for (final input in [null, true, 1, 'PRIVATE', <Object?>[]]) {
          expect(() => entry.value(input), throwsFormatException);
        }
        for (final key in valid.keys.where((k) => k != 'live_feedback')) {
          expect(
            () => entry.value(Map<String, Object?>.from(valid)..remove(key)),
            throwsFormatException,
          );
        }
        expect(
          () => entry.value({...valid, 'code': 'INTERNAL_ERROR'}),
          throwsFormatException,
        );
      }
      for (final bad in [
        correction()..['item_refs'] = [ref()..['item_type'] = 'OTHER'],
        correction()..['original_text'] = '',
        correction()..['secret'] = 'PRIVATE',
      ]) {
        for (final turn in [true, false]) {
          final decode = turn
              ? ConversationTurnResponse.fromJson
              : FinishConversationResponse.fromJson;
          final input = turn
              ? {
                  'assistant_message': message(),
                  'live_feedback': [bad],
                }
              : (finish()..['errors'] = [bad]);
          try {
            decode(input);
            fail('expected invalid payload');
          } on FormatException catch (e) {
            expect(e.message, 'Invalid conversation response');
            expect(e.source, isNull);
            expect(e.toString(), isNot(contains('PRIVATE')));
          }
        }
      }
    },
  );
}
