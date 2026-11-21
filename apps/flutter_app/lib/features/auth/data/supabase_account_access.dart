import '../../srs/data/review_repository.dart';
import '../../srs/data/supabase_review_binding.dart';
import '../application/account_controller.dart';

/// Uses the configured existing Supabase email/password capability; never
/// enables providers or changes server Auth settings. Binding disables SDK logs
/// before credential operations. No credential/token persistence here.
final class SupabaseAccountAccess implements AccountAccess {
  SupabaseAccountAccess(this.binding);
  final SupabaseReviewBinding binding;
  @override
  ReviewSession? get currentSession => binding.currentSession;
  @override
  Stream<void> get sessionChanges => binding.sessionChanges;
  @override
  Future<void> signIn(String email, String password) async {
    try {
      await binding.authenticateWithPassword(email, password);
    } on Object {
      throw const ReviewTransportFailure(ReviewErrorCode.unauthorized);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await binding.signOutLocally();
    } on Object {
      throw const ReviewTransportFailure(ReviewErrorCode.internalError);
    }
  }
}
