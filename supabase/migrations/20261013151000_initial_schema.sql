-- Initial additive storage baseline. Apply once through Supabase migrations.
-- No client write grants for events/derived state. Public RPCs arrive in #4/#11/#7.
begin;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;
create type public.jlpt_level as enum ('N5','N4','N3','N2','N1');
create type public.srs_state as enum ('NEW','LEARNING','REVIEW','MASTERED','RELEARNING');
create type public.learning_item_type as enum ('VOCABULARY','KANJI','GRAMMAR');
create domain public.unit_interval as numeric check (value between 0 and 1);
create domain public.nonnegative_days as numeric check (value >= 0 and value < 'Infinity'::numeric);
create domain public.score_100 as numeric check (value between 0 and 100);

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  display_name text not null default '' check (char_length(display_name) <= 100),
  preferred_jlpt public.jlpt_level not null default 'N5',
  daily_target_minutes integer not null default 120 check (daily_target_minutes between 7 and 1440),
  timezone text not null default 'Asia/Saigon',
  foreign key (id) references auth.users(id) on delete restrict
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict, device_name text not null check (char_length(device_name) between 1 and 200),
  platform text not null check (platform in ('WEB','WINDOWS','IOS','ANDROID','MACOS','LINUX')),
  last_seen_at timestamptz not null default now() check (isfinite(last_seen_at))
);

create table public.vocabulary (
  id uuid primary key default gen_random_uuid(),
  jlpt_level public.jlpt_level not null,
  difficulty public.unit_interval not null,
  content_version integer not null check (content_version >= 1),
  is_active boolean not null default false,
  expression text not null check (char_length(expression) between 1 and 200),
  reading text not null check (char_length(reading) between 1 and 200),
  meaning_vi text not null check (char_length(meaning_vi) between 1 and 2000),
  part_of_speech text not null check (char_length(part_of_speech) between 1 and 100),
  usage_context_vi text not null check (char_length(usage_context_vi) between 1 and 2000),
  audio_ref text check (char_length(audio_ref) between 1 and 1000),
  tags text[] not null default '{}' check (cardinality(tags) <= 100 and array_position(tags, null) is null)
);

create table public.vocabulary_examples (
  id uuid primary key default gen_random_uuid(),
  vocabulary_id uuid not null references public.vocabulary(id) on delete restrict,
  sentence_ja text not null check (char_length(sentence_ja) between 1 and 2000),
  reading_ja text not null check (char_length(reading_ja) between 1 and 2000),
  translation_vi text not null check (char_length(translation_vi) between 1 and 2000),
  sort_order integer not null check (sort_order >= 0), unique (vocabulary_id, sort_order)
);

create table public.kanji (
  id uuid primary key default gen_random_uuid(),
  jlpt_level public.jlpt_level not null,
  difficulty public.unit_interval not null,
  content_version integer not null check (content_version >= 1),
  is_active boolean not null default false,
  character text not null check (char_length(character) = 1),
  meaning_vi text not null check (char_length(meaning_vi) between 1 and 2000),
  onyomi text[] not null default '{}' check (cardinality(onyomi) <= 100 and array_position(onyomi, null) is null),
  kunyomi text[] not null default '{}' check (cardinality(kunyomi) <= 100 and array_position(kunyomi, null) is null),
  stroke_count integer not null check (stroke_count between 1 and 64),
  radical text check (char_length(radical) between 1 and 20),
  stroke_data_ref text check (char_length(stroke_data_ref) between 1 and 1000)
);

create table public.grammar (
  id uuid primary key default gen_random_uuid(),
  jlpt_level public.jlpt_level not null,
  difficulty public.unit_interval not null,
  content_version integer not null check (content_version >= 1),
  is_active boolean not null default false,
  title text not null check (char_length(title) between 1 and 200),
  pattern text not null check (char_length(pattern) between 1 and 500),
  meaning_vi text not null check (char_length(meaning_vi) between 1 and 2000),
  explanation_vi text not null check (char_length(explanation_vi) between 1 and 5000),
  usage_notes_vi text[] not null default '{}' check (cardinality(usage_notes_vi) <= 100 and array_position(usage_notes_vi, null) is null),
  common_mistakes text[] not null default '{}' check (cardinality(common_mistakes) <= 100 and array_position(common_mistakes, null) is null)
);

