-- Native role fixtures, not hosted JWT/Auth or real learner acceptance.
begin;
create schema plan_test;
create function plan_test.assert_true(ok boolean, label text) returns void
language plpgsql as $$ begin
  if ok is distinct from true then raise exception 'FAIL: %', label; end if;
  raise notice 'PASS: %', label;
end $$;
create function plan_test.denied(statement text) returns boolean language plpgsql as $$
begin execute statement; return false;
exception when insufficient_privilege then return true;
end $$;
grant usage on schema plan_test to authenticated, anon, service_role;
grant execute on all functions in schema plan_test to authenticated, anon, service_role;
create temp table results(label text primary key, payload jsonb);
grant select, insert on results to authenticated;
-- Earlier native suites intentionally commit their own curriculum fixtures.
-- A plan counts all active published content, not just this test's rows.
create temp table expected_counts as select
  (select count(*) from public.vocabulary where is_active and jlpt_level='N5') as vocabulary_n5,
  (select count(*) from public.vocabulary where is_active and jlpt_level='N4') as vocabulary_n4,
  (select count(*) from public.grammar where is_active and jlpt_level='N5') as grammar_n5;
grant select on expected_counts to authenticated;

select plan_test.assert_true(private.daily_plan_minutes(120) = array[20,15,20,15,15,25,10], 'exact default allocation');
select plan_test.assert_true(bool_and((select sum(m)=target and min(m)>=1 and max(m)<=1440
  from unnest(private.daily_plan_minutes(target)) m)), 'all targets7..1440 sum exactly with positive blocks')
from generate_series(7,1440) target;
select plan_test.assert_true(not has_function_privilege('anon','public.get_daily_plan(jsonb)','EXECUTE'), 'anonymous RPC denied');
select plan_test.assert_true(not has_function_privilege('service_role','public.get_daily_plan(jsonb)','EXECUTE'), 'no identity-free service RPC grant');
select plan_test.assert_true(not has_function_privilege('authenticated','private.daily_plan_minutes(integer)','EXECUTE'), 'private allocator denied');
select plan_test.assert_true((select prosecdef and proconfig @> array['search_path=""']
  from pg_proc where oid='public.get_daily_plan(jsonb)'::regprocedure), 'definer uses closed search path');

insert into auth.users values ('d1100000-0000-4000-8000-000000000001'),
  ('d1100000-0000-4000-8000-000000000002'), ('d1100000-0000-4000-8000-000000000003');
insert into public.profiles(id,preferred_jlpt,daily_target_minutes,timezone) values
  ('d1100000-0000-4000-8000-000000000001','N5',120,'Asia/Saigon'),
  ('d1100000-0000-4000-8000-000000000002','N4',90,'UTC');
insert into public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,expression,reading,meaning_vi,part_of_speech,usage_context_vi) values
  ('d1200000-0000-4000-8000-000000000001','N5',0.1,1,true,'水','みず','nước','noun','TEST ONLY'),
  ('d1200000-0000-4000-8000-000000000002','N5',0.1,1,true,'川','かわ','sông','noun','TEST ONLY'),
  ('d1200000-0000-4000-8000-000000000003','N5',0.1,1,true,'山','やま','núi','noun','TEST ONLY'),
  ('d1200000-0000-4000-8000-000000000004','N4',0.1,1,true,'森','もり','rừng','noun','TEST ONLY'),
  ('d1200000-0000-4000-8000-000000000005','N5',0.1,1,false,'本','ほん','sách','noun','TEST ONLY');
insert into public.kanji(jlpt_level,difficulty,content_version,is_active,character,meaning_vi,stroke_count,stroke_data_ref)
values ('N5',0.1,1,true,'水','nước',4,'TEST ONLY unverified reference');
insert into public.grammar(jlpt_level,difficulty,content_version,is_active,title,pattern,meaning_vi,explanation_vi)
values ('N5',0.1,1,true,'TEST ONLY','Nです','là','TEST ONLY');
insert into public.user_learning_items(user_id,item_type,item_id,next_review_at) values
  ('d1100000-0000-4000-8000-000000000001','VOCABULARY','d1200000-0000-4000-8000-000000000001','2026-10-19T16:59:59Z'),
  ('d1100000-0000-4000-8000-000000000001','VOCABULARY','d1200000-0000-4000-8000-000000000002','2026-10-19T17:00:00Z'),
  ('d1100000-0000-4000-8000-000000000001','VOCABULARY','d1200000-0000-4000-8000-000000000003',null),
  ('d1100000-0000-4000-8000-000000000002','VOCABULARY','d1200000-0000-4000-8000-000000000004',null);

