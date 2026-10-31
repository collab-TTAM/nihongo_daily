-- Private, undeployed report ledger. No public RPC or active-content validation.
begin;

create function private.quiz_report_uuid(p_value jsonb) returns uuid
language plpgsql immutable set search_path = '' as $$
begin
  if jsonb_typeof(p_value) is distinct from 'string' or
     length(p_value #>> '{}') <> 36 or
     (p_value #>> '{}') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  return (p_value #>> '{}')::uuid;
end $$;

-- Validates decoded JSONB, not original HTTP bytes/duplicate keys/number lexemes.
create function private.quiz_report_request(p_request jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare answer jsonb; choice jsonb; targets uuid[] := '{}'; choices uuid[];
  target uuid; selected uuid; version_text text; instant_text text; keys text[];
begin
  if jsonb_typeof(p_request) is distinct from 'object' or
     octet_length(p_request::text) > 16384 then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  select array_agg(k order by k) into keys from jsonb_object_keys(p_request) as fields(k);
  if keys is distinct from array['answers','client_event_id','completed_at','jlpt_level','practice_kind','quiz_type'] then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  perform private.quiz_report_uuid(p_request->'client_event_id');
  if (p_request->>'quiz_type') not in ('vocabulary_reading','grammar_meaning') or
     (p_request->>'quiz_type') is null or
     (p_request->>'jlpt_level') not in ('N5','N4') or (p_request->>'jlpt_level') is null then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  if p_request->>'quiz_type'='vocabulary_reading' then
    if p_request->'practice_kind' is distinct from 'null'::jsonb then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
  elsif (p_request->>'practice_kind') not in ('primary','correction') or
        (p_request->>'practice_kind') is null then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  instant_text := p_request->>'completed_at';
  if jsonb_typeof(p_request->'completed_at') is distinct from 'string' or
     length(instant_text)>27 or right(instant_text,1)<>'Z' or
     instant_text !~ '^(20[0-9]{2}|2100)-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]{1,6})?Z$' then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  perform private.review_instant(instant_text);
  if jsonb_typeof(p_request->'answers') is distinct from 'array' then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  if jsonb_array_length(p_request->'answers') not between 1 and 10 then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  for answer in select value from jsonb_array_elements(p_request->'answers') loop
    if jsonb_typeof(answer) is distinct from 'object' then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
    select array_agg(k order by k) into keys from jsonb_object_keys(answer) as fields(k);
    if keys is distinct from array['choices','content_version','item_id','selected_id'] then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
    target := private.quiz_report_uuid(answer->'item_id');
    selected := private.quiz_report_uuid(answer->'selected_id');
    if target=any(targets) then raise exception 'VALIDATION_FAILURE' using errcode='P0001'; end if;
    targets := array_append(targets,target);
    version_text := answer->>'content_version';
    if jsonb_typeof(answer->'content_version') is distinct from 'number' or
       version_text !~ '^[1-9][0-9]{0,9}$' then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
    if version_text::bigint>2147483647 then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
    if jsonb_typeof(answer->'choices') is distinct from 'array' then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
    if jsonb_array_length(answer->'choices')<>4 then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
    choices := '{}';
    for choice in select value from jsonb_array_elements(answer->'choices') loop
      selected := private.quiz_report_uuid(choice);
      if selected=any(choices) then raise exception 'VALIDATION_FAILURE' using errcode='P0001'; end if;
      choices := array_append(choices,selected);
    end loop;
    if not target=any(choices) or not (answer->>'selected_id')::uuid=any(choices) then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
  end loop;
  return p_request;
end $$;

create table private.quiz_report_receipts (
  user_id uuid not null references auth.users(id) on delete restrict,
  client_event_id uuid not null,
  request_json jsonb not null check (jsonb_typeof(request_json)='object'),
  response_json jsonb not null check (jsonb_typeof(response_json)='object'),
  received_at timestamptz not null default clock_timestamp(),
  primary key (user_id,client_event_id),
  check ((request_json->>'client_event_id')::uuid=client_event_id)
);
alter table private.quiz_report_receipts enable row level security;
revoke all on table private.quiz_report_receipts from public,anon,authenticated,service_role;
create policy quiz_report_owner_read on private.quiz_report_receipts for select
  to authenticated using ((select auth.uid())=user_id);
create trigger quiz_report_receipts_immutable before update or delete on private.quiz_report_receipts
  for each row execute function private.reject_event_mutation();

-- Holds the owner lock until transaction end, including a miss. A future trusted
-- wrapper must call lookup BEFORE current-content checks, then validate, then store.
create function private.replay_quiz_report(p_request jsonb) returns jsonb
language plpgsql volatile set search_path = '' as $$
declare owner_id uuid := auth.uid(); event_id uuid; existing private.quiz_report_receipts;
begin
  if owner_id is null then raise exception 'UNAUTHORIZED' using errcode='P0001'; end if;
  perform private.quiz_report_request(p_request);
  event_id := (p_request->>'client_event_id')::uuid;
  perform pg_advisory_xact_lock(hashtextextended(owner_id::text,3164));
  select * into existing from private.quiz_report_receipts
    where user_id=owner_id and client_event_id=event_id;
  if found then
    if existing.request_json<>p_request then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
    return existing.response_json;
  end if;
  return null;
end $$;

create function private.store_quiz_report(p_request jsonb) returns jsonb
language plpgsql volatile set search_path = '' as $$
declare owner_id uuid := auth.uid(); original jsonb; response jsonb; total integer; correct integer;
begin
  original := private.replay_quiz_report(p_request);
  if original is not null then return original; end if;
  if (private.review_instant(p_request->>'completed_at')->>'epoch')::numeric >
     extract(epoch from clock_timestamp())+300 then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  select count(*)::integer,count(*) filter (where value->>'item_id'=value->>'selected_id')::integer
    into total,correct from jsonb_array_elements(p_request->'answers');
  response := (p_request-'answers') || jsonb_build_object('answer_count',total,'correct_count',correct);
  insert into private.quiz_report_receipts(user_id,client_event_id,request_json,response_json)
    values (owner_id,(p_request->>'client_event_id')::uuid,p_request,response);
  return response;
end $$;

revoke all on function private.quiz_report_uuid(jsonb) from public,anon,authenticated,service_role;
revoke all on function private.quiz_report_request(jsonb) from public,anon,authenticated,service_role;
revoke all on function private.replay_quiz_report(jsonb) from public,anon,authenticated,service_role;
revoke all on function private.store_quiz_report(jsonb) from public,anon,authenticated,service_role;
comment on table private.quiz_report_receipts is
  'Private self-report ledger foundation only; no public RPC/canonical content validation/hosted Auth proof/mastery or duration credit.';
commit;