create table public.grammar_examples (
  id uuid primary key default gen_random_uuid(),
  grammar_id uuid not null references public.grammar(id) on delete restrict,
  sentence_ja text not null check (char_length(sentence_ja) between 1 and 2000),
  reading_ja text not null check (char_length(reading_ja) between 1 and 2000),
  translation_vi text not null check (char_length(translation_vi) between 1 and 2000),
  explanation_vi text check (char_length(explanation_vi) between 1 and 5000),
  sort_order integer not null check (sort_order >= 0), unique (grammar_id, sort_order)
);

create table public.user_learning_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict, item_type public.learning_item_type not null, item_id uuid not null,
  vocabulary_id uuid generated always as (case when item_type = 'VOCABULARY' then item_id end) stored references public.vocabulary(id) on delete restrict,
  kanji_id uuid generated always as (case when item_type = 'KANJI' then item_id end) stored references public.kanji(id) on delete restrict,
  grammar_id uuid generated always as (case when item_type = 'GRAMMAR' then item_id end) stored references public.grammar(id) on delete restrict,
  srs_state public.srs_state not null default 'NEW',
  last_review_at timestamptz check (isfinite(last_review_at)),
  next_review_at timestamptz check (isfinite(next_review_at)),
  interval_days public.nonnegative_days not null default 0,
  difficulty public.unit_interval not null default 0.5,
  review_count integer not null default 0 check (review_count >= 0),
  correct_count integer not null default 0 check (correct_count >= 0),
  incorrect_count integer not null default 0 check (incorrect_count >= 0),
  stability public.nonnegative_days not null default 0,
  retrievability public.unit_interval not null default 1,
  unique (user_id, item_type, item_id), unique (id, user_id),
  check (correct_count::bigint + incorrect_count::bigint = review_count),
  check ((review_count = 0 and last_review_at is null) or
    (review_count > 0 and last_review_at is not null and next_review_at is not null))
);

create table public.review_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict, learning_item_id uuid not null,
  rating integer not null check (rating between 0 and 3),
  response_ms integer not null check (response_ms between 0 and 3600000),
  is_correct boolean not null, occurred_at timestamptz not null check (isfinite(occurred_at)),
  client_event_id uuid not null, result_json jsonb not null check (jsonb_typeof(result_json) = 'object'),
  request_json jsonb not null check (jsonb_typeof(request_json) = 'object'),
  metadata jsonb not null default '{}' check (jsonb_typeof(metadata) = 'object'),
  unique (user_id, client_event_id),
  foreign key (learning_item_id, user_id) references public.user_learning_items(id, user_id) on delete restrict,
  check (is_correct = (rating <> 0))
);

create table public.study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict, session_type text not null check (session_type in
    ('SRS','VOCABULARY','KANJI','GRAMMAR','LISTENING_READING','AI_CONVERSATION','QUIZ_REVIEW')),
  started_at timestamptz not null check (isfinite(started_at)),
  ended_at timestamptz check (isfinite(ended_at) and ended_at >= started_at),
  planned_minutes integer not null check (planned_minutes > 0),
  actual_minutes integer not null default 0 check (actual_minutes >= 0),
  jlpt_level public.jlpt_level not null,
  metadata jsonb not null default '{}' check (jsonb_typeof(metadata) = 'object')
);

create table public.daily_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict, plan_date date not null check (isfinite(plan_date)),
  target_minutes integer not null check (target_minutes between 7 and 1440),
  plan_json jsonb not null check (jsonb_typeof(plan_json) = 'object'),
  completed_minutes integer not null default 0 check (completed_minutes >= 0),
  generated_at timestamptz not null default now() check (isfinite(generated_at)),
  updated_at timestamptz not null default now() check (isfinite(updated_at) and updated_at >= generated_at),
  unique (user_id, plan_date)
);

