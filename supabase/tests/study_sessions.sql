-- Disposable role/transaction fixtures; no real JWT or learner proof.
begin;
create schema session_test;
create function session_test.ok(p_ok boolean,p_label text) returns void language plpgsql as $$
begin
  if p_ok is distinct from true then raise exception 'FAIL session: %',p_label; end if;
  raise notice 'PASS session: %',p_label;
end $$;
create function session_test.denied(statement text) returns boolean language plpgsql as $$
begin execute statement; return false;
exception when insufficient_privilege then return true;
end $$;
create function session_test.request(p_id integer,
  p_start text default '2026-10-17T17:00:00Z',p_end text default '2026-10-17T17:15:00Z',
  p_kind text default 'VOCABULARY',p_day text default '2026-10-18') returns jsonb language sql as $$
  select jsonb_build_object('client_event_id','e1400000-0000-4000-8000-'||lpad(p_id::text,12,'0'),
    'plan_date',p_day,'session_type',p_kind,'started_at',p_start,'ended_at',p_end)
$$;
grant usage on schema session_test to anon,authenticated,service_role;
grant execute on all functions in schema session_test to anon,authenticated,service_role;
create temp table session_results(label text primary key,payload jsonb);
grant select,insert on session_results to service_role,authenticated;

select session_test.ok(not has_function_privilege('authenticated','private.record_study_session(uuid,jsonb)','EXECUTE')
  and not has_function_privilege('anon','private.record_study_session(uuid,jsonb)','EXECUTE'), 'client/anonymous helper denied');
select session_test.ok(not has_function_privilege('service_role','private.study_session_instant(text)','EXECUTE'), 'private parser denied even to service');
select session_test.ok(not has_table_privilege('service_role','private.study_session_receipts','SELECT,INSERT,UPDATE,DELETE'), 'no direct service receipt access');
select session_test.ok((select prosecdef and proconfig @> array['search_path=""']
  from pg_proc where oid='private.record_study_session(uuid,jsonb)'::regprocedure), 'narrow definer empty search path');
insert into auth.users(id) values ('e1100000-0000-4000-8000-000000000001'),
 ('e1100000-0000-4000-8000-000000000002'),('e1100000-0000-4000-8000-000000000003');
insert into public.profiles(id,timezone) values
 ('e1100000-0000-4000-8000-000000000001','Asia/Saigon'),
 ('e1100000-0000-4000-8000-000000000002','Asia/Saigon');
