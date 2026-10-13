// Generated from contracts/v0.1/models.schema.json; do not edit.
export type uuid = string;
export type timestamp = string;
export type local_date = string;
export type jlpt_level = "N5" | "N4" | "N3" | "N2" | "N1";
export type item_type = "VOCABULARY" | "KANJI" | "GRAMMAR";
export type srs_state =
  | "NEW"
  | "LEARNING"
  | "REVIEW"
  | "MASTERED"
  | "RELEARNING";
export type error_code =
  | "UNAUTHORIZED"
  | "FORBIDDEN"
  | "NOT_FOUND"
  | "VALIDATION_FAILURE"
  | "RATE_LIMITED"
  | "NETWORK_UNAVAILABLE"
  | "PROVIDER_UNAVAILABLE"
  | "SYNC_CONFLICT"
  | "INTERNAL_ERROR";
export type item_ref = {
  readonly item_type: item_type;
  readonly item_id: uuid;
};
export type example = {
  readonly sentence_ja: string;
  readonly reading_ja: string;
  readonly translation_vi: string;
};
export type practice = {
  readonly question_ja: string;
  readonly answer_ja: string;
  readonly explanation_vi: string;
};
export type correction = {
  readonly original_text: string;
  readonly corrected_text: string;
  readonly explanation_vi: string;
  readonly item_refs: ReadonlyArray<item_ref>;
};
export type error = {
  readonly code: error_code;
  readonly message_vi: string;
  readonly retryable: boolean;
};
export type vocabulary = {
  readonly id: uuid;
  readonly jlpt_level: jlpt_level;
  readonly difficulty: number;
  readonly content_version: number;
  readonly is_active: boolean;
  readonly expression: string;
  readonly reading: string;
  readonly meaning_vi: string;
  readonly part_of_speech: string;
  readonly usage_context_vi: string;
  readonly audio_ref: string | null;
  readonly tags: ReadonlyArray<string>;
  readonly examples: ReadonlyArray<example>;
};
export type kanji = {
  readonly id: uuid;
  readonly jlpt_level: jlpt_level;
  readonly difficulty: number;
  readonly content_version: number;
  readonly is_active: boolean;
  readonly character: string;
  readonly meaning_vi: string;
  readonly onyomi: ReadonlyArray<string>;
  readonly kunyomi: ReadonlyArray<string>;
  readonly stroke_count: number;
  readonly radical: string | null;
  readonly stroke_data_ref: string | null;
};
export type grammar = {
  readonly id: uuid;
  readonly jlpt_level: jlpt_level;
  readonly difficulty: number;
  readonly content_version: number;
  readonly is_active: boolean;
  readonly title: string;
  readonly pattern: string;
  readonly meaning_vi: string;
  readonly explanation_vi: string;
  readonly usage_notes_vi: ReadonlyArray<string>;
  readonly common_mistakes: ReadonlyArray<string>;
  readonly related_grammar_ids: ReadonlyArray<uuid>;
  readonly examples: ReadonlyArray<example>;
};
export type get_daily_plan_request = { readonly date: local_date };
export type daily_plan_block = {
  readonly type:
    | "SRS"
    | "VOCABULARY"
    | "KANJI"
    | "GRAMMAR"
    | "LISTENING_READING"
    | "AI_CONVERSATION"
    | "QUIZ_REVIEW";
  readonly planned_minutes: number;
  readonly status: "READY" | "IN_PROGRESS" | "DONE" | "BLOCKED";
  readonly item_count: number;
};
export type get_daily_plan_response = {
  readonly plan_date: local_date;
  readonly target_minutes: number;
  readonly completed_minutes: number;
  readonly blocks: ReadonlyArray<daily_plan_block>;
};
export type submit_review_request = {
  readonly client_event_id: uuid;
  readonly item_type: item_type;
  readonly item_id: uuid;
  readonly rating: number;
  readonly is_correct: boolean;
  readonly response_ms: number;
  readonly occurred_at: timestamp;
};
export type submit_review_response = {
  readonly srs_state: srs_state;
  readonly next_review_at: timestamp;
  readonly interval_days: number;
  readonly difficulty: number;
  readonly review_count: number;
};
export type stroke_point = {
  readonly x: number;
  readonly y: number;
  readonly t: number;
};
export type stroke = {
  readonly index: number;
  readonly points: ReadonlyArray<stroke_point>;
};
export type evaluate_kanji_request = {
  readonly kanji_id: uuid;
  readonly strokes: ReadonlyArray<stroke>;
};
export type evaluate_kanji_response = {
  readonly score_total: number;
  readonly score_shape: number;
  readonly score_order: number;
  readonly score_direction: number;
  readonly score_balance: number;
  readonly feedback_vi: ReadonlyArray<string>;
};
export type tutor_context = {
  readonly recent_grammar_ids: ReadonlyArray<uuid>;
  readonly recent_vocabulary_ids: ReadonlyArray<uuid>;
};
export type tutor_explain_request = {
  readonly jlpt_level: jlpt_level;
  readonly question_vi: string;
  readonly context: tutor_context;
};
export type tutor_explain_response = {
  readonly answer_vi: string;
  readonly examples: ReadonlyArray<example>;
  readonly practice: ReadonlyArray<practice>;
};
export type correct_sentence_request = {
  readonly jlpt_level: jlpt_level;
  readonly sentence_ja: string;
};
export type correct_sentence_response = {
  readonly corrected_sentence: string;
  readonly natural_sentence: string;
  readonly grammar_errors: ReadonlyArray<correction>;
  readonly vocabulary_errors: ReadonlyArray<correction>;
};
export type assistant_message = {
  readonly id: uuid;
  readonly role: "assistant";
  readonly text_ja: string;
  readonly text_vi: string | null;
  readonly audio_ref: string | null;
  readonly sequence_no: number;
};
export type start_conversation_request = {
  readonly scenario_id: uuid;
  readonly jlpt_level: jlpt_level;
  readonly client_event_id: uuid;
};
export type start_conversation_response = {
  readonly session_id: uuid;
  readonly assistant_message: assistant_message;
};
export type conversation_turn_request = {
  readonly session_id: uuid;
  readonly client_event_id: uuid;
  readonly text_ja: string;
};
export type conversation_turn_response = {
  readonly assistant_message: assistant_message;
  readonly live_feedback?: ReadonlyArray<correction>;
};
export type finish_conversation_request = {
  readonly session_id: uuid;
  readonly client_event_id: uuid;
};
export type conversation_scores = {
  readonly grammar: number;
  readonly vocabulary: number;
  readonly fluency: number;
};
export type finish_conversation_response = {
  readonly scores: conversation_scores;
  readonly errors: ReadonlyArray<correction>;
  readonly strengths_vi: ReadonlyArray<string>;
  readonly focus_next_vi: ReadonlyArray<string>;
  readonly srs_recommendations: ReadonlyArray<item_ref>;
};
