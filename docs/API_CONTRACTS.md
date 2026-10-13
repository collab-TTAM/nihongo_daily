# API CONTRACTS — frozen v0.1

The machine-readable source is `contracts/v0.1/models.schema.json` (named `$defs`), with endpoint bindings/defaults in `contract.json` and executable examples in `fixtures.json`. These interfaces are specified, not deployed. CONTRACT_BASELINE records the Lead review and delivery order.

## Transport, types and ownership

JSON uses snake_case, UUID strings and real YYYY-MM-DD calendar dates. Instants use the RFC3339 subset YYYY-MM-DDTHH:MM:SS with optional fractional seconds and UTC Z or an explicit offset; uppercase T/Z, seconds 00–59, no local timestamps or leap-second inputs. Database instants use timestamptz; responses normalize to UTC. Unknown payload fields are rejected.

Every endpoint authenticates using Supabase Auth and derives the user from verified identity. Requests never accept user_id or arbitrary message roles. Flutter calls typed repositories, not raw feature tables. RPC adapters map named request fields to parameters and normalize transport failures into the shared error model; Edge Functions accept the same request JSON.

| Operation | Transport | Named request / response definitions |
| --- | --- | --- |
| get_daily_plan | Supabase RPC | get_daily_plan_request / get_daily_plan_response |
| submit_review | Supabase RPC | submit_review_request / submit_review_response |
| evaluate_kanji | Edge Function | evaluate_kanji_request / evaluate_kanji_response |
| tutor_explain | Edge Function | tutor_explain_request / tutor_explain_response |
| correct_sentence | Edge Function | correct_sentence_request / correct_sentence_response |
| start_conversation | Edge Function | start_conversation_request / start_conversation_response |
| conversation_turn | Edge Function | conversation_turn_request / conversation_turn_response |
| finish_conversation | Edge Function | finish_conversation_request / finish_conversation_response |

Success is the named response object. Failure is the named error object: code, message_vi, retryable. Adapters distinguish failure from success; do not return an error inside a success object. Error codes remain UNAUTHORIZED, FORBIDDEN, NOT_FOUND, VALIDATION_FAILURE, RATE_LIMITED, NETWORK_UNAVAILABLE, PROVIDER_UNAVAILABLE, SYNC_CONFLICT, INTERNAL_ERROR. Only transient network/provider errors and retryable limits advertise retryable=true. Do not expose SQL/provider internals or secrets.

## Daily plan

The request date and response plan_date refer to the profile's IANA timezone, initially Asia/Saigon. `(user_id, plan_date)` is unique. Generation is deterministic for the same profile/date/content snapshot and preserves a plan already started; reads never reset progress.

The default 120-minute plan has seven unique blocks: SRS 20, VOCABULARY 15, KANJI 20, GRAMMAR 15, LISTENING_READING 15, AI_CONVERSATION 25, QUIZ_REVIEW 10. Planned minutes are positive and sum to target_minutes. Targets are 7–1440 minutes; completed_minutes may exceed the target. Status is READY, IN_PROGRESS, DONE or BLOCKED; unavailable live AI is BLOCKED, not simulated completion. Completed time comes from valid study sessions, not a client overwrite.

## Review and retries

| Rating | Meaning | is_correct |
| --- | --- | --- |
| 0 | AGAIN: could not recall | false |
| 1 | HARD: recalled with difficulty | true |
| 2 | GOOD: recalled normally | true |
| 3 | EASY: recalled easily | true |

Reject inconsistent rating/is_correct. response_ms is an integer 0–3,600,000. Difficulty/retrievability use [0,1]; stability and interval_days use days. interval_days may be fractional for sub-day learning. Scheduling uses elapsed time from the valid event instant, not local date rounding. The pure nd-srs-1 scheduler is specified in docs/SRS_ALGORITHM.md and implemented in the Dart SRS domain. Authenticated transaction/replay integration remains #22; this is not a deployed endpoint.

`(user_id, client_event_id)` identifies a review. Verify item_type/item_id in the selected active curriculum table, bind/create the user's unique learning item, then atomically append the event and update scheduling state. Replay identical fields returns the stored original response without incrementing counters; changed fields under the same ID return SYNC_CONFLICT. Retain the event instant on retry. New events older than last_review_at return SYNC_CONFLICT; future events beyond five minutes from server time return VALIDATION_FAILURE. Check duplicates before stale-time rejection. These remain backend acceptance criteria for #22; storage/RLS is delivered by #3 and the pure scheduler by #4. The local SQL transaction increment is specified in docs/SRS_RPC.md; hosted/typed UI integration is still unverified.

SRS states remain NEW, LEARNING, REVIEW, MASTERED, RELEARNING. MASTERED is reserved and not emitted by the initial scheduler; mastery is derived separately for progress. Reviewed responses have next_review_at and review_count >= 1. NEW items may have null database review dates.

## Kanji and AI

Coordinates use [0,1] in a square canvas. Stroke indices are consecutive zero-based capture order; t is milliseconds since that stroke began, starting at zero and never decreasing. Each stroke has 2–4096 points, each attempt 1–64 strokes. All Kanji score components use [0,100]. A real grade requires reference data; unavailable data gives an explicit error. The algorithm is delivered in #6.

Tutor examples contain sentence_ja, reading_ja, translation_vi. Practice contains question_ja, answer_ja, explanation_vi. Corrections contain original_text, corrected_text, explanation_vi, item_refs. Validate bounded response schemas before persisting or returning model output; empty error arrays mean no correction.

Conversation start selects an active scenario matching jlpt_level. Each mutation has client_event_id with a user/operation-scoped receipt. Retry returns the original response; changed input under the same ID returns SYNC_CONFLICT and must not call the provider again. Validate session ownership on every turn/finish. Sequence numbers are unique within a session. Only the backend creates assistant messages; the client supplies text_ja. Finish is idempotent, ends the session and returns grammar/vocabulary/fluency scores [0,100], errors, strengths_vi, focus_next_vi and srs_recommendations. Recommendations do not automatically mutate SRS.

Provider selection, audio upload/streaming, billing and credentials are not frozen here. They need a later scoped contract and applicable user decisions before live integration. Text adapters/failure handling can be delivered first without claiming voice is available.

## Validation and limits

Run the commands in README. JSON Schema formats are asserted explicitly by the validator; cross-field plan totals/types and stroke indices/times are checked separately. Select a named definition; the root schema alone is only a definition library. Backend tests must still verify auth, RLS, scoped idempotency, curriculum existence, skew, ownership and provider limits. Fixture validation is not evidence of deployed security.

## Local submit_review transaction increment — Issue #22

Migration 20261013200000_submit_review.sql defines public.submit_review(p_request jsonb).
A future typed repository calls rpc('submit_review', params: {'p_request':
review.toJson()}); the inner seven-field wire request and five-field response
are unchanged. Strict request/canonical replay/server scheduling is implemented
locally; no hosted endpoint, JWT/PostgREST or Flutter review integration is claimed.
See SRS_RPC.md for safe error objects, exact fractional retry identity, UTC
microsecond policy, resource limits and the still-open #22 acceptance.
