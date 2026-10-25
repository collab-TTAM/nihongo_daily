// TEST ONLY injected Auth/read port. No SDK, live catalog or default activation.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/data/captured_conversation_scenarios.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/domain/ai_text_models.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';

final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(
    userId: '11111111-1111-4111-8111-111111111111',
  );
}

Map<String, Object?> row({String level = 'N5'}) => {
  'id': 'AAAAAAAA-1111-4111-8111-111111111111',
  'jlpt_level': level,
  'title_vi': '  Xin chào  ',
  'title_ja': '<b>こんにちは</b>',
  'description_vi': 'Mô tả',
  'content_version': 1,
  'is_active': true,
};

final class Port implements ConversationScenarioReadPort {
  int calls = 0;
  ReviewSession? captured;
  AiTextLevel? selected;
  Future<Object?> Function()? reply;
  @override
  Future<Object?> read({
    required ReviewSession capturedSession,
    required AiTextLevel level,
  }) {
    calls++;
    captured = capturedSession;
    selected = level;
    return reply?.call() ?? Future<Object?>.value([row(level: level.wireName)]);
  }
}

Matcher failure(AiTextErrorCode code) =>
    throwsA(isA<AiTextFailure>().having((e) => e.code, 'code', code));
void main() {
  test(
    'no auto read, exact captured level, immutable detached literal projection',
    () async {
      final a = Auth();
      final p = Port();
      final raw = row();
      p.reply = () async => [raw];
      final r = CapturedConversationScenarios(
        auth: a,
        port: p,
        isReady: () => true,
      );
      expect(p.calls, 0);
      final result = await r.load(AiTextLevel.n5);
      expect(identical(p.captured, a.currentSession), isTrue);
      expect(p.selected, AiTextLevel.n5);
      expect(result.single.id, raw['id']);
      expect(result.single.titleVi, '  Xin chào  ');
      expect(result.single.titleJa, '<b>こんにちは</b>');
      raw['title_vi'] = 'mutated';
      expect(result.single.titleVi, '  Xin chào  ');
      expect(() => result.clear(), throwsUnsupportedError);
      expect(r.isBusy, isFalse);
    },
  );
  test(
    'N4 and honest empty catalog, no cached or invented scenarios',
    () async {
      final p = Port();
      final r = CapturedConversationScenarios(
        auth: Auth(),
        port: p,
        isReady: () => true,
      );
      expect((await r.load(AiTextLevel.n4)).single.level, AiTextLevel.n4);
      p.reply = () async => <Object>[];
      expect(await r.load(AiTextLevel.n4), isEmpty);
      expect(p.calls, 2);
    },
  );
  test('missing session and invalid timeout fail before any dispatch', () {
    final p = Port();
    expect(
      () => CapturedConversationScenarios(
        auth: Auth()..currentSession = null,
        port: p,
        isReady: () => true,
      ),
      throwsA(isA<AiTextFailure>()),
    );
    for (final t in [Duration.zero, const Duration(seconds: 16)]) {
      expect(
        () => CapturedConversationScenarios(
          auth: Auth(),
          port: p,
          isReady: () => true,
          timeout: t,
        ),
        throwsArgumentError,
      );
    }
    expect(p.calls, 0);
  });
  test('unsupported level releases local slot without dispatch', () async {
    final p = Port();
    final r = CapturedConversationScenarios(
      auth: Auth(),
      port: p,
      isReady: () => true,
    );
    await expectLater(
      r.load(AiTextLevel.n3),
      failure(AiTextErrorCode.validationFailure),
    );
    expect(r.isBusy, isFalse);
    expect(p.calls, 0);
    expect(await r.load(AiTextLevel.n5), hasLength(1));
  });
  test(
    'reject all malformed/extra/private/duplicate/mismatched rows atomically',
    () async {
      final variants = <Object?>[
        null,
        {},
        [
          row(),
          {...row(), 'system_context': 'PRIVATE'},
        ],
        [
          row(),
          {...row(), 'id': (row()['id']! as String).toLowerCase()},
        ],
        [row(level: 'N4')],
        [
          {...row(), 'is_active': false},
        ],
        [
          {...row(), 'is_active': 'true'},
        ],
        [
          {...row(), 'content_version': 1.0},
        ],
        [
          {...row(), 'content_version': 0},
        ],
        [
          {...row(), 'id': 'bad'},
        ],
        [
          {...row()}..remove('description_vi'),
        ],
        [
          {...row(), 'title_ja': null},
        ],
        [
          {...row(), 'title_vi': ' '},
        ],
        [
          {...row(), 'title_vi': List.filled(201, '語').join()},
        ],
        List.generate(101, (_) => row()),
      ];
      final p = Port();
      final r = CapturedConversationScenarios(
        auth: Auth(),
        port: p,
        isReady: () => true,
      );
      for (final value in variants) {
        p.reply = () async => value;
        await expectLater(
          r.load(AiTextLevel.n5),
          failure(AiTextErrorCode.internalError),
        );
        expect(r.isBusy, isFalse);
      }
    },
  );
  test(
    'Unicode point limits and maximum count/version accepted without trimming',
    () async {
      final p = Port();
      p.reply = () async => List.generate(
        100,
        (i) => {
          ...row(),
          'id': '11111111-1111-4111-8111-${i.toString().padLeft(12, '0')}',
          'title_vi': List.filled(200, '😀').join(),
          'content_version': 2147483647,
        },
      );
      final r = CapturedConversationScenarios(
        auth: Auth(),
        port: p,
        isReady: () => true,
      );
      expect(await r.load(AiTextLevel.n5), hasLength(100));
    },
  );
  test('held read excludes duplicate and port reentry until drained', () async {
    final p = Port();
    final held = Completer<Object?>();
    final r = CapturedConversationScenarios(
      auth: Auth(),
      port: p,
      isReady: () => true,
    );
    Future<void>? nested;
    p.reply = () {
      nested = expectLater(
        r.load(AiTextLevel.n4),
        throwsA(isA<AiTextRequestPending>()),
      );
      return held.future;
    };
    final first = r.load(AiTextLevel.n5);
    await nested;
    await expectLater(
      r.load(AiTextLevel.n5),
      throwsA(isA<AiTextRequestPending>()),
    );
    expect(p.calls, 1);
    held.complete([row()]);
    await first;
    expect(r.isBusy, isFalse);
  });
  for (final error in [false, true]) {
    test(
      'timeout keeps slot until late wire drains error=$error, no auto retry',
      () async {
        final p = Port();
        final held = Completer<Object?>();
        p.reply = () => held.future;
        final r = CapturedConversationScenarios(
          auth: Auth(),
          port: p,
          isReady: () => true,
          timeout: const Duration(milliseconds: 5),
        );
        await expectLater(
          r.load(AiTextLevel.n5),
          failure(AiTextErrorCode.networkUnavailable),
        );
        expect(r.isBusy, isTrue);
        await expectLater(
          r.load(AiTextLevel.n5),
          throwsA(isA<AiTextRequestPending>()),
        );
        if (error) {
          held.completeError(StateError('PRIVATE'));
        } else {
          held.complete([row()]);
        }
        await Future<void>.delayed(Duration.zero);
        expect(r.isBusy, isFalse);
        expect(p.calls, 1);
        p.reply = () async => [row()];
        expect(await r.load(AiTextLevel.n5), hasLength(1));
      },
    );
  }
  for (final mode in ['same-user', 'other-user', 'logout', 'ready', 'revoke']) {
    test('late response permanently fenced on $mode including A B A', () async {
      final a = Auth();
      final original = a.currentSession;
      final p = Port();
      var ready = true;
      final held = Completer<Object?>();
      p.reply = () => held.future;
      final r = CapturedConversationScenarios(
        auth: a,
        port: p,
        isReady: () => ready,
      );
      final first = r.load(AiTextLevel.n5);
      final assertion = expectLater(
        first,
        failure(AiTextErrorCode.unauthorized),
      );
      switch (mode) {
        case 'same-user':
          a.currentSession = ReviewSession(userId: original!.userId);
        case 'other-user':
          a.currentSession = ReviewSession(
            userId: '22222222-2222-4222-8222-222222222222',
          );
        case 'logout':
          a.currentSession = null;
        case 'ready':
          ready = false;
        case 'revoke':
          r.revoke();
      }
      expect(r.isCurrent, isFalse);
      a.currentSession = original;
      ready = true;
      held.complete([row()]);
      await assertion;
      expect(r.isCurrent, isFalse);
      expect(r.isBusy, isFalse);
      expect(p.calls, 1);
      await expectLater(
        r.load(AiTextLevel.n5),
        failure(AiTextErrorCode.unauthorized),
      );
    });
  }
  test(
    'safe raw errors, terminal unauthorized and getter revocation',
    () async {
      final p = Port();
      var broken = false;
      final r = CapturedConversationScenarios(
        auth: Auth(),
        port: p,
        isReady: () {
          if (broken) throw StateError('PRIVATE');
          return true;
        },
      );
      p.reply = () async => throw StateError('PRIVATE');
      await expectLater(
        r.load(AiTextLevel.n5),
        failure(AiTextErrorCode.internalError),
      );
      expect(r.isCurrent, isTrue);
      broken = true;
      expect(r.isCurrent, isFalse);
      broken = false;
      expect(r.isCurrent, isFalse);
      final s = CapturedConversationScenarios(
        auth: Auth(),
        port: p,
        isReady: () => true,
      );
      p.reply = () async =>
          throw const AiTextFailure(AiTextErrorCode.unauthorized);
      await expectLater(
        s.load(AiTextLevel.n5),
        failure(AiTextErrorCode.unauthorized),
      );
      expect(s.isCurrent, isFalse);
    },
  );
}