create table public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict, item_type public.learning_item_type not null, item_id uuid not null,
  vocabulary_id uuid generated always as (case when item_type = 'VOCABULARY' then item_id end) stored references public.vocabulary(id) on delete restrict,
  kanji_id uuid generated always as (case when item_type = 'KANJI' then item_id end) stored references public.kanji(id) on delete restrict,
  grammar_id uuid generated always as (case when item_type = 'GRAMMAR' then item_id end) stored references public.grammar(id) on delete restrict, quiz_type text not null,
  question_json jsonb not null check (jsonb_typeof(question_json) = 'object'),
  answer_json jsonb not null check (jsonb_typeof(answer_json) = 'object'),
  is_correct boolean not null, score public.score_100 not null,
  duration_ms integer not null check (duration_ms between 0 and 3600000),
  occurred_at timestamptz not null check (isfinite(occurred_at))
);

create table public.kanji_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict, kanji_id uuid not null references public.kanji(id) on delete restrict,
  stroke_payload jsonb not null check (jsonb_typeof(stroke_payload) = 'array' and jsonb_array_length(stroke_payload) between 1 and 64),
  score_total public.score_100 not null, score_shape public.score_100 not null,
  score_order public.score_100 not null, score_direction public.score_100 not null,
  score_balance public.score_100 not null
);

create table public.conversation_scenarios (
  id uuid primary key default gen_random_uuid(),
  jlpt_level public.jlpt_level not null,
  difficulty public.unit_interval not null,
  content_version integer not null check (content_version >= 1),
  is_active boolean not null default false,
  title_vi text not null, title_ja text not null, description_vi text not null,
  system_context text not null
);

create table public.grammar_relations (
  id uuid primary key default gen_random_uuid(),
  grammar_id uuid not null references public.grammar(id) on delete restrict,
  related_grammar_id uuid not null references public.grammar(id) on delete restrict,
  unique (grammar_id, related_grammar_id), check (grammar_id <> related_grammar_id)
);

create table public.scenario_grammar (
  id uuid primary key default gen_random_uuid(),
  scenario_id uuid not null references public.conversation_scenarios(id) on delete restrict,
  grammar_id uuid not null references public.grammar(id) on delete restrict,
  unique (scenario_id, grammar_id)
);

create table public.scenario_vocabulary (
  id uuid primary key default gen_random_uuid(),
  scenario_id uuid not null references public.conversation_scenarios(id) on delete restrict,
  vocabulary_id uuid not null references public.vocabulary(id) on delete restrict,
  unique (scenario_id, vocabulary_id)
);

create table public.conversation_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict, scenario_id uuid not null references public.conversation_scenarios(id) on delete restrict,
  jlpt_level public.jlpt_level not null,
  started_at timestamptz not null default now() check (isfinite(started_at)),
  ended_at timestamptz check (isfinite(ended_at) and ended_at >= started_at),
  summary_json jsonb check (jsonb_typeof(summary_json) = 'object'),
  score_json jsonb check (jsonb_typeof(score_json) = 'object')
);

create table public.conversation_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_session_id uuid not null references public.conversation_sessions(id) on delete restrict,
  role text not null check (role in ('user','assistant')),
  text_ja text not null check (char_length(text_ja) between 1 and 10000),
  text_vi text check (char_length(text_vi) <= 10000),
  audio_ref text check (char_length(audio_ref) between 1 and 1000),
  sequence_no integer not null check (sequence_no >= 0), unique (conversation_session_id, sequence_no)
);

create table public.learning_errors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict, source_type text not null, source_id uuid not null,
  error_type text not null, original_text text not null, corrected_text text not null,
  explanation_vi text not null, severity text not null check (severity in ('LOW','MEDIUM','HIGH')),
  item_refs jsonb not null default '[]' check (jsonb_typeof(item_refs) = 'array'),
  occurrence_count integer not null default 1 check (occurrence_count > 0),
  metadata jsonb not null default '{}' check (jsonb_typeof(metadata) = 'object')
);

