-- Additive, private nd-quiz-report-2 ledger support. No public endpoint or grant.
-- V1 helpers remain unchanged; both versions share the same owner/event receipt key.
begin;
create function private.quiz_report_request_v2(p_request jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  answer jsonb; choice jsonb; targets uuid[] := '{}'; choices uuid[];
  choice_versions integer[]; target uuid; selected uuid; version_text text;
  version_value integer; instant_text text; keys text[]; target_index integer;
begin
  if jsonb_typeof(p_request) is distinct from 'object' or octet_length(p_request::text)>16384 then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  select array_agg(k order by k) into keys from jsonb_object_keys(p_request) as fields(k);
  if keys is distinct from array[
    'answers','client_event_id','completed_at','jlpt_level','practice_kind','quiz_type'
  ] then raise exception 'VALIDATION_FAILURE' using errcode='P0001'; end if;
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
  if jsonb_typeof(p_request->'answers') is distinct from 'array' or
     jsonb_array_length(p_request->'answers') not between 1 and 10 then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;

  for answer in select value from jsonb_array_elements(p_request->'answers') loop
    if jsonb_typeof(answer) is distinct from 'object' then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
    select array_agg(k order by k) into keys from jsonb_object_keys(answer) as fields(k);
    if keys is distinct from array[
      'choice_content_versions','choices','content_version','item_id','selected_id'
    ] then raise exception 'VALIDATION_FAILURE' using errcode='P0001'; end if;
    target := private.quiz_report_uuid(answer->'item_id');
    selected := private.quiz_report_uuid(answer->'selected_id');
    if target=any(targets) then raise exception 'VALIDATION_FAILURE' using errcode='P0001'; end if;
    targets := array_append(targets,target);

    version_text := answer->>'content_version';
    if jsonb_typeof(answer->'content_version') is distinct from 'number' or
       version_text !~ '^[1-9][0-9]{0,9}$' or version_text::bigint>2147483647 then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
    version_value := version_text::integer;

    if jsonb_typeof(answer->'choices') is distinct from 'array' or
       jsonb_array_length(answer->'choices')<>4 then
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

    if jsonb_typeof(answer->'choice_content_versions') is distinct from 'array' or
       jsonb_array_length(answer->'choice_content_versions')<>4 then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
    choice_versions := '{}';
    for choice in select value from jsonb_array_elements(answer->'choice_content_versions') loop
      version_text := choice #>> '{}';
      if jsonb_typeof(choice) is distinct from 'number' or
         version_text !~ '^[1-9][0-9]{0,9}$' or version_text::bigint>2147483647 then
        raise exception 'VALIDATION_FAILURE' using errcode='P0001';
      end if;
      choice_versions := array_append(choice_versions,version_text::integer);
    end loop;
    target_index := array_position(choices,target);
    if target_index is null or choice_versions[target_index]<>version_value then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
  end loop;
  return p_request;
end $$;

create function private.replay_quiz_report_v2(p_request jsonb) returns jsonb
language plpgsql volatile set search_path = '' as $$
declare owner_id uuid := auth.uid(); event_id uuid; existing private.quiz_report_receipts;
begin
  if owner_id is null then raise exception 'UNAUTHORIZED' using errcode='P0001'; end if;
  perform private.quiz_report_request_v2(p_request);
  event_id := private.quiz_report_uuid(p_request->'client_event_id');
  perform pg_advisory_xact_lock(hashtextextended(owner_id::text,3164));
  select * into existing from private.quiz_report_receipts
    where user_id=owner_id and client_event_id=event_id;
  if found then
    if existing.request_json<>p_request then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
    return existing.response_json;
  end if;
  return null;
end $$;

create function private.store_quiz_report_v2(p_request jsonb) returns jsonb
language plpgsql volatile set search_path = '' as $$
declare owner_id uuid := auth.uid(); original jsonb; response jsonb; total integer; correct integer;
begin
  original := private.replay_quiz_report_v2(p_request);
  if original is not null then return original; end if;
  if (private.review_instant(p_request->>'completed_at')->>'epoch')::numeric >
     extract(epoch from clock_timestamp())+300 then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  select count(*)::integer,
         count(*) filter (where value->>'item_id'=value->>'selected_id')::integer
    into total,correct from jsonb_array_elements(p_request->'answers');
  response := (p_request-'answers') || jsonb_build_object('answer_count',total,'correct_count',correct);
  insert into private.quiz_report_receipts(user_id,client_event_id,request_json,response_json)
    values (owner_id,(p_request->>'client_event_id')::uuid,p_request,response);
  return response;
end $$;

revoke all on function private.quiz_report_request_v2(jsonb) from public,anon,authenticated,service_role;
revoke all on function private.replay_quiz_report_v2(jsonb) from public,anon,authenticated,service_role;
revoke all on function private.store_quiz_report_v2(jsonb) from public,anon,authenticated,service_role;
comment on function private.quiz_report_request_v2(jsonb) is
  'Private nd-quiz-report-2 JSONB validator; original raw bytes must be validated before JSONB conversion.';
comment on function private.replay_quiz_report_v2(jsonb) is
  'Private v2 replay using the same owner/event lock and receipt table as frozen v1.';
comment on function private.store_quiz_report_v2(jsonb) is
  'Private v2 self-report receipt store; no public grant, mastery, SRS or study credit.';
commit;
