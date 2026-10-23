import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/captured_ai_text_repository.dart';

/// Trusted host input for one captured ready generation. Acquisition itself must
/// issue no request. Replace this object after every readiness barrier; never
/// mutate it to point at a new account. The runtime still owns transport cleanup.
final class AiTextViewBinding {
  const AiTextViewBinding({required this.repository, this.availabilityChanges});
  final CapturedAiTextRepository repository;
  final Stream<void>? availabilityChanges;
}

/// No default service/provider/SDK activation. A reviewed host may supply a
/// binding from its owned ready factory; startup assembly remains separate work.
final aiTextViewBindingProvider = Provider<AiTextViewBinding?>((ref) => null);