create table public.user_progress_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict, snapshot_date date not null check (isfinite(snapshot_date)),
  jlpt_level public.jlpt_level not null,
  vocabulary_mastery public.unit_interval not null, kanji_mastery public.unit_interval not null,
  grammar_mastery public.unit_interval not null, study_minutes integer not null check (study_minutes >= 0),
  weak_points jsonb not null default '[]' check (jsonb_typeof(weak_points) = 'array'),
  unique (user_id, snapshot_date, jlpt_level)
);

create table public.operation_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict, operation text not null check (operation in
    ('start_conversation','conversation_turn','finish_conversation')),
  client_event_id uuid not null, request_json jsonb not null check (jsonb_typeof(request_json) = 'object'),
  response_json jsonb check (jsonb_typeof(response_json) = 'object'),
  status text not null default 'PENDING' check (status in ('PENDING','COMPLETED')),
  created_at timestamptz not null default now() check (isfinite(created_at)),
  unique (user_id, operation, client_event_id),
  check ((status = 'PENDING' and response_json is null) or (status = 'COMPLETED' and response_json is not null))
);

-- Profile settings are the only direct client mutation. No arbitrary auth metadata.
create function private.validate_timezone() returns trigger
language plpgsql set search_path = '' as $$
begin
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new.timezone) then
    raise exception 'Invalid IANA timezone' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger profiles_timezone before insert or update of timezone on public.profiles
for each row execute function private.validate_timezone();

-- IDs, parent relationships and ownership cannot change, even on trusted updates.
create function private.immutable_keys() returns trigger
language plpgsql set search_path = '' as $$
declare key_name text;
begin
  foreach key_name in array tg_argv loop
    if to_jsonb(new)->key_name is distinct from to_jsonb(old)->key_name then
      raise exception 'Immutable record key' using errcode = '23514';
    end if;
  end loop;
  return new;
end $$;

create function private.reject_event_mutation() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'Append-only event' using errcode = '23514';
end $$;
create trigger review_events_append_only before update or delete on public.review_events
for each row execute function private.reject_event_mutation();

-- Existing inactive content remains referentially intact; new learning must be active.
create function private.validate_learning_content() returns trigger
language plpgsql set search_path = '' as $$
declare active boolean;
begin
  case new.item_type
    when 'VOCABULARY' then select is_active into active from public.vocabulary where id = new.item_id for key share;
    when 'KANJI' then select is_active into active from public.kanji where id = new.item_id for key share;
    when 'GRAMMAR' then select is_active into active from public.grammar where id = new.item_id for key share;
  end case;
  if active is distinct from true then
    raise exception 'Missing or inactive curriculum' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger learning_content before insert on public.user_learning_items
for each row execute function private.validate_learning_content();

-- Internal helper for the future authenticated submit_review transaction.
-- Not an exposed RPC, and does not schedule a review or trust client state.
create function private.review_replay(p_user_id uuid, p_request jsonb) returns jsonb
language plpgsql set search_path = '' as $$
declare stored_request jsonb; stored_result jsonb;
begin
  select request_json, result_json into stored_request, stored_result
  from public.review_events where user_id = p_user_id
    and client_event_id = (p_request->>'client_event_id')::uuid;
  if not found then return null; end if;
  if stored_request is distinct from p_request then
    raise exception 'SYNC_CONFLICT' using errcode = 'P0001';
  end if;
  return stored_result;
end $$;

create trigger profiles_immutable_keys before update on public.profiles
for each row execute function private.immutable_keys('id');

create trigger devices_immutable_keys before update on public.devices
for each row execute function private.immutable_keys('id', 'user_id');

create trigger user_learning_items_immutable_keys before update on public.user_learning_items
for each row execute function private.immutable_keys('id', 'user_id', 'item_type', 'item_id');

