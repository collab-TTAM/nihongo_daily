-- Undeployed trusted completion component. No endpoint, provider or recovery dispatch.
begin;
create function private.validate_ai_conversation_response(p_operation text,p_response jsonb,p_context jsonb)
returns void language plpgsql immutable set search_path='' as $$
declare message jsonb; correction jsonb; ref jsonb; refs jsonb:='[]'; field text; value jsonb;
begin
  if p_operation is null or p_operation not in ('start_conversation','conversation_turn','finish_conversation')
    or p_response is null or jsonb_typeof(p_response)<>'object'
    or octet_length(convert_to(p_response::text,'UTF8'))>1048576
    or p_context is null or jsonb_typeof(p_context->'allowedRefs') is distinct from 'array' then
    raise exception 'VALIDATION_FAILURE' using errcode='22023';
  end if;
  if p_operation='finish_conversation' then
    if p_response-array['scores','errors','strengths_vi','focus_next_vi','srs_recommendations']<>'{}'
      or not (p_response ?& array['scores','errors','strengths_vi','focus_next_vi','srs_recommendations'])
      or jsonb_typeof(p_response->'scores') is distinct from 'object' then
      raise exception 'VALIDATION_FAILURE' using errcode='22023';
    end if;
    if (p_response->'scores')-array['grammar','vocabulary','fluency']<>'{}' then
      raise exception 'VALIDATION_FAILURE' using errcode='22023';
    end if;
    foreach field in array array['grammar','vocabulary','fluency'] loop
      if jsonb_typeof(p_response->'scores'->field) is distinct from 'number' then
        raise exception 'VALIDATION_FAILURE' using errcode='22023';
      end if;
      if (p_response->'scores'->>field)::numeric not between 0 and 100 then
        raise exception 'VALIDATION_FAILURE' using errcode='22023';
      end if;
    end loop;
    foreach field in array array['strengths_vi','focus_next_vi'] loop
      if jsonb_typeof(p_response->field) is distinct from 'array' then
        raise exception 'VALIDATION_FAILURE' using errcode='22023';
      end if;
      if jsonb_array_length(p_response->field)>100 then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
      for value in select v from jsonb_array_elements(p_response->field) v loop
        if jsonb_typeof(value)<>'string' or char_length(value#>>'{}') not between 1 and 2000 then
          raise exception 'VALIDATION_FAILURE' using errcode='22023';
        end if;
      end loop;
    end loop;
    if jsonb_typeof(p_response->'srs_recommendations') is distinct from 'array' then
      raise exception 'VALIDATION_FAILURE' using errcode='22023';
    end if;
    if jsonb_array_length(p_response->'srs_recommendations')>100 then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
    refs:=p_response->'srs_recommendations';
  else
    if (p_operation='start_conversation' and (p_response-array['session_id','assistant_message']<>'{}'
        or p_response->'session_id' is distinct from p_context->'sessionId'))
      or (p_operation='conversation_turn' and p_response-array['assistant_message','live_feedback']<>'{}')
      or jsonb_typeof(p_response->'assistant_message') is distinct from 'object' then
      raise exception 'VALIDATION_FAILURE' using errcode='22023';
    end if;
    message:=p_response->'assistant_message';
    if message-array['id','role','text_ja','text_vi','audio_ref','sequence_no']<>'{}'
      or not (message ?& array['id','role','text_ja','text_vi','audio_ref','sequence_no'])
      or message->'id' is distinct from p_context->'messageId'
      or message->'sequence_no' is distinct from p_context->'sequenceNo'
      or message->>'role' is distinct from 'assistant'
      or message->'audio_ref' is distinct from 'null'::jsonb
      or jsonb_typeof(message->'text_ja') is distinct from 'string'
      or char_length(message->>'text_ja') not between 1 and 5000
      or (message->'text_vi'<>'null' and (jsonb_typeof(message->'text_vi')<>'string'
        or char_length(message->>'text_vi') not between 1 and 5000)) then
      raise exception 'VALIDATION_FAILURE' using errcode='22023';
    end if;
  end if;
  field:=case when p_operation='finish_conversation' then 'errors' else 'live_feedback' end;
  if p_operation='finish_conversation' or p_response ? field then
    if jsonb_typeof(p_response->field) is distinct from 'array' then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
    if jsonb_array_length(p_response->field)>100 then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
    for correction in select v from jsonb_array_elements(p_response->field) v loop
      if jsonb_typeof(correction)<>'object' or correction-array['original_text','corrected_text','explanation_vi','item_refs']<>'{}'
        or not (correction ?& array['original_text','corrected_text','explanation_vi','item_refs']) then
        raise exception 'VALIDATION_FAILURE' using errcode='22023';
      end if;
      foreach field in array array['original_text','corrected_text','explanation_vi'] loop
        if jsonb_typeof(correction->field) is distinct from 'string' or char_length(correction->>field) not between 1 and 2000 then
          raise exception 'VALIDATION_FAILURE' using errcode='22023';
        end if;
      end loop;
      if jsonb_typeof(correction->'item_refs') is distinct from 'array' then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
      if jsonb_array_length(correction->'item_refs')>100 then raise exception 'VALIDATION_FAILURE' using errcode='22023'; end if;
      refs:=refs||(correction->'item_refs');
    end loop;
  end if;
  for ref in select v from jsonb_array_elements(refs) v loop
    if jsonb_typeof(ref)<>'object' or ref-array['item_type','item_id']<>'{}'
      or coalesce(ref->>'item_type','') not in ('GRAMMAR','VOCABULARY','KANJI')
      or jsonb_typeof(ref->'item_id') is distinct from 'string'
      or ref->>'item_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception 'VALIDATION_FAILURE' using errcode='22023';
    end if;
    -- Same canonical identity policy as AiService: no invented or case-rewritten refs.
    if not (p_context->'allowedRefs' @> jsonb_build_array(ref)) then
      raise exception 'FORBIDDEN' using errcode='42501';
    end if;
  end loop;
end $$;

-- Narrow definer authority is necessary to release the private row without giving
-- service callers direct UPDATE privileges. Every write is owner/request/token bound.
create function private.ai_conversation_complete(p_user_id uuid,p_operation text,p_request jsonb,p_token uuid,p_response jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare receipt public.operation_receipts%rowtype; reservation private.ai_conversation_reservations%rowtype;
  session public.conversation_sessions%rowtype; v_scenario_id uuid; level public.jlpt_level; context jsonb; result jsonb;
begin
  perform private.validate_ai_conversation_request(p_user_id,p_operation,p_request);
  perform pg_advisory_xact_lock(hashtextextended('nihongo-ai-conversation:'||p_user_id::text,0));
  select * into receipt from public.operation_receipts where user_id=p_user_id and operation=p_operation
    and client_event_id=(p_request->>'client_event_id')::uuid for update;
  if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
  if receipt.request_json is distinct from p_request then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
  if p_token is null or not exists(select 1 from private.ai_receipt_claims c where c.receipt_id=receipt.id and c.dispatch_token=p_token) then
    raise exception 'FORBIDDEN' using errcode='42501';
  end if;
  select * into reservation from private.ai_conversation_reservations where receipt_id=receipt.id for update;
  if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
  if receipt.status='COMPLETED' then
    if not reservation.is_completed or receipt.response_json is distinct from p_response then
      raise exception 'SYNC_CONFLICT' using errcode='P0001';
    end if;
    return receipt.response_json;
  end if;
  if reservation.is_completed then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
  select preferred_jlpt into level from public.profiles where id=p_user_id for share;
  if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
  if p_operation='start_conversation' then v_scenario_id:=(p_request->>'scenario_id')::uuid;
  else
    select * into session from public.conversation_sessions where id=reservation.session_id and user_id=p_user_id for update;
    if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
    v_scenario_id:=session.scenario_id;
    -- Parent lock blocks FK inserts; row locks also freeze updates/deletes of old text.
    perform 1 from public.conversation_messages where conversation_session_id=session.id order by id for share;
  end if;
  -- Freeze additions via the scenario FK as well as existing links/target updates.
  -- These short locks end before returning; none is held during provider I/O.
  perform 1 from public.conversation_scenarios where id=v_scenario_id for update;
  perform 1 from public.scenario_grammar sg where sg.scenario_id=v_scenario_id order by sg.id for share;
  perform 1 from public.scenario_vocabulary sv where sv.scenario_id=v_scenario_id order by sv.id for share;
  perform 1 from public.grammar g where exists(select 1 from public.scenario_grammar sg
    where sg.scenario_id=v_scenario_id and sg.grammar_id=g.id) order by g.id for share;
  perform 1 from public.vocabulary v where exists(select 1 from public.scenario_vocabulary sv
    where sv.scenario_id=v_scenario_id and sv.vocabulary_id=v.id) order by v.id for share;
  context:=private.ai_conversation_context(p_user_id,p_operation,p_request,reservation.session_id,
    reservation.assistant_message_id,reservation.assistant_sequence_no);
  if context is distinct from reservation.context_json then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
  perform private.validate_ai_conversation_response(p_operation,p_response,context);
  if p_operation='start_conversation' then
    insert into public.conversation_sessions(id,user_id,scenario_id,jlpt_level,started_at)
      values(reservation.session_id,p_user_id,v_scenario_id,level,reservation.created_at);
  elsif p_operation='conversation_turn' then
    insert into public.conversation_messages(id,conversation_session_id,role,text_ja,sequence_no)
      values(reservation.user_message_id,reservation.session_id,'user',p_request->>'text_ja',reservation.user_sequence_no);
  else
    update public.conversation_sessions set ended_at=greatest(clock_timestamp(),started_at),
      summary_json=p_response-'scores',score_json=p_response->'scores' where id=reservation.session_id and user_id=p_user_id;
  end if;
  if p_operation<>'finish_conversation' then
    insert into public.conversation_messages(id,conversation_session_id,role,text_ja,text_vi,audio_ref,sequence_no)
      values(reservation.assistant_message_id,reservation.session_id,'assistant',p_response->'assistant_message'->>'text_ja',
        p_response->'assistant_message'->>'text_vi',null,reservation.assistant_sequence_no);
  end if;
  result:=private.ai_receipt_complete(p_user_id,p_operation,p_request,p_token,p_response);
  update private.ai_conversation_reservations set is_completed=true where receipt_id=receipt.id;
  return result;
end $$;
revoke all on function private.validate_ai_conversation_response(text,jsonb,jsonb) from public,anon,authenticated,service_role;
revoke all on function private.ai_conversation_complete(uuid,text,jsonb,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function private.validate_ai_conversation_response(text,jsonb,jsonb) to service_role;
grant execute on function private.ai_conversation_complete(uuid,text,jsonb,uuid,jsonb) to service_role;
-- No direct UPDATE/DELETE/TRUNCATE grant, reset, expiry, takeover or client RPC.
commit;
