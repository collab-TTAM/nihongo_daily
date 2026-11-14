-- Additive authenticated transaction; no hosted deployment or Auth strategy change.
begin;

-- Exact retry identity preserves sub-microsecond wire digits. Scheduling uses
-- truncated microseconds, matching Dart DateTime; epoch retains full precision.
create function private.review_instant(p_text text) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare m text[]; local_second timestamp; utc_second timestamp; offset_minutes integer;
  fraction text; instant timestamptz; exact_epoch numeric; wire text;
begin
  if p_text is null or length(p_text)>4096 then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  m := regexp_match(p_text,
    '^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})([.][0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$');
  if m is null or m[1]::integer not between 1 and 9999 or
     m[4]::integer>23 or m[5]::integer>59 or m[6]::integer>59 then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  local_second := make_timestamp(m[1]::integer,m[2]::integer,m[3]::integer,
    m[4]::integer,m[5]::integer,m[6]::double precision);
  offset_minutes := 0;
  if m[8]<>'Z' then
    if substring(m[8],2,2)::integer>23 or substring(m[8],5,2)::integer>59 then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
    offset_minutes := (substring(m[8],2,2)::integer*60+substring(m[8],5,2)::integer)
      * case when left(m[8],1)='-' then -1 else 1 end;
  end if;
  utc_second := local_second - make_interval(mins=>offset_minutes);
  if extract(year from utc_second) not between 1 and 9999 then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  fraction := rtrim(coalesce(substring(m[7],2),''),'0');
  exact_epoch := extract(epoch from (utc_second at time zone 'UTC'))
    + case when fraction='' then 0 else ('0.'||fraction)::numeric end;
  instant := (utc_second at time zone 'UTC')
    + (rpad(left(fraction,6),6,'0')::integer * interval '1 microsecond');
  wire := to_char(utc_second,'YYYY-MM-DD"T"HH24:MI:SS')
    || case when fraction='' then '' else '.'||fraction end || 'Z';
  return jsonb_build_object('wire',wire,'instant',
    to_char(instant at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'epoch',exact_epoch);
exception when data_exception then
  raise exception 'VALIDATION_FAILURE' using errcode='P0001';
end $$;

create function private.review_request(p_request jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare field text; num numeric; parsed jsonb;
  fields constant text[] := array['client_event_id','item_type','item_id','rating',
    'is_correct','response_ms','occurred_at'];
begin
  if p_request is null or jsonb_typeof(p_request)<>'object' then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  if octet_length(p_request::text)>32768 or not (p_request ?& fields) or
     (select count(*) from jsonb_object_keys(p_request))<>7 then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  foreach field in array array['client_event_id','item_id'] loop
    if jsonb_typeof(p_request->field)<>'string' or (p_request->>field) !~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
  end loop;
  if jsonb_typeof(p_request->'item_type')<>'string' or
     p_request->>'item_type' not in ('VOCABULARY','KANJI','GRAMMAR') or
     jsonb_typeof(p_request->'is_correct')<>'boolean' or
     jsonb_typeof(p_request->'occurred_at')<>'string' then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  foreach field in array array['rating','response_ms'] loop
    if jsonb_typeof(p_request->field)<>'number' then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
    num := (p_request->>field)::numeric;
    if num<>trunc(num) or num<0 or num>(case when field='rating' then 3 else 3600000 end) then
      raise exception 'VALIDATION_FAILURE' using errcode='P0001';
    end if;
  end loop;
  if (p_request->>'is_correct')::boolean is distinct from ((p_request->>'rating')::numeric<>0) then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  parsed := private.review_instant(p_request->>'occurred_at');
  return p_request || jsonb_build_object(
    'client_event_id',lower(p_request->>'client_event_id'),
    'item_id',lower(p_request->>'item_id'),
    'occurred_at',parsed->>'wire');
end $$;

-- Private pure port of nd-srs-1. Never callable with client-supplied card state.
create function private.schedule_review(p_card public.user_learning_items,
  p_rating integer, p_event timestamptz) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare d double precision; days double precision; base double precision;
  overdue double precision; elapsed double precision; micros bigint; due timestamptz;
  state public.srs_state; delta double precision;
begin
  if p_rating is null or p_rating not between 0 and 3 or p_event is null or
     not isfinite(p_event) or p_card.srs_state is null or p_card.srs_state='MASTERED' or
     p_card.review_count is null or p_card.review_count<0 or p_card.review_count>=2147483647 or
     p_card.correct_count is null or p_card.incorrect_count is null or
     p_card.correct_count<0 or p_card.incorrect_count<0 or
     p_card.correct_count::bigint+p_card.incorrect_count::bigint<>p_card.review_count or
     p_card.difficulty is null or p_card.interval_days is null then
    raise exception 'INTERNAL_ERROR' using errcode='P0001';
  end if;
  if p_card.srs_state='NEW' then
    if p_card.review_count<>0 or p_card.interval_days<>0 or
       p_card.last_review_at is not null or p_card.next_review_at is not null then
      raise exception 'INTERNAL_ERROR' using errcode='P0001';
    end if;
  elsif p_card.review_count=0 or p_card.interval_days<=0 or
    p_card.last_review_at is null or p_card.next_review_at is null or
    p_card.next_review_at<=p_card.last_review_at then
    raise exception 'INTERNAL_ERROR' using errcode='P0001';
  end if;
  if p_event<p_card.last_review_at then
    raise exception 'SYNC_CONFLICT' using errcode='P0001';
  end if;
  delta := case p_rating when 0 then 0.15 when 1 then 0.05 when 2 then -0.02 else -0.05 end;
  d := floor(least(1.0,greatest(0.0,p_card.difficulty::double precision+delta))*1000000+0.5)/1000000;
  if p_rating=0 then
    days := 1.0::double precision/1440;
    state := case when p_card.srs_state in ('REVIEW','RELEARNING') then 'RELEARNING' else 'LEARNING' end;
  elsif p_card.srs_state<>'REVIEW' then
    case p_rating
      when 1 then
        state := case when p_card.srs_state='RELEARNING' then 'RELEARNING' else 'LEARNING' end;
        days := 5.0::double precision/1440;
      when 2 then
        state := case when p_card.srs_state='NEW' then 'LEARNING' else 'REVIEW' end;
        days := case when p_card.srs_state='NEW' then 10.0::double precision/1440 else 1 end;
      when 3 then state := 'REVIEW'; days := 4;
    end case;
  else
    state := 'REVIEW';
    elapsed := (extract(epoch from (p_event-p_card.last_review_at))*1000000)::double precision/86400000000;
    base := least(365.0,p_card.interval_days::double precision,greatest(1.0,elapsed));
    overdue := greatest(0.0,(extract(epoch from (p_event-p_card.next_review_at))*1000000)::double precision/86400000000);
    days := case p_rating
      when 1 then greatest(1.0,base*1.2)
      when 2 then greatest(1.0,(base+least(overdue/2,base))*(2.5-d))
      when 3 then greatest(4.0,(base+least(overdue,base))*(3.0-d)) end;
    days := least(365.0,greatest(1.0,days));
  end if;
  micros := floor(days*86400000000+0.5)::bigint;
  due := p_event + (micros::double precision*interval '1 microsecond');
  if extract(year from due at time zone 'UTC') not between 1 and 9999 then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  return jsonb_build_object('srs_state',state,'interval_days',micros::double precision/86400000000,
    'difficulty',d,'review_count',p_card.review_count+1,
    'correct_count',p_card.correct_count+case when p_rating=0 then 0 else 1 end,
    'incorrect_count',p_card.incorrect_count+case when p_rating=0 then 1 else 0 end,
    'last_review_at',to_char(p_event at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'next_review_at',to_char(due at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'));
end $$;

create function private.review_response(p_result jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare field text; value numeric;
begin
  if p_result is null or jsonb_typeof(p_result)<>'object' then
    raise exception 'INTERNAL_ERROR' using errcode='P0001';
  end if;
  if not (p_result ?& array['srs_state','next_review_at','interval_days','difficulty','review_count']) or
     (select count(*) from jsonb_object_keys(p_result))<>5 or
     jsonb_typeof(p_result->'srs_state')<>'string' or
     p_result->>'srs_state' not in ('LEARNING','REVIEW','RELEARNING') or
     jsonb_typeof(p_result->'next_review_at')<>'string' then
    raise exception 'INTERNAL_ERROR' using errcode='P0001';
  end if;
  perform private.review_instant(p_result->>'next_review_at');
  foreach field in array array['interval_days','difficulty','review_count'] loop
    if jsonb_typeof(p_result->field)<>'number' then
      raise exception 'INTERNAL_ERROR' using errcode='P0001';
    end if;
    value := (p_result->>field)::numeric;
    if (field='interval_days' and (value<=0 or value>365)) or
       (field='difficulty' and (value<0 or value>1)) or
       (field='review_count' and (value<>trunc(value) or value<1 or value>2147483647)) then
      raise exception 'INTERNAL_ERROR' using errcode='P0001';
    end if;
  end loop;
  return p_result;
exception when others then
  raise exception 'INTERNAL_ERROR' using errcode='P0001';
end $$;

create function public.submit_review(p_request jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare owner_id uuid; request jsonb; parsed jsonb; replay jsonb;
  kind public.learning_item_type; content_id uuid; event_id uuid; rating integer;
  active boolean; card public.user_learning_items%rowtype; state jsonb; response jsonb;
  last_epoch numeric; code text; message text;
begin
  begin owner_id := auth.uid();
  exception when invalid_text_representation then
    raise exception 'UNAUTHORIZED' using errcode='P0001';
  end;
  if owner_id is null or not exists(select 1 from auth.users where id=owner_id) then
    raise exception 'UNAUTHORIZED' using errcode='P0001';
  end if;
  request := private.review_request(p_request);
  parsed := private.review_instant(request->>'occurred_at');
  kind := (request->>'item_type')::public.learning_item_type;
  content_id := (request->>'item_id')::uuid;
  event_id := (request->>'client_event_id')::uuid;
  rating := (request->>'rating')::numeric::integer;
  -- One owner-scoped transaction mutex also serializes the same event sent for
  -- different items. Hash collisions only serialize extra users, never authorize.
  perform pg_advisory_xact_lock(hashtextextended('nd-review/'||owner_id::text,0));
  replay := private.review_replay(owner_id,request);
  if replay is not null then return private.review_response(replay); end if;
  if (parsed->>'epoch')::numeric>extract(epoch from clock_timestamp())+300 then
    raise exception 'VALIDATION_FAILURE' using errcode='P0001';
  end if;
  case kind
    when 'VOCABULARY' then select is_active into active from public.vocabulary where id=content_id for share;
    when 'KANJI' then select is_active into active from public.kanji where id=content_id for share;
    when 'GRAMMAR' then select is_active into active from public.grammar where id=content_id for share;
  end case;
  if active is distinct from true then raise exception 'NOT_FOUND' using errcode='P0001'; end if;
  insert into public.user_learning_items(user_id,item_type,item_id)
    values(owner_id,kind,content_id) on conflict(user_id,item_type,item_id) do nothing;
  select * into strict card from public.user_learning_items
    where user_id=owner_id and item_type=kind and item_id=content_id for update;
  last_epoch := extract(epoch from card.last_review_at);
  -- Metadata preserves exact raw fractional chronology beyond DB microseconds.
  select coalesce((metadata->>'occurred_epoch')::numeric,last_epoch) into last_epoch
    from public.review_events where learning_item_id=card.id and user_id=owner_id
      and metadata->'review_count'=to_jsonb(card.review_count);
  if not found then last_epoch := extract(epoch from card.last_review_at); end if;
  if (parsed->>'epoch')::numeric<last_epoch then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
  state := private.schedule_review(card,rating,(parsed->>'instant')::timestamptz);
  response := state - array['correct_count','incorrect_count','last_review_at'];
  perform private.review_response(response);
  update public.user_learning_items set srs_state=(state->>'srs_state')::public.srs_state,
    interval_days=(state->>'interval_days')::double precision,
    difficulty=(state->>'difficulty')::double precision,
    review_count=(state->>'review_count')::integer,
    correct_count=(state->>'correct_count')::integer,
    incorrect_count=(state->>'incorrect_count')::integer,
    last_review_at=(state->>'last_review_at')::timestamptz,
    next_review_at=(state->>'next_review_at')::timestamptz where id=card.id and user_id=owner_id;
  insert into public.review_events(user_id,learning_item_id,rating,response_ms,is_correct,
    occurred_at,client_event_id,request_json,result_json,metadata)
    values(owner_id,card.id,rating,(request->>'response_ms')::numeric::integer,rating<>0,
      (parsed->>'instant')::timestamptz,event_id,request,response,
      jsonb_build_object('algorithm_version','nd-srs-1','occurred_epoch',parsed->'epoch',
                        'review_count',state->'review_count'));
  return response;
exception when others then
  -- The exception block rolls back *all* writes before returning a wire error.
  code := case when sqlstate='P0001' and sqlerrm in
    ('UNAUTHORIZED','NOT_FOUND','VALIDATION_FAILURE','SYNC_CONFLICT','INTERNAL_ERROR')
    then sqlerrm else 'INTERNAL_ERROR' end;
  message := case code when 'UNAUTHORIZED' then 'Phiên đăng nhập không hợp lệ. Hãy đăng nhập lại.'
    when 'NOT_FOUND' then 'Không tìm thấy nội dung đang hoạt động.'
    when 'VALIDATION_FAILURE' then 'Dữ liệu ôn tập không hợp lệ.'
    when 'SYNC_CONFLICT' then 'Lượt ôn tập xung đột với dữ liệu đã lưu.'
    else 'Không lưu được lượt ôn tập. Hãy thử lại sau.' end;
  return jsonb_build_object('code',code,'message_vi',message,'retryable',false);
end $$;

revoke all on function private.review_instant(text) from public,anon,authenticated,service_role;
revoke all on function private.review_request(jsonb) from public,anon,authenticated,service_role;
revoke all on function private.review_response(jsonb) from public,anon,authenticated,service_role;
revoke all on function private.schedule_review(public.user_learning_items,integer,timestamptz)
  from public,anon,authenticated,service_role;
revoke all on function public.submit_review(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.submit_review(jsonb) to authenticated;
-- No table write grants or RLS policies changed. All identifiers are qualified;
-- only this reviewed definer function may mutate caller-derived review state.
commit;
