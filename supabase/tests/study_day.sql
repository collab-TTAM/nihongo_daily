-- TEST ONLY role claims; no hosted JWT identity proof. Roll back own fixtures.
begin;
create schema day_test;
create function day_test.ok(ok boolean,label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL study day: %',label; end if; end $$;
create function day_test.denied(statement text) returns boolean language plpgsql as $$
begin execute statement; return false; exception when insufficient_privilege then return true; end $$;
grant usage on schema day_test to anon,authenticated,service_role;
grant execute on all functions in schema day_test to anon,authenticated,service_role;
create temp table day_wire(label text primary key,payload jsonb);
grant select,insert on day_wire to authenticated;
select day_test.ok(has_function_privilege('authenticated','public.get_study_day(jsonb)','EXECUTE')
 and not has_function_privilege('anon','public.get_study_day(jsonb)','EXECUTE')
 and not has_function_privilege('service_role','public.get_study_day(jsonb)','EXECUTE'),'wrapper ACL');
select day_test.ok((select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.get_study_day(jsonb)'::regprocedure),'closed path');
select day_test.ok(not has_function_privilege('authenticated','private.study_day_at(timestamptz,text)','EXECUTE')
 and not has_function_privilege('service_role','private.study_day_at(timestamptz,text)','EXECUTE'),'helper not exposed');
select day_test.ok(private.study_day_at('2026-10-19T16:59:59Z','Asia/Ho_Chi_Minh')='2026-10-19'
 and private.study_day_at('2026-10-19T17:00:00Z','Asia/Ho_Chi_Minh')='2026-10-20','Vietnam midnight');
select day_test.ok(private.study_day_at('2026-03-08T04:59:59Z','America/New_York')='2026-03-07'
 and private.study_day_at('2026-03-08T05:00:00Z','America/New_York')='2026-03-08'
 and private.study_day_at('2026-03-09T03:59:59Z','America/New_York')='2026-03-08'
 and private.study_day_at('2026-03-09T04:00:00Z','America/New_York')='2026-03-09','23-hour DST day');
select day_test.ok(private.study_day_at('2026-11-01T04:00:00Z','America/New_York')='2026-11-01'
 and private.study_day_at('2026-11-02T04:59:59Z','America/New_York')='2026-11-01'
 and private.study_day_at('2026-11-02T05:00:00Z','America/New_York')='2026-11-02','25-hour DST day');
select day_test.ok(private.study_day_at('2028-02-29T00:00:00Z','UTC')='2028-02-29'
 and private.study_day_at('2026-12-31T10:00:00Z','Pacific/Kiritimati')='2027-01-01','leap/year rollover');
insert into auth.users values ('f4100000-0000-4000-8000-000000000001'),('f4100000-0000-4000-8000-000000000002'),('f4100000-0000-4000-8000-000000000003');
insert into public.profiles(id,timezone) values ('f4100000-0000-4000-8000-000000000001','Pacific/Honolulu'),('f4100000-0000-4000-8000-000000000002','Pacific/Kiritimati');
set local role anon;
select day_test.ok(day_test.denied($s$select public.get_study_day('{}')$s$),'anon actual denial');
reset role;
set local role service_role;
select day_test.ok(day_test.denied($s$select public.get_study_day('{}')$s$),'service actual denial');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
insert into day_wire values ('unauthorized', public.get_study_day('{}'));
select day_test.ok((select payload->>'code'='UNAUTHORIZED' from day_wire where label='unauthorized'),'no identity');
select set_config('request.jwt.claim.sub','f4100000-0000-4000-8000-000000000003',true);
select day_test.ok(public.get_study_day('{}')->>'code'='NOT_FOUND','missing profile not bootstrapped');
select set_config('request.jwt.claim.sub','f4100000-0000-4000-8000-000000000001',true);
do $$declare raw jsonb; result jsonb; begin
 for raw in select value from jsonb_array_elements('[null,[],1,"",{"user_id":"other"},{"date":"2026-10-20"},{"timezone":"UTC"},{"now":"2026-10-20T00:00:00Z"}]') loop
  perform day_test.ok(public.get_study_day(raw)->>'code'='VALIDATION_FAILURE','strict request');
 end loop;
 result := public.get_study_day('{}');
 perform day_test.ok(result->>'timezone'='Pacific/Honolulu' and (result->>'date')::date=(statement_timestamp() at time zone 'Pacific/Honolulu')::date,'own server date A');
end $$;
insert into day_wire values ('owner-a',public.get_study_day('{}'));
select set_config('request.jwt.claim.sub','f4100000-0000-4000-8000-000000000002',true);
insert into day_wire values ('owner-b',public.get_study_day('{}'));
select day_test.ok((select payload->>'timezone'='Pacific/Kiritimati' from day_wire where label='owner-b'),'own zone B');
update public.profiles set timezone='Asia/Saigon' where id='f4100000-0000-4000-8000-000000000002';
set local datestyle='SQL, DMY';
set local timezone='America/Los_Angeles';
insert into day_wire values ('changed-profile',public.get_study_day('{}'));
select day_test.ok((select payload->>'timezone'='Asia/Ho_Chi_Minh' and payload->>'date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' from day_wire where label='changed-profile'),'current normalized profile/DateStyle independent');
select day_test.ok(day_test.denied($s$select private.study_day_at(statement_timestamp(),'UTC')$s$),'auth cannot inject helper clock');
reset role;
select day_test.ok(not exists(select 1 from public.profiles where id='f4100000-0000-4000-8000-000000000003'),'read did not provision profile');
select day_test.ok(not exists(select 1 from public.daily_plans where user_id in ('f4100000-0000-4000-8000-000000000001','f4100000-0000-4000-8000-000000000002'))
 and not exists(select 1 from public.study_sessions where user_id in ('f4100000-0000-4000-8000-000000000001','f4100000-0000-4000-8000-000000000002')),'read created no learning records');
select 'WIRE:'||jsonb_build_object('label',label,'payload',payload)::text from day_wire order by label;
rollback;
