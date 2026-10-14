# DATABASE SCHEMA — v0.1

## Enums

Additive get_review_queue read projection/security/evidence limits are specified
in REVIEW_QUEUE.md. It uses caller privileges/RLS and has no enrollment/state write;
hosted Auth/profile provisioning remains #20. Frozen v0.1 storage fields are unchanged.
jlpt_level: N5 | N4 | N3 | N2 | N1
srs_state: NEW | LEARNING | REVIEW | MASTERED | RELEARNING
learning_item_type: VOCABULARY | KANJI | GRAMMAR

## Core tables
- profiles(id=auth.users.id, display_name, preferred_jlpt, daily_target_minutes, timezone)
- devices(id, user_id, device_name, platform, last_seen_at)
- vocabulary(id, jlpt_level, expression, reading, meaning_vi, part_of_speech, usage_context_vi, difficulty, audio_ref, tags, content_version, is_active)
- vocabulary_examples(id, vocabulary_id, sentence_ja, reading_ja, translation_vi, sort_order)
- kanji(id, character, jlpt_level, meaning_vi, onyomi[], kunyomi[], stroke_count, radical, stroke_data_ref, difficulty, content_version, is_active)
- grammar(id, jlpt_level, title, pattern, meaning_vi, explanation_vi, usage_notes_vi, common_mistakes, related_grammar_ids, difficulty, content_version, is_active)
- grammar_examples(id, grammar_id, sentence_ja, reading_ja, translation_vi, explanation_vi, sort_order)
- user_learning_items(id, user_id, item_type, item_id, srs_state, last_review_at, next_review_at, interval_days, difficulty, review_count, correct_count, incorrect_count, stability, retrievability)
- review_events(id, user_id, learning_item_id, rating, response_ms, is_correct, occurred_at, client_event_id, result_json, metadata)
- study_sessions(id, user_id, session_type, started_at, ended_at, planned_minutes, actual_minutes, jlpt_level, metadata)
- daily_plans(id, user_id, plan_date, target_minutes, plan_json, completed_minutes, generated_at, updated_at)
- quiz_attempts(id, user_id, quiz_type, item_type, item_id, question_json, answer_json, is_correct, score, duration_ms, occurred_at)
- kanji_attempts(id, user_id, kanji_id, stroke_payload, score_total, score_shape, score_order, score_direction, score_balance)
- conversation_scenarios(id, jlpt_level, title_vi, title_ja, description_vi, system_context, target_grammar, target_vocabulary, difficulty, content_version, is_active)
- conversation_sessions(id, user_id, scenario_id, jlpt_level, started_at, ended_at, summary_json, score_json)
- conversation_messages(id, conversation_session_id, role, text_ja, text_vi, audio_ref, sequence_no)
- learning_errors(id, user_id, source_type, source_id, error_type, original_text, corrected_text, explanation_vi, severity, item_refs, occurrence_count, metadata)
- user_progress_snapshots(id, user_id, snapshot_date, jlpt_level, vocabulary_mastery, kanji_mastery, grammar_mastery, study_minutes, weak_points)

## Frozen integrity and storage rules

The initial storage migration is supabase/migrations/20261013151000_initial_schema.sql; it is not deployed. See supabase/README.md for SQL verification and adapter mapping. Shared wire models are in contracts/v0.1. Content exports embed examples; database tables normalize them and repository adapters map the two forms. Required nullable fields remain explicit.

