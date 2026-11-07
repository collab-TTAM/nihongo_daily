-- Additive study-submit-v1 RPC. Existing frozen v0.1 endpoints are unchanged.
begin;
create function public.submit_study_session(p_request jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare owner_id uuid;
begin
  owner_id := auth.uid();
  if owner_id is null then
    return jsonb_build_object('code','UNAUTHORIZED','message_vi','Vui lòng đăng nhập.','retryable',false);
  end if;
  -- This version requires explicit UTC; internal trusted ingestion also supports
  -- offsets, but public retries retain one exact immutable UTC spelling.
  if right(p_request->>'started_at',1) is distinct from 'Z'
    or right(p_request->>'ended_at',1) is distinct from 'Z' then
    return jsonb_build_object('code','VALIDATION_FAILURE','message_vi','Thời gian phiên học không hợp lệ.','retryable',false);
  end if;
  -- Ownership comes exclusively from the gateway-verified JWT, never input.
  -- This records authenticated self-reported duration, not attention/mastery.
  return private.record_study_session(owner_id,p_request);
exception when others then
  return jsonb_build_object('code','INTERNAL_ERROR','message_vi','Không lưu được phiên học.','retryable',false);
end $$;
revoke all on function public.submit_study_session(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.submit_study_session(jsonb) to authenticated;
comment on function public.submit_study_session(jsonb) is
  'study-submit-v1: strict completed UTC interval; derives owner from auth.uid, records self-reported minutes through atomic ledger, never mastery. Request contracts/study/v1; frozen daily-plan/error response.';
commit;
