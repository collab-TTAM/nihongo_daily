-- TEST ONLY privileged SQL/Auth claims, never hosted identity proof.
begin;
create schema quiz_test;
create function quiz_test.ok(value boolean,label text) returns void language plpgsql as $$
begin
 if value is distinct from true then raise exception 'FAIL quiz ledger: %',label; end if;
 raise notice 'PASS quiz ledger: %',label;
end $$;
create function quiz_test.fails(statement text,expected_state text,expected_message text default null)
returns boolean language plpgsql as $$
begin execute statement; return false;
exception when others then
 return SQLSTATE=expected_state and (expected_message is null or SQLERRM=expected_message);
end $$;
grant usage on schema quiz_test to anon,authenticated,service_role;
grant execute on all functions in schema quiz_test to anon,authenticated,service_role;
create temp table quiz_cases(name text,request jsonb,response jsonb);
insert into quiz_cases values ('vocabulary_reading-None','{"client_event_id": "a3000000-0000-4000-8000-000000000001", "quiz_type": "vocabulary_reading", "practice_kind": null, "jlpt_level": "N5", "completed_at": "2000-01-01T00:00:00.000001Z", "answers": [{"item_id": "a2000000-0000-4000-8000-000000000001", "content_version": 1, "selected_id": "a2000000-0000-4000-8000-000000000002", "choices": ["a2000000-0000-4000-8000-000000000001", "a2000000-0000-4000-8000-000000000002", "a2000000-0000-4000-8000-000000000003", "a2000000-0000-4000-8000-000000000004"]}]}','{"client_event_id": "a3000000-0000-4000-8000-000000000001", "quiz_type": "vocabulary_reading", "practice_kind": null, "jlpt_level": "N5", "completed_at": "2000-01-01T00:00:00.000001Z", "answer_count": 1, "correct_count": 0}');
insert into quiz_cases values ('grammar_meaning-primary','{"client_event_id": "a3000000-0000-4000-8000-000000000002", "quiz_type": "grammar_meaning", "practice_kind": "primary", "jlpt_level": "N5", "completed_at": "2000-01-01T00:00:00.000001Z", "answers": [{"item_id": "a2000000-0000-4000-8000-000000000001", "content_version": 1, "selected_id": "a2000000-0000-4000-8000-000000000001", "choices": ["a2000000-0000-4000-8000-000000000001", "a2000000-0000-4000-8000-000000000002", "a2000000-0000-4000-8000-000000000003", "a2000000-0000-4000-8000-000000000004"]}]}','{"client_event_id": "a3000000-0000-4000-8000-000000000002", "quiz_type": "grammar_meaning", "practice_kind": "primary", "jlpt_level": "N5", "completed_at": "2000-01-01T00:00:00.000001Z", "answer_count": 1, "correct_count": 1}');
insert into quiz_cases values ('grammar_meaning-correction','{"client_event_id": "a3000000-0000-4000-8000-000000000003", "quiz_type": "grammar_meaning", "practice_kind": "correction", "jlpt_level": "N5", "completed_at": "2000-01-01T00:00:00.000001Z", "answers": [{"item_id": "a2000000-0000-4000-8000-000000000001", "content_version": 1, "selected_id": "a2000000-0000-4000-8000-000000000004", "choices": ["a2000000-0000-4000-8000-000000000001", "a2000000-0000-4000-8000-000000000002", "a2000000-0000-4000-8000-000000000003", "a2000000-0000-4000-8000-000000000004"]}]}','{"client_event_id": "a3000000-0000-4000-8000-000000000003", "quiz_type": "grammar_meaning", "practice_kind": "correction", "jlpt_level": "N5", "completed_at": "2000-01-01T00:00:00.000001Z", "answer_count": 1, "correct_count": 0}');
insert into auth.users values ('e3100000-0000-4000-8000-000000000001'),('e3100000-0000-4000-8000-000000000002');
select quiz_test.ok(to_regprocedure('public.submit_quiz_report(jsonb)') is null,'no public mutation exposed');
select quiz_test.ok((select relrowsecurity from pg_class where oid='private.quiz_report_receipts'::regclass),'ledger RLS enabled');
select quiz_test.ok(not has_table_privilege('authenticated','private.quiz_report_receipts','SELECT')
 and not has_table_privilege('authenticated','private.quiz_report_receipts','INSERT')
 and not has_table_privilege('service_role','private.quiz_report_receipts','INSERT'),'app and service ledger privileges absent');
