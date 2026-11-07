-- Native Auth-role fixtures; no hosted signature/session/learner proof.
begin;
create schema submit_test;
create function submit_test.ok(ok boolean,label text) returns void language plpgsql as $$
begin
 if ok is distinct from true then raise exception 'FAIL submit: %',label; end if;
 raise notice 'PASS submit: %',label;
end $$;
create function submit_test.denied(statement text) returns boolean language plpgsql as $$
begin execute statement; return false;
exception when insufficient_privilege then return true;
end $$;
grant usage on schema submit_test to anon,authenticated,service_role;
grant execute on all functions in schema submit_test to anon,authenticated,service_role;
create temp table submit_results(label text primary key,request jsonb,payload jsonb);
grant select,insert on submit_results to authenticated;
create temp table submit_request as select '{"client_event_id":"e2400000-0000-4000-8000-000000000001","plan_date":"2026-10-18","session_type":"VOCABULARY","started_at":"2026-10-18T00:00:00.000Z","ended_at":"2026-10-18T00:05:00.000Z"}'::jsonb as payload;
grant select on submit_request to authenticated;

select submit_test.ok(has_function_privilege('authenticated','public.submit_study_session(jsonb)','EXECUTE')
 and not has_function_privilege('anon','public.submit_study_session(jsonb)','EXECUTE')
 and not has_function_privilege('service_role','public.submit_study_session(jsonb)','EXECUTE'),'only authenticated gateway role can execute');
select submit_test.ok((select prosecdef and proconfig @> array['search_path=""'] from pg_proc
 where oid='public.submit_study_session(jsonb)'::regprocedure),'closed definer path');
insert into auth.users values ('e2100000-0000-4000-8000-000000000001'),
 ('e2100000-0000-4000-8000-000000000002'),('e2100000-0000-4000-8000-000000000003');
insert into public.profiles(id) values ('e2100000-0000-4000-8000-000000000001'),('e2100000-0000-4000-8000-000000000002');
insert into public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,expression,reading,meaning_vi,part_of_speech,usage_context_vi)
values ('e2200000-0000-4000-8000-000000000001','N5',0.1,1,true,'水','みず','nước','noun','TEST ONLY');
set local role anon;
select submit_test.ok(submit_test.denied($s$select public.submit_study_session('{}')$s$),'anon actual call denied');
reset role;
set local role service_role;
select submit_test.ok(submit_test.denied($s$select public.submit_study_session('{}')$s$),'service actual wrapper call denied');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
insert into submit_results select 'unauthorized',payload,public.submit_study_session(payload) from submit_request;
select submit_test.ok((select payload->>'code'='UNAUTHORIZED' from submit_results where label='unauthorized'),'missing identity fails');
select set_config('request.jwt.claim.sub','e2100000-0000-4000-8000-000000000003',true);
select submit_test.ok((select public.submit_study_session(payload)->>'code'='NOT_FOUND' from submit_request),'profile required');
select set_config('request.jwt.claim.sub','e2100000-0000-4000-8000-000000000001',true);
select public.get_daily_plan('{"date":"2026-10-18"}');
insert into submit_results select 'first',payload,public.submit_study_session(payload) from submit_request;
select submit_test.ok((select payload->>'completed_minutes'='5' and payload#>>'{blocks,1,status}'='IN_PROGRESS' from submit_results where label='first'),
 'A self-reported duration accepted; observed='||(select payload::text from submit_results where label='first'));
select submit_test.ok((select public.submit_study_session(request)=payload from submit_results where label='first'),'exact retry preserves result');
select submit_test.ok((select public.submit_study_session(request||'{"ended_at":"2026-10-18T00:06:00.000Z"}')->>'code'='SYNC_CONFLICT' from submit_results where label='first'),'changed input conflicts');
select submit_test.ok((select public.submit_study_session(payload||'{"user_id":"e2100000-0000-4000-8000-000000000002"}')->>'code'='VALIDATION_FAILURE' from submit_request),'owner override forbidden');
select submit_test.ok((select public.submit_study_session(payload||'{"actual_minutes":999}')->>'code'='VALIDATION_FAILURE' from submit_request),'derived minutes override forbidden');
select submit_test.ok((select public.submit_study_session(payload||'{"started_at":"2026-10-18T00:00:00+00:00"}')->>'code'='VALIDATION_FAILURE' from submit_request),'public version requires UTC Z');
select submit_test.ok(submit_test.denied($s$select private.record_study_session('e2100000-0000-4000-8000-000000000002','{}')$s$),'auth cannot invoke private owner argument');
select submit_test.ok(submit_test.denied('update public.daily_plans set completed_minutes=999'),'auth cannot overwrite progress');
select set_config('request.jwt.claim.sub','e2100000-0000-4000-8000-000000000002',true);
select public.get_daily_plan('{"date":"2026-10-18"}');
select submit_test.ok((select completed_minutes=0 from public.daily_plans),'B plan unaffected by A');
insert into submit_results select 'other-owner',payload,public.submit_study_session(payload) from submit_request;
select submit_test.ok((select payload->>'completed_minutes'='5' from submit_results where label='other-owner'),'same event independent B');
select submit_test.ok((select count(*)=1 and bool_and(user_id='e2100000-0000-4000-8000-000000000002') from public.study_sessions),'B only sees own session');
select set_config('request.jwt.claim.sub','e2100000-0000-4000-8000-000000000001',true);
insert into submit_results select 'second',payload||'{"client_event_id":"e2400000-0000-4000-8000-000000000002","started_at":"2026-10-18T00:05:00.000Z","ended_at":"2026-10-18T00:10:00.000Z"}',
 public.submit_study_session(payload||'{"client_event_id":"e2400000-0000-4000-8000-000000000002","started_at":"2026-10-18T00:05:00.000Z","ended_at":"2026-10-18T00:10:00.000Z"}') from submit_request;
select submit_test.ok((select payload->>'completed_minutes'='10' from submit_results where label='second'),'adjacent completion adds once');
select submit_test.ok((select public.submit_study_session(request)=payload from submit_results where label='first'),'old receipt unchanged after later completion');
select submit_test.ok((select public.get_daily_plan('{"date":"2026-10-18"}')=payload from submit_results where label='second'),'fresh read sees latest authoritative progress');
reset role;
select submit_test.ok((select count(*)=2 and sum(actual_minutes)=10 from public.study_sessions
 where user_id='e2100000-0000-4000-8000-000000000001'),'retries/overrides create no extra A session');
select 'WIRE:'||jsonb_build_object('label',label,'request',request,'payload',payload)::text from submit_results order by label;
rollback;
