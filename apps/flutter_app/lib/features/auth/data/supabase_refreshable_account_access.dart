import 'dart:async';
import 'package:supabase/supabase.dart';
import '../../srs/data/review_repository.dart';
import '../../srs/data/supabase_review_binding.dart';
import 'persistent_account_access.dart';
import 'supabase_account_access.dart';

/// Internal host component: sole Auth mutation port for the caller-owned SDK.
/// Supply its matching binding, with SDK logs/auto-refresh configured by host.
/// Secret getter is operational data only, never app state/logging. Owns only
/// subscriptions; host owns SDK/binding/persistence and drains before close.
final class SupabaseRefreshableAccountAccess
    implements RefreshableAccountAccess {
  SupabaseRefreshableAccountAccess(this._client, this._binding) {
    _bindingSubscription = _binding.sessionChanges.listen(
      (_) => _events.add(null),
      onError: (Object _, StackTrace _) => _events.addError(_failure()),
    );
    // Binding retains ReviewSession identity on same-lifecycle refresh and does
    // not emit a review invalidation. Persistence also needs every SDK rotation.
    _authSubscription = _client.auth.onAuthStateChange.listen(
      (_) => _events.add(null),
      onError: (Object _, StackTrace _) => _events.addError(_failure()),
    );
  }
  final SupabaseClient _client;
  final SupabaseReviewBinding _binding;
  final _events = StreamController<void>.broadcast();
  late final StreamSubscription<void> _bindingSubscription;
  late final StreamSubscription<AuthState> _authSubscription;
  static ReviewTransportFailure _failure() =>
      const ReviewTransportFailure(ReviewErrorCode.unauthorized);
  @override
  Stream<void> get sessionChanges => _events.stream;
  @override
  ReviewSession? get currentSession => _binding.currentSession;
  @override
  String? get currentRefreshToken =>
      currentSession == null ? null : _client.auth.currentSession?.refreshToken;
  @override
  Future<void> signIn(String email, String password) =>
      SupabaseAccountAccess(_binding).signIn(email, password);
  @override
  Future<void> signOut() => _binding.signOutLocally();
  @override
  Future<void> restore(String refreshToken) async {
    try {
      await _client.auth.setSession(refreshToken);
    } on Object {
      throw _failure();
    }
  }

  @override
  Future<void> refresh() async {
    try {
      await _client.auth.refreshSession();
    } on Object {
      throw _failure();
    }
  }

  Future<void> close() async {
    await _bindingSubscription.cancel();
    await _authSubscription.cancel();
    await _events.close();
  }
}
