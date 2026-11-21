# Runtime-owned conversation capability — Issue #17

AiTextRuntimeOwner now retains at most one CapturedConversationSession on its
existing text lease and exact shared owned HTTP transport. acquireConversation
first uses the existing guarded acquisition path; a text-only injected transport
cannot supply a conversation. A construction reservation protects subsequent
readiness/getter reentry. It returns the same session, including unresolved or
finished work; repeated factory calls cannot reset receipts/progression or create
fresh event IDs. No request is dispatched by factory construction.

Invalidation synchronously revokes the conversation before the text repository
and transport, then retains the existing actual close/drain barrier. Old generation
identities remain retired; a new generation cannot acquire during old I/O drain.
Failed cleanup prevents replacement. check includes retained conversation
availability, and reentrant close also waits for in-progress construction/orphans.
This adds no second SDK, token writer or independently owned network engine.

PersistentSupabaseRuntime exposes createAiConversationSession only behind a new
trusted aiConversationEnabled=false flag, separate from aiTextEnabled=false.
The factory requires exact persisted rotation and own-profile ready runtime/
session/generation. It shares the existing AI owner with text; refresh already
invalidates before persistence refresh, account readiness/logout invalidates, and
close already revokes/drains AI before SDK disposal. No default/staging flag,
startup source interface, Riverpod/view, endpoint configuration or provider is
activated. Borrowed SDK/HTTP/journal/vault ownership stays with the current host.

One session per generation is a conservative local limit. Finished/uncertain
sessions are not replaced automatically; explicit server reconciliation/new-round
policy, durable restart receipts/transcripts and UI remain future work. Refresh
is a lifecycle boundary, not permission to reconstruct an uncertain old event
under a new ID. Keep caller event identity and server authority. Revocation does
not prove remote cancellation/deletion/rollback; old returned snapshots must not
be rendered by retained views. Scores/recommendations authorize no derived write.

Six pure owner cases cover retained finished-session identity/shared allocation,
synchronous revoke with generation retirement/held drain, same-user identity loss,
getter reentry/reentrant close, failed cleanup and unresolved-event factory retention. Existing owner tests remain.
Four additional actual runtime tests cover separate default-off flag, vault-write/
profile barriers with conversation-only opt-in, refresh/rotated bearer/ignored
abort/replacement/logout, and owned close with held HTTP/preserved vault/borrowed
clients. Auth/vault/provider responses are TEST ONLY; actual-runtime tests require
full Flutter and their execution is reported separately from pure owner checks.
No hosted JWT/provider/receipt/voice/learner acceptance is implied.

Parent dec021c CI40089202113 passed allfive jobs/every required step/no skips,
995 Flutter/five Chrome. New exact-head full CI is required. Main/staging AI flags
stay off; all14 hosted release groups and existing human approval gates remain.