set local role anon;
select plan_test.assert_true(plan_test.denied($s$select public.get_daily_plan('{"date":"2026-10-19"}')$s$), 'anon cannot call exposed RPC');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select plan_test.assert_true(public.get_daily_plan('{"date":"2026-10-19"}')->>'code'='UNAUTHORIZED', 'missing Auth fails closed');
select set_config('request.jwt.claim.sub','d1100000-0000-4000-8000-000000000003',true);
select plan_test.assert_true(public.get_daily_plan('{"date":"2026-10-19"}')->>'code'='NOT_FOUND', 'profile must be provisioned');
select set_config('request.jwt.claim.sub','d1100000-0000-4000-8000-000000000001',true);
select plan_test.assert_true(public.get_daily_plan(request)->>'code'='VALIDATION_FAILURE', 'invalid request rejected')
from (values (null::jsonb),('null'::jsonb),('[]'::jsonb),('{}'::jsonb),('{"date":null}'::jsonb),
  ('{"date":"2026-02-30"}'::jsonb),('{"date":"2100-02-29"}'::jsonb),('{"date":"0000-01-01"}'::jsonb),
  ('{"date":"infinity"}'::jsonb),('{"date":"2026-1-1"}'::jsonb),('{"date":"2026-10-19","target_minutes":1440}'::jsonb),
  ('{"date":"2026-10-19","user_id":"d1100000-0000-4000-8000-000000000002"}'::jsonb)) bad(request);