create trigger review_events_immutable_keys before update on public.review_events
for each row execute function private.immutable_keys('id', 'user_id', 'learning_item_id', 'client_event_id');

create trigger study_sessions_immutable_keys before update on public.study_sessions
for each row execute function private.immutable_keys('id', 'user_id');

create trigger daily_plans_immutable_keys before update on public.daily_plans
for each row execute function private.immutable_keys('id', 'user_id');

create trigger quiz_attempts_immutable_keys before update on public.quiz_attempts
for each row execute function private.immutable_keys('id', 'user_id', 'item_type', 'item_id');

create trigger kanji_attempts_immutable_keys before update on public.kanji_attempts
for each row execute function private.immutable_keys('id', 'user_id');

create trigger conversation_sessions_immutable_keys before update on public.conversation_sessions
for each row execute function private.immutable_keys('id', 'user_id', 'scenario_id', 'jlpt_level');

create trigger learning_errors_immutable_keys before update on public.learning_errors
for each row execute function private.immutable_keys('id', 'user_id');

create trigger user_progress_snapshots_immutable_keys before update on public.user_progress_snapshots
for each row execute function private.immutable_keys('id', 'user_id');

create trigger operation_receipts_immutable_keys before update on public.operation_receipts
for each row execute function private.immutable_keys('id', 'user_id', 'operation', 'client_event_id', 'request_json');

create trigger conversation_messages_immutable_keys before update on public.conversation_messages
for each row execute function private.immutable_keys('id', 'conversation_session_id', 'sequence_no', 'role');

create function private.validate_receipt_transition() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.status = 'COMPLETED' or new.status <> 'COMPLETED' then
    raise exception 'Invalid receipt transition' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger receipt_transition before update on public.operation_receipts
for each row execute function private.validate_receipt_transition();
create trigger receipts_no_delete before delete on public.operation_receipts
for each row execute function private.reject_event_mutation();

alter table public.profiles enable row level security;
revoke all on table public.profiles from public, anon, authenticated;
grant select, insert, update, delete on table public.profiles to service_role;

grant select on table public.profiles to authenticated;

create policy profiles_read on public.profiles for select to authenticated using ((select auth.uid()) = id);

alter table public.devices enable row level security;
revoke all on table public.devices from public, anon, authenticated;
grant select, insert, update, delete on table public.devices to service_role;

grant select on table public.devices to authenticated;

create policy devices_read on public.devices for select to authenticated using ((select auth.uid()) = user_id);

alter table public.user_learning_items enable row level security;
revoke all on table public.user_learning_items from public, anon, authenticated;
grant select, insert, update, delete on table public.user_learning_items to service_role;

grant select on table public.user_learning_items to authenticated;

create policy user_learning_items_read on public.user_learning_items for select to authenticated using ((select auth.uid()) = user_id);

alter table public.review_events enable row level security;
revoke all on table public.review_events from public, anon, authenticated;
grant select, insert, update, delete on table public.review_events to service_role;

grant select on table public.review_events to authenticated;

create policy review_events_read on public.review_events for select to authenticated using ((select auth.uid()) = user_id);

alter table public.study_sessions enable row level security;
revoke all on table public.study_sessions from public, anon, authenticated;
grant select, insert, update, delete on table public.study_sessions to service_role;

grant select on table public.study_sessions to authenticated;

create policy study_sessions_read on public.study_sessions for select to authenticated using ((select auth.uid()) = user_id);

alter table public.daily_plans enable row level security;
revoke all on table public.daily_plans from public, anon, authenticated;
grant select, insert, update, delete on table public.daily_plans to service_role;

grant select on table public.daily_plans to authenticated;

create policy daily_plans_read on public.daily_plans for select to authenticated using ((select auth.uid()) = user_id);

alter table public.quiz_attempts enable row level security;
revoke all on table public.quiz_attempts from public, anon, authenticated;
grant select, insert, update, delete on table public.quiz_attempts to service_role;

grant select on table public.quiz_attempts to authenticated;

