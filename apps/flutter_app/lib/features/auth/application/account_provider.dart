import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../srs/application/srs_study_runtime.dart';
import '../../srs/data/durable_review_repository.dart';
import '../../srs/data/review_repository.dart';
import '../../srs/data/rpc_srs_study_queue.dart';
import '../../srs/data/supabase_review_binding.dart';
import '../data/own_profile_repository.dart';
import '../data/supabase_account_access.dart';
import 'account_controller.dart';
import 'account_session_refresh.dart';

/// Caller owns the binding, configured store and this controller's lifetime.
/// App preview never manufactures Auth/profile/save success or activates one.
AccountController<SrsStudyRuntime> createSupabaseAccountRuntime(
  SupabaseReviewBinding binding, {
  DurableReviewStore? store,
  AccountAccess? access,
}) {
  final accountAccess = access ?? SupabaseAccountAccess(binding);
  final profiles = RpcOwnProfileRepository(
    auth: accountAccess,
    transport: binding,
  );
  return AccountController<SrsStudyRuntime>(
    access: accountAccess,
    ensureProfile: profiles.ensure,
    buildStudyRuntime: (auth, changes) {
      final delegate = RpcReviewRepository(auth: auth, transport: binding);
      return SrsStudyRuntime(
        auth: auth,
        reviews: store == null
            ? delegate
            : DurableReviewRepository(
                auth: auth,
                delegate: delegate,
                store: store,
              ),
        queue: RpcSrsStudyQueue(auth: auth, transport: binding),
        sessionChanges: changes,
      );
    },
  );
}

final accountRuntimeProvider = Provider<AccountController<SrsStudyRuntime>?>(
  (ref) => null,
);
final accountSessionRefreshActionProvider =
    Provider<AccountSessionRefreshAction?>((ref) => null);
final accountStateProvider =
    StateNotifierProvider<AccountNotifier, AccountState>(
      (ref) => AccountNotifier(ref.watch(accountRuntimeProvider)),
    );

final class AccountNotifier extends StateNotifier<AccountState> {
  AccountNotifier(this.runtime)
    : super(runtime?.state ?? const AccountState(AccountPhase.unavailable)) {
    _subscription = runtime?.changes.listen(
      (_) {
        state = runtime!
            .state; // Reentrant revocation can supersede a queued snapshot.
      },
      onError: (Object _, StackTrace __) =>
          state = const AccountState(AccountPhase.unavailable),
      onDone: () => state = const AccountState(AccountPhase.unavailable),
    );
  }
  final AccountController<SrsStudyRuntime>? runtime;
  StreamSubscription<AccountState>? _subscription;
  Future<void> signIn(String email, String password) async =>
      runtime?.signIn(email, password);
  Future<void> signOut() async => runtime?.signOut();
  Future<void> retryProfile() async => runtime?.retryProfile();
  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