insert into public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,expression,reading,meaning_vi,part_of_speech,usage_context_vi)
values ('e1200000-0000-4000-8000-000000000001','N5',0.1,1,true,'水','みず','nước','noun','TEST ONLY');
set local role authenticated;
select set_config('request.jwt.claim.sub','e1100000-0000-4000-8000-000000000001',true);
select session_test.ok(public.get_daily_plan('{"date":"2026-10-18"}')->>'completed_minutes'='0','initial A plan');
select session_test.ok(session_test.denied($s$select private.record_study_session('e1100000-0000-4000-8000-000000000001',session_test.request(1))$s$),'actual auth execution denied');
select session_test.ok(session_test.denied('select * from private.study_session_receipts'),'client receipt storage denied');
select set_config('request.jwt.claim.sub','e1100000-0000-4000-8000-000000000002',true);
select session_test.ok(public.get_daily_plan('{"date":"2026-10-18"}')->>'completed_minutes'='0','initial B plan');
reset role;
set local role anon;
select session_test.ok(session_test.denied($s$select private.record_study_session('e1100000-0000-4000-8000-000000000001','{}')$s$),'actual anon execution denied');
reset role;
set local role service_role;
select session_test.ok(private.record_study_session(null,session_test.request(1))->>'code'='UNAUTHORIZED','missing verified owner');
select session_test.ok(private.record_study_session('e1100000-0000-4000-8000-000000000003',session_test.request(1))->>'code'='NOT_FOUND','missing profile');
select session_test.ok(private.record_study_session('e1100000-0000-4000-8000-000000000001',session_test.request(90,'2025-01-01T00:00:00Z','2025-01-01T00:15:00Z','VOCABULARY','2025-01-01'))->>'code'='NOT_FOUND','no implicit plan creation');
insert into session_results values ('first',private.record_study_session('e1100000-0000-4000-8000-000000000001',session_test.request(1)));
select session_test.ok((select payload->>'completed_minutes'='15' and payload#>>'{blocks,1,status}'='DONE' from session_results where label='first'),
 'derived15 minutes and block DONE; observed='||(select payload::text from session_results where label='first'));
select session_test.ok(private.record_study_session('e1100000-0000-4000-8000-000000000001',session_test.request(1))=(select payload from session_results where label='first'),'exact immutable replay');
select session_test.ok(private.record_study_session('e1100000-0000-4000-8000-000000000001',session_test.request(1,'2026-10-17T17:00:00Z','2026-10-17T17:16:00Z'))->>'code'='SYNC_CONFLICT','changed same event conflicts');
select session_test.ok(private.record_study_session('e1100000-0000-4000-8000-000000000001',session_test.request(4,'2026-10-17T17:05:00Z','2026-10-17T17:20:00Z'))->>'code'='SYNC_CONFLICT','different event cannot overlap');
insert into session_results values ('other-owner',private.record_study_session('e1100000-0000-4000-8000-000000000002',session_test.request(1)));
select session_test.ok((select payload->>'completed_minutes'='15' from session_results where label='other-owner'),'same ID/interval other owner independent');
reset role;
update public.profiles set timezone='UTC',preferred_jlpt='N4',daily_target_minutes=7 where id='e1100000-0000-4000-8000-000000000001';
set local role service_role;
insert into session_results values ('over-target',private.record_study_session('e1100000-0000-4000-8000-000000000001',
  session_test.request(2,'2026-10-18T00:00:00Z','2026-10-18T02:10:00Z')));
select session_test.ok((select payload->>'completed_minutes'='145' and payload->>'target_minutes'='120' from session_results where label='over-target'),'over-target preserved using original settings');
insert into session_results values ('replay-old',private.record_study_session('e1100000-0000-4000-8000-000000000001',session_test.request(1)));
select session_test.ok((select payload=(select payload from session_results where label='first') from session_results where label='replay-old'),'old replay retains original response after later progress');
select session_test.ok(private.record_study_session('e1100000-0000-4000-8000-000000000001',request)->>'code'='VALIDATION_FAILURE','strict invalid request rejected')
from (values (null::jsonb),('null'::jsonb),('[]'::jsonb),('{}'::jsonb),
 (session_test.request(10)||'{"actual_minutes":999}'),(session_test.request(10)||'{"user_id":"other"}'),
 (session_test.request(10)||'{"client_event_id":"bad"}'),(session_test.request(10)||'{"plan_date":"2026-02-30"}'),
 (session_test.request(10)||'{"session_type":"UNKNOWN"}'),(session_test.request(10)||'{"started_at":"2026-10-18"}'),
 (session_test.request(10)||'{"started_at":"2026-02-30T00:00:00Z"}'),
 (session_test.request(10)||'{"started_at":"2026-10-18T24:00:00Z"}'),
 (session_test.request(10)||'{"ended_at":"2026-10-18T00:00:60Z"}'),
 (session_test.request(10)||'{"started_at":null}'),
 (session_test.request(10,'2026-10-18T03:00:00Z','2026-10-18T03:00:59Z')),
 (session_test.request(10,'2026-10-18T03:01:00Z','2026-10-18T03:00:00Z')),
 (session_test.request(10,'2026-10-17T16:59:00Z','2026-10-17T17:00:00Z')),
 (session_test.request(10,'2026-10-18T16:59:00Z','2026-10-18T17:01:00Z')),
 (session_test.request(10,'2026-10-18T03:00:00Z','2026-10-18T03:01:00Z','KANJI')),
 (session_test.request(10)||jsonb_build_object('ended_at',to_char(clock_timestamp()+interval '1 day','YYYY-MM-DD"T"HH24:MI:SS"Z"')))) bad(request);
reset role;
select session_test.ok((select count(*)=2 and sum(actual_minutes)=145 and bool_and(jlpt_level='N5' and planned_minutes=15)
 from public.study_sessions where user_id='e1100000-0000-4000-8000-000000000001'),'only accepted sessions exist with trusted derived fields');
-- Unvalidated legacy/trusted rows cannot inflate this new ledger's aggregation.
insert into public.study_sessions(user_id,session_type,started_at,ended_at,planned_minutes,actual_minutes,jlpt_level)
values ('e1100000-0000-4000-8000-000000000001','VOCABULARY','2026-10-18T03:00:00Z','2026-10-18T03:01:00Z',1,999,'N5');
set local role service_role;
insert into session_results values ('whole-minute',private.record_study_session('e1100000-0000-4000-8000-000000000001',
 session_test.request(3,'2026-10-18T03:00:00.000000Z','2026-10-18T03:01:01+00:00')));
select session_test.ok((select payload->>'completed_minutes'='146' from session_results where label='whole-minute'),'floor actual elapsed duration, ignore unvalidated999 row');
insert into session_results values ('end-boundary',private.record_study_session('e1100000-0000-4000-8000-000000000001',
 session_test.request(5,'2026-10-18T16:59:00Z','2026-10-18T17:00:00Z')));
select session_test.ok((select payload->>'completed_minutes'='147' from session_results where label='end-boundary'),'end at snapshot next midnight allowed');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','e1100000-0000-4000-8000-000000000001',true);
insert into session_results values ('read-latest',public.get_daily_plan('{"date":"2026-10-18"}'));
select session_test.ok((select payload=(select payload from session_results where label='end-boundary') from session_results where label='read-latest'),'get_daily_plan recovers latest accepted progress');
select session_test.ok((select bool_and(user_id='e1100000-0000-4000-8000-000000000001') from public.study_sessions),'A cannot read B sessions');
select session_test.ok(session_test.denied('update public.daily_plans set completed_minutes=0'),'client progress overwrite still denied');
select set_config('request.jwt.claim.sub','e1100000-0000-4000-8000-000000000002',true);
select public.get_daily_plan('{"date":"2026-10-17"}');
reset role;
set local role service_role;
insert into session_results values ('in-progress',private.record_study_session('e1100000-0000-4000-8000-000000000002',
 session_test.request(31,'2026-10-16T17:00:00Z','2026-10-16T17:01:00Z','VOCABULARY','2026-10-17')));
select session_test.ok((select payload->>'completed_minutes'='1' and payload#>>'{blocks,1,status}'='IN_PROGRESS' from session_results where label='in-progress'),'partial block becomes IN_PROGRESS');
insert into session_results values ('adjacent-done',private.record_study_session('e1100000-0000-4000-8000-000000000002',
 session_test.request(32,'2026-10-16T17:01:00Z','2026-10-16T17:15:00Z','VOCABULARY','2026-10-17')));
select session_test.ok((select payload->>'completed_minutes'='15' and payload#>>'{blocks,1,status}'='DONE' from session_results where label='adjacent-done'),'adjacent accepted minutes complete block');
reset role;

savepoint corrupt_snapshot;
update public.daily_plans set plan_json=jsonb_set(plan_json,'{blocks}','[]')
 where user_id='e1100000-0000-4000-8000-000000000001' and plan_date='2026-10-18';
set local role service_role;
select session_test.ok(private.record_study_session('e1100000-0000-4000-8000-000000000001',
 session_test.request(7,'2026-10-18T04:00:00Z','2026-10-18T04:10:00Z'))->>'code'='INTERNAL_ERROR','corrupt snapshot fails closed');
reset role;
rollback to savepoint corrupt_snapshot;

-- Failure after inserting a session/updating the plan rolls back both plus receipt.
create function session_test.break_receipt() returns trigger language plpgsql as $$
begin raise exception 'TEST ONLY sensitive failure'; end $$;
create trigger session_test_break before insert on private.study_session_receipts
for each row execute function session_test.break_receipt();
set local role service_role;
insert into session_results values ('failure',private.record_study_session('e1100000-0000-4000-8000-000000000001',
 session_test.request(6,'2026-10-18T03:10:00Z','2026-10-18T03:20:00Z')));
select session_test.ok((select payload->>'code'='INTERNAL_ERROR' and payload::text not like '%sensitive%' from session_results where label='failure'),'redacted failure');
reset role;
drop trigger session_test_break on private.study_session_receipts;
select session_test.ok((select completed_minutes=147 from public.daily_plans where user_id='e1100000-0000-4000-8000-000000000001' and plan_date='2026-10-18')
 and not exists(select 1 from public.study_sessions where user_id='e1100000-0000-4000-8000-000000000001' and started_at='2026-10-18T03:10:00Z')
 and not exists(select 1 from private.study_session_receipts where user_id='e1100000-0000-4000-8000-000000000001' and client_event_id='e1400000-0000-4000-8000-000000000006'),'atomic failure leaves no partial session/progress/receipt');

-- Calendar days use the frozen timezone; DST elapsed time is23/25 hours.
update public.profiles set timezone='America/New_York' where id='e1100000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','e1100000-0000-4000-8000-000000000002',true);
select public.get_daily_plan('{"date":"2026-03-08"}');
select public.get_daily_plan('{"date":"2025-11-02"}');
reset role;
set local role service_role;
insert into session_results values ('dst-short',private.record_study_session('e1100000-0000-4000-8000-000000000002',
 session_test.request(21,'2026-03-08T05:00:00Z','2026-03-09T04:00:00Z','VOCABULARY','2026-03-08')));
insert into session_results values ('dst-long',private.record_study_session('e1100000-0000-4000-8000-000000000002',
 session_test.request(22,'2025-11-02T04:00:00Z','2025-11-03T05:00:00Z','VOCABULARY','2025-11-02')));
select session_test.ok((select payload->>'completed_minutes'='1380' from session_results where label='dst-short')
 and (select payload->>'completed_minutes'='1500' from session_results where label='dst-long'),'actual23/25-hour DST days');
reset role;
select 'WIRE:'||jsonb_build_object('label',label,'payload',payload)::text from session_results order by label;
rollback;
