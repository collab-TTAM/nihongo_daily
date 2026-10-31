-- Additive read-only boundary. Existing v0.1 writes and RLS/grants unchanged.
begin;
create function public.get_review_queue(p_request jsonb) returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
declare
  owner_id uuid; wanted text; page_size integer; captured timestamptz;
  rows jsonb; invalid_epoch boolean;
begin
  owner_id := auth.uid();
  if owner_id is null or not exists(select 1 from public.profiles where id=owner_id) then
    return jsonb_build_object('code','UNAUTHORIZED','message_vi','Cần phiên đăng nhập và hồ sơ hợp lệ.','retryable',false);
  end if;
  if p_request is null or jsonb_typeof(p_request)<>'object' or pg_column_size(p_request)>32768 then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Yêu cầu danh sách ôn tập không hợp lệ.','retryable',false);
  end if;
  if not (p_request ?& array['jlpt_level','limit']) or
     (select count(*) from jsonb_object_keys(p_request))<>2 or
     jsonb_typeof(p_request->'jlpt_level')<>'string' or
     p_request->>'jlpt_level' not in ('N5','N4','N3','N2','N1') or
     jsonb_typeof(p_request->'limit')<>'number' then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Yêu cầu danh sách ôn tập không hợp lệ.','retryable',false);
  end if;
  if (p_request->>'limit')::numeric<1 or (p_request->>'limit')::numeric>100 or
     trunc((p_request->>'limit')::numeric)<>(p_request->>'limit')::numeric then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Giới hạn danh sách ôn tập không hợp lệ.','retryable',false);
  end if;
  wanted := p_request->>'jlpt_level';
  page_size := (p_request->>'limit')::numeric::integer;
  captured := statement_timestamp();
  -- INVOKER uses the caller's RLS and explicit owner predicate. No locks/writes,
  -- NEW enrollment, private context or client-supplied wall clock/owner.
  with own_due as (
    select item_type,item_id,next_review_at from public.user_learning_items
    where user_id=owner_id and srs_state in ('LEARNING','REVIEW','RELEARNING')
      and review_count>0 and next_review_at<=captured
  ), projected as (
    select 'VOCABULARY'::text item_type,u.item_id,u.next_review_at,
      v.expression prompt_ja,v.reading reading_ja,v.meaning_vi answer_vi
    from own_due u join public.vocabulary v on u.item_type='VOCABULARY' and v.id=u.item_id
    where v.is_active and v.jlpt_level::text=wanted
    union all
    select 'KANJI',u.item_id,u.next_review_at,k.character,
      coalesce(array_to_string(k.onyomi||k.kunyomi,'・'),''),k.meaning_vi
    from own_due u join public.kanji k on u.item_type='KANJI' and k.id=u.item_id
    where k.is_active and k.jlpt_level::text=wanted
    union all
    -- Grammar has no canonical pattern-reading field. Do not invent one or
    -- label an example-sentence reading as the pattern's pronunciation.
    select 'GRAMMAR',u.item_id,u.next_review_at,g.pattern,''::text,g.meaning_vi
    from own_due u join public.grammar g on u.item_type='GRAMMAR' and g.id=u.item_id
    where g.is_active and g.jlpt_level::text=wanted
  ), limited as (
    select * from projected order by next_review_at,item_type collate "C",item_id limit page_size
  )
  select coalesce(jsonb_agg(jsonb_build_object('item_type',item_type,'item_id',item_id,
    'prompt_ja',prompt_ja,'reading_ja',reading_ja,'answer_vi',answer_vi,
    'next_review_at',to_char(next_review_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))
    order by next_review_at,item_type collate "C",item_id),'[]'::jsonb),
    coalesce(bool_or(extract(year from next_review_at)<1 or extract(year from next_review_at)>9999),false)
    into rows,invalid_epoch from limited;
  if invalid_epoch or exists(select 1 from jsonb_array_elements(rows) r where
    btrim(r->>'prompt_ja')='' or btrim(r->>'answer_vi')='' or
    char_length(r->>'prompt_ja')>5000 or char_length(r->>'reading_ja')>5000 or
    char_length(r->>'answer_vi')>5000 or
    (r->>'next_review_at') !~ '^\d{4}-\d{2}-\d{2}T') then
    return jsonb_build_object('code','INTERNAL_ERROR','message_vi','Không thể tải danh sách ôn tập.','retryable',false);
  end if;
  return jsonb_build_object('jlpt_level',wanted,
    'server_time',to_char(captured at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'items',rows);
exception
  when invalid_text_representation then
    return jsonb_build_object('code','UNAUTHORIZED','message_vi','Cần phiên đăng nhập và hồ sơ hợp lệ.','retryable',false);
  when others then
    return jsonb_build_object('code','INTERNAL_ERROR','message_vi','Không thể tải danh sách ôn tập.','retryable',false);
end $$;
revoke all on function public.get_review_queue(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.get_review_queue(jsonb) to authenticated;
commit;
