begin;
-- Additive nd-own-profile-1 bootstrap. No caller identity/settings accepted;
-- authenticated table INSERT grants and every existing RLS policy stay unchanged.
create function public.ensure_profile(p_request jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare owner_id uuid; profile public.profiles%rowtype;
begin
  begin owner_id := auth.uid();
  exception when invalid_text_representation then
    return jsonb_build_object('code','UNAUTHORIZED','message_vi','Cần phiên đăng nhập hợp lệ.','retryable',false);
  end;
  if owner_id is null or not exists(select 1 from auth.users where id=owner_id) then
    return jsonb_build_object('code','UNAUTHORIZED','message_vi','Cần phiên đăng nhập hợp lệ.','retryable',false);
  end if;
  if p_request is null or p_request <> '{}'::jsonb then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Yêu cầu hồ sơ không hợp lệ.','retryable',false);
  end if;
  insert into public.profiles(id) values(owner_id) on conflict(id) do nothing;
  select * into strict profile from public.profiles where id=owner_id;
  return jsonb_build_object('id',profile.id,'display_name',profile.display_name,
    'preferred_jlpt',profile.preferred_jlpt,'daily_target_minutes',profile.daily_target_minutes,
    'timezone',profile.timezone);
exception when others then
  -- Any insert/trigger/select failure rolls back the whole function body.
  return jsonb_build_object('code','INTERNAL_ERROR','message_vi','Không thể xác nhận hồ sơ học tập.','retryable',false);
end $$;
revoke all on function public.ensure_profile(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.ensure_profile(jsonb) to authenticated;
commit;
