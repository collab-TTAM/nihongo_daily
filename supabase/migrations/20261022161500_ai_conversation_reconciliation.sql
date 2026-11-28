-- Undeployed SQL reconciliation component, not an upstream-result verifier.
begin;
-- One statement snapshot. Inspect only an existing owned immutable receipt;
-- never acquire/renew/return a dispatch capability or fabricate missing context.
create function private.ai_conversation_recovery_lookup(p_user_id uuid,p_operation text,p_request jsonb)
returns jsonb language plpgsql stable set search_path='' as $$
declare receipt public.operation_receipts%rowtype; reservation private.ai_conversation_reservations%rowtype;
begin
  perform private.validate_ai_conversation_request(p_user_id,p_operation,p_request);
  select * into receipt from public.operation_receipts where user_id=p_user_id and operation=p_operation
    and client_event_id=(p_request->>'client_event_id')::uuid;
  if not found then return jsonb_build_object('kind','missing'); end if;
  if receipt.request_json is distinct from p_request then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
  if receipt.status='COMPLETED' then return jsonb_build_object('kind','completed','response',receipt.response_json); end if;
  select * into reservation from private.ai_conversation_reservations where receipt_id=receipt.id;
  -- Legacy pending has no atomic saved reservation. It stays unrecoverable here.
  if not found then return jsonb_build_object('kind','pending'); end if;
  if reservation.is_completed then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
  return jsonb_build_object('kind','pending','correlation',jsonb_build_object(
    'receipt_id',receipt.id,'user_id',receipt.user_id,'operation',receipt.operation,'client_event_id',receipt.client_event_id,
    'idempotency_key',receipt.user_id::text||'/'||receipt.operation||'/'||receipt.client_event_id::text),
    'context',reservation.context_json);
end $$;

-- Only a trusted backend verifier may call this after authenticated lookup-only
-- upstream correlation. SQL binds stored identities/context; it cannot prove that
-- a provider actually produced p_response. No learner/model proof is accepted.
create function private.ai_conversation_reconcile(p_user_id uuid,p_operation text,p_request jsonb,
  p_receipt_id uuid,p_idempotency_key text,p_context jsonb,p_response jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare receipt public.operation_receipts%rowtype; reservation private.ai_conversation_reservations%rowtype; v_token uuid;
begin
  perform private.validate_ai_conversation_request(p_user_id,p_operation,p_request);
  if p_receipt_id is null or p_idempotency_key is null or char_length(p_idempotency_key)>128
    or p_context is null or jsonb_typeof(p_context)<>'object'
    or octet_length(convert_to(p_context::text,'UTF8'))>65536 then
    raise exception 'VALIDATION_FAILURE' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('nihongo-ai-conversation:'||p_user_id::text,0));
  select * into receipt from public.operation_receipts where user_id=p_user_id and operation=p_operation
    and client_event_id=(p_request->>'client_event_id')::uuid for update;
  if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
  if receipt.request_json is distinct from p_request then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
  if receipt.id<>p_receipt_id or p_idempotency_key<>receipt.user_id::text||'/'||receipt.operation||'/'||receipt.client_event_id::text then
    raise exception 'FORBIDDEN' using errcode='42501';
  end if;
  select * into reservation from private.ai_conversation_reservations where receipt_id=receipt.id for update;
  if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
  if p_context is distinct from reservation.context_json then raise exception 'SYNC_CONFLICT' using errcode='P0001'; end if;
  select dispatch_token into v_token from private.ai_receipt_claims where receipt_id=receipt.id;
  if not found then raise exception 'NOT_FOUND' using errcode='P0002'; end if;
  -- Token stays inside SQL; reuse every validated public-write/replay/source/slot
  -- guard and whole-transaction release. No new receipt, token or claim is created.
  return private.ai_conversation_complete(p_user_id,p_operation,p_request,v_token,p_response);
end $$;
revoke all on function private.ai_conversation_recovery_lookup(uuid,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function private.ai_conversation_reconcile(uuid,text,jsonb,uuid,text,jsonb,jsonb) from public,anon,authenticated,service_role;
grant execute on function private.ai_conversation_recovery_lookup(uuid,text,jsonb) to service_role;
grant execute on function private.ai_conversation_reconcile(uuid,text,jsonb,uuid,text,jsonb,jsonb) to service_role;
-- Existing table grants/RLS/claim lifetime unchanged. No reset/expiry/takeover.
commit;