- UUID primary keys; user references point to auth.users.id; instants use timestamptz and plan/snapshot dates use date. Profile timezone is a valid IANA name, default Asia/Saigon; target minutes are 7–1440, default 120.
- Content version is a positive integer; difficulty/retrievability [0,1]; stability/interval_days in days; counts/durations nonnegative; Kanji/conversation scores [0,100]. JSON and array fields follow the named schemas in API_CONTRACTS.
- Unique `(user_id, item_type, item_id)` on user_learning_items. Enforce polymorphic curriculum references using a validating trigger or typed FK columns plus an exactly-one constraint, not unchecked UUIDs. Events reference the same owner's learning item using a composite FK `(learning_item_id, user_id)`.
- Unique `(user_id, client_event_id)` on review_events, replacing ambiguous global uniqueness. result_json stores the original scheduling response. Clients cannot rewrite/delete events; validated submit_review atomically appends the event and updates derived state.
- Unique `(user_id, plan_date)` on plans, `(conversation_session_id, sequence_no)` on messages and `(user_id, snapshot_date, jlpt_level)` on snapshots. Index user + next_review_at and session + sequence_no.
- Add operation_receipts(id, user_id, operation, client_event_id, request_json, response_json, created_at), unique by `(user_id, operation, client_event_id)`. Conversation mutation receipts are immutable client-side. Pending/completed transitions must prevent duplicate provider calls; #7 implements this with fault tests.
- Foreign keys cover examples/parents, sessions/scenarios, attempts/content and user records. Retire curriculum with is_active=false to preserve history. Migrations are append-only.

## RLS and write boundaries

Owner isolation is necessary but does not permit editing server-derived fields:

| Group | Ownership predicate | Client write path |
| --- | --- | --- |
| profiles | auth.uid() = id | Allowlisted settings; immutable id |
| devices, user study sessions/attempts | auth.uid() = user_id | Validated repositories/RPCs; immutable owner |
| user_learning_items, review_events, plans, snapshots | auth.uid() = user_id | Validated server transaction for derived state |
| conversation_sessions | auth.uid() = user_id | Authenticated conversation backend |
| conversation_messages | EXISTS parent session owned by auth.uid() | Authenticated conversation backend |
| learning_errors, operation_receipts | auth.uid() = user_id | Trusted validated backend |
| curriculum, examples, scenarios | Authenticated read of published active content | No client writes |

Use USING/WITH CHECK and column grants/validated functions for write restrictions. Messages inherit session ownership; they have no user_id column. Service-role paths verify the end-user before acting; credentials never enter Flutter. RPC privileges/search_path and elevated functions need audit in #3. No blanket client grants on append-only events or derived metrics.

Acceptance tests must cover User A/User B reads and writes, forged ownership, parent-message access, concurrent/duplicate reviews, rollback and retry results. The schema fixture suite does not execute RLS.

## Implemented baseline mapping — Issue #3

Array references use normalized grammar_relations, scenario_grammar and
scenario_vocabulary with restrictive foreign keys. Adapters reconstruct the
specified arrays; wire contracts are unchanged. Learning/quiz item_type + item_id
map to generated typed FK columns. review_events also persists request_json for
original-result replay. operation_receipts adds PENDING/COMPLETED state and checked
completion response shape. Every project table has RLS and explicit grants;
profiles alone permits allowlisted client settings updates. Scenario
system_context is excluded from authenticated column grants.

Storage constraints/replay are implemented; submit_review scheduling/atomic state
updates, get_daily_plan, provider receipts and full payload validation remain in
#22/#11/#7 (scheduler #4). Read supabase/README.md before applying or adapting the migration.
Local SQL/PGlite evidence is not evidence of a deployed Supabase instance.

Timezone alias compatibility: Asia/Saigon is accepted at provisioning/settings
writes and stored as Asia/Ho_Chi_Minh. Both denote Vietnam UTC+7; canonical storage
avoids backward-link omissions in native tzdata. No wire endpoint changed.

## Local review transaction increment — Issue #22

Migration 20261013200000_submit_review.sql adds private timestamp/request/scheduler
helpers and the narrowly authenticated public.submit_review(jsonb) definer RPC.
No table grants or RLS policies are weakened; owner comes only from auth.uid().
Per-user transaction advisory lock, content FOR SHARE and learning-item FOR UPDATE
protect original event replay plus atomic state/event persistence. nd-srs-1 and
exact canonical event epoch/review count are recorded in immutable event metadata.
See SRS_RPC.md; real JWT/PostgREST and typed Flutter/UI integration remain unverified.