select plan_test.assert_true(plan_test.denied('select private.daily_plan_minutes(120)'), 'auth cannot call private helper');
select plan_test.assert_true(plan_test.denied('update public.daily_plans set completed_minutes=999'), 'client cannot overwrite derived minutes');
insert into results values ('initial',public.get_daily_plan('{"date":"2026-10-19"}'));
select plan_test.assert_true((select payload->>'target_minutes'='120' and payload->>'completed_minutes'='0'
  and payload#>>'{blocks,0,item_count}'='2'
  and (payload#>>'{blocks,1,item_count}')::bigint=(select vocabulary_n5+3 from expected_counts)
  and (payload#>>'{blocks,3,item_count}')::bigint=(select grammar_n5+1 from expected_counts)
  from results where label='initial'), 'Vietnam local midnight exclusive cutoff and active level counts; observed=' || (select payload::text from results where label='initial'));
select plan_test.assert_true((select bool_and(b->>'status'='BLOCKED')
  from results r, lateral jsonb_array_elements(r.payload->'blocks') b
  where label='initial' and b->>'type' in ('KANJI','LISTENING_READING','AI_CONVERSATION','QUIZ_REVIEW')), 'unverified resources/services never fabricated as ready');
select plan_test.assert_true((select public.get_daily_plan('{"date":"2026-10-19"}')=payload from results where label='initial'), 'duplicate read identical');
reset role;
create temp table original_row as select * from public.daily_plans
where user_id='d1100000-0000-4000-8000-000000000001' and plan_date='2026-10-19';
update public.profiles set preferred_jlpt='N4',daily_target_minutes=7 where id='d1100000-0000-4000-8000-000000000001';
update public.vocabulary set is_active=false where id='d1200000-0000-4000-8000-000000000001';
update public.daily_plans set completed_minutes=145,
  plan_json=jsonb_set(plan_json,'{blocks,0,status}','"IN_PROGRESS"')
where user_id='d1100000-0000-4000-8000-000000000001' and plan_date='2026-10-19';
set local role authenticated;
insert into results values ('started',public.get_daily_plan('{"date":"2026-10-19"}'));
select plan_test.assert_true((select payload->>'target_minutes'='120' and payload->>'completed_minutes'='145'
  and payload#>>'{blocks,0,status}'='IN_PROGRESS'
  and (payload#>>'{blocks,1,item_count}')::bigint=(select vocabulary_n5+3 from expected_counts)
  from results where label='started'), 'settings/content changes and retries preserve started snapshot and over-target progress');
insert into results values ('minimum',public.get_daily_plan('{"date":"2026-10-20"}'));
select plan_test.assert_true((select payload->>'target_minutes'='7'
  and (payload#>>'{blocks,1,item_count}')::bigint=(select vocabulary_n4+1 from expected_counts)
  and (select bool_and(b->>'planned_minutes'='1') from jsonb_array_elements(payload->'blocks') b)
  from results where label='minimum'), 'new date gets new settings, minimum target and N4 counts');
select set_config('request.jwt.claim.sub','d1100000-0000-4000-8000-000000000002',true);
insert into results values ('other-owner',public.get_daily_plan('{"date":"2026-10-19"}'));
select plan_test.assert_true((select count(*)=1 and bool_and(user_id='d1100000-0000-4000-8000-000000000002') from public.daily_plans), 'two-account RLS isolation');
select plan_test.assert_true((select payload->>'target_minutes'='90' and payload#>>'{blocks,0,item_count}'='1' from results where label='other-owner'), 'same date has independent user snapshot');
reset role;
select plan_test.assert_true((select p.id=o.id and p.generated_at=o.generated_at
  from public.daily_plans p join original_row o using(user_id,plan_date)), 'retry preserves row identity and generation instant');

-- Actual RPC cutoffs, not 24-hour arithmetic: spring day23h/fall day25h.
update public.profiles set timezone='America/New_York',preferred_jlpt='N5',daily_target_minutes=1440
where id='d1100000-0000-4000-8000-000000000001';
update public.vocabulary set is_active=true where id='d1200000-0000-4000-8000-000000000001';
update public.user_learning_items set next_review_at=case item_id
  when 'd1200000-0000-4000-8000-000000000001' then '2026-03-09T03:59:59Z'::timestamptz
  when 'd1200000-0000-4000-8000-000000000002' then '2026-03-09T04:00:00Z'::timestamptz else null end
where user_id='d1100000-0000-4000-8000-000000000001';
set local role authenticated; select set_config('request.jwt.claim.sub','d1100000-0000-4000-8000-000000000001',true);
insert into results values ('spring',public.get_daily_plan('{"date":"2026-03-08"}'));
select plan_test.assert_true((select payload#>>'{blocks,0,item_count}'='2' and payload->>'target_minutes'='1440' from results where label='spring'), '23-hour local day and maximum target');
reset role;
update public.user_learning_items set next_review_at=case item_id
  when 'd1200000-0000-4000-8000-000000000001' then '2026-11-02T04:59:59Z'::timestamptz
  when 'd1200000-0000-4000-8000-000000000002' then '2026-11-02T05:00:00Z'::timestamptz else null end
where user_id='d1100000-0000-4000-8000-000000000001';
set local role authenticated;
insert into results values ('fall',public.get_daily_plan('{"date":"2026-11-01"}'));
select plan_test.assert_true((select payload#>>'{blocks,0,item_count}'='2' from results where label='fall'), '25-hour local day exclusive cutoff');
set local datestyle='SQL, DMY';
insert into results values ('leap',public.get_daily_plan('{"date":"2028-02-29"}'));
select plan_test.assert_true((select payload->>'plan_date'='2028-02-29' from results where label='leap'), 'wire calendar date independent of DateStyle');
reset role;
insert into public.daily_plans(user_id,plan_date,target_minutes,plan_json)
values ('d1100000-0000-4000-8000-000000000001','2026-12-01',120,'{}');
set local role authenticated;
select plan_test.assert_true(public.get_daily_plan('{"date":"2026-12-01"}')->>'code'='INTERNAL_ERROR', 'malformed stored snapshot fails closed');
reset role;
create function plan_test.reject_plan() returns trigger language plpgsql as $$
begin raise exception 'TEST ONLY private failure'; end $$;
create trigger plan_test_failure after insert on public.daily_plans
for each row when(new.plan_date='2026-12-02') execute function plan_test.reject_plan();
set local role authenticated;
insert into results values ('failure',public.get_daily_plan('{"date":"2026-12-02"}'));
select plan_test.assert_true((select payload->>'code'='INTERNAL_ERROR' and payload::text not like '%TEST ONLY%' from results where label='failure'), 'internal failure redacted');
reset role;
select plan_test.assert_true(not exists(select 1 from public.daily_plans
  where user_id='d1100000-0000-4000-8000-000000000001' and plan_date='2026-12-02'), 'failed generation rolls back');
select 'WIRE:' || jsonb_build_object('label',label,'payload',payload)::text from results order by label;
rollback;