select quiz_test.ok((select bool_and(not has_function_privilege(role_name,oid,'EXECUTE')) from pg_proc
 cross join (values ('anon'),('authenticated'),('service_role')) as roles(role_name)
 where oid in ('private.quiz_report_uuid(jsonb)'::regprocedure,'private.quiz_report_request(jsonb)'::regprocedure,
 'private.replay_quiz_report(jsonb)'::regprocedure,'private.store_quiz_report(jsonb)'::regprocedure)), 'all helper execute grants revoked');
select quiz_test.ok((select bool_and(not prosecdef and proconfig @> array['search_path=""']) from pg_proc
 where oid in ('private.quiz_report_request(jsonb)'::regprocedure,'private.replay_quiz_report(jsonb)'::regprocedure,'private.store_quiz_report(jsonb)'::regprocedure)), 'private invoker functions have closed search path');
set local role anon;
select quiz_test.ok(quiz_test.fails($s$select private.store_quiz_report('{}')$s$,'42501'),'anon actual call denied');
reset role;
set local role authenticated;
select quiz_test.ok(quiz_test.fails($s$select private.store_quiz_report('{}')$s$,'42501'),'authenticated actual call denied');
reset role;
set local role service_role;
select quiz_test.ok(quiz_test.fails($s$select private.store_quiz_report('{}')$s$,'42501'),'service actual call denied');
reset role;
select set_config('request.jwt.claim.sub','',true);
select quiz_test.ok(quiz_test.fails($s$select private.store_quiz_report('{}')$s$,'P0001','UNAUTHORIZED'),'missing identity rejected before store');
select set_config('request.jwt.claim.sub','e3100000-0000-4000-8000-000000000001',true);
select quiz_test.ok((select private.replay_quiz_report(request) is null from quiz_cases limit 1),'lookup miss has no fabricated receipt');
select quiz_test.ok((select count(*)=0 from private.quiz_report_receipts),'lookup miss does not insert');
select quiz_test.ok(private.store_quiz_report(request)=response,'fixture response: '||name) from quiz_cases;
select quiz_test.ok((select count(*)=3 from private.quiz_report_receipts),'three reports committed once');
select quiz_test.ok(private.store_quiz_report(request)=response,'original replay: '||name) from quiz_cases;
select quiz_test.ok((select count(*)=3 from private.quiz_report_receipts),'retry creates no rows');
select quiz_test.ok(quiz_test.fails(format('select private.store_quiz_report(%L::jsonb)',
 request||'{"quiz_type":"grammar_meaning","practice_kind":"primary"}'),'P0001','SYNC_CONFLICT'),'event key spans quiz types') from quiz_cases where request->>'quiz_type'='vocabulary_reading';
select quiz_test.ok(quiz_test.fails(format('select private.store_quiz_report(%L::jsonb)',
 request||'{"practice_kind":"correction"}'),'P0001','SYNC_CONFLICT'),'event key spans grammar kinds') from quiz_cases where request->>'practice_kind'='primary';
