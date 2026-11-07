-- Internal trusted-backend boundary only; no client RPC or hosted deployment.
-- A verified backend must derive p_owner, verify genuine study activity and
-- retain the immutable event. Never ship a service-role credential to Flutter.
begin;

create table private.study_session_receipts (
  user_id uuid not null references auth.users(id) on delete restrict,
  client_event_id uuid not null,
  plan_id uuid not null references public.daily_plans(id) on delete restrict,
  session_id uuid not null unique references public.study_sessions(id) on delete restrict,
  session_type text not null,
  started_at timestamptz not null check (isfinite(started_at)),
  ended_at timestamptz not null check (isfinite(ended_at) and ended_at > started_at),
  credited_minutes integer not null check (credited_minutes between 1 and 1500),
  request_json jsonb not null check (jsonb_typeof(request_json) = 'object'),
  response_json jsonb not null check (jsonb_typeof(response_json) = 'object'),
  primary key (user_id, client_event_id)
);
alter table private.study_session_receipts enable row level security;
revoke all on table private.study_session_receipts from public, anon, authenticated, service_role;
create index study_session_receipts_plan_idx on private.study_session_receipts(plan_id, session_type);

create function private.study_session_instant(p_value text) returns timestamptz
language plpgsql immutable set search_path = '' as $$
declare result timestamptz;
begin
  if p_value is null or p_value !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]{1,6})?(Z|[+-]([01][0-9]|2[0-3]):[0-5][0-9])$' then
    raise exception 'Invalid study instant' using errcode='22023';
  end if;
  result := p_value::timestamptz;
  if not isfinite(result) or extract(year from result at time zone 'UTC') not between 1 and 9999 then
    raise exception 'Invalid study instant' using errcode='22023';
  end if;
  return result;
end $$;

