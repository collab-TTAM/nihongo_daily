-- Additive, not deployed. Auth identity is supplied by the existing Supabase
-- JWT boundary; never accept user_id, readiness or completed minutes as input.
begin;

-- nd-plan-1: reserve one minute per block, then apportion the remainder by
-- largest remainder, stable ordinal ties. At 120 this is exactly 20/15/20/15/15/25/10.
create function private.daily_plan_minutes(p_target integer) returns integer[]
language plpgsql immutable set search_path = '' as $$
begin
  if p_target is null or p_target not between 7 and 1440 then
    raise exception 'Invalid plan target' using errcode = '22023';
  end if;
  return (
    with weights(ord, weight) as (values (1,19),(2,14),(3,19),(4,14),(5,14),(6,24),(7,9)),
    shares as (
      select ord, 1 + (p_target - 7) * weight / 113 as minutes,
        (p_target - 7) * weight % 113 as remainder from weights
    ), ranked as (
      select *, row_number() over (order by remainder desc, ord) as rank from shares
    )
    select array_agg((minutes + case when rank <= p_target -
      (select sum(minutes) from shares) then 1 else 0 end)::integer order by ord)
    from ranked
  );
end $$;

-- Fail closed on legacy/corrupt trusted snapshots, rather than returning a
-- success-shaped response that violates the frozen named wire model.
create function private.daily_plan_blocks_valid(p_blocks jsonb, p_target integer)
returns boolean language plpgsql immutable set search_path = '' as $$
declare block jsonb; types text[] := '{}'; total integer := 0; minutes integer;
begin
  if jsonb_typeof(p_blocks) is distinct from 'array' then return false; end if;
  if jsonb_array_length(p_blocks) <> 7 then return false; end if;
  for block in select value from jsonb_array_elements(p_blocks) loop
    if jsonb_typeof(block) is distinct from 'object' then return false; end if;
    if (select count(*) from jsonb_object_keys(block)) <> 4
      or jsonb_typeof(block->'type') is distinct from 'string'
      or jsonb_typeof(block->'status') is distinct from 'string'
      or jsonb_typeof(block->'planned_minutes') is distinct from 'number'
      or jsonb_typeof(block->'item_count') is distinct from 'number' then return false; end if;
    if block->>'type' not in ('SRS','VOCABULARY','KANJI','GRAMMAR','LISTENING_READING','AI_CONVERSATION','QUIZ_REVIEW')
      or block->>'type' = any(types)
      or block->>'status' not in ('READY','IN_PROGRESS','DONE','BLOCKED')
      or block->>'planned_minutes' !~ '^[0-9]{1,4}$'
      or block->>'item_count' !~ '^(0|[1-9][0-9]{0,18})$' then return false; end if;
    minutes := (block->>'planned_minutes')::integer;
    if minutes not between 1 and 1440
      or (block->>'item_count')::numeric > 9223372036854775807 then return false; end if;
    types := array_append(types, block->>'type');
    total := total + minutes;
  end loop;
  return total = p_target;
exception when others then return false;
end $$;

