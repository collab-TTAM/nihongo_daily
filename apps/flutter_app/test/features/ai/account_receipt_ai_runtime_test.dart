// TEST ONLY SDK/vault/profile/transport ports. Actual persistence, account barrier,
// receipt/runtime/session/store components. No hosted or native Windows proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/ai/application/account_receipt_ai_runtime.dart';
import 'package:nihongo_daily/features/ai/data/captured_ai_text_repository.dart';
import 'package:nihongo_daily/features/ai/data/conversation_receipt_store.dart';
import 'package:nihongo_daily/features/ai/data/receipt_guarded_ai_transport.dart';
import 'package:nihongo_daily/features/ai/domain/conversation_receipt_reference.dart';
import 'package:nihongo_daily/features/auth/application/account_controller.dart';
import 'package:nihongo_daily/features/auth/data/own_profile_repository.dart';
import 'package:nihongo_daily/features/auth/data/persistent_account_access.dart';
import 'package:nihongo_daily/features/auth/data/session_credential_vault.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import '../srs/session_lifecycle_fixtures.dart' as lifecycle;
import '../srs/own_profile_fixtures.dart' as profiles;
import 'receipt_guarded_ai_transport_test.dart' as ports;

final class _Backend implements SecureConversationReceiptBackend {
  Object? value;
  bool failWrite = false;
  bool failClear = false;
  Completer<void>? writeWait;
  final wrote = Completer<void>();
  final calls = <String>[];
  @override
  Future<Object?> read(String target) async {
    calls.add('read');
    return value;
  }

  @override
  Future<void> write(String target, String encoded) async {
    calls.add('write-begin');
    wrote.complete();
    await writeWait?.future;
    value = encoded; // Failed write may still have persisted: fail closed.
    if (failWrite) throw StateError('PRIVATE_STORAGE');
    calls.add('write-end');
  }

  @override
  Future<void> clear(String target) async {
    calls.add('clear');
    if (failClear) throw StateError('PRIVATE_CLEAR');
    value = null;
  }
}