-- Deliberately PRIVATE: not a new/changed frozen v0.1 client endpoint. The
-- service caller must authenticate and authorize the learner before invoking.
create function private.record_study_session(p_owner uuid, p_request jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  event_id uuid; day_value date; started timestamptz; ended timestamptz;
  kind text; zone text; level public.jlpt_level; day_start timestamptz; day_end timestamptz;
  plan public.daily_plans%rowtype; receipt private.study_session_receipts%rowtype;
  block jsonb; updated_blocks jsonb; session_id_value uuid; credit integer; block_credit bigint;
  response jsonb;
begin
  if p_owner is null then
    return jsonb_build_object('code','UNAUTHORIZED','message_vi','Vui lòng đăng nhập.','retryable',false);
  end if;
  if jsonb_typeof(p_request) is distinct from 'object' or pg_column_size(p_request)>4096 then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Phiên học không hợp lệ.','retryable',false);
  end if;
  if (select count(*) from jsonb_object_keys(p_request)) <> 5
    or not (p_request ?& array['client_event_id','plan_date','session_type','started_at','ended_at'])
    or exists (select 1 from jsonb_each(p_request) where jsonb_typeof(value) is distinct from 'string') then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Phiên học không hợp lệ.','retryable',false);
  end if;
  begin
    if p_request->>'client_event_id' !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      or p_request->>'plan_date' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
      raise exception 'Invalid session request' using errcode='22023';
    end if;
    event_id := (p_request->>'client_event_id')::uuid;
    day_value := (p_request->>'plan_date')::date;
    started := private.study_session_instant(p_request->>'started_at');
    ended := private.study_session_instant(p_request->>'ended_at');
  exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow or invalid_parameter_value then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Phiên học không hợp lệ.','retryable',false);
  end;
  kind := p_request->>'session_type';
  if kind not in ('SRS','VOCABULARY','KANJI','GRAMMAR','LISTENING_READING','AI_CONVERSATION','QUIZ_REVIEW') then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Phiên học không hợp lệ.','retryable',false);
  end if;

  -- Same-owner submissions serialize before reading receipts/overlaps. This also
  -- fixes lock order with get_daily_plan's profile-before-plan snapshot boundary.
  perform 1 from public.profiles where id=p_owner for update;
  if not found then
    return jsonb_build_object('code','NOT_FOUND','message_vi','Chưa có hồ sơ học tập.','retryable',false);
  end if;
  select * into receipt from private.study_session_receipts
    where user_id=p_owner and client_event_id=event_id;
  if found then
    if receipt.request_json <> p_request then
      return jsonb_build_object('code','SYNC_CONFLICT','message_vi','Mã phiên học đã được sử dụng.','retryable',false);
    end if;
    return receipt.response_json;
  end if;
  select * into plan from public.daily_plans where user_id=p_owner and plan_date=day_value for update;
  if not found then
    return jsonb_build_object('code','NOT_FOUND','message_vi','Chưa có kế hoạch cho ngày học.','retryable',false);
  end if;
  if not private.daily_plan_blocks_valid(plan.plan_json->'blocks',plan.target_minutes)
    or plan.plan_json->>'policy_version' is distinct from 'nd-plan-1'
    or jsonb_typeof(plan.plan_json->'timezone') is distinct from 'string'
    or jsonb_typeof(plan.plan_json->'jlpt_level') is distinct from 'string' then
    return jsonb_build_object('code','INTERNAL_ERROR','message_vi','Không lưu được phiên học.','retryable',false);
  end if;
  zone := plan.plan_json->>'timezone';
  level := (plan.plan_json->>'jlpt_level')::public.jlpt_level;
  day_start := day_value::timestamp at time zone zone;
  day_end := (day_value+1)::timestamp at time zone zone;
  if ended <= started or ended > clock_timestamp()+interval '5 minutes'
    or started < day_start or ended > day_end
    or extract(epoch from ended-started) < 60
    or extract(epoch from ended-started) > 90000 then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Thời gian phiên học không hợp lệ.','retryable',false);
  end if;
  select value into block from jsonb_array_elements(plan.plan_json->'blocks') where value->>'type'=kind;
  if block->>'status'='BLOCKED' then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Nội dung học chưa sẵn sàng.','retryable',false);
  end if;
  -- Reject even differently identified overlapping sessions across all days and
  -- blocks for this owner. Adjacent half-open intervals are allowed.
  if exists (select 1 from private.study_session_receipts
    where user_id=p_owner and started_at < ended and ended_at > started) then
    return jsonb_build_object('code','SYNC_CONFLICT','message_vi','Thời gian học bị trùng.','retryable',false);
  end if;
  credit := floor(extract(epoch from ended-started)/60)::integer;
  insert into public.study_sessions(user_id,session_type,started_at,ended_at,planned_minutes,actual_minutes,jlpt_level,metadata)
  values(p_owner,kind,started,ended,(block->>'planned_minutes')::integer,credit,level,
    jsonb_build_object('policy_version','nd-study-1','plan_id',plan.id)) returning id into session_id_value;
  select coalesce(sum(credited_minutes),0)+credit into block_credit
    from private.study_session_receipts where user_id=p_owner and plan_id=plan.id and session_type=kind;
  select jsonb_agg(case when value->>'type'=kind then jsonb_set(value,'{status}',
    to_jsonb(case when value->>'status'='DONE' or block_credit >= (value->>'planned_minutes')::integer
      then 'DONE'::text else 'IN_PROGRESS'::text end)) else value end order by ordinal)
    into updated_blocks from jsonb_array_elements(plan.plan_json->'blocks') with ordinality as b(value,ordinal);
  update public.daily_plans set completed_minutes=completed_minutes+credit,
    plan_json=jsonb_set(plan_json,'{blocks}',updated_blocks), updated_at=greatest(clock_timestamp(),generated_at)
    where id=plan.id and user_id=p_owner returning * into plan;
  response := jsonb_build_object('plan_date',to_char(plan.plan_date,'YYYY-MM-DD'),
    'target_minutes',plan.target_minutes,'completed_minutes',plan.completed_minutes,'blocks',updated_blocks);
  insert into private.study_session_receipts(user_id,client_event_id,plan_id,session_id,session_type,
    started_at,ended_at,credited_minutes,request_json,response_json)
  values(p_owner,event_id,plan.id,session_id_value,kind,started,ended,credit,p_request,response);
  return response;
exception when others then
  -- Session, progress and receipt share one subtransaction. No partial success.
  return jsonb_build_object('code','INTERNAL_ERROR','message_vi','Không lưu được phiên học.','retryable',false);
end $$;

revoke all on function private.study_session_instant(text) from public, anon, authenticated, service_role;
revoke all on function private.record_study_session(uuid,jsonb) from public, anon, authenticated, service_role;
grant execute on function private.record_study_session(uuid,jsonb) to service_role;
comment on function private.record_study_session(uuid,jsonb) is
  'Internal verified-backend completed-session ingestion, nd-study-1. No client RPC; frozen daily-plan response. Owner must be verified by caller. Single snapshot-local day, whole minutes, immutable owner/event replay.';
commit;