create function public.get_daily_plan(p_request jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid; plan_date_value date; local_day_end timestamptz;
  profile_row public.profiles%rowtype; plan_row public.daily_plans%rowtype;
  minutes integer[]; counts bigint[]; blocks jsonb := '[]'; index integer;
  kinds text[] := array['SRS','VOCABULARY','KANJI','GRAMMAR','LISTENING_READING','AI_CONVERSATION','QUIZ_REVIEW'];
begin
  owner_id := auth.uid();
  if owner_id is null then
    return jsonb_build_object('code','UNAUTHORIZED','message_vi','Vui lòng đăng nhập.','retryable',false);
  end if;
  if jsonb_typeof(p_request) is distinct from 'object' then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Ngày kế hoạch không hợp lệ.','retryable',false);
  end if;
  if (select count(*) from jsonb_object_keys(p_request)) <> 1
    or jsonb_typeof(p_request->'date') is distinct from 'string'
    or p_request->>'date' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Ngày kế hoạch không hợp lệ.','retryable',false);
  end if;
  begin
    plan_date_value := (p_request->>'date')::date;
  exception when invalid_datetime_format or datetime_field_overflow then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Ngày kế hoạch không hợp lệ.','retryable',false);
  end;
  -- Shared profile lock freezes settings across generation. No client owner,
  -- target, block readiness or derived-progress input is accepted.
  select * into profile_row from public.profiles where id = owner_id for share;
  if not found then
    return jsonb_build_object('code','NOT_FOUND','message_vi','Chưa có hồ sơ học tập.','retryable',false);
  end if;
  select * into plan_row from public.daily_plans
    where user_id = owner_id and plan_date = plan_date_value;
  if not found then
    local_day_end := (plan_date_value + 1)::timestamp at time zone profile_row.timezone;
    minutes := private.daily_plan_minutes(profile_row.daily_target_minutes);
    select array[
      (select count(*) from public.user_learning_items l
       where l.user_id = owner_id and (l.next_review_at is null or l.next_review_at < local_day_end)
         and (exists (select 1 from public.vocabulary v where v.id = l.vocabulary_id and v.is_active and v.jlpt_level = profile_row.preferred_jlpt)
           or exists (select 1 from public.kanji k where k.id = l.kanji_id and k.is_active and k.jlpt_level = profile_row.preferred_jlpt)
           or exists (select 1 from public.grammar g where g.id = l.grammar_id and g.is_active and g.jlpt_level = profile_row.preferred_jlpt))),
      (select count(*) from public.vocabulary where is_active and jlpt_level = profile_row.preferred_jlpt),
      -- A reference string alone is not validated handwriting/reference data.
      0::bigint,
      (select count(*) from public.grammar where is_active and jlpt_level = profile_row.preferred_jlpt),
      0::bigint, 0::bigint, 0::bigint
    ] into counts;
    for index in 1..7 loop
      blocks := blocks || jsonb_build_array(jsonb_build_object(
        'type',kinds[index], 'planned_minutes',minutes[index],
        'status',case when counts[index] > 0 then 'READY' else 'BLOCKED' end,
        'item_count',counts[index]));
    end loop;
    insert into public.daily_plans(user_id, plan_date, target_minutes, plan_json)
    values(owner_id, plan_date_value, profile_row.daily_target_minutes,
      jsonb_build_object('policy_version','nd-plan-1','timezone',profile_row.timezone,
        'jlpt_level',profile_row.preferred_jlpt,'blocks',blocks))
    on conflict (user_id, plan_date) do nothing;
    -- READ COMMITTED: a concurrent winner may commit while INSERT waits.
    -- Re-read that winner, never replace its blocks, identity or progress.
    select * into plan_row from public.daily_plans
      where user_id = owner_id and plan_date = plan_date_value;
  end if;
  if plan_row.id is null or not private.daily_plan_blocks_valid(plan_row.plan_json->'blocks', plan_row.target_minutes) then
    return jsonb_build_object('code','INTERNAL_ERROR','message_vi','Không tải được kế hoạch học tập.','retryable',false);
  end if;
  return jsonb_build_object('plan_date',to_char(plan_row.plan_date,'YYYY-MM-DD'),
    'target_minutes',plan_row.target_minutes,'completed_minutes',plan_row.completed_minutes,
    'blocks',plan_row.plan_json->'blocks');
exception when others then
  -- PL/pgSQL rolls back this function's writes before returning a fixed error.
  return jsonb_build_object('code','INTERNAL_ERROR','message_vi','Không tải được kế hoạch học tập.','retryable',false);
end $$;

revoke all on function private.daily_plan_minutes(integer) from public, anon, authenticated, service_role;
revoke all on function private.daily_plan_blocks_valid(jsonb, integer) from public, anon, authenticated, service_role;
revoke all on function public.get_daily_plan(jsonb) from public, anon, authenticated, service_role;
grant execute on function public.get_daily_plan(jsonb) to authenticated;
comment on function public.get_daily_plan(jsonb) is
  'Authenticated own-profile daily snapshot. Frozen v0.1 request in p_request. No session/progress writes; READ COMMITTED retry preserves the winner.';
commit;
