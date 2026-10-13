# DATABASE SCHEMA — v0.1

## Enums
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
- review_events(id, user_id, learning_item_id, rating, response_ms, is_correct, occurred_at, client_event_id unique, metadata)
- study_sessions(id, user_id, session_type, started_at, ended_at, planned_minutes, actual_minutes, jlpt_level, metadata)
- daily_plans(id, user_id, plan_date, target_minutes, plan_json, completed_minutes, generated_at, updated_at)
- quiz_attempts(id, user_id, quiz_type, item_type, item_id, question_json, answer_json, is_correct, score, duration_ms, occurred_at)
- kanji_attempts(id, user_id, kanji_id, stroke_payload, score_total, score_shape, score_order, score_direction, score_balance)
- conversation_scenarios(id, jlpt_level, title_vi, title_ja, description_vi, system_context, target_grammar, target_vocabulary, difficulty, content_version, is_active)
- conversation_sessions(id, user_id, scenario_id, jlpt_level, started_at, ended_at, summary_json, score_json)
- conversation_messages(id, conversation_session_id, role, text_ja, text_vi, audio_ref, sequence_no)
- learning_errors(id, user_id, source_type, source_id, error_type, original_text, corrected_text, explanation_vi, severity, item_refs, occurrence_count, metadata)
- user_progress_snapshots(id, user_id, snapshot_date, jlpt_level, vocabulary_mastery, kanji_mastery, grammar_mastery, study_minutes, weak_points)

## RLS
Every user-owned table: SELECT/INSERT/UPDATE/DELETE only when auth.uid() = user_id. Static curriculum tables are client-read-only. Service-role operations exist only on trusted backend paths.
