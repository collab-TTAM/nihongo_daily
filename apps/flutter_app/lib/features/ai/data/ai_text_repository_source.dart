import 'captured_ai_text_repository.dart';

/// Borrowed owner capability. The factory must require persisted Auth/profile
/// readiness, capture one generation and perform no request. Owner revokes/drains
/// accepted work; views never own SDK, HTTP, credentials or source lifetime.
abstract interface class AiTextRepositorySource {
  CapturedAiTextRepository? createAiTextRepository();
  Stream<void> get aiTextChanges;
}
