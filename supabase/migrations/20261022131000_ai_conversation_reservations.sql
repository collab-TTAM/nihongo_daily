-- Undeployed reservation component; no provider/session completion is installed.
begin;
create table private.ai_conversation_reservations (
  receipt_id uuid primary key references private.ai_receipt_claims(receipt_id) on delete restrict,
  session_id uuid not null,
  assistant_message_id uuid unique,
  assistant_sequence_no integer,
  user_message_id uuid unique,
  user_sequence_no integer,
  context_json jsonb not null check (jsonb_typeof(context_json)='object'
    and octet_length(convert_to(context_json::text,'UTF8'))<=65536
    and context_json ? 'sessionId' and jsonb_typeof(context_json->'sessionId')='string'
    and context_json->>'sessionId'=session_id::text),
  is_completed boolean not null default false,
  created_at timestamptz not null default clock_timestamp() check (isfinite(created_at)),
  check ((assistant_message_id is null and assistant_sequence_no is null
      and not (context_json ? 'messageId') and not (context_json ? 'sequenceNo')) or
    (assistant_message_id is not null and assistant_sequence_no is not null and assistant_sequence_no>=0
      and context_json ? 'messageId' and context_json ? 'sequenceNo'
      and jsonb_typeof(context_json->'messageId')='string'
      and context_json->>'messageId'=assistant_message_id::text
      and context_json->'sequenceNo'=to_jsonb(assistant_sequence_no))),
  check ((user_message_id is null and user_sequence_no is null) or
    (user_message_id is not null and user_sequence_no is not null and user_sequence_no>=1
      and assistant_message_id is not null and assistant_sequence_no is not null
      and assistant_sequence_no=user_sequence_no+1))
);
create unique index ai_conversation_one_pending on private.ai_conversation_reservations(session_id) where not is_completed;
alter table private.ai_conversation_reservations enable row level security;
revoke all on private.ai_conversation_reservations from public,anon,authenticated,service_role;
grant select on private.ai_conversation_reservations to service_role;
-- A caller cannot bypass the pending guard by inserting is_completed=true or
-- resetting/deleting rows. Completion/release needs a later validated transaction.
grant insert(receipt_id,session_id,assistant_message_id,assistant_sequence_no,
  user_message_id,user_sequence_no,context_json) on private.ai_conversation_reservations to service_role;

create function private.validate_ai_conversation_request(p_user_id uuid,p_operation text,p_request jsonb)
returns void language plpgsql immutable set search_path='' as $$
declare field text;
begin
  if p_user_id is null or p_operation is null or p_operation not in
    ('start_conversation','conversation_turn','finish_conversation')
    or p_request is null or jsonb_typeof(p_request)<>'object'
    or octet_length(convert_to(p_request::text,'UTF8'))>32768 then
    raise exception 'VALIDATION_FAILURE' using errcode='22023';
  end if;
  foreach field in array array['client_event_id',case when p_operation='start_conversation' then 'scenario_id' else 'session_id' end] loop
    if jsonb_typeof(p_request->field) is distinct from 'string'
      or p_request->>field !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception 'VALIDATION_FAILURE' using errcode='22023';
    end if;
  end loop;
  if p_operation='start_conversation' then
    if p_request-array['client_event_id','scenario_id','jlpt_level']<>'{}'
      or coalesce(p_request->>'jlpt_level','') not in ('N5','N4','N3','N2','N1') then
      raise exception 'VALIDATION_FAILURE' using errcode='22023';
    end if;
  elsif p_operation='conversation_turn' then
    if p_request-array['client_event_id','session_id','text_ja']<>'{}'
      or jsonb_typeof(p_request->'text_ja') is distinct from 'string'
      or char_length(p_request->>'text_ja') not between 1 and 5000 then
      raise exception 'VALIDATION_FAILURE' using errcode='22023';
    end if;
  elsif p_request-array['client_event_id','session_id']<>'{}' then
    raise exception 'VALIDATION_FAILURE' using errcode='22023';
  end if;
end $$;

-- One statement snapshot for source/context reads. IDs are supplied only by the
-- trusted reservation helper; calling this read helper alone grants no dispatch.
create function private.ai_conversation_context(p_user_id uuid,p_operation text,p_request jsonb,
  p_session_id uuid,p_message_id uuid,p_sequence_no integer) returns jsonb