create policy quiz_attempts_read on public.quiz_attempts for select to authenticated using ((select auth.uid()) = user_id);

alter table public.kanji_attempts enable row level security;
revoke all on table public.kanji_attempts from public, anon, authenticated;
grant select, insert, update, delete on table public.kanji_attempts to service_role;

grant select on table public.kanji_attempts to authenticated;

create policy kanji_attempts_read on public.kanji_attempts for select to authenticated using ((select auth.uid()) = user_id);

alter table public.conversation_sessions enable row level security;
revoke all on table public.conversation_sessions from public, anon, authenticated;
grant select, insert, update, delete on table public.conversation_sessions to service_role;

grant select on table public.conversation_sessions to authenticated;

create policy conversation_sessions_read on public.conversation_sessions for select to authenticated using ((select auth.uid()) = user_id);

alter table public.learning_errors enable row level security;
revoke all on table public.learning_errors from public, anon, authenticated;
grant select, insert, update, delete on table public.learning_errors to service_role;

grant select on table public.learning_errors to authenticated;

create policy learning_errors_read on public.learning_errors for select to authenticated using ((select auth.uid()) = user_id);

alter table public.user_progress_snapshots enable row level security;
revoke all on table public.user_progress_snapshots from public, anon, authenticated;
grant select, insert, update, delete on table public.user_progress_snapshots to service_role;

grant select on table public.user_progress_snapshots to authenticated;

create policy user_progress_snapshots_read on public.user_progress_snapshots for select to authenticated using ((select auth.uid()) = user_id);

alter table public.operation_receipts enable row level security;
revoke all on table public.operation_receipts from public, anon, authenticated;
grant select, insert, update, delete on table public.operation_receipts to service_role;

grant select on table public.operation_receipts to authenticated;

create policy operation_receipts_read on public.operation_receipts for select to authenticated using ((select auth.uid()) = user_id);

alter table public.conversation_messages enable row level security;
revoke all on table public.conversation_messages from public, anon, authenticated;
grant select, insert, update, delete on table public.conversation_messages to service_role;

grant select on table public.conversation_messages to authenticated;

create policy conversation_messages_read on public.conversation_messages for select to authenticated using (exists (select 1 from public.conversation_sessions s where s.id = conversation_session_id and s.user_id = (select auth.uid())));

alter table public.vocabulary enable row level security;
revoke all on table public.vocabulary from public, anon, authenticated;
grant select, insert, update, delete on table public.vocabulary to service_role;

grant select on table public.vocabulary to authenticated;

create policy vocabulary_read on public.vocabulary for select to authenticated using (is_active);

alter table public.kanji enable row level security;
revoke all on table public.kanji from public, anon, authenticated;
grant select, insert, update, delete on table public.kanji to service_role;

grant select on table public.kanji to authenticated;

create policy kanji_read on public.kanji for select to authenticated using (is_active);

alter table public.grammar enable row level security;
revoke all on table public.grammar from public, anon, authenticated;
grant select, insert, update, delete on table public.grammar to service_role;

grant select on table public.grammar to authenticated;

create policy grammar_read on public.grammar for select to authenticated using (is_active);

alter table public.conversation_scenarios enable row level security;
revoke all on table public.conversation_scenarios from public, anon, authenticated;
grant select, insert, update, delete on table public.conversation_scenarios to service_role;

grant select (id,jlpt_level,difficulty,content_version,is_active,title_vi,title_ja,description_vi) on public.conversation_scenarios to authenticated;

create policy conversation_scenarios_read on public.conversation_scenarios for select to authenticated using (is_active);

alter table public.vocabulary_examples enable row level security;
revoke all on table public.vocabulary_examples from public, anon, authenticated;
grant select, insert, update, delete on table public.vocabulary_examples to service_role;

grant select on table public.vocabulary_examples to authenticated;

create policy vocabulary_examples_read on public.vocabulary_examples for select to authenticated using (exists (select 1 from public.vocabulary v where v.id = vocabulary_id and v.is_active));

