import 'conversation_requests.dart';

/// Full original input, retained in memory only. This value carries no account,
/// receipt, retry, result-application or pending-slot release authority.
/// Hosts must reacquire a current session/reader before any authenticated read.
/// Do not log or persist the payload; an acquired value cannot be recalled from
/// the caller's memory when its originating session is revoked.
sealed class RetainedConversationCommand {
  const RetainedConversationCommand();

  @override
  String toString() => 'RetainedConversationCommand';
}

final class RetainedConversationStart extends RetainedConversationCommand {
  const RetainedConversationStart(this.request);
  final StartConversationRequest request;
}

final class RetainedConversationTurn extends RetainedConversationCommand {
  const RetainedConversationTurn(this.request);
  final ConversationTurnRequest request;
}

final class RetainedConversationFinish extends RetainedConversationCommand {
  const RetainedConversationFinish(this.request);
  final FinishConversationRequest request;
}
