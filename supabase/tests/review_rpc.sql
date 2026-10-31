-- Actual authenticated SQL calls; auth fixture does NOT verify real JWT expiry.
begin;
create schema review_test;
create function review_test.ok(value boolean,label text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL REVIEW: %',label; end if;
raise notice 'PASS REVIEW: %',label; end $$;
create function review_test.request(event_no integer, rating integer default 2) returns jsonb
language sql stable as $$
select jsonb_build_object('client_event_id','b2000000-0000-4000-8000-'||lpad(event_no::text,12,'0'),
 'item_type','VOCABULARY','item_id','b3000000-0000-4000-8000-000000000001',
 'rating',rating,'is_correct',rating<>0,'response_ms',100,
 'occurred_at',to_char((current_timestamp-interval '1 day') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))
$$;
grant usage on schema review_test to authenticated,anon,service_role;
grant execute on all functions in schema review_test to authenticated,anon,service_role;
insert into auth.users values ('b1000000-0000-4000-8000-000000000001'),('b1000000-0000-4000-8000-000000000002');
insert into public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,expression,reading,meaning_vi,part_of_speech,usage_context_vi)
 values('b3000000-0000-4000-8000-000000000001','N5',0.1,1,true,'試験','しけん','kiểm thử','noun','SQL test');
insert into public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,expression,reading,meaning_vi,part_of_speech,usage_context_vi)
 values('b3000000-0000-4000-8000-000000000002','N5',0.1,1,true,'追加','ついか','kiểm thử khác','noun','SQL test');
