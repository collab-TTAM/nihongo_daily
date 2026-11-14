import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';

const _project = 'https://receipt-test.supabase.invalid';
const _owner = 'a1000000-0000-4000-8000-000000000001';
const _other = 'a1000000-0000-4000-8000-000000000002';
const _event = 'AB000000-0000-4000-8000-000000000001';
const _session = 'b1000000-0000-4000-8000-000000000001';

ConversationReceiptReference _start({
  String project = _project,
  String owner = _owner,
  String event = _event,
}) => ConversationReceiptReference.fromStart(
  projectUrl: project,
  ownerId: owner,
  request: StartConversationRequest(
    scenarioId: _session,
    level: AiTextLevel.n4,
    clientEventId: event,
  ),
);

void _reject(void Function() action) {
  try {
    action();
  } on FormatException catch (error) {
    expect(error.message, 'Invalid conversation receipt reference');
    expect(error.source, isNull);
    expect(error.offset, isNull);
    expect(error.toString(), isNot(contains('PRIVATE')));
    return;
  }
  fail('Invalid reference was accepted');
}

void main() {
  test('typed start turn finish references contain only receipt metadata', () {
    final turn = ConversationTurnRequest(
      sessionId: _session,
      clientEventId: _event,
      textJa: '  日\u3099😀 TEST_ONLY_PRIVATE_TEXT  ',
    );
    final original = jsonEncode(turn.toJson());
    final references = [
      _start(),
      ConversationReceiptReference.fromTurn(
        projectUrl: _project,
        ownerId: _owner,
        request: turn,
      ),
      ConversationReceiptReference.fromFinish(
        projectUrl: _project,
        ownerId: _owner,
        request: FinishConversationRequest(
          sessionId: _session,
          clientEventId: _event,
        ),
      ),
    ];
    for (var i = 0; i < references.length; i++) {
      final reference = references[i];
      expect(reference.operation, ConversationReceiptOperation.values[i]);
      expect(reference.clientEventId, _event);
      expect(reference.toJson(), {
        'version': 1,
        'project_origin': _project,
        'owner_id': _owner,
        'operation': ConversationReceiptOperation.values[i].wireName,
        'client_event_id': _event,
      });
      final encoded = reference.encode();
      expect(encoded, isNot(contains('PRIVATE')));
      expect(encoded, isNot(contains('text_ja')));
      expect(encoded, isNot(contains('session_id')));
      expect(encoded, isNot(contains('scenario_id')));
      expect(encoded, isNot(contains('token')));
      expect(encoded, isNot(contains('日')));
      expect(
        utf8.encode(encoded).length,
        lessThanOrEqualTo(ConversationReceiptReference.maxEncodedBytes),
      );
      expect(
        ConversationReceiptReference.decode(encoded).toJson(),
        reference.toJson(),
      );
    }
    expect(references.map((r) => r.encode()).toSet(), hasLength(3));
    expect(jsonEncode(turn.toJson()), original);
  });

  test('origin aliases and logical owner casing share only local scope', () {
    final reference = _start(
      project: 'HTTPS://RECEIPT-TEST.SUPABASE.INVALID:443/',
    );
    expect(reference.projectOrigin, _project);
    expect(
      reference.matchesScope(
        projectUrl: '$_project/',
        ownerId: _owner.toUpperCase(),
      ),
      isTrue,
    );
    for (final project in [
      'https://other.supabase.invalid',
      '$_project:444',
      'http://receipt-test.supabase.invalid',
      '$_project/functions/v1/start_conversation',
      'TEST_ONLY_PRIVATE_URL',
    ]) {
      expect(
        reference.matchesScope(projectUrl: project, ownerId: _owner),
        isFalse,
      );
    }
    expect(
      reference.matchesScope(projectUrl: _project, ownerId: _other),
      isFalse,
    );
    expect(
      reference.matchesScope(projectUrl: _project, ownerId: 'PRIVATE'),
      isFalse,
    );
  });

  test('trusted IPv6 and explicit nondefault port partition scope', () {
    final reference = _start(project: 'https://[2001:DB8::1]:444/');
    expect(reference.projectOrigin, 'https://[2001:db8::1]:444');
    expect(
      reference.matchesScope(
        projectUrl: 'https://[2001:db8::1]:444',
        ownerId: _owner,
      ),
      isTrue,
    );
    expect(
      reference.matchesScope(
        projectUrl: 'https://[2001:db8::1]',
        ownerId: _owner,
      ),
      isFalse,
    );
  });

  test(
    'UUID spelling and schema permitted nil IDs are retained without generating IDs',
    () {
      const nil = '00000000-0000-0000-0000-000000000000';
      final reference = _start(owner: nil, event: nil);
      expect(reference.ownerId, nil);
      expect(reference.clientEventId, nil);
      expect(_start().clientEventId, _event);
      expect(
        ConversationReceiptReference.decode(_start().encode()).clientEventId,
        _event,
      );
    },
  );

  test('exact version keys types operation and UUIDs are required', () {
    final good = _start().toJson();
    for (final key in good.keys) {
      final missing = Map<String, Object?>.from(good)..remove(key);
      _reject(() => ConversationReceiptReference.fromJson(missing));
      final nullValue = Map<String, Object?>.from(good)..[key] = null;
      _reject(() => ConversationReceiptReference.fromJson(nullValue));
    }
    for (final entry in <String, List<Object?>>{
      'version': [0, 2, 1.0, '1', true],
      'owner_id': ['', 'PRIVATE', 1, <Object?>[], ' $_owner', '$_owner '],
      'client_event_id': ['', 'PRIVATE', 1, <String, Object?>{}],
      'operation': ['', 'tutor_explain', 'START_CONVERSATION', 1, <Object?>[]],
      'project_origin': [1, <Object?>[], '$_project/', _project.toUpperCase()],
    }.entries) {
      for (final value in entry.value) {
        final bad = Map<String, Object?>.from(good)..[entry.key] = value;
        _reject(() => ConversationReceiptReference.fromJson(bad));
      }
    }
    for (final value in [
      null,
      1,
      true,
      'PRIVATE',
      <Object?>[],
      <Object?, Object?>{1: 'x'},
    ]) {
      _reject(() => ConversationReceiptReference.fromJson(value));
    }
  });

  test(
    'token transcript response claim and nested payload fields are rejected',
    () {
      for (final key in [
        'access_token',
        'refresh_token',
        'text_ja',
        'request',
        'response',
        'dispatch_token',
        'session_id',
        'expires_at',
      ]) {
        final bad = Map<String, Object?>.from(_start().toJson())
          ..[key] = {'PRIVATE': 'TEST_ONLY_PRIVATE'};
        _reject(() => ConversationReceiptReference.fromJson(bad));
        _reject(() => ConversationReceiptReference.decode(jsonEncode(bad)));
      }
    },
  );

  test(
    'only canonical local encoding is accepted including duplicate member rejection',
    () {
      final encoded = _start().encode();
      final reversed = Map<String, Object>.fromEntries(
        _start().toJson().entries.toList().reversed,
      );
      for (final bad in [
        ' $encoded',
        '$encoded\n',
        const JsonEncoder.withIndent('  ').convert(_start().toJson()),
        jsonEncode(reversed),
        encoded.replaceFirst('"version":1', '"version":1,"version":1'),
        encoded.replaceFirst('"version":1', '"version":2,"version":1'),
        encoded.replaceFirst('start_conversation', r'\u0073tart_conversation'),
        encoded.replaceFirst('"version":1', '"version":1.0'),
        '$encoded{}',
        '{"PRIVATE":',
      ]) {
        _reject(() => ConversationReceiptReference.decode(bad));
      }
    },
  );

  test('encoded byte limits and parser errors never echo their input', () {
    _reject(() => ConversationReceiptReference.decode('P' * 1025));
    _reject(() => ConversationReceiptReference.decode('😀' * 300));
    _reject(
      () => ConversationReceiptReference.decode('TEST_ONLY_PRIVATE_JSON'),
    );
    final bad = _start().toJson()..['owner_id'] = 'PRIVATE' * 100;
    _reject(() => ConversationReceiptReference.fromJson(bad));
  });

  test(
    'invalid project configuration and owner IDs fail with fixed errors',
    () {
      for (final project in [
        '',
        'https://',
        'http://host.invalid',
        'https://user:PRIVATE@host.invalid',
        '$_project/path',
        '$_project?',
        '$_project#',
        '$_project:0',
        '$_project:65536',
        '$_project:PRIVATE',
        '$_project\n',
        ' https://host.invalid',
        'https://日本.invalid',
        'https://${'x' * 480}.invalid',
      ]) {
        _reject(() => _start(project: project));
      }
      _reject(() => _start(owner: 'PRIVATE'));
    },
  );

  test(
    'decoded values are immutable snapshots and exported objects are fresh',
    () {
      final input = Map<String, Object?>.from(_start().toJson());
      final reference = ConversationReceiptReference.fromJson(input);
      input['owner_id'] = _other;
      input['operation'] = 'finish_conversation';
      reference.toJson().clear();
      expect(reference.ownerId, _owner);
      expect(reference.operation, ConversationReceiptOperation.start);
      expect(reference.toJson(), _start().toJson());
      expect(reference.toJson(), isNot(same(reference.toJson())));
      expect(reference.toString(), 'ConversationReceiptReference');
      expect(reference.toString(), isNot(contains(_owner)));
      expect(reference.toString(), isNot(contains(_event)));
      expect(reference.toString(), isNot(contains(_project)));
    },
  );
}
