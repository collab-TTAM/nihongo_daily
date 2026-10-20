-- Additive read-only profile-study-day-v1; not deployed. No caller owner/clock/
-- timezone and no plan, session, profile bootstrap or derived-progress write.
begin;
create function private.study_day_at(p_instant timestamptz, p_zone text) returns date
language sql stable strict set search_path = '' as $$
  select (p_instant at time zone p_zone)::date
$$;
revoke all on function private.study_day_at(timestamptz,text) from public,anon,authenticated,service_role;

create function public.get_study_day(p_request jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare owner_id uuid; zone text; day_value date; captured timestamptz := statement_timestamp();
begin
  begin owner_id := auth.uid();
  exception when others then
    return jsonb_build_object('code','UNAUTHORIZED','message_vi','Vui lòng đăng nhập.','retryable',false);
  end;
  if owner_id is null then
    return jsonb_build_object('code','UNAUTHORIZED','message_vi','Vui lòng đăng nhập.','retryable',false);
  end if;
  if jsonb_typeof(p_request) is distinct from 'object' then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Yêu cầu ngày học không hợp lệ.','retryable',false);
  end if;
  if (select count(*) from jsonb_object_keys(p_request)) <> 0 then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Yêu cầu ngày học không hợp lệ.','retryable',false);
  end if;
  select timezone into zone from public.profiles where id = owner_id;
  if not found then
    return jsonb_build_object('code','NOT_FOUND','message_vi','Chưa có hồ sơ học tập.','retryable',false);
  end if;
  day_value := private.study_day_at(captured,zone);
  if day_value is null or extract(year from day_value) not between 1 and 9999 then
    raise exception 'Invalid study day';
  end if;
  return jsonb_build_object('date',to_char(day_value,'YYYY-MM-DD'),'timezone',zone);
exception when others then
  return jsonb_build_object('code','INTERNAL_ERROR','message_vi','Chưa thể tải ngày học.','retryable',false);
end $$;
revoke all on function public.get_study_day(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.get_study_day(jsonb) to authenticated;
comment on function public.get_study_day(jsonb) is
 'profile-study-day-v1: strict empty request, own profile timezone and server statement clock; no writes. Gateway verifies JWT, auth.uid derives owner.';
commit;