select quiz_test.ok(quiz_test.fails(format('select private.store_quiz_report(%L::jsonb)',request||'{"user_id":"forged"}'),'P0001','VALIDATION_FAILURE'),'owner field rejected') from quiz_cases limit 1;
select quiz_test.ok(quiz_test.fails(format('select private.store_quiz_report(%L::jsonb)',jsonb_set(request,'{answers,0,content_version}','true')),'P0001','VALIDATION_FAILURE'),'boolean version rejected') from quiz_cases limit 1;
select quiz_test.ok(quiz_test.fails(format('select private.store_quiz_report(%L::jsonb)',jsonb_set(request,'{answers,0,content_version}','1.0')),'P0001','VALIDATION_FAILURE'),'decimal version rejected') from quiz_cases limit 1;
select quiz_test.ok(quiz_test.fails(format('select private.store_quiz_report(%L::jsonb)',jsonb_set(request,'{completed_at}','"2026-02-30T00:00:00Z"')),'P0001','VALIDATION_FAILURE'),'real calendar required') from quiz_cases limit 1;
select quiz_test.ok(quiz_test.fails(format('select private.store_quiz_report(%L::jsonb)',jsonb_set(request,'{completed_at}',to_jsonb(E'2000-01-01T00:00:00Z\n'::text))),'P0001','VALIDATION_FAILURE'),'trailing timestamp newline rejected') from quiz_cases limit 1;
select quiz_test.ok(quiz_test.fails(format('select private.store_quiz_report(%L::jsonb)',jsonb_set(request,'{answers}',(request->'answers')||(request->'answers'))),'P0001','VALIDATION_FAILURE'),'duplicate target rejected') from quiz_cases limit 1;
select quiz_test.ok(quiz_test.fails(format('select private.store_quiz_report(%L::jsonb)',jsonb_set(request,'{answers,0,selected_id}','"a2000000-0000-4000-8000-000000000099"')),'P0001','VALIDATION_FAILURE'),'selection must be offered') from quiz_cases limit 1;
select quiz_test.ok(quiz_test.fails(format('select private.store_quiz_report(%L::jsonb)',jsonb_set(request,'{answers,0,choices}','["a2000000-0000-4000-8000-000000000001","a2000000-0000-4000-8000-000000000001","a2000000-0000-4000-8000-000000000003","a2000000-0000-4000-8000-000000000004"]')),'P0001','VALIDATION_FAILURE'),'choice IDs unique') from quiz_cases limit 1;
select set_config('request.jwt.claim.sub','e3100000-0000-4000-8000-000000000002',true);
select quiz_test.ok(private.store_quiz_report(request)=response,'same event independent B') from quiz_cases where request->>'practice_kind'='primary';
select quiz_test.ok((select count(*)=1 from private.quiz_report_receipts where user_id=auth.uid()),'B receipt isolated');
-- Transaction-local read grants solely to exercise actual RLS; all roll back.
grant usage on schema private to authenticated;
grant select on private.quiz_report_receipts to authenticated;
set local role authenticated;
select quiz_test.ok((select count(*)=1 and bool_and(user_id=auth.uid()) from private.quiz_report_receipts),'B actual RLS select owns one receipt');
select set_config('request.jwt.claim.sub','e3100000-0000-4000-8000-000000000001',true);
select quiz_test.ok((select count(*)=3 and bool_and(user_id=auth.uid()) from private.quiz_report_receipts),'A actual RLS select owns three receipts');
select quiz_test.ok(quiz_test.fails($s$delete from private.quiz_report_receipts$s$,'42501'),'read grant does not grant deletion');
reset role;
select quiz_test.ok(quiz_test.fails($s$update private.quiz_report_receipts set received_at=clock_timestamp()$s$,'23514'),'privileged update rejected by immutable trigger');
select quiz_test.ok(quiz_test.fails($s$delete from private.quiz_report_receipts$s$,'23514'),'privileged deletion rejected by immutable trigger');
do $$ declare payload jsonb; before_count integer; begin
 select count(*) into before_count from private.quiz_report_receipts;
 select request||'{"client_event_id":"e3400000-0000-4000-8000-000000000099"}' into payload from quiz_cases limit 1;
 begin
  perform private.store_quiz_report(payload);
  raise exception 'TEST ONLY rollback' using errcode='45000';
 exception when sqlstate '45000' then null;
 end;
 perform quiz_test.ok((select count(*)=before_count from private.quiz_report_receipts),'outer rollback leaves no partial receipt');
end $$;
-- Privileged synthetic prior receipt models server clock rollback. Not learner evidence.
do $$ declare payload jsonb; response jsonb; begin
 select request||jsonb_build_object('client_event_id','e3400000-0000-4000-8000-000000000098',
 'completed_at',to_char((clock_timestamp()+interval '1 day') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')),
 quiz_cases.response into payload,response from quiz_cases limit 1;
 response := response||jsonb_build_object('client_event_id',payload->>'client_event_id','completed_at',payload->>'completed_at');
 insert into private.quiz_report_receipts(user_id,client_event_id,request_json,response_json)
 values(auth.uid(),(payload->>'client_event_id')::uuid,payload,response);
 perform quiz_test.ok(private.store_quiz_report(payload)=response,'exact replay precedes future-time check');
 payload := payload||'{"client_event_id":"e3400000-0000-4000-8000-000000000097"}';
 perform quiz_test.ok(quiz_test.fails(format('select private.store_quiz_report(%L::jsonb)',payload),'P0001','VALIDATION_FAILURE'),'new future report rejected');
end $$;
rollback;
-- Assert test-only grants did not escape the rollback.
do $$ begin
 if has_table_privilege('authenticated','private.quiz_report_receipts','SELECT') then
  raise exception 'TEST ONLY ledger grant escaped rollback';
 end if;
 raise notice 'PASS quiz ledger: TEST ONLY read grants rolled back';
end $$;
