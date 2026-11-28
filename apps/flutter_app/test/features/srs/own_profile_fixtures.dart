import 'dart:async';
import 'package:nihongo_daily/features/auth/data/own_profile_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_connection_registry.dart';

const owner = 'e2000000-0000-4000-8000-000000000001';
const other = 'e2000000-0000-4000-8000-000000000002';
Map<String, Object> profile([String id = owner]) => {
  'id': id,
  'display_name': '学習者',
  'preferred_jlpt': 'N4',
  'daily_target_minutes': 150,
  'timezone': 'Asia/Tokyo',
};
void check(bool value, String message) {
  if (!value) throw StateError(message);
}

final class Auth implements ReviewAuth {
  @override
  ReviewSession? currentSession = ReviewSession(userId: owner);
}

final class Transport implements ReviewRpcTransport {
  Completer<Object?>? reply;
  Object? result = profile();
  bool fail = false;
  int calls = 0;
  @override
  Future<Object?> invoke({
    required ReviewSession capturedSession,
    required String function,
    required Map<String, Object> params,
  }) {
    calls++;
    check(function == 'ensure_profile', 'wrong bootstrap endpoint');
    check(
      (params['p_request']! as Map<String, Object>).isEmpty &&
          params.length == 1,
      'bootstrap leaked caller fields',
    );
    if (fail) throw StateError('PRIVATE TOKEN / SQL');
    return reply?.future ?? Future.value(result);
  }
}

Future<void> expectCode(
  Future<Object?> operation,
  ReviewErrorCode expected,
) async {
  var failed = false;
  try {
    await operation;
  } on ReviewTransportFailure catch (error) {
    failed = error.code == expected;
  }
  check(failed, 'unexpected/missing safe profile error');
}

Future<void> verifyProfile(String scenario) async {
  final auth = Auth();
  final transport = Transport();
  final repository = RpcOwnProfileRepository(auth: auth, transport: transport);
  if (scenario == 'valid') {
    final value = await repository.ensure();
    check(
      value.id == owner &&
          value.displayName == '学習者' &&
          value.dailyTargetMinutes == 150,
      'profile projection changed',
    );
    check(
      value.toJson().toString() == profile().toString(),
      'profile encoder changed fields',
    );
  } else if (scenario == 'malformed') {
    for (final raw in <Object?>[
      null,
      [],
      {},
      {...profile(), 'id': other},
      {...profile(), 'display_name': 12},
      {...profile(), 'display_name': 'a' * 101},
      {...profile(), 'preferred_jlpt': 'N0'},
      {...profile(), 'daily_target_minutes': 6},
      {...profile(), 'daily_target_minutes': 1441},
      {...profile(), 'daily_target_minutes': 150.0},
      {...profile(), 'timezone': 'PRIVATE\\PATH'},
      {...profile(), 'timezone': ''},
      {...profile(), 'extra': true},
    ]) {
      transport.result = raw;
      await expectCode(repository.ensure(), ReviewErrorCode.internalError);
    }
  } else if (scenario == 'signed-out') {
    auth.currentSession = null;
    await expectCode(repository.ensure(), ReviewErrorCode.unauthorized);
    check(transport.calls == 0, 'signed-out bootstrap dispatched');
  } else if (scenario == 'late-session') {
    transport.reply = Completer();
    final pending = repository.ensure();
    auth.currentSession = ReviewSession(userId: other);
    auth.currentSession = ReviewSession(userId: owner);
    transport.reply!.complete(profile());
    await expectCode(pending, ReviewErrorCode.unauthorized);
  } else if (scenario == 'timeout') {
    transport.reply = Completer();
    final bounded = RpcOwnProfileRepository(
      auth: auth,
      transport: transport,
      timeout: const Duration(milliseconds: 10),
    );
    await expectCode(bounded.ensure(), ReviewErrorCode.networkUnavailable);
    check(transport.calls == 1, 'timeout caused automatic retry');
  } else if (scenario == 'errors') {
    transport.result = ReviewFailure(
      ReviewErrorCode.validationFailure,
    ).toJson();
    await expectCode(repository.ensure(), ReviewErrorCode.validationFailure);
    transport.fail = true;
    await expectCode(repository.ensure(), ReviewErrorCode.internalError);
  } else if (scenario == 'envelope') {
    final registry = ReviewConnectionRegistry();
    var calls = 0;
    registry.begin(
      userId: owner,
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      rpc: (function, params) async {
        calls++;
        check(
          function == 'ensure_profile',
          'registry dispatched wrong endpoint',
        );
        return profile();
      },
    );
    try {
      await RpcOwnProfileRepository(
        auth: registry,
        transport: registry,
      ).ensure();
      for (final payload in <Map<String, Object>>[
        {
          'p_request': <String, Object>{'id': owner},
        },
        {'p_request': <String, Object>{}, 'user_id': owner},
      ]) {
        await expectCode(
          registry.invoke(
            capturedSession: registry.currentSession!,
            function: 'ensure_profile',
            params: payload,
          ),
          ReviewErrorCode.validationFailure,
        );
      }
      check(calls == 1, 'forged envelope reached dispatch');
    } finally {
      registry.dispose();
    }
  } else {
    throw StateError('unknown profile test');
  }
}

const scenarios = [
  'valid',
  'malformed',
  'signed-out',
  'late-session',
  'timeout',
  'errors',
  'envelope',
];
