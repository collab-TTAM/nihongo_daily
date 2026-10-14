import 'dart:async';
import '../data/durable_review_repository.dart';
import '../data/review_connection_registry.dart';
import '../data/review_repository.dart';
import '../data/rpc_srs_study_queue.dart';
import '../data/supabase_review_binding.dart';

/// No default fixture/demo runtime. Future #20/#22 binding must supply real
/// authenticated queue/review ports and immediate lifecycle notifications.
final class SrsStudyRuntime {
  const SrsStudyRuntime({
    required this.auth,
    required this.reviews,
    required this.queue,
    required this.sessionChanges,
  });
  final ReviewAuth auth;
  final ReviewRepository reviews;
  final SrsStudyQueue queue;
  final Stream<void> sessionChanges;
}

/// Owner must explicitly configure Auth/secure storage/profile provisioning and
/// own this binding. Default preview never creates or installs one automatically.
SrsStudyRuntime createSupabaseStudyRuntime(
  SupabaseReviewBinding binding, {
  DurableReviewStore? store,
}) => SrsStudyRuntime(
  auth: binding,
  reviews: _withStorage(
    binding,
    RpcReviewRepository(auth: binding, transport: binding),
    store,
  ),
  queue: RpcSrsStudyQueue(auth: binding, transport: binding),
  sessionChanges: binding.sessionChanges,
);

/// Explicit assembly only. The caller owns the registry and its trusted Auth
/// binding/disposal; the app does not install one by default. A fixture closure
/// here is not a real Supabase connection or signed-in learner journey.
SrsStudyRuntime createSessionBoundStudyRuntime(
  ReviewConnectionRegistry registry, {
  DurableReviewStore? store,
}) => SrsStudyRuntime(
  auth: registry,
  reviews: _withStorage(
    registry,
    RpcReviewRepository(auth: registry, transport: registry),
    store,
  ),
  queue: RpcSrsStudyQueue(auth: registry, transport: registry),
  sessionChanges: registry.sessionChanges,
);

ReviewRepository _withStorage(
  ReviewAuth auth,
  ReviewRepository repository,
  DurableReviewStore? store,
) => store == null
    ? repository
    : DurableReviewRepository(auth: auth, delegate: repository, store: store);