alter table public.grammar_examples enable row level security;
revoke all on table public.grammar_examples from public, anon, authenticated;
grant select, insert, update, delete on table public.grammar_examples to service_role;

grant select on table public.grammar_examples to authenticated;

create policy grammar_examples_read on public.grammar_examples for select to authenticated using (exists (select 1 from public.grammar g where g.id = grammar_id and g.is_active));

alter table public.grammar_relations enable row level security;
revoke all on table public.grammar_relations from public, anon, authenticated;
grant select, insert, update, delete on table public.grammar_relations to service_role;

grant select on table public.grammar_relations to authenticated;

create policy grammar_relations_read on public.grammar_relations for select to authenticated using (exists (select 1 from public.grammar g where g.id = grammar_id and g.is_active) and exists (select 1 from public.grammar g where g.id = related_grammar_id and g.is_active));

alter table public.scenario_grammar enable row level security;
revoke all on table public.scenario_grammar from public, anon, authenticated;
grant select, insert, update, delete on table public.scenario_grammar to service_role;

grant select on table public.scenario_grammar to authenticated;

create policy scenario_grammar_read on public.scenario_grammar for select to authenticated using (exists (select 1 from public.conversation_scenarios s where s.id = scenario_id and s.is_active) and exists (select 1 from public.grammar g where g.id = grammar_id and g.is_active));

alter table public.scenario_vocabulary enable row level security;
revoke all on table public.scenario_vocabulary from public, anon, authenticated;
grant select, insert, update, delete on table public.scenario_vocabulary to service_role;

grant select on table public.scenario_vocabulary to authenticated;

create policy scenario_vocabulary_read on public.scenario_vocabulary for select to authenticated using (exists (select 1 from public.conversation_scenarios s where s.id = scenario_id and s.is_active) and exists (select 1 from public.vocabulary v where v.id = vocabulary_id and v.is_active));

grant update (display_name, preferred_jlpt, daily_target_minutes, timezone) on public.profiles to authenticated;
create policy profiles_settings_update on public.profiles for update to authenticated
using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.review_replay(uuid,jsonb) to service_role;

create index devices_owner_idx on public.devices(user_id);

create index user_learning_items_owner_idx on public.user_learning_items(user_id);

create index review_events_owner_idx on public.review_events(user_id);

create index study_sessions_owner_idx on public.study_sessions(user_id);

create index daily_plans_owner_idx on public.daily_plans(user_id);

create index quiz_attempts_owner_idx on public.quiz_attempts(user_id);

create index kanji_attempts_owner_idx on public.kanji_attempts(user_id);

create index conversation_sessions_owner_idx on public.conversation_sessions(user_id);

create index learning_errors_owner_idx on public.learning_errors(user_id);

create index user_progress_snapshots_owner_idx on public.user_progress_snapshots(user_id);

create index operation_receipts_owner_idx on public.operation_receipts(user_id);

create index grammar_relations_target_idx on public.grammar_relations(related_grammar_id);
create index scenario_grammar_target_idx on public.scenario_grammar(grammar_id);
create index scenario_vocabulary_target_idx on public.scenario_vocabulary(vocabulary_id);
create index learning_due_idx on public.user_learning_items(user_id,next_review_at);
create index review_item_idx on public.review_events(learning_item_id,user_id);
create index quiz_vocabulary_idx on public.quiz_attempts(vocabulary_id);
create index quiz_kanji_idx on public.quiz_attempts(kanji_id);
create index quiz_grammar_idx on public.quiz_attempts(grammar_id);
create index learning_vocabulary_idx on public.user_learning_items(vocabulary_id);
create index learning_kanji_idx on public.user_learning_items(kanji_id);
create index learning_grammar_idx on public.user_learning_items(grammar_id);
create index kanji_attempt_content_idx on public.kanji_attempts(kanji_id);
create index conversation_scenario_idx on public.conversation_sessions(scenario_id);
-- Message sequence and example-parent indexes are supplied by their unique constraints.
commit;