create table review_test.saved(request jsonb,response jsonb);
insert into review_test.saved values(review_test.request(1),null);
grant select,update on review_test.saved to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select review_test.ok(public.submit_review(review_test.request(1))->>'code'='UNAUTHORIZED','missing identity fails closed');
select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
update review_test.saved set response=public.submit_review(request);
select review_test.ok((select response->>'srs_state'='LEARNING' and response->>'review_count'='1' from review_test.saved),'first authenticated review schedules');
select review_test.ok((select public.submit_review(request)=response from review_test.saved),'identical replay returns original result');
select review_test.ok((select public.submit_review(request||jsonb_build_object('client_event_id',upper(request->>'client_event_id'),'item_id',upper(request->>'item_id')))=response from review_test.saved),'logical UUID capitalization preserves replay');
select review_test.ok((select public.submit_review(request||'{"rating":2.0,"response_ms":100.0}')=response from review_test.saved),'integer-valued JSON numbers preserve replay');
select review_test.ok((select count(*)=1 and max(review_count)=1 from public.user_learning_items where item_id='b3000000-0000-4000-8000-000000000001'),'replay does not increment');
select review_test.ok(public.submit_review(review_test.request(1,3))->>'code'='SYNC_CONFLICT','changed retry conflicts');
select review_test.ok(public.submit_review(review_test.request(2,0))->>'srs_state'='LEARNING','second distinct event accepted at equal instant');
select review_test.ok((select public.submit_review(request)=response from review_test.saved),'old retry survives later review');
select review_test.ok(public.submit_review(review_test.request(3)||jsonb_build_object('occurred_at','2000-01-01T00:00:00Z'))->>'code'='SYNC_CONFLICT','stale new event rejected');
select review_test.ok(public.submit_review(review_test.request(3)||jsonb_build_object('occurred_at',to_char((current_timestamp+interval '1 day') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')))->>'code'='VALIDATION_FAILURE','future skew rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"user_id":"b1000000-0000-4000-8000-000000000002"}')->>'code'='VALIDATION_FAILURE','forged owner rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"next_review_at":"2099-01-01T00:00:00Z"}')->>'code'='VALIDATION_FAILURE','derived client state rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"is_correct":false}')->>'code'='VALIDATION_FAILURE','contradictory correctness rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"rating":"2"}')->>'code'='VALIDATION_FAILURE','numeric strings rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"rating":1.5}')->>'code'='VALIDATION_FAILURE','fractional rating rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"rating":4}')->>'code'='VALIDATION_FAILURE','rating bounds');
select review_test.ok(public.submit_review(review_test.request(3)||'{"response_ms":3600001}')->>'code'='VALIDATION_FAILURE','duration bounds');
select review_test.ok(public.submit_review(review_test.request(3)||'{"response_ms":null}')->>'code'='VALIDATION_FAILURE','required null rejected');
select review_test.ok(public.submit_review(review_test.request(3)-'item_id')->>'code'='VALIDATION_FAILURE','missing field rejected');
select review_test.ok(public.submit_review('[]')->>'code'='VALIDATION_FAILURE','array input rejected');
select review_test.ok(public.submit_review(null)->>'code'='VALIDATION_FAILURE','SQL null rejected');
select review_test.ok(public.submit_review('null')->>'code'='VALIDATION_FAILURE','JSON null rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"client_event_id":"bad"}')->>'code'='VALIDATION_FAILURE','malformed UUID rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"occurred_at":"2026-02-30T10:00:00Z"}')->>'code'='VALIDATION_FAILURE','invalid calendar date rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"occurred_at":"2026-01-01T24:00:00Z"}')->>'code'='VALIDATION_FAILURE','hour overflow rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"occurred_at":"2026-01-01T10:00:60Z"}')->>'code'='VALIDATION_FAILURE','leap second rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"occurred_at":"2026-01-01T10:00:00"}')->>'code'='VALIDATION_FAILURE','missing timezone rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"item_type":"KANJI"}')->>'code'='NOT_FOUND','wrong curriculum type rejected');
select review_test.ok(public.submit_review(review_test.request(3)||'{"item_id":"b3000000-0000-4000-8000-000000000099"}')->>'code'='NOT_FOUND','missing curriculum rejected');
select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000002',true);
select review_test.ok((select count(*)=0 from public.review_events where learning_item_id in(select id from public.user_learning_items where item_id='b3000000-0000-4000-8000-000000000001')),'B cannot read A events');
select review_test.ok(public.submit_review(review_test.request(1))->>'review_count'='1','same event UUID independent for B');
select review_test.ok((select count(*)=1 from public.review_events where client_event_id='b2000000-0000-4000-8000-000000000001'),'B sees only own event');
reset role;
select review_test.ok((select count(*)=2 from public.review_events where client_event_id='b2000000-0000-4000-8000-000000000001'),'A/B events separately persisted');
select review_test.ok((select bool_and(metadata->>'algorithm_version'='nd-srs-1') from public.review_events where user_id::text like 'b100%'),'algorithm metadata recorded');
select review_test.ok((select correct_count=1 and incorrect_count=1 and review_count=2 from public.user_learning_items where user_id='b1000000-0000-4000-8000-000000000001'),'exact correctness counters');
select review_test.ok(not has_table_privilege('authenticated','public.user_learning_items','UPDATE') and not has_table_privilege('authenticated','public.review_events','INSERT'),'no direct client writes introduced');
select review_test.ok(not has_function_privilege('anon','public.submit_review(jsonb)','EXECUTE') and not has_function_privilege('service_role','public.submit_review(jsonb)','EXECUTE'),'anon/backend roles lack RPC grant');
select review_test.ok(not has_function_privilege('authenticated','private.schedule_review(public.user_learning_items,integer,timestamptz)','EXECUTE'),'client cannot submit derived card to private scheduler');
select review_test.ok((select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.submit_review(jsonb)'::regprocedure),'RPC definer has fixed empty search path');
update public.vocabulary set is_active=false where id='b3000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
select review_test.ok((select public.submit_review(request)=response from review_test.saved),'replay survives content retirement');
select review_test.ok(public.submit_review(review_test.request(3))->>'code'='NOT_FOUND','retired curriculum blocks new event');
reset role;
update public.vocabulary set is_active=true where id='b3000000-0000-4000-8000-000000000001';
update public.user_learning_items set stability=9,retrievability=0.4 where user_id='b1000000-0000-4000-8000-000000000001';
-- Force a failure *after state update*; public wrapper must roll everything back.
create function review_test.fail_event() returns trigger language plpgsql as $$
begin raise exception 'PRIVATE SQL DETAIL: never expose me' using errcode='23514'; end $$;
create trigger injected_failure before insert on public.review_events for each row execute function review_test.fail_event();
set local role authenticated;
select review_test.ok(public.submit_review(review_test.request(3))->>'code'='INTERNAL_ERROR','injected post-update failure is safe');
select review_test.ok(public.submit_review(review_test.request(3))::text not like '%PRIVATE SQL DETAIL%','SQL exception details are not returned');
select review_test.ok(public.submit_review(review_test.request(3)||'{"item_id":"b3000000-0000-4000-8000-000000000002"}')->>'code'='INTERNAL_ERROR','new item failure after scheduling is safe');
select review_test.ok((select count(*)=0 from public.user_learning_items where item_id='b3000000-0000-4000-8000-000000000002'),'failed event rolls back newly created learning item');
select review_test.ok((select review_count=2 and stability=9 and retrievability=0.4 from public.user_learning_items where item_id='b3000000-0000-4000-8000-000000000001'),'failed event rolls back counters and preserves reserved memory fields');
select review_test.ok((select count(*)=0 from public.review_events where client_event_id='b2000000-0000-4000-8000-000000000003'),'failed transaction has no orphan event');
reset role;
drop trigger injected_failure on public.review_events;
set local role authenticated;
select review_test.ok(public.submit_review(review_test.request(3))->>'review_count'='3','same immutable retry works after rolled-back error');
select review_test.ok(public.submit_review(review_test.request(90)||jsonb_build_object('occurred_at',repeat('1',4097)))->>'code'='VALIDATION_FAILURE','timestamp resource limit fails before parse');
select review_test.ok(public.submit_review(review_test.request(99)||'{"item_id":"b3000000-0000-4000-8000-000000000002","occurred_at":"2000-01-01T00:00:00.1234567Z"}')->>'review_count'='1','raw fractional event is stored');
select review_test.ok(public.submit_review(review_test.request(100)||'{"item_id":"b3000000-0000-4000-8000-000000000002","occurred_at":"2000-01-01T00:00:00.1234566Z"}')->>'code'='SYNC_CONFLICT','sub-microsecond stale event is rejected');
select review_test.ok(public.submit_review(review_test.request(99)||'{"item_id":"b3000000-0000-4000-8000-000000000002","occurred_at":"2000-01-01T00:00:00.1234568Z"}')->>'code'='SYNC_CONFLICT','changed fractional retry conflicts');
select review_test.ok(public.submit_review(review_test.request(101)||'{"item_id":"b3000000-0000-4000-8000-000000000002","occurred_at":"2000-01-01T00:00:00.1234568Z"}')->>'review_count'='2','newer exact fractional event is accepted');
select review_test.ok(public.submit_review(review_test.request(102)||'{"item_id":"b3000000-0000-4000-8000-000000000002","occurred_at":"2000-01-01T00:00:00.1234567Z"}')->>'code'='SYNC_CONFLICT','exact chronology follows most recent metadata count');
select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000099',true);
select review_test.ok(public.submit_review(review_test.request(1))->>'code'='UNAUTHORIZED','unknown account identity cannot write');
reset role;
-- Exact canonical equivalence; no collapse of differing sub-microsecond events.
select review_test.ok(private.review_request(review_test.request(99)||'{"occurred_at":"2026-01-01T07:00:00.123456700+07:00"}')=
 private.review_request(review_test.request(99)||'{"occurred_at":"2026-01-01T00:00:00.1234567Z"}'),'offset/trailing-zero normalization preserves exact instant');
select review_test.ok(private.review_request(review_test.request(99)||'{"occurred_at":"2026-01-01T00:00:00.1234567Z"}')<>
 private.review_request(review_test.request(99)||'{"occurred_at":"2026-01-01T00:00:00.1234568Z"}'),'sub-microsecond changed input does not collapse');
select review_test.ok(private.review_instant('2026-01-02T00:00:00+23:59')->>'wire'='2026-01-01T00:01:00Z','large valid wire timezone offset supported');
select review_test.ok(private.review_instant('2026-01-01T00:00:00.1234569Z')->>'instant'='2026-01-01T00:00:00.123456Z','scheduler precision truncates rather than rounding');
-- Corrupt pre-existing trusted receipt must never leak extra fields as a success.
insert into public.review_events(user_id,learning_item_id,rating,response_ms,is_correct,occurred_at,client_event_id,request_json,result_json)
 select user_id,id,2,100,true,current_timestamp-interval '1 day',
   'b2000000-0000-4000-8000-000000000700',private.review_request(review_test.request(700)),
   '{"unexpected_private_field":"secret-test-fixture"}'::jsonb
 from public.user_learning_items where user_id='b1000000-0000-4000-8000-000000000001' and item_id='b3000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
select review_test.ok(public.submit_review(review_test.request(700))->>'code'='INTERNAL_ERROR','corrupt original response fails closed');
select review_test.ok(public.submit_review(review_test.request(700))::text not like '%secret-test-fixture%','corrupt receipt cannot leak private output fields');
reset role;
rollback;
