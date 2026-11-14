-- Undeployed trusted-backend quota. No public RPC or client mutation grants.
begin;
create table private.ai_rate_buckets (
  user_id uuid primary key references auth.users(id) on delete restrict,
  tokens numeric not null check (tokens >= 0 and tokens <= 10),
  refilled_at timestamptz not null check (isfinite(refilled_at)),
  budget_day date not null check (isfinite(budget_day)),
  used_today integer not null check (used_today between 0 and 100)
);
alter table private.ai_rate_buckets enable row level security;
revoke all on table private.ai_rate_buckets from public, anon, authenticated, service_role;
grant select, insert, update on table private.ai_rate_buckets to service_role;

-- All five operations spend one shared user budget. No caller-selected rate,
-- clock, key namespace or refund. Caller must verify identity and COMMIT this
-- reservation before dispatch; any SQL/commit uncertainty must fail closed.
create function private.consume_ai_quota(p_user_id uuid, p_operation text)
returns boolean language plpgsql set search_path = '' as $$
declare
  stored private.ai_rate_buckets%rowtype;
  observed timestamptz;
  today date;
  available numeric;
  used integer;
begin
  if p_user_id is null or p_operation is null or p_operation not in
    ('tutor_explain','correct_sentence','start_conversation','conversation_turn','finish_conversation') then
    raise exception 'VALIDATION_FAILURE' using errcode='22023';
  end if;
  observed := clock_timestamp();
  insert into private.ai_rate_buckets(user_id,tokens,refilled_at,budget_day,used_today)
    values(p_user_id,10,observed,(observed at time zone 'UTC')::date,0)
    on conflict (user_id) do nothing;
  select * into stored from private.ai_rate_buckets where user_id=p_user_id for update;
  if not found then return false; end if;
  -- Sample AFTER acquiring the row lock, not transaction/statement start. A
  -- waiter must see the predecessor's committed state and current server time.
  observed := clock_timestamp();
  today := (observed at time zone 'UTC')::date;
  if observed < stored.refilled_at or today < stored.budget_day then return false; end if;
  available := least(10::numeric,stored.tokens + extract(epoch from (observed-stored.refilled_at))/6);
  used := case when today > stored.budget_day then 0 else stored.used_today end;
  if available < 1 or used >= 100 then return false; end if;
  update private.ai_rate_buckets set tokens=available-1,refilled_at=observed,
    budget_day=today,used_today=used+1 where user_id=p_user_id;
  return true;
end $$;
revoke all on function private.consume_ai_quota(uuid,text) from public, anon, authenticated, service_role;
grant execute on function private.consume_ai_quota(uuid,text) to service_role;
-- No cleanup/reset/refund endpoint, public schema bridge or RLS policy added.
commit;
