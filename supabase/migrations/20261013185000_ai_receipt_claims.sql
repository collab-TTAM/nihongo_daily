-- Trusted backend-only claims. No client RPC, auth change or live deployment.
begin;
create table private.ai_receipt_claims (
  receipt_id uuid primary key references public.operation_receipts(id) on delete restrict,
  dispatch_token uuid not null unique default gen_random_uuid()
);
alter table private.ai_receipt_claims enable row level security;
revoke all on table private.ai_receipt_claims from public, anon, authenticated, service_role;
grant select, insert on table private.ai_receipt_claims to service_role;

create function private.ai_receipt_lookup(p_user_id uuid, p_operation text, p_request jsonb) returns jsonb
language plpgsql set search_path = '' as $$
declare stored public.operation_receipts%rowtype; event_id uuid;
begin
  if p_user_id is null or p_operation is null or p_operation not in
    ('start_conversation','conversation_turn','finish_conversation') or
    p_request is null or jsonb_typeof(p_request) <> 'object' or
    p_request ? 'user_id' or not (p_request ? 'client_event_id') then
    raise exception 'VALIDATION_FAILURE' using errcode = '22023';
  end if;
  begin event_id := (p_request->>'client_event_id')::uuid;
  exception when invalid_text_representation then
    raise exception 'VALIDATION_FAILURE' using errcode = '22023';
  end;
  if event_id is null then raise exception 'VALIDATION_FAILURE' using errcode = '22023'; end if;
  select * into stored from public.operation_receipts where user_id=p_user_id
    and operation=p_operation and client_event_id=event_id;
  if not found then return jsonb_build_object('kind','missing'); end if;
  if stored.request_json is distinct from p_request then
    raise exception 'SYNC_CONFLICT' using errcode = 'P0001';
  end if;
  if stored.status='COMPLETED' then
    return jsonb_build_object('kind','completed','response',stored.response_json);
  end if;
  return jsonb_build_object('kind','pending');
end $$;

create function private.ai_receipt_claim(p_user_id uuid, p_operation text, p_request jsonb) returns jsonb
language plpgsql set search_path = '' as $$
declare prior jsonb; v_receipt_id uuid; claim_token uuid;
begin
  prior := private.ai_receipt_lookup(p_user_id,p_operation,p_request);
  if prior->>'kind' <> 'missing' then return prior; end if;
  insert into public.operation_receipts(user_id,operation,client_event_id,request_json)
    values(p_user_id,p_operation,(p_request->>'client_event_id')::uuid,p_request)
    on conflict (user_id,operation,client_event_id) do nothing returning id into v_receipt_id;
  if v_receipt_id is null then
    -- A concurrent inserter commits first. New READ COMMITTED statement observes it.
    return private.ai_receipt_lookup(p_user_id,p_operation,p_request);
  end if;
  insert into private.ai_receipt_claims(receipt_id) values(v_receipt_id)
    returning dispatch_token into claim_token;
  return jsonb_build_object('kind','acquired','token',claim_token);
end $$;

create function private.ai_receipt_complete(p_user_id uuid, p_operation text,
  p_request jsonb, p_token uuid, p_response jsonb) returns jsonb
language plpgsql set search_path = '' as $$
declare prior jsonb; stored public.operation_receipts%rowtype; token uuid;
begin
  prior := private.ai_receipt_lookup(p_user_id,p_operation,p_request);
  if prior->>'kind' = 'missing' then raise exception 'NOT_FOUND' using errcode='P0001'; end if;
  select * into stored from public.operation_receipts where user_id=p_user_id and operation=p_operation
    and client_event_id=(p_request->>'client_event_id')::uuid for update;
  select dispatch_token into token from private.ai_receipt_claims where receipt_id=stored.id;
  if token is null or p_token is distinct from token then
    raise exception 'FORBIDDEN' using errcode='42501';
  end if;
  if p_response is null or jsonb_typeof(p_response) <> 'object' then
    raise exception 'VALIDATION_FAILURE' using errcode='22023';
  end if;
  if stored.status='COMPLETED' then
    if stored.response_json is distinct from p_response then
      raise exception 'SYNC_CONFLICT' using errcode='P0001';
    end if;
    return stored.response_json;
  end if;
  -- Full request/output schemas and session mutations are validated by the backend.
  -- Its adapter must invoke this within the same transaction as message/session writes.
  update public.operation_receipts set status='COMPLETED',response_json=p_response where id=stored.id;
  return p_response;
end $$;

revoke all on function private.ai_receipt_lookup(uuid,text,jsonb) from public,anon,authenticated;
revoke all on function private.ai_receipt_claim(uuid,text,jsonb) from public,anon,authenticated;
revoke all on function private.ai_receipt_complete(uuid,text,jsonb,uuid,jsonb) from public,anon,authenticated;
grant execute on function private.ai_receipt_lookup(uuid,text,jsonb) to service_role;
grant execute on function private.ai_receipt_claim(uuid,text,jsonb) to service_role;
grant execute on function private.ai_receipt_complete(uuid,text,jsonb,uuid,jsonb) to service_role;
-- No automatic expiration/takeover/deletion of PENDING dispatches. Recovery must
-- correlate an existing provider result; absence/timeout never authorizes reissue.
commit;