language plpgsql stable set search_path='' as $$
declare
  level public.jlpt_level;
  scenario public.conversation_scenarios%rowtype;
  session public.conversation_sessions%rowtype;
  item record;
  message record;
  refs jsonb:='[]'; targets jsonb:='[]'; transcript jsonb:='[]';
  count_messages integer:=0;
  instruction jsonb;
  result jsonb;
begin
  perform private.validate_ai_conversation_request(p_user_id,p_operation,p_request);
  if p_session_id is null or (p_operation='finish_conversation' and (p_message_id is not null or p_sequence_no is not null))
    or (p_operation<>'finish_conversation' and (p_message_id is null or p_sequence_no is null or p_sequence_no<0)) then
    raise exception 'VALIDATION_FAILURE' using errcode='22023';
  end if;
  select preferred_jlpt into level from public.profiles where id=p_user_id;
  if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
  if p_operation='start_conversation' then
    if p_request->>'jlpt_level'<>level::text then raise exception 'FORBIDDEN' using errcode='42501'; end if;
    if p_sequence_no<>0 then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
    select * into scenario from public.conversation_scenarios where id=(p_request->>'scenario_id')::uuid;
  else
    select * into session from public.conversation_sessions where id=(p_request->>'session_id')::uuid and user_id=p_user_id;
    if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
    if p_session_id<>session.id then raise exception 'FORBIDDEN' using errcode='42501'; end if;
    if session.ended_at is not null then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
    if session.jlpt_level<>level then raise exception 'FORBIDDEN' using errcode='42501'; end if;
    select * into scenario from public.conversation_scenarios where id=session.scenario_id;
  end if;
  if not found or not scenario.is_active or scenario.jlpt_level<>level then
    raise exception 'NOT_FOUND' using errcode='P0002';
  end if;
  if octet_length(convert_to(scenario.system_context,'UTF8'))>8000 then
    raise exception 'VALIDATION_FAILURE' using errcode='22023';
  end if;
  for item in
    select 'GRAMMAR'::text as kind,g.id,g.jlpt_level,g.is_active,g.content_version,
      jsonb_build_object('title',g.title,'pattern',g.pattern,'meaning_vi',g.meaning_vi) as detail
      from public.scenario_grammar sg join public.grammar g on g.id=sg.grammar_id where sg.scenario_id=scenario.id
    union all
    select 'VOCABULARY',v.id,v.jlpt_level,v.is_active,v.content_version,
      jsonb_build_object('expression',v.expression,'reading',v.reading,'meaning_vi',v.meaning_vi)
      from public.scenario_vocabulary sv join public.vocabulary v on v.id=sv.vocabulary_id where sv.scenario_id=scenario.id
    order by kind,id
  loop
    if not item.is_active or item.jlpt_level<>level then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
    if jsonb_array_length(refs)>=1000 then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
    refs:=refs||jsonb_build_array(jsonb_build_object('item_type',item.kind,'item_id',item.id));
    targets:=targets||jsonb_build_array(item.detail||jsonb_build_object('item_type',item.kind,'item_id',item.id,'content_version',item.content_version));
    if octet_length(convert_to(targets::text,'UTF8'))>8000 then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
  end loop;
  instruction:=jsonb_build_object('jlpt_level',level,'scenario_id',scenario.id,
    'content_version',scenario.content_version,'scenario_context',scenario.system_context,'curriculum',targets);
  if octet_length(convert_to(instruction::text,'UTF8'))>10000 then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
  if p_operation<>'start_conversation' then
    for message in select role,text_ja,sequence_no from public.conversation_messages
      where conversation_session_id=session.id order by sequence_no limit 100 loop
      if count_messages>=99 or char_length(message.text_ja)>5000 then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
      if message.sequence_no<>count_messages or message.role<>(case when count_messages%2=0 then 'assistant' else 'user' end) then
        raise exception 'SYNC_CONFLICT' using errcode='P0001';
      end if;
      transcript:=transcript||jsonb_build_array(jsonb_build_object('role',message.role,'text_ja',message.text_ja));
      count_messages:=count_messages+1;
      if octet_length(convert_to(transcript::text,'UTF8'))>60000 then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
    end loop;
    if count_messages=0 or count_messages%2=0 then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
    if p_operation='conversation_turn' and (count_messages>97 or p_sequence_no<>count_messages+1) then
      raise exception 'VALIDATION_FAILURE' using errcode='22023';
    end if;
  end if;
  result:=jsonb_build_object('instruction',instruction::text,'transcript',transcript,'allowedRefs',refs,'sessionId',p_session_id);
  if p_operation<>'finish_conversation' then result:=result||jsonb_build_object('messageId',p_message_id,'sequenceNo',p_sequence_no); end if;
  if octet_length(convert_to(result::text,'UTF8'))>65536 then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
  return result;