void main() {
  late lifecycle.MemorySdk sdk;
  late lifecycle.MemoryVault vault;
  late PersistentAccountAccess persistence;
  late AccountController<ReviewAuth> account;
  late AccountReceiptAiRuntime<ReviewAuth> host;
  late _Backend backend;
  late ConversationReceiptStore store;
  late Map<String, Object?> fixtures;
  final inners = <ports.Inner>[];
  Completer<OwnProfile>? profileWait;
  var profileFailure = false;
  var profileCalls = 0;
  Future<Object?>? wire;
  var failInnerClose = false;
  ReviewAuth Function(ReviewAuth)? authAccessor;

  OwnProfile profile(String id) => decodeOwnProfile(profiles.profile(id), id);
  AccountReceiptAiRuntime<ReviewAuth> open({String owner = ports.owner}) {
    store = ConversationReceiptStore(
      scope: ConversationReceiptScope(
        projectUrl: ports.scope.projectOrigin,
        ownerId: owner,
      ),
      backend: backend,
    );
    return AccountReceiptAiRuntime<ReviewAuth>(
      account: account,
      authForRuntime: (ready) => authAccessor?.call(ready) ?? ready,
      store: store,
      createTransport: ({required auth, required isReady, required store}) {
        final inner = ports.Inner()..badClose = failInnerClose;
        final wait = wire;
        if (wait != null) {
          final response = Completer<Object?>();
          unawaited(
            wait.then(response.complete, onError: response.completeError),
          );
          inner.wire = response;
        } else {
          inner.wire = Completer<Object?>()
            ..complete(fixtures['start_conversation_response']);
        }
        inners.add(inner);
        return ReceiptGuardedAiTransport(
          inner: inner,
          store: store,
          auth: auth,
          capturedSession: auth.currentSession!,
          isReady: isReady,
        );
      },
    );
  }

  void unavailable() {
    expect(host.createAiTextRepository(), isNull);
    expect(host.createAiConversationSession(), isNull);
    expect(host.createAiConversationScenarios(), isNull);
  }

  Future<void> login() async {
    await persistence.start();
    await account.signIn('fixture@example.invalid', 'TEST_ONLY_PASSWORD');
    await lifecycle.flush();
    expect(account.state.phase, AccountPhase.ready);
  }

  setUpAll(() {
    fixtures =
        jsonDecode(
              File('../../contracts/v0.1/fixtures.json').readAsStringSync(),
            )
            as Map<String, Object?>;
  });
  setUp(() {
    sdk = lifecycle.MemorySdk();
    vault = lifecycle.MemoryVault();
    persistence = PersistentAccountAccess(
      sdk: sdk,
      vault: SessionCredentialVault(
        projectUrl: ports.scope.projectOrigin,
        backend: vault,
      ),
    );
    profileWait = null;
    profileFailure = false;
    profileCalls = 0;
    wire = null;
    failInnerClose = false;
    authAccessor = null;
    inners.clear();
    backend = _Backend();
    account = AccountController<ReviewAuth>(
      access: persistence,
      ensureProfile: () {
        profileCalls++;
        if (profileFailure) throw StateError('PRIVATE_PROFILE');
        return profileWait?.future ??
            Future.value(profile(persistence.currentSession!.userId));
      },
      buildStudyRuntime: (auth, changes) => auth,
    );
    host = open();
  });
  tearDown(() async {
    final wait = backend.writeWait;
    if (wait != null && !wait.isCompleted) wait.complete();
    final saved = vault.writeWait;
    if (saved != null && !saved.isCompleted) saved.complete();
    final pending = profileWait;
    if (pending != null && !pending.isCompleted) {
      pending.complete(profile(ports.owner));
    }
    // Every held transport is released by its own test's finally before cleanup.
    try {
      await host.close();
    } on AiTextFailure {
      // An explicitly tested cleanup failure remains a failure, never new access.
    }
    account.dispose();
    await persistence.close();
    await sdk.events.close();
    await store
        .close(); // TEST ONLY final cleanup, never host failure recovery.
  });

  test(
    'receipt account startup waits persisted rotation then exact own profile',
    () async {
      unavailable();
      expect(inners, isEmpty);
      expect(backend.calls, isEmpty);
      vault.secret = 'TEST_ONLY_SAVED';
      vault.writeWait = Completer<void>();
      profileWait = Completer<OwnProfile>();
      final starting = persistence.start();
      await lifecycle.flush();
      expect(sdk.restores, 1);
      expect(sdk.currentSession, isNotNull);
      expect(persistence.currentSession, isNull);
      expect(profileCalls, 0);
      unavailable();
      expect(inners, isEmpty);
      vault.writeWait!.complete();
      await starting;
      await lifecycle.flush();
      expect(vault.secret, sdk.nextSecret);
      expect(account.state.phase, AccountPhase.loadingProfile);
      unavailable();
      expect(backend.calls, isEmpty);
      profileWait!.complete(profile(ports.owner));
      await lifecycle.flush();
      final session = host.createAiConversationSession()!;
      expect(identical(host.createAiConversationSession(), session), isTrue);
      expect(host.createAiTextRepository(), isNotNull);
      expect(host.createAiConversationScenarios(), isNotNull);
      expect(inners.length, 1);
      expect(backend.calls, isEmpty);
      expect(inners.single.sends, 0);
      await session.start(ports.start);
      expect(inners.single.sent, ports.start.toJson());
      expect(identical(inners.single.session, account.readySession), isTrue);
      expect(backend.calls, ['read', 'read', 'write-begin', 'write-end']);
      final receipt = ConversationReceiptReference.decode(
        backend.value! as String,
      );
      expect(receipt.ownerId, ports.owner);
      expect(receipt.clientEventId, ports.event);
    },
  );

  for (final failure in ['vault', 'profile', 'foreign-profile']) {
    test(
      'receipt account $failure failure cannot create a transport',
      () async {
        vault.failWrite = failure == 'vault';
        profileFailure = failure == 'profile';
        if (failure == 'foreign-profile') {
          profileWait = Completer<OwnProfile>()
            ..complete(profile(lifecycle.other));
        }
        await persistence.start();
        await account.signIn('fixture@example.invalid', 'TEST_ONLY_PASSWORD');
        await lifecycle.flush();
        unavailable();
        expect(inners, isEmpty);
        expect(backend.calls, isEmpty);
        expect(account.readyRuntime, isNull);
        if (failure == 'vault') expect(profileCalls, 0);
      },
    );
  }

  test(
    'receipt account fixed partition cannot retarget another ready owner',
    () async {
      await host.close();
      host = open(owner: lifecycle.other);
      await login();
      unavailable();
      expect(inners, isEmpty);
      expect(backend.calls, isEmpty);
      expect(account.readySession!.userId, ports.owner);
    },
  );

  test(
    'receipt account accessor reentry cannot publish a partial ready generation',
    () async {
      var accessors = 0;
      authAccessor = (ready) {
        accessors++;
        unavailable();
        expect(inners, isEmpty);
        return ready;
      };
      await login();
      expect(accessors, 1);
      expect(host.createAiConversationSession(), isNotNull);
      expect(inners.length, 1);
      expect(backend.calls, isEmpty);
    },
  );

  test(
    'receipt account accessor cannot revive readiness revoked during capture',
    () async {
      Future<void>? logout;
      authAccessor = (ready) {
        logout = account.signOut();
        return ready;
      };
      await persistence.start();
      await account.signIn('fixture@example.invalid', 'TEST_ONLY_PASSWORD');
      await lifecycle.flush();
      await logout;
      unavailable();
      expect(account.readyRuntime, isNull);
      expect(inners, isEmpty);
      expect(backend.calls, isEmpty);
    },
  );

  test(
    'receipt account accessor with a foreign Auth hint fails closed',
    () async {
      final foreign = ports.Auth()
        ..currentSession = ReviewSession(userId: lifecycle.other);
      authAccessor = (_) => foreign;
      await login();
      unavailable();
      expect(inners, isEmpty);
      expect(backend.calls, isEmpty);
    },
  );

  test(
    'receipt account refresh retires late write and preserves ambiguous metadata',
    () async {
      await login();
      backend.writeWait = Completer<void>();
      final old = host.createAiConversationSession()!;
      final result = expectLater(
        old.start(ports.start),
        throwsA(ports.code(AiTextErrorCode.unauthorized)),
      );
      await backend.wrote.future;
      final first = account.readySession;
      sdk.nextSecret = 'TEST_ONLY_ROTATED_2';
      await persistence.refresh();
      await lifecycle.flush();
      expect(account.state.phase, AccountPhase.ready);
      expect(identical(first, account.readySession), isFalse);
      expect(old.isCurrent, isFalse);
      unavailable(); // Original storage still holds the transport drain.
      expect(inners.length, 1);
      expect(inners.single.sends, 0);
      backend.writeWait!.complete();
      await result;
      await lifecycle.flush();
      expect(inners.single.closes, 1);
      expect(backend.value, isNotNull);
      final next = host.createAiConversationSession()!;
      expect(identical(next, old), isFalse);
      await expectLater(
        next.start(ports.start),
        throwsA(ports.code(AiTextErrorCode.syncConflict)),
      );
      expect(inners.every((inner) => inner.sends == 0), isTrue);
      await host.close();
      expect(backend.value, isNotNull);
      expect(backend.calls, isNot(contains('clear')));
      expect(
        persistence.currentSession,
        isNotNull,
      ); // Borrowed Auth remains live.
    },
  );

  test(
    'receipt account A-B-A during held write never sends or replaces metadata',
    () async {
      await login();
      backend.writeWait = Completer<void>();
      final old = host.createAiConversationSession()!;
      final result = expectLater(
        old.start(ports.start),
        throwsA(ports.code(AiTextErrorCode.unauthorized)),
      );
      await backend.wrote.future;
      sdk.change(lifecycle.other, 'TEST_ONLY_B');
      await lifecycle.flush();
      expect(account.readySession!.userId, lifecycle.other);
      unavailable();
      sdk.change(ports.owner, 'TEST_ONLY_RETURN_A');
      await lifecycle.flush();
      expect(account.readySession!.userId, ports.owner);
      unavailable();
      backend.writeWait!.complete();
      await result;
      await lifecycle.flush();
      expect(old.isCurrent, isFalse);
      final replacement = host.createAiConversationSession()!;
      await expectLater(
        replacement.start(ports.start),
        throwsA(ports.code(AiTextErrorCode.syncConflict)),
      );
      expect(inners.every((inner) => inner.sends == 0), isTrue);
      expect(
        ConversationReceiptReference.decode(
          backend.value! as String,
        ).clientEventId,
        ports.event,
      );
    },
  );

  for (final error in [false, true]) {
    test(
      'receipt account logout waits actual callback before clear error=$error',
      () async {
        await login();
        final held = Completer<Object?>();
        wire = held.future;
        final session = host.createAiConversationSession()!;
        final response = expectLater(
          session.start(ports.start),
          throwsA(ports.code(AiTextErrorCode.unauthorized)),
        );
        try {
          await inners.single.entered.future;
          var cleared = false;
          final clearing = host.clearForSignOut().then((_) => cleared = true);
          await account.signOut();
          await lifecycle.flush();
          unavailable();
          expect(inners.single.revoked, isTrue);
          expect(persistence.currentSession, isNull);
          expect(vault.secret, isNull);
          expect(backend.value, isNotNull);
          expect(backend.calls, isNot(contains('clear')));
          expect(cleared, isFalse);
          expect(
            () =>
                ConversationReceiptStore(scope: store.scope, backend: backend),
            throwsA(isA<ConversationReceiptStoreFailure>()),
          );
          if (error) {
            held.completeError(StateError('PRIVATE_LATE_HTTP'));
          } else {
            held.complete(fixtures['start_conversation_response']);
          }
          await response;
          await clearing;
          expect(backend.calls.last, 'clear');
          expect(backend.value, isNull);
          expect(cleared, isTrue);
          expect(session.isCurrent, isFalse);
          expect(inners.single.sends, 1);
        } finally {
          if (!held.isCompleted) {
            held.completeError(StateError('PRIVATE_CLEANUP'));
          }
        }
      },
    );
  }

  test(
    'receipt account ambiguous write and failed clear block replacement until explicit retry',
    () async {
      await login();
      backend.failWrite = true;
      final session = host.createAiConversationSession()!;
      await expectLater(
        session.start(ports.start),
        throwsA(ports.code(AiTextErrorCode.internalError)),
      );
      expect(backend.value, isNotNull);
      expect(inners.single.sends, 0);
      backend.failClear = true;
      await expectLater(
        host.clearForSignOut(),
        throwsA(ports.code(AiTextErrorCode.internalError)),
      );
      await expectLater(
        host.close(),
        throwsA(ports.code(AiTextErrorCode.internalError)),
      );
      unavailable();
      expect(backend.calls.where((c) => c == 'clear').length, 1);
      expect(
        () => ConversationReceiptStore(scope: store.scope, backend: backend),
        throwsA(isA<ConversationReceiptStoreFailure>()),
      );
      expect(
        persistence.currentSession,
        isNotNull,
      ); // Local receipt cleanup is not Auth logout.
      backend.failClear = false;
      await host.clearForSignOut();
      expect(backend.calls.where((c) => c == 'clear').length, 2);
      expect(backend.value, isNull);
      final reopened = ConversationReceiptStore(
        scope: store.scope,
        backend: backend,
      );
      await reopened.close();
    },
  );

  test(
    'receipt account failed owned transport drain never clears or releases partition',
    () async {
      await login();
      failInnerClose = true;
      host.createAiConversationSession();
      await expectLater(
        host.clearForSignOut(),
        throwsA(ports.code(AiTextErrorCode.internalError)),
      );
      expect(backend.calls, isEmpty);
      await expectLater(
        host.close(),
        throwsA(ports.code(AiTextErrorCode.internalError)),
      );
      unavailable();
      expect(
        () => ConversationReceiptStore(scope: store.scope, backend: backend),
        throwsA(isA<ConversationReceiptStoreFailure>()),
      );
      expect(persistence.currentSession, isNotNull);
    },
  );
}
