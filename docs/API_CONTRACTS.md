# API CONTRACTS — v0.1

General: snake_case JSON, UUID ids, ISO-8601 timestamps, authenticated user-scoped endpoints, no secrets in responses.

## get_daily_plan
Input: {"date":"YYYY-MM-DD"}
Output: {"plan_date":"...","target_minutes":120,"completed_minutes":0,"blocks":[{"type":"SRS","planned_minutes":20,"status":"READY","item_count":0}]}

## submit_review
Input: {"client_event_id":"uuid","item_type":"VOCABULARY","item_id":"uuid","rating":0,"is_correct":false,"response_ms":0,"occurred_at":"ISO8601"}
Output: {"srs_state":"REVIEW","next_review_at":"ISO8601","interval_days":1,"difficulty":0,"review_count":1}

## evaluate_kanji
Input: {"kanji_id":"uuid","strokes":[{"index":0,"points":[{"x":0.1,"y":0.2,"t":0}]}]}
Output: {"score_total":0.0,"score_shape":0.0,"score_order":0.0,"score_direction":0.0,"score_balance":0.0,"feedback_vi":[]}

## tutor_explain
Input: {"jlpt_level":"N5","question_vi":"...","context":{"recent_grammar_ids":[],"recent_vocabulary_ids":[]}}
Output: {"answer_vi":"...","examples":[],"practice":[]}

## correct_sentence
Input: {"jlpt_level":"N5","sentence_ja":"..."}
Output: {"corrected_sentence":"...","natural_sentence":"...","grammar_errors":[],"vocabulary_errors":[]}

## conversation
start_conversation -> session_id + assistant_message
conversation_turn -> assistant_message + optional live_feedback
finish_conversation -> scores + errors + strengths_vi + focus_next_vi + srs_recommendations

Canonical error codes: UNAUTHORIZED, FORBIDDEN, NOT_FOUND, VALIDATION_FAILURE, RATE_LIMITED, NETWORK_UNAVAILABLE, PROVIDER_UNAVAILABLE, SYNC_CONFLICT, INTERNAL_ERROR.
