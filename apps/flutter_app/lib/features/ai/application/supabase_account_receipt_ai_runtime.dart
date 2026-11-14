import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import '../../auth/application/account_controller.dart';
import '../../srs/data/review_repository.dart';
import '../../srs/data/supabase_review_binding.dart';
import '../data/captured_ai_text_repository.dart';
import '../data/conversation_receipt_store.dart';
import '../data/receipt_guarded_ai_transport.dart';
import '../data/supabase_ai_text_transport.dart';
import 'account_receipt_ai_runtime.dart';

/// Explicit host composition. Validate BEFORE transferring store ownership.
/// Borrows the same caller-owned SDK/account/HTTP; no login, request, persistence
/// writer or default activation. Host owns the Auth persistence/profile barrier.
AccountReceiptAiRuntime<T>
createSupabaseAccountReceiptAiRuntime<T extends Object>({
  required SupabaseClient client,
  required AccountController<T> account,
  required ReviewAuth Function(T runtime) authForRuntime,
  required String projectUrl,
  required String publishableKey,
  required ConversationReceiptStore store,
  http.Client? httpClient,
  DateTime Function()? now,
  Duration timeout = const Duration(seconds: 15),
}) {
  final String url;
  final String key;
  try {
    url = SupabaseReviewBinding.validateProjectUrl(projectUrl);
    key = SupabaseReviewBinding.validatePublicKey(publishableKey);
    if (store.scope.projectOrigin != Uri.parse(url).origin.toLowerCase() ||
        client.rest.url != '$url/rest/v1' ||
        client.auth.headers['apikey'] != key ||
        timeout <= Duration.zero ||
        timeout > const Duration(seconds: 15)) {
      throw const FormatException();
    }
  } on Object {
    throw const AiTextFailure(AiTextErrorCode.validationFailure);
  }
  return AccountReceiptAiRuntime<T>(
    account: account,
    authForRuntime: authForRuntime,
    store: store,
    createTransport: ({required auth, required isReady, required store}) {
      final session = auth.currentSession;
      // Validate every possible decorator-construction rejection before creating
      // the inner transport, so an unowned asynchronous orphan cannot escape.
      if (session == null ||
          session.userId != store.scope.ownerId ||
          !isReady()) {
        throw const AiTextFailure(AiTextErrorCode.unauthorized);
      }
      final inner = SupabaseAiTextTransport(
        client: client,
        auth: auth,
        isReady: isReady,
        projectUrl: url,
        publishableKey: key,
        httpClient: httpClient,
        now: now,
        timeout: timeout,
      );
      return ReceiptGuardedAiTransport(
        inner: inner,
        store: store,
        auth: auth,
        capturedSession: session,
        isReady: isReady,
      );
    },
  );
}
