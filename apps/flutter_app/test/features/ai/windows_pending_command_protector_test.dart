// TEST ONLY mocked MethodChannel/Auth. Not DPAPI, hosted Auth or recovery proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/windows_pending_command_protector.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_requests.dart';
import 'package:nihongo_daily/features/ai/domain/pending_conversation_command_envelope.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

const origin = 'https://command-facade.test';
const owner = 'a1000000-0000-4000-8000-000000000001';
const other = 'a1000000-0000-4000-8000-000000000002';
const channel = MethodChannel('nihongo_daily/conversation_receipts_v1');
final scope = ConversationReceiptScope(projectUrl: origin, ownerId: owner);

final class Auth implements ReviewAuth {
  ReviewSession? session = ReviewSession(userId: owner);
  bool fail = false;
  @override
  ReviewSession? get currentSession {
    if (fail) throw StateError('PRIVATE_AUTH');
    return session;
  }
}

Matcher failure(CommandProtectionError code) => isA<CommandProtectionFailure>()
    .having((e) => e.code, 'code', code)
    .having((e) => e.toString().contains('PRIVATE'), 'safe', false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Auth auth;
  late bool ready;
  late Map<String, Object?> fixtures;
  final calls = <MethodCall>[];
  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  setUp(() {
    auth = Auth();
    ready = true;
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  WindowsPendingCommandProtector open({bool Function()? check}) {
    final result = WindowsPendingCommandProtector(
      auth: auth,
      scope: scope,
      isReady: check ?? () => ready,
    );
    addTearDown(result.revoke);
    return result;
  }

  PendingConversationCommandEnvelope command([
    String op = 'start_conversation',
    String url = origin,
  ]) {
    final value = fixtures['${op}_request'];
    return switch (op) {
      'start_conversation' => PendingConversationCommandEnvelope.fromStart(
        projectUrl: url,
        ownerId: owner,
        request: StartConversationRequest.fromJson(value),
      ),
      'conversation_turn' => PendingConversationCommandEnvelope.fromTurn(
        projectUrl: url,
        ownerId: owner,
        request: ConversationTurnRequest.fromJson(value),
      ),
      _ => PendingConversationCommandEnvelope.fromFinish(
        projectUrl: url,
        ownerId: owner,
        request: FinishConversationRequest.fromJson(value),
      ),
    };
  }

  void mock(Future<Object?> Function(MethodCall) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  test(
    'all three typed commands use fixed scope bytes and strict decode',
    () async {
      Uint8List? plain;
      mock((call) async {
        final args = call.arguments as Map<Object?, Object?>;
        expect(args.keys.toSet(), {'target', 'bytes'});
        expect(
          args['target'],
          'NihongoDaily.ConversationReceipt.v1|$origin|$owner',
        );
        expect(args['bytes'], isA<Uint8List>());
        if (call.method == 'protectCommand') {
          plain = args['bytes']! as Uint8List;
          return Uint8List.fromList([7, 8]);
        }
        expect(call.method, 'unprotectCommand');
        return plain;
      });
      final p = open();
      for (final op in [
        'start_conversation',
        'conversation_turn',
        'finish_conversation',
      ]) {
        final e = command(op);
        final cipher = await p.protect(e);
        expect(cipher, [7, 8]);
        expect(utf8.decode(plain!), e.encode());
        expect((await p.unprotect(cipher)).encode(), e.encode());
      }
      expect(calls.length, 6);
    },
  );
  test('foreign command and invalid cipher bounds dispatch nothing', () async {
    mock((_) async => Uint8List(1));
    final p = open();
    await expectLater(
      p.protect(command('start_conversation', 'https://foreign.test')),
      throwsA(failure(CommandProtectionError.invalidInput)),
    );
    for (final input in [Uint8List(0), Uint8List(65537)]) {
      await expectLater(
        p.unprotect(input),
        throwsA(failure(CommandProtectionError.invalidInput)),
      );
    }
    expect(calls, isEmpty);
  });
  test('wrong platform and missing receiver fail closed', () async {
    final p = open();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await expectLater(
      p.protect(command()),
      throwsA(failure(CommandProtectionError.unavailable)),
    );
    expect(calls, isEmpty);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await expectLater(
      p.protect(command()),
      throwsA(failure(CommandProtectionError.unavailable)),
    );
  });
  test(
    'native errors and malformed typed responses never expose details',
    () async {
      final p = open();
      for (final value in [
        null,
        true,
        'PRIVATE',
        <int>[1],
        Uint8List(0),
        Uint8List(65537),
      ]) {
        mock((_) async => value);
        await expectLater(
          p.protect(command()),
          throwsA(failure(CommandProtectionError.unavailable)),
        );
      }
      mock(
        (_) async => throw PlatformException(
          code: 'PRIVATE',
          message: 'PRIVATE_TOKEN',
          details: owner,
        ),
      );
      await expectLater(
        p.protect(command()),
        throwsA(failure(CommandProtectionError.unavailable)),
      );
    },
  );
  test(
    'unprotect rejects oversized nonUTF8 noncanonical and foreign envelopes',
    () async {
      final p = open();
      for (final value in [
        Uint8List(32769),
        Uint8List.fromList([255]),
        Uint8List.fromList(utf8.encode('${command().encode()} ')),
        Uint8List.fromList(
          utf8.encode(
            command('start_conversation', 'https://foreign.test').encode(),
          ),
        ),
      ]) {
        mock((_) async => value);
        await expectLater(
          p.unprotect(Uint8List(1)),
          throwsA(failure(CommandProtectionError.unavailable)),
        );
      }
    },
  );
  test(
    'constructor requires current ready matching owner and hides getter failure',
    () {
      ready = false;
      expect(open, throwsA(failure(CommandProtectionError.unauthorized)));
      ready = true;
      auth.session = ReviewSession(userId: other);
      expect(open, throwsA(failure(CommandProtectionError.unauthorized)));
      auth.session = null;
      expect(open, throwsA(failure(CommandProtectionError.unauthorized)));
      auth.fail = true;
      expect(open, throwsA(failure(CommandProtectionError.unauthorized)));
    },
  );
  test('same owner replacement readiness loss and revoke are sticky', () async {
    mock((_) async => Uint8List(1));
    final p = open();
    ready = false;
    expect(p.isCurrent, false);
    ready = true;
    await expectLater(
      p.protect(command()),
      throwsA(failure(CommandProtectionError.unauthorized)),
    );
    final q = open();
    auth.session = ReviewSession(userId: owner);
    await expectLater(
      q.protect(command()),
      throwsA(failure(CommandProtectionError.unauthorized)),
    );
    final r = open();
    r.revoke();
    await expectLater(
      r.unprotect(Uint8List(1)),
      throwsA(failure(CommandProtectionError.unauthorized)),
    );
    expect(calls, isEmpty);
  });
  for (final error in [false, true]) {
    test('late native result after A-B-A is suppressed error=$error', () async {
      final held = Completer<Object?>();
      mock((_) => held.future);
      final p = open();
      final future = p.unprotect(Uint8List(1));
      final assertion = expectLater(
        future,
        throwsA(failure(CommandProtectionError.unauthorized)),
      );
      auth.session = ReviewSession(userId: other);
      auth.session = ReviewSession(userId: owner);
      if (error) {
        held.completeError(StateError('PRIVATE_LATE'));
      } else {
        held.complete(Uint8List.fromList(utf8.encode(command().encode())));
      }
      await assertion;
      expect(p.isCurrent, false);
      expect(calls.length, 1);
    });
  }
  test(
    'external timeout retains actual busy lease and immutable input snapshot',
    () async {
      final held = Completer<Object?>();
      final entered = Completer<Uint8List>();
      mock((call) {
        entered.complete(
          (call.arguments as Map<Object?, Object?>)['bytes']! as Uint8List,
        );
        return held.future;
      });
      final p = open();
      final input = Uint8List.fromList([1, 2]);
      final work = p.unprotect(input);
      final snapshot = await entered.future;
      input[0] = 9;
      expect(snapshot, [1, 2]);
      await expectLater(
        work.timeout(Duration.zero),
        throwsA(isA<TimeoutException>()),
      );
      await expectLater(
        p.protect(command()),
        throwsA(failure(CommandProtectionError.busy)),
      );
      p.revoke();
      held.complete(Uint8List.fromList(utf8.encode(command().encode())));
      await expectLater(
        work,
        throwsA(failure(CommandProtectionError.unauthorized)),
      );
      expect(calls.length, 1);
    },
  );
  test('synchronous readiness revocation prevents native dispatch', () async {
    mock((_) async => Uint8List(1));
    WindowsPendingCommandProtector? p;
    final result = open(
      check: () {
        p?.revoke();
        return true;
      },
    );
    p = result;
    await expectLater(
      result.protect(command()),
      throwsA(failure(CommandProtectionError.unauthorized)),
    );
    expect(calls, isEmpty);
  });
  test('readiness reentry cannot open a second native operation', () async {
    mock((_) async => Uint8List(1));
    WindowsPendingCommandProtector? p;
    Future<void>? nestedAssertion;
    var trigger = false;
    final result = open(
      check: () {
        if (trigger) {
          trigger = false;
          nestedAssertion = expectLater(
            p!.protect(command()),
            throwsA(failure(CommandProtectionError.busy)),
          );
        }
        return true;
      },
    );
    p = result;
    trigger = true;
    await result.protect(command());
    await nestedAssertion!;
    expect(calls.length, 1);
  });
  test('nested availability read is redacted without revoking outer owner', () {
    WindowsPendingCommandProtector? p;
    final nested = <bool>[];
    final result = open(
      check: () {
        if (p != null) nested.add(p!.isCurrent);
        return true;
      },
    );
    p = result;
    expect(result.isCurrent, true);
    expect(nested, [false, false]);
    expect(calls, isEmpty);
    result.revoke();
    expect(result.isCurrent, false);
    expect(nested, [false, false]);
  });
  for (final decrypt in [false, true]) {
    test(
      'standalone readiness read blocks native reentry decrypt=$decrypt',
      () async {
        mock((_) async => Uint8List(1));
        WindowsPendingCommandProtector? p;
        Future<void>? nestedAssertion;
        var trigger = false;
        final result = open(
          check: () {
            if (trigger) {
              trigger = false;
              nestedAssertion = expectLater(
                decrypt ? p!.unprotect(Uint8List(1)) : p!.protect(command()),
                throwsA(failure(CommandProtectionError.busy)),
              );
            }
            return true;
          },
        );
        p = result;
        trigger = true;
        expect(result.isCurrent, true);
        await nestedAssertion!;
        expect(calls, isEmpty);
        // The denied callback did not poison readiness or reserve the wire lease.
        await result.protect(command());
        expect(calls.length, 1);
        expect(result.isCurrent, true);
      },
    );
  }
}