end $$;

create function private.ai_conversation_reserve(p_user_id uuid,p_operation text,p_request jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare
  prior jsonb; claim jsonb; context jsonb;
  session public.conversation_sessions%rowtype;
  level public.jlpt_level; scenario_id uuid; v_session_id uuid; receipt uuid;
  assistant_id uuid; assistant_seq integer; reserved_user_message_id uuid; user_seq integer;
begin
  perform private.validate_ai_conversation_request(p_user_id,p_operation,p_request);
  -- Serialize short transactions for one verified owner. No lock is held across
  -- provider I/O; the durable unique pending reservation protects that interval.
  perform pg_advisory_xact_lock(hashtextextended('nihongo-ai-conversation:'||p_user_id::text,0));
  prior:=private.ai_receipt_lookup(p_user_id,p_operation,p_request);
  if prior->>'kind'<>'missing' then return prior; end if;
  select preferred_jlpt into level from public.profiles where id=p_user_id for share;
  if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
  if p_operation='start_conversation' then
    v_session_id:=gen_random_uuid(); scenario_id:=(p_request->>'scenario_id')::uuid;
    assistant_id:=gen_random_uuid(); assistant_seq:=0;
  else
    select * into session from public.conversation_sessions
      where id=(p_request->>'session_id')::uuid and user_id=p_user_id for update;
    if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
    v_session_id:=session.id; scenario_id:=session.scenario_id;
    if exists(select 1 from private.ai_conversation_reservations r where r.session_id=v_session_id and not r.is_completed) then
      raise exception 'SYNC_CONFLICT' using errcode='P0001';
    end if;
    -- A committed legacy pending turn/finish may predate private reservations.
    -- It cannot be overtaken merely because no new slot row exists yet.
    if exists(select 1 from public.operation_receipts r where r.user_id=p_user_id
      and r.operation in ('conversation_turn','finish_conversation') and r.status='PENDING'
      and lower(r.request_json->>'session_id')=v_session_id::text) then
      raise exception 'SYNC_CONFLICT' using errcode='P0001';
    end if;
    if p_operation='conversation_turn' then
      select count(*)::integer into user_seq from public.conversation_messages where conversation_session_id=v_session_id;
      if user_seq>97 then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
      reserved_user_message_id:=gen_random_uuid(); assistant_id:=gen_random_uuid(); assistant_seq:=user_seq+1;
    end if;
  end if;
  perform 1 from public.conversation_scenarios where id=scenario_id for share;
  context:=private.ai_conversation_context(p_user_id,p_operation,p_request,v_session_id,assistant_id,assistant_seq);
  claim:=private.ai_receipt_claim(p_user_id,p_operation,p_request);
  -- Legacy callers may race the same receipt without using this account lock.
  -- A losing pending/completed result never exposes context/another token.
  if claim->>'kind'<>'acquired' then return claim; end if;
  select id into strict receipt from public.operation_receipts where user_id=p_user_id
    and operation=p_operation and client_event_id=(p_request->>'client_event_id')::uuid;
  insert into private.ai_conversation_reservations(receipt_id,session_id,assistant_message_id,assistant_sequence_no,
    user_message_id,user_sequence_no,context_json) values(receipt,v_session_id,assistant_id,assistant_seq,reserved_user_message_id,user_seq,context);
  return claim||jsonb_build_object('context',context);
end $$;
revoke all on function private.validate_ai_conversation_request(uuid,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function private.ai_conversation_context(uuid,text,jsonb,uuid,uuid,integer) from public,anon,authenticated,service_role;
revoke all on function private.ai_conversation_reserve(uuid,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function private.validate_ai_conversation_request(uuid,text,jsonb) to service_role;
grant execute on function private.ai_conversation_context(uuid,text,jsonb,uuid,uuid,integer) to service_role;
grant execute on function private.ai_conversation_reserve(uuid,text,jsonb) to service_role;
-- No public session/message is written yet. Only confirmed COMMIT of acquired
-- may ever authorize dispatch through a future validated conversation runtime.
commit;
