-- Disposable SQL roles/time manipulation only; not hosted Auth or live AI proof.
begin;
create schema quota_test;
create function quota_test.ok(value boolean,label text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',label; end if;
raise notice 'PASS QUOTA: %',label; end $$;
create function quota_test.reject(statement text,code text,label text) returns void language plpgsql as $$
declare got text; begin
begin execute statement; exception when others then get stacked diagnostics got=returned_sqlstate; end;
perform quota_test.ok(got=code,label || ' got ' || coalesce(got,'SUCCESS')); end $$;
grant usage on schema quota_test to anon,authenticated,service_role;
grant execute on all functions in schema quota_test to anon,authenticated,service_role;
insert into auth.users values('b1000000-0000-4000-8000-000000000001'),('b1000000-0000-4000-8000-000000000002'),
  ('b1000000-0000-4000-8000-000000000003'),('b1000000-0000-4000-8000-000000000004');
select quota_test.ok((select relrowsecurity from pg_class where oid='private.ai_rate_buckets'::regclass),'quota table RLS enabled');
select quota_test.ok((select not prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='private.consume_ai_quota(uuid,text)'::regprocedure),'invoker fixed empty path');
select quota_test.ok(not exists(select 1 from pg_proc p, lateral aclexplode(p.proacl) a where p.oid='private.consume_ai_quota(uuid,text)'::regprocedure and a.grantee=0 and a.privilege_type='EXECUTE'),'PUBLIC has no execute');
set local role service_role;
select quota_test.ok(private.consume_ai_quota('b1000000-0000-4000-8000-000000000001','tutor_explain'),'first reservation');
select quota_test.ok((select tokens=9 and used_today=1 from private.ai_rate_buckets where user_id='b1000000-0000-4000-8000-000000000001'),'one user row starts nine tokens and one debit');
do $$ declare op text; begin
foreach op in array array['correct_sentence','start_conversation','conversation_turn','finish_conversation'] loop
  perform quota_test.ok(private.consume_ai_quota('b1000000-0000-4000-8000-000000000001',op),'shared operation '||op);
end loop; end $$;
select quota_test.ok((select count(*)=1 and min(used_today)=5 from private.ai_rate_buckets),'rotating operation does not create more buckets');
select quota_test.ok(private.consume_ai_quota('b1000000-0000-4000-8000-000000000002','tutor_explain'),'user B independently allowed');
select quota_test.ok((select used_today=5 from private.ai_rate_buckets where user_id='b1000000-0000-4000-8000-000000000001'),'B does not debit A');
select quota_test.reject($s$select private.consume_ai_quota(null,'tutor_explain')$s$,'22023','null owner');
select quota_test.reject($s$select private.consume_ai_quota('b1000000-0000-4000-8000-000000000001',null)$s$,'22023','null operation');
select quota_test.reject($s$select private.consume_ai_quota('b1000000-0000-4000-8000-000000000001','TUTOR_EXPLAIN')$s$,'22023','unknown operation');
select quota_test.reject($s$select private.consume_ai_quota('b1000000-0000-4000-8000-000000000099','tutor_explain')$s$,'23503','nonexistent owner');
select quota_test.ok((select count(*)=2 from private.ai_rate_buckets),'invalid input allocates no row');
do $$ begin for i in 1..10 loop
  perform quota_test.ok(private.consume_ai_quota('b1000000-0000-4000-8000-000000000003','start_conversation'),'burst reservation '||i);
end loop; end $$;
select quota_test.ok(not private.consume_ai_quota('b1000000-0000-4000-8000-000000000003','correct_sentence'),'eleventh burst reservation denied');
select quota_test.ok((select used_today=10 from private.ai_rate_buckets where user_id='b1000000-0000-4000-8000-000000000003'),'burst grants exactly ten');
-- Fixture-only server state setup; no fake clock parameter exists in production.
update private.ai_rate_buckets set tokens=0,refilled_at=clock_timestamp() where user_id='b1000000-0000-4000-8000-000000000001';
select quota_test.ok(not private.consume_ai_quota('b1000000-0000-4000-8000-000000000001','finish_conversation'),'empty burst denies');
select quota_test.ok((select tokens=0 and used_today=5 from private.ai_rate_buckets where user_id='b1000000-0000-4000-8000-000000000001'),'denial writes no counter/refill');
update private.ai_rate_buckets set refilled_at=clock_timestamp()-interval '9 seconds' where user_id='b1000000-0000-4000-8000-000000000001';
select quota_test.ok(private.consume_ai_quota('b1000000-0000-4000-8000-000000000001','tutor_explain'),'fractional elapsed refill');
select quota_test.ok((select tokens>=0.5 and tokens<1 from private.ai_rate_buckets where user_id='b1000000-0000-4000-8000-000000000001'),'fractional remainder retained');
update private.ai_rate_buckets set tokens=0,refilled_at=clock_timestamp()-interval '2 days' where user_id='b1000000-0000-4000-8000-000000000001';
select quota_test.ok(private.consume_ai_quota('b1000000-0000-4000-8000-000000000001','tutor_explain'),'long idle refills');
select quota_test.ok((select tokens=9 from private.ai_rate_buckets where user_id='b1000000-0000-4000-8000-000000000001'),'refill caps at ten');
update private.ai_rate_buckets set tokens=10,used_today=99 where user_id='b1000000-0000-4000-8000-000000000001';
select quota_test.ok(private.consume_ai_quota('b1000000-0000-4000-8000-000000000001','conversation_turn'),'last daily reservation');
select quota_test.ok(not private.consume_ai_quota('b1000000-0000-4000-8000-000000000001','tutor_explain'),'daily cap across operations');
select quota_test.ok((select used_today=100 and tokens=9 from private.ai_rate_buckets where user_id='b1000000-0000-4000-8000-000000000001'),'daily denial spends no token');
update private.ai_rate_buckets set budget_day=budget_day-1 where user_id='b1000000-0000-4000-8000-000000000001';
set local timezone='Pacific/Honolulu';
select quota_test.ok(private.consume_ai_quota('b1000000-0000-4000-8000-000000000001','tutor_explain'),'new UTC day resets daily budget');
select quota_test.ok((select used_today=1 and budget_day=(clock_timestamp() at time zone 'UTC')::date and tokens<9 from private.ai_rate_buckets where user_id='b1000000-0000-4000-8000-000000000001'),'session timezone cannot reset or bypass shared burst');
update private.ai_rate_buckets set budget_day=(clock_timestamp() at time zone 'UTC')::date+1 where user_id='b1000000-0000-4000-8000-000000000001';
select quota_test.ok(not private.consume_ai_quota('b1000000-0000-4000-8000-000000000001','tutor_explain'),'clock day rollback denies');
update private.ai_rate_buckets set budget_day=(clock_timestamp() at time zone 'UTC')::date,refilled_at=clock_timestamp()+interval '1 hour' where user_id='b1000000-0000-4000-8000-000000000001';
select quota_test.ok(not private.consume_ai_quota('b1000000-0000-4000-8000-000000000001','tutor_explain'),'future refill clock denies');
select quota_test.ok((select used_today=1 from private.ai_rate_buckets where user_id='b1000000-0000-4000-8000-000000000001'),'clock denial retains debit');
select quota_test.reject($s$delete from private.ai_rate_buckets$s$,'42501','service cannot delete/reset buckets');
select quota_test.reject($s$truncate private.ai_rate_buckets$s$,'42501','service cannot truncate');
select quota_test.reject($s$update private.ai_rate_buckets set tokens=11$s$,'23514','tokens above burst rejected');
select quota_test.reject($s$update private.ai_rate_buckets set tokens='NaN'$s$,'23514','nonfinite token rejected');
select quota_test.reject($s$update private.ai_rate_buckets set used_today=101$s$,'23514','daily overflow rejected');
select quota_test.reject($s$update private.ai_rate_buckets set refilled_at='infinity'$s$,'23514','nonfinite clock rejected');
select quota_test.reject($s$update private.ai_rate_buckets set budget_day='infinity'$s$,'23514','nonfinite day rejected');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
select quota_test.reject($s$select * from private.ai_rate_buckets$s$,'42501','authenticated cannot inspect even own quota');
select quota_test.reject($s$select private.consume_ai_quota('b1000000-0000-4000-8000-000000000002','tutor_explain')$s$,'42501','authenticated cannot debit any owner');
select quota_test.reject($s$insert into private.ai_rate_buckets values('b1000000-0000-4000-8000-000000000001',10,clock_timestamp(),current_date,0)$s$,'42501','authenticated cannot forge fresh quota');
reset role;
set local role anon;
select quota_test.reject($s$select private.consume_ai_quota('b1000000-0000-4000-8000-000000000001','tutor_explain')$s$,'42501','anon cannot consume');
select quota_test.reject($s$select * from private.ai_rate_buckets$s$,'42501','anon cannot inspect');
reset role;
savepoint cancelled;
set local role service_role;
select quota_test.ok(private.consume_ai_quota('b1000000-0000-4000-8000-000000000002','tutor_explain'),'uncommitted reservation');
rollback to savepoint cancelled;
select quota_test.ok((select used_today=1 from private.ai_rate_buckets where user_id='b1000000-0000-4000-8000-000000000002'),'rollback retains prior quota exactly');
savepoint cancelled_first;
set local role service_role;
select quota_test.ok(private.consume_ai_quota('b1000000-0000-4000-8000-000000000004','tutor_explain'),'uncommitted first reservation');
rollback to savepoint cancelled_first;
select quota_test.ok((select count(*)=0 from private.ai_rate_buckets where user_id='b1000000-0000-4000-8000-000000000004'),'rollback leaves no first bucket');
rollback;
