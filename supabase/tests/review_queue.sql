-- TEST ONLY Auth/roles/curriculum, in a disposable database. Entire fixture rolls back.
begin;
create schema queue_test;
create function queue_test.ok(value boolean,label text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',label; end if;
raise notice 'PASS: %',label; end $$;
grant usage on schema queue_test to authenticated;
grant execute on function queue_test.ok(boolean,text) to authenticated;
create table queue_test.results(name text primary key,request jsonb,response jsonb);
grant select,insert on queue_test.results to authenticated;
insert into auth.users values ('d1000000-0000-4000-8000-000000000001'),
 ('d1000000-0000-4000-8000-000000000002'),('d1000000-0000-4000-8000-000000000003');
insert into public.profiles(id) select id from auth.users where id::text like 'd100%';
insert into public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,expression,reading,meaning_vi,part_of_speech,usage_context_vi)
select ('d3000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 case when i=3 then 'N4'::public.jlpt_level else 'N5'::public.jlpt_level end,
 0.1,1,i<>4,case when i=1 then '猫' else '犬' end,
 case when i=1 then 'ねこ' else 'いぬ' end,'nghĩa kiểm thử','noun','TEST ONLY'
from generate_series(1,6) i;
insert into public.kanji(id,jlpt_level,difficulty,content_version,is_active,character,meaning_vi,onyomi,kunyomi,stroke_count)
 values('d5000000-0000-4000-8000-000000000001','N5',0.1,1,true,'日','ngày',array['ニチ'],array['ひ'],4);
insert into public.grammar(id,jlpt_level,difficulty,content_version,is_active,title,pattern,meaning_vi,explanation_vi)
 values('d4000000-0000-4000-8000-000000000001','N5',0.1,1,true,'TEST ONLY','～です','là','TEST ONLY');
insert into public.user_learning_items(user_id,item_type,item_id,srs_state,last_review_at,next_review_at,interval_days,review_count,correct_count)
 select 'd1000000-0000-4000-8000-000000000001','VOCABULARY',id,'REVIEW','2010-01-01T00:00:00Z'::timestamptz,
 case when right(id::text,1)='1' then '2020-01-01T00:00:00Z'::timestamptz
      when right(id::text,1)='2' then '2020-01-03T00:00:00Z'::timestamptz
      when right(id::text,1)='5' then current_timestamp+interval '1 day'
      else '2019-01-01T00:00:00Z'::timestamptz end,10,1,1
from public.vocabulary where id::text like 'd300%' and right(id::text,1)<>'6';
insert into public.user_learning_items(user_id,item_type,item_id)
 values('d1000000-0000-4000-8000-000000000001','VOCABULARY','d3000000-0000-4000-8000-000000000006');
insert into public.user_learning_items(user_id,item_type,item_id,srs_state,last_review_at,next_review_at,interval_days,review_count,correct_count)
 values('d1000000-0000-4000-8000-000000000001','GRAMMAR','d4000000-0000-4000-8000-000000000001','LEARNING','2010-01-01T00:00:00Z','2020-01-02T00:00:00Z',10,1,1),
 ('d1000000-0000-4000-8000-000000000001','KANJI','d5000000-0000-4000-8000-000000000001','RELEARNING','2010-01-01T00:00:00Z','2020-01-02T00:00:00Z',10,1,1),
 ('d1000000-0000-4000-8000-000000000002','VOCABULARY','d3000000-0000-4000-8000-000000000001','REVIEW','2010-01-01T00:00:00Z','2018-01-01T00:00:00Z',10,1,1);
select queue_test.ok((select not prosecdef and provolatile='s' and proconfig @> array['search_path=""'] from pg_proc where oid='public.get_review_queue(jsonb)'::regprocedure),'queue is stable invoker with empty search path');
select queue_test.ok(has_function_privilege('authenticated','public.get_review_queue(jsonb)','EXECUTE') and
 not has_function_privilege('anon','public.get_review_queue(jsonb)','EXECUTE') and
 not has_function_privilege('service_role','public.get_review_queue(jsonb)','EXECUTE'),'queue EXECUTE only authenticated');
select queue_test.ok(not has_table_privilege('authenticated','public.user_learning_items','UPDATE') and
 not has_table_privilege('authenticated','public.review_events','INSERT'),'queue introduces no direct write privilege');
set local role authenticated;
select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000001',true);
insert into queue_test.results values('A_N5','{"jlpt_level":"N5","limit":100}',public.get_review_queue('{"jlpt_level":"N5","limit":100}'));
insert into queue_test.results values('A_LIMIT2','{"jlpt_level":"N5","limit":2}',public.get_review_queue('{"jlpt_level":"N5","limit":2}'));
insert into queue_test.results values('A_N4','{"jlpt_level":"N4","limit":100}',public.get_review_queue('{"jlpt_level":"N4","limit":100}'));
select queue_test.ok((select jsonb_array_length(response->'items')=4 from queue_test.results where name='A_N5'),'A receives four active own due N5 items, not future NEW retired N4 or B');
select queue_test.ok((select response->'items'->0->>'item_id'='d3000000-0000-4000-8000-000000000001' and
 response->'items'->1->>'item_type'='GRAMMAR' and response->'items'->2->>'item_type'='KANJI' and
 response->'items'->3->>'item_id'='d3000000-0000-4000-8000-000000000002' from queue_test.results where name='A_N5'),'queue order is due time then type then UUID');
select queue_test.ok((select response->'items'->1->>'reading_ja'='' from queue_test.results where name='A_N5'),'grammar missing canonical reading is explicit empty, not invented');
select queue_test.ok((select response->'items'->2->>'reading_ja'='ニチ・ひ' from queue_test.results where name='A_N5'),'Kanji readings come from published arrays');
select queue_test.ok((select jsonb_array_length(response->'items')=2 from queue_test.results where name='A_LIMIT2'),'queue honors bounded limit after active filtering');
select queue_test.ok((select jsonb_array_length(response->'items')=1 and response->'items'->0->>'item_id'='d3000000-0000-4000-8000-000000000003' from queue_test.results where name='A_N4'),'queue filters N4 independently');
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N3","limit":100}')->'items'='[]','N3 enum remains supported');
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N2","limit":100}')->'items'='[]','N2 enum remains supported');
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N1","limit":100}')->'items'='[]','N1 enum remains supported');
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N5","limit":0}')->>'code'='VALIDATION_FAILURE','zero limit rejected');
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N5","limit":101}')->>'code'='VALIDATION_FAILURE','excess limit rejected');
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N5","limit":1.5}')->>'code'='VALIDATION_FAILURE','fractional limit rejected');
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N5","limit":"2"}')->>'code'='VALIDATION_FAILURE','string limit rejected');
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N5","limit":true}')->>'code'='VALIDATION_FAILURE','boolean limit rejected');
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N5","limit":null}')->>'code'='VALIDATION_FAILURE','null limit rejected');
select queue_test.ok(jsonb_array_length(public.get_review_queue('{"jlpt_level":"N5","limit":2.0}')->'items')=2,'integer-valued JSON limit accepted');
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N6","limit":2}')->>'code'='VALIDATION_FAILURE','unknown level rejected');
select queue_test.ok(public.get_review_queue('{"limit":2}')->>'code'='VALIDATION_FAILURE','missing level rejected');
select queue_test.ok(public.get_review_queue('[]')->>'code'='VALIDATION_FAILURE','array request rejected');
select queue_test.ok(public.get_review_queue(null)->>'code'='VALIDATION_FAILURE','SQL null request rejected');
select queue_test.ok(public.get_review_queue('null')->>'code'='VALIDATION_FAILURE','JSON null request rejected');
select queue_test.ok(public.get_review_queue(jsonb_build_object('jlpt_level',repeat('N',40000),'limit',2))->>'code'='VALIDATION_FAILURE','oversized parsed request rejected');
insert into queue_test.results values('FORGED_OWNER','{"jlpt_level":"N5","limit":100,"user_id":"d1000000-0000-4000-8000-000000000002"}',public.get_review_queue('{"jlpt_level":"N5","limit":100,"user_id":"d1000000-0000-4000-8000-000000000002"}'));
select queue_test.ok((select response->>'code'='VALIDATION_FAILURE' from queue_test.results where name='FORGED_OWNER'),'forged owner is not a queue parameter');
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N5","limit":2,"server_time":"2099-01-01T00:00:00Z"}')->>'code'='VALIDATION_FAILURE','client clock rejected');
select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000002',true);
insert into queue_test.results values('B_N5','{"jlpt_level":"N5","limit":100}',public.get_review_queue('{"jlpt_level":"N5","limit":100}'));
select queue_test.ok((select jsonb_array_length(response->'items')=1 and response->'items'->0->>'next_review_at'='2018-01-01T00:00:00.000000Z' from queue_test.results where name='B_N5'),'B receives only B due history');
select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000003',true);
insert into queue_test.results values('C_EMPTY','{"jlpt_level":"N5","limit":100}',public.get_review_queue('{"jlpt_level":"N5","limit":100}'));
select queue_test.ok((select response->'items'='[]' from queue_test.results where name='C_EMPTY'),'valid fresh account has empty queue, not fake enrollment');
select set_config('request.jwt.claim.sub','',true);
insert into queue_test.results values('NO_AUTH','{"jlpt_level":"N5","limit":100}',public.get_review_queue('{"jlpt_level":"N5","limit":100}'));
select queue_test.ok((select response->>'code'='UNAUTHORIZED' from queue_test.results where name='NO_AUTH'),'missing identity fails closed');
select set_config('request.jwt.claim.sub','bad',true);
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N5","limit":100}')->>'code'='UNAUTHORIZED','malformed identity is safe');
select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000099',true);
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N5","limit":100}')->>'code'='UNAUTHORIZED','missing provisioned profile fails closed');
reset role;
select queue_test.ok((select count(*)=9 and sum(review_count)=8 from public.user_learning_items where user_id::text like 'd100%'),'queue reads preserve item counts and counters');
select queue_test.ok((select count(*)=0 from public.review_events where user_id::text like 'd100%'),'queue reads never append events');
update public.kanji set onyomi=array[repeat('x',5001)] where id='d5000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000001',true);
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N5","limit":100}')->>'code'='INTERNAL_ERROR','oversized trusted projection fails closed');
reset role;
update public.kanji set onyomi=array['ニチ'] where id='d5000000-0000-4000-8000-000000000001';
update public.user_learning_items set next_review_at='0001-01-01 00:00:00 BC'::timestamptz
 where user_id='d1000000-0000-4000-8000-000000000001' and item_type='VOCABULARY' and item_id='d3000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000001',true);
select queue_test.ok(public.get_review_queue('{"jlpt_level":"N5","limit":100}')->>'code'='INTERNAL_ERROR','BC trusted due dates cannot masquerade as AD wire dates');
reset role;
-- One marked JSON line consumed by exporter; responses come from actual SQL.
select 'QUEUE_WIRE:'||jsonb_agg(jsonb_build_object('name',name,'request',request,'response',response) order by name)::text from queue_test.results;
rollback;
