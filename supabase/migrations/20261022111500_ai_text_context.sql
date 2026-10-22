-- Undeployed read-only tutor/correction component. Verified identity is supplied
-- ONLY by the trusted backend; this is not a client RPC or Auth verifier.
begin;
create function private.ai_text_context(p_user_id uuid, p_operation text, p_request jsonb)
returns jsonb language plpgsql stable set search_path = '' as $$
declare
  level_text text;
  selected_level public.jlpt_level;
  context_json jsonb;
  ids jsonb;
  value jsonb;
  kind text;
  item_id uuid;
  seen uuid[];
  entry jsonb;
  items jsonb := '[]';
  refs jsonb := '[]';
  result jsonb;
begin
  if p_user_id is null or p_operation is null or p_operation not in ('tutor_explain','correct_sentence')
    or p_request is null or jsonb_typeof(p_request) <> 'object'
    or octet_length(convert_to(p_request::text,'UTF8')) > 32768 then
    raise exception 'VALIDATION_FAILURE' using errcode='22023';
  end if;
  level_text := p_request->>'jlpt_level';
  if level_text is null or level_text not in ('N5','N4','N3','N2','N1') then
    raise exception 'VALIDATION_FAILURE' using errcode='22023';
  end if;
  if p_operation='tutor_explain' then
    context_json := p_request->'context';
    if p_request - array['jlpt_level','question_vi','context'] <> '{}'
      or jsonb_typeof(p_request->'question_vi') is distinct from 'string'
      or char_length(p_request->>'question_vi') not between 1 and 5000
      or jsonb_typeof(context_json) is distinct from 'object'
      or context_json - array['recent_grammar_ids','recent_vocabulary_ids'] <> '{}' then
      raise exception 'VALIDATION_FAILURE' using errcode='22023';
    end if;
    foreach kind in array array['GRAMMAR','VOCABULARY'] loop
      ids := context_json->case when kind='GRAMMAR' then 'recent_grammar_ids' else 'recent_vocabulary_ids' end;
      if jsonb_typeof(ids) is distinct from 'array' then
        raise exception 'VALIDATION_FAILURE' using errcode='22023';
      end if;
      if jsonb_array_length(ids) > 100 then
        raise exception 'VALIDATION_FAILURE' using errcode='22023';
      end if;
      seen := '{}';
      for value in select x from jsonb_array_elements(ids) x loop
        if jsonb_typeof(value) <> 'string' or value#>>'{}' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
          raise exception 'VALIDATION_FAILURE' using errcode='22023';
        end if;
        item_id := (value#>>'{}')::uuid;
        if item_id=any(seen) then
          raise exception 'VALIDATION_FAILURE' using errcode='22023';
        end if;
        seen := array_append(seen,item_id);
      end loop;
    end loop;
  elsif p_request - array['jlpt_level','sentence_ja'] <> '{}'
    or jsonb_typeof(p_request->'sentence_ja') is distinct from 'string'
    or char_length(p_request->>'sentence_ja') not between 1 and 5000 then
    raise exception 'VALIDATION_FAILURE' using errcode='22023';
  end if;

  select preferred_jlpt into selected_level from public.profiles where id=p_user_id;
  if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
  if selected_level::text <> level_text then
    raise exception 'FORBIDDEN' using errcode='42501';
  end if;
  -- STABLE gives all these reads one statement snapshot. No user history,
  -- scenarios/system_context, audio, tokens or learner-supplied roles are read.
  for kind in select unnest(array['GRAMMAR','VOCABULARY']) loop
    if p_operation='tutor_explain' then
      ids := context_json->case when kind='GRAMMAR' then 'recent_grammar_ids' else 'recent_vocabulary_ids' end;
    else
      -- Fixed bounded candidate selection, not a caller-controlled SQL limit.
      if kind='GRAMMAR' then
        select coalesce(jsonb_agg(id order by id),'[]') into ids from
          (select id from public.grammar where is_active and jlpt_level=selected_level order by id limit 32) candidates;
      else
        select coalesce(jsonb_agg(id order by id),'[]') into ids from
          (select id from public.vocabulary where is_active and jlpt_level=selected_level order by id limit 32) candidates;
      end if;
    end if;
    -- Canonical ordering/case is independent of the learner's array order.
    for item_id in select (x#>>'{}')::uuid from jsonb_array_elements(ids) x order by (x#>>'{}')::uuid loop
      if kind='GRAMMAR' then
        select jsonb_build_object('item_type',kind,'item_id',g.id,'content_version',g.content_version,
          'title',g.title,'pattern',g.pattern,'meaning_vi',g.meaning_vi) into entry
          from public.grammar g where g.id=item_id and g.is_active and g.jlpt_level=selected_level;
      else
        select jsonb_build_object('item_type',kind,'item_id',v.id,'content_version',v.content_version,
          'expression',v.expression,'reading',v.reading,'meaning_vi',v.meaning_vi) into entry
          from public.vocabulary v where v.id=item_id and v.is_active and v.jlpt_level=selected_level;
      end if;
      if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
      if octet_length(convert_to((items || jsonb_build_array(entry))::text,'UTF8')) > 8000 then
        if p_operation='tutor_explain' then
          -- Required references are never silently dropped or partially cut.
          raise exception 'VALIDATION_FAILURE' using errcode='22023';
        end if;
        continue;
      end if;
      items := items || jsonb_build_array(entry);
      refs := refs || jsonb_build_array(jsonb_build_object('item_type',kind,'item_id',item_id));
    end loop;
  end loop;
  result := jsonb_build_object('instruction',jsonb_build_object('jlpt_level',selected_level,'curriculum',items)::text,
    'transcript','[]'::jsonb,'allowedRefs',refs);
  if char_length(result->>'instruction') > 10000
    or octet_length(convert_to(result::text,'UTF8')) > 65536 then
    raise exception 'VALIDATION_FAILURE' using errcode='22023';
  end if;
  return result;
end $$;

-- Re-read profile/content after a provider result. The runtime must also validate
-- the original wire response and allowed refs; no model text is accepted here.
create function private.ai_validate_text_context(p_user_id uuid, p_operation text, p_request jsonb, p_context jsonb)
returns void language plpgsql stable set search_path = '' as $$
begin
  if private.ai_text_context(p_user_id,p_operation,p_request) is distinct from p_context then
    raise exception 'SYNC_CONFLICT' using errcode='P0001';
  end if;
end $$;
revoke all on function private.ai_text_context(uuid,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function private.ai_validate_text_context(uuid,text,jsonb,jsonb) from public,anon,authenticated,service_role;
grant execute on function private.ai_text_context(uuid,text,jsonb) to service_role;
grant execute on function private.ai_validate_text_context(uuid,text,jsonb,jsonb) to service_role;
-- Existing table/RLS/client grants and every public wire contract are unchanged.
commit;
