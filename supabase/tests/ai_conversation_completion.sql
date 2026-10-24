-- Disposable SQL roles and fixed model fixtures, never hosted Auth/provider proof.
begin;
create schema completion_test;
create function completion_test.ok(value boolean,label text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',label; end if;
raise notice 'PASS COMPLETION: %',label; end $$;
create function completion_test.reject(statement text,code text,label text) returns void language plpgsql as $$
declare got text; begin
begin execute statement; exception when others then get stacked diagnostics got=returned_sqlstate; end;
perform completion_test.ok(got=code,label||' got '||coalesce(got,'SUCCESS')); end $$;
create table completion_test.calls(label text primary key,op text,request jsonb,claim jsonb,response jsonb);
create function completion_test.add(label text,op text,req jsonb) returns void language plpgsql as $$
declare claim jsonb; response jsonb; begin
claim:=private.ai_conversation_reserve('e1000000-0000-4000-8000-000000000001',op,req);
if op='finish_conversation' then
 response:='{"scores":{"grammar":85.5,"vocabulary":90,"fluency":75},"errors":[],"strengths_vi":["Rõ ràng"],"focus_next_vi":[],"srs_recommendations":[]}';
else
 response:=jsonb_build_object('assistant_message',jsonb_build_object('id',claim->'context'->'messageId','role','assistant',
 'text_ja','こんにちは','text_vi',null,'audio_ref',null,'sequence_no',claim->'context'->'sequenceNo'));
 if op='start_conversation' then response:=response||jsonb_build_object('session_id',claim->'context'->'sessionId'); end if;
end if;
insert into completion_test.calls values(label,op,req,claim,response); end $$;
create function completion_test.complete(label text) returns jsonb language sql as $$
 select private.ai_conversation_complete('e1000000-0000-4000-8000-000000000001',op,request,(claim->>'token')::uuid,response)
 from completion_test.calls c where c.label=complete.label $$;
create function completion_test.state() returns jsonb language sql stable as $$
 select jsonb_build_array((select count(*) from public.conversation_sessions),(select count(*) from public.conversation_messages),
 (select count(*) from public.operation_receipts where status='COMPLETED'),(select count(*) from private.ai_conversation_reservations where is_completed)) $$;
grant usage on schema completion_test to anon,authenticated,service_role;
grant all on completion_test.calls to service_role;
grant execute on all functions in schema completion_test to anon,authenticated,service_role;
insert into auth.users values('e1000000-0000-4000-8000-000000000001'),('e1000000-0000-4000-8000-000000000002');
insert into public.profiles(id) values('e1000000-0000-4000-8000-000000000001'),('e1000000-0000-4000-8000-000000000002');
insert into public.conversation_scenarios(id,jlpt_level,difficulty,content_version,is_active,title_vi,title_ja,description_vi,system_context)
 values('e2000000-0000-4000-8000-000000000001','N5',0,1,true,'fixture','会話','fixture','固定文脈');
insert into public.grammar(id,jlpt_level,difficulty,content_version,is_active,title,pattern,meaning_vi,explanation_vi)
 values('e3000000-0000-4000-8000-000000000001','N5',0,1,true,'文法','です','nghĩa','giải thích');
insert into public.scenario_grammar(scenario_id,grammar_id) values('e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001');
select completion_test.ok((select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='private.ai_conversation_complete(uuid,text,jsonb,uuid,jsonb)'::regprocedure),'narrow definer fixed empty search path');
select completion_test.ok(not exists(select 1 from pg_proc p,lateral aclexplode(p.proacl) a where p.oid in
 ('private.ai_conversation_complete(uuid,text,jsonb,uuid,jsonb)'::regprocedure,'private.validate_ai_conversation_response(text,jsonb,jsonb)'::regprocedure)
 and a.grantee=0 and a.privilege_type='EXECUTE'),'PUBLIC cannot execute either new helper');
set local role service_role;
select completion_test.add('start','start_conversation','{"scenario_id":"e2000000-0000-4000-8000-000000000001","jlpt_level":"N5","client_event_id":"e4000000-0000-4000-8000-000000000001"}');
select completion_test.ok((select response->'assistant_message'->>'sequence_no'='0' from completion_test.calls where label='start'),'fixture uses original reserved identity sequence');
select completion_test.reject($s$select private.ai_conversation_complete('e1000000-0000-4000-8000-000000000002',op,request,(claim->>'token')::uuid,response) from completion_test.calls where label='start'$s$,'P0002','owner B cannot use owner A capability');
select completion_test.reject($s$select private.ai_conversation_complete('e1000000-0000-4000-8000-000000000001',op,request,null,response) from completion_test.calls where label='start'$s$,'42501','null token denied');
select completion_test.reject($s$select private.ai_conversation_complete('e1000000-0000-4000-8000-000000000001',op,request,gen_random_uuid(),response) from completion_test.calls where label='start'$s$,'42501','wrong token denied');
select completion_test.reject($s$select private.ai_conversation_complete('e1000000-0000-4000-8000-000000000001',op,request||'{"jlpt_level":"N4"}',(claim->>'token')::uuid,response) from completion_test.calls where label='start'$s$,'P0001','changed request denied before public write');
do $$ declare bad jsonb; before jsonb:=completion_test.state(); c completion_test.calls%rowtype; begin
select * into c from completion_test.calls where label='start';
for bad in select v from jsonb_array_elements(jsonb_build_array(null,'[]'::jsonb,'{}'::jsonb,c.response-'session_id',
 c.response||'{"extra":true}',jsonb_set(c.response,'{session_id}',to_jsonb(gen_random_uuid())),
 jsonb_set(c.response,'{assistant_message,id}',to_jsonb(gen_random_uuid())),jsonb_set(c.response,'{assistant_message,role}','"user"'),
 jsonb_set(c.response,'{assistant_message,sequence_no}','1'),jsonb_set(c.response,'{assistant_message,audio_ref}','"untrusted"'),
 jsonb_set(c.response,'{assistant_message,text_ja}','null'),jsonb_set(c.response,'{assistant_message,text_ja}','""'),
 jsonb_set(c.response,'{assistant_message,text_vi}','5'),jsonb_set(c.response,'{assistant_message,text_vi}','""'),
 jsonb_set(c.response,'{assistant_message,text_ja}',to_jsonb(repeat('文',5001))),
 jsonb_set(c.response,'{assistant_message,text_vi}',to_jsonb(repeat('v',5001))),
 jsonb_set(c.response,'{assistant_message}',(c.response->'assistant_message')-'text_vi'),
 jsonb_set(c.response,'{assistant_message}',c.response->'assistant_message'||'{"owner":"forged"}'))) v loop
 perform completion_test.reject(format('select private.ai_conversation_complete(%L,%L,%L::jsonb,%L,%L::jsonb)',
 'e1000000-0000-4000-8000-000000000001',c.op,c.request,c.claim->>'token',bad),'22023','strict start response shape identity audio bounds');
end loop;
perform completion_test.ok(before=completion_test.state(),'every rejected start leaves session messages receipt release unchanged'); end $$;
select completion_test.ok(completion_test.complete('start')=(select response from completion_test.calls where label='start'),'start returns original validated response');
select completion_test.ok((select s.user_id='e1000000-0000-4000-8000-000000000001' and s.jlpt_level='N5' and s.started_at=r.created_at and s.ended_at is null
 from public.conversation_sessions s join private.ai_conversation_reservations r on r.session_id=s.id join completion_test.calls c on c.claim->'context'->>'sessionId'=s.id::text where c.label='start'),'start session owner level and server reservation clock persisted');
select completion_test.ok((select m.id=r.assistant_message_id and m.role='assistant' and m.sequence_no=0 and m.text_vi is null and m.audio_ref is null
 from public.conversation_messages m join private.ai_conversation_reservations r on r.session_id=m.conversation_session_id join completion_test.calls c on c.claim->'context'->>'sessionId'=r.session_id::text where c.label='start'),'only reserved assistant zero persisted');
select completion_test.ok((select o.status='COMPLETED' and o.response_json=c.response and r.is_completed from completion_test.calls c join public.operation_receipts o on o.client_event_id=(c.request->>'client_event_id')::uuid join private.ai_conversation_reservations r on r.receipt_id=o.id where c.label='start'),'same transaction completes receipt and releases guard');
select completion_test.add('turn','conversation_turn',jsonb_build_object('session_id',claim->'context'->'sessionId','client_event_id','e4000000-0000-4000-8000-000000000002','text_ja','猫です')) from completion_test.calls where label='start';
-- Model feedback uses only captured typed refs; it cannot authorize new learning writes.
update completion_test.calls set response=response||jsonb_build_object('live_feedback',jsonb_build_array(jsonb_build_object(
 'original_text','猫','corrected_text','猫です','explanation_vi','Lịch sự','item_refs',claim->'context'->'allowedRefs'))) where label='turn';
do $$ declare bad jsonb; before jsonb:=completion_test.state(); c completion_test.calls%rowtype; begin
select * into c from completion_test.calls where label='turn';
for bad in select v from jsonb_array_elements(jsonb_build_array(c.response||'{"live_feedback":null}',
 c.response||'{"live_feedback":[null]}',c.response||'{"live_feedback":[{}]}',
 jsonb_set(c.response,'{live_feedback,0,original_text}','""'),jsonb_set(c.response,'{live_feedback,0,corrected_text}','null'),
 jsonb_set(c.response,'{live_feedback,0,explanation_vi}',to_jsonb(repeat('v',2001))),
 jsonb_set(c.response,'{live_feedback,0,item_refs}','null'),jsonb_set(c.response,'{live_feedback,0,item_refs}','[{}]'),
 jsonb_set(c.response,'{live_feedback,0,item_refs}','[{"item_type":"GRAMMAR","item_id":"bad"}]'),
 jsonb_set(c.response,'{live_feedback,0,item_refs}','[{"item_type":"GRAMMAR","item_id":"e3000000-0000-4000-8000-000000000001","extra":1}]'),
 jsonb_set(c.response,'{live_feedback,0}',c.response->'live_feedback'->0||'{"role":"user"}'),
 jsonb_set(c.response,'{live_feedback}',(select jsonb_agg(c.response->'live_feedback'->0) from generate_series(1,101))))) v loop
 perform completion_test.reject(format('select private.ai_conversation_complete(%L,%L,%L::jsonb,%L,%L::jsonb)',
 'e1000000-0000-4000-8000-000000000001',c.op,c.request,c.claim->>'token',bad),'22023','strict turn correction and ref shapes'); end loop;
perform completion_test.ok(before=completion_test.state(),'malformed turns never persist even the user message'); end $$;
select completion_test.reject($s$select private.ai_conversation_complete('e1000000-0000-4000-8000-000000000001',op,request,(claim->>'token')::uuid,
 jsonb_set(response,'{live_feedback,0,item_refs}','[{"item_type":"KANJI","item_id":"e3000000-0000-4000-8000-000000000001"}]')) from completion_test.calls where label='turn'$s$,'42501','wrong typed reference cannot escape captured allowlist');
select completion_test.reject($s$update private.ai_conversation_reservations set is_completed=true$s$,'42501','service still cannot directly release any reservation');
reset role;
-- Actual storage faults, raised AFTER some public writes, must roll back everything.
create function completion_test.fail() returns trigger language plpgsql as $$ begin raise exception 'TEST_ONLY_STORAGE_FAILURE' using errcode='40001'; end $$;
create trigger completion_fail before insert on public.conversation_messages for each row when(new.role='assistant' and new.sequence_no=2) execute function completion_test.fail();
set local role service_role;
do $$ declare before jsonb:=completion_test.state(); begin
perform completion_test.reject('select completion_test.complete(''turn'')','40001','assistant storage failure after user insert');
perform completion_test.ok(before=completion_test.state(),'assistant fault rolls back user insert and receipt release'); end $$;
reset role;
drop trigger completion_fail on public.conversation_messages;
create trigger completion_fail before update on public.operation_receipts for each row execute function completion_test.fail();
set local role service_role;
do $$ declare before jsonb:=completion_test.state(); begin
perform completion_test.reject('select completion_test.complete(''turn'')','40001','receipt storage failure after both messages');
perform completion_test.ok(before=completion_test.state(),'receipt fault rolls back both messages and release'); end $$;
reset role;
drop trigger completion_fail on public.operation_receipts;
create trigger completion_fail before update on private.ai_conversation_reservations for each row execute function completion_test.fail();
set local role service_role;
do $$ declare before jsonb:=completion_test.state(); begin
perform completion_test.reject('select completion_test.complete(''turn'')','40001','release storage failure after receipt');
perform completion_test.ok(before=completion_test.state(),'release fault rolls back messages and completed receipt'); end $$;
reset role;
drop trigger completion_fail on private.ai_conversation_reservations;
-- Recheck exact captured source, never silently replace the provider's context.
update public.grammar set content_version=2 where id='e3000000-0000-4000-8000-000000000001';
set local role service_role;
select completion_test.reject('select completion_test.complete(''turn'')','P0001','target version drift rejected');
reset role;
update public.grammar set content_version=1,is_active=false where id='e3000000-0000-4000-8000-000000000001';
set local role service_role;
select completion_test.reject('select completion_test.complete(''turn'')','P0002','retired linked curriculum rejected');
reset role;
update public.grammar set is_active=true where id='e3000000-0000-4000-8000-000000000001';
update public.profiles set preferred_jlpt='N4' where id='e1000000-0000-4000-8000-000000000001';
set local role service_role;
select completion_test.reject('select completion_test.complete(''turn'')','42501','changed profile level rejected');
reset role;
update public.profiles set preferred_jlpt='N5' where id='e1000000-0000-4000-8000-000000000001';
update public.conversation_messages set text_ja='変更' where conversation_session_id=(select (claim->'context'->>'sessionId')::uuid from completion_test.calls where label='start');
set local role service_role;
select completion_test.reject('select completion_test.complete(''turn'')','P0001','transcript drift rejected');
reset role;
update public.conversation_messages set text_ja='こんにちは' where conversation_session_id=(select (claim->'context'->>'sessionId')::uuid from completion_test.calls where label='start');
set local role service_role;
select completion_test.ok(completion_test.complete('turn')=(select response from completion_test.calls where label='turn'),'turn persists and returns original bounded feedback');
select completion_test.ok((select count(*)=3 and string_agg(role,',' order by sequence_no)='assistant,user,assistant'
 from public.conversation_messages where conversation_session_id=(select (claim->'context'->>'sessionId')::uuid from completion_test.calls where label='turn')),'turn appends exactly one alternating pair');
select completion_test.ok((select m.id=r.user_message_id and m.text_ja=c.request->>'text_ja' and m.sequence_no=r.user_sequence_no and m.text_vi is null and m.audio_ref is null
 from completion_test.calls c join private.ai_conversation_reservations r on r.assistant_message_id=(c.claim->'context'->>'messageId')::uuid join public.conversation_messages m on m.id=r.user_message_id where c.label='turn'),'user message identity sequence exact input never model supplied');
select completion_test.add('finish','finish_conversation',jsonb_build_object('session_id',claim->'context'->'sessionId','client_event_id','e4000000-0000-4000-8000-000000000003')) from completion_test.calls where label='start';
update completion_test.calls set response=jsonb_set(response,'{srs_recommendations}',claim->'context'->'allowedRefs') where label='finish';
do $$ declare bad jsonb; before jsonb:=completion_test.state(); c completion_test.calls%rowtype; begin
select * into c from completion_test.calls where label='finish';
for bad in select v from jsonb_array_elements(jsonb_build_array(c.response-'scores',c.response||'{"extra":1}',c.response||'{"scores":null}',
 jsonb_set(c.response,'{scores}','{}'),jsonb_set(c.response,'{scores,grammar}','null'),jsonb_set(c.response,'{scores,grammar}','"85"'),
 jsonb_set(c.response,'{scores,grammar}','-1'),jsonb_set(c.response,'{scores,vocabulary}','101'),jsonb_set(c.response,'{scores,extra}','0'),
 jsonb_set(c.response,'{errors}','null'),jsonb_set(c.response,'{strengths_vi}','[null]'),jsonb_set(c.response,'{strengths_vi}','[""]'),
 jsonb_set(c.response,'{focus_next_vi}',jsonb_build_array(repeat('v',2001))),jsonb_set(c.response,'{focus_next_vi}','{}'),
 jsonb_set(c.response,'{srs_recommendations}','null'),jsonb_set(c.response,'{srs_recommendations}','[{}]'),
 jsonb_set(c.response,'{strengths_vi}',(select jsonb_agg('v'::text) from generate_series(1,101))),
 jsonb_set(c.response,'{srs_recommendations}',(select jsonb_agg(c.claim->'context'->'allowedRefs'->0) from generate_series(1,101)))) ) v loop
 perform completion_test.reject(format('select private.ai_conversation_complete(%L,%L,%L::jsonb,%L,%L::jsonb)',
 'e1000000-0000-4000-8000-000000000001',c.op,c.request,c.claim->>'token',bad),'22023','strict finish scores arrays refs and bounds'); end loop;
perform completion_test.ok(before=completion_test.state(),'invalid finish never closes session completes receipt or releases guard'); end $$;
reset role;
create trigger completion_fail before update on public.operation_receipts for each row execute function completion_test.fail();
set local role service_role;
select completion_test.reject('select completion_test.complete(''finish'')','40001','finish receipt failure after session close');
select completion_test.ok((select s.ended_at is null and s.score_json is null and s.summary_json is null and o.status='PENDING' and not r.is_completed
 from completion_test.calls c join public.operation_receipts o on o.client_event_id=(c.request->>'client_event_id')::uuid
 join private.ai_conversation_reservations r on r.receipt_id=o.id join public.conversation_sessions s on s.id=r.session_id where c.label='finish'),'failed finish rolls back closure scores summary receipt and release');
reset role;
drop trigger completion_fail on public.operation_receipts;
set local role service_role;
select completion_test.ok(completion_test.complete('finish')=(select response from completion_test.calls where label='finish'),'finish returns original scores and recommendations');
select completion_test.ok((select s.ended_at>=s.started_at and isfinite(s.ended_at) and s.score_json=c.response->'scores' and s.summary_json=c.response-'scores'
 from completion_test.calls c join public.conversation_sessions s on s.id=(c.request->>'session_id')::uuid where c.label='finish'),'finish saves server close clock scores and exact summary');
select completion_test.ok((select count(*)=0 from public.learning_errors where user_id='e1000000-0000-4000-8000-000000000001')
 and (select count(*)=0 from public.user_learning_items where user_id='e1000000-0000-4000-8000-000000000001'),'model feedback never writes learning errors or SRS state');
reset role;
update public.profiles set preferred_jlpt='N4' where id='e1000000-0000-4000-8000-000000000001';
update public.conversation_scenarios set is_active=false where id='e2000000-0000-4000-8000-000000000001';
set local role service_role;
do $$ declare before jsonb:=completion_test.state(); c completion_test.calls%rowtype; begin
for c in select * from completion_test.calls loop
 perform completion_test.ok(completion_test.complete(c.label)=c.response,'original completed replay after closure retirement and profile change '||c.label);
 perform completion_test.ok(private.ai_conversation_reserve('e1000000-0000-4000-8000-000000000001',c.op,c.request)=jsonb_build_object('kind','completed','response',c.response),'restart reserve returns original response without new capability '||c.label);
end loop;
perform completion_test.ok(before=completion_test.state(),'all completed replays are exactly once no duplicate public writes'); end $$;
select completion_test.reject($s$select private.ai_conversation_complete('e1000000-0000-4000-8000-000000000001',op,request,(claim->>'token')::uuid,response||'{"changed":true}') from completion_test.calls where label='finish'$s$,'P0001','completed changed response conflicts');
select completion_test.reject($s$select private.ai_conversation_complete('e1000000-0000-4000-8000-000000000001',op,request,gen_random_uuid(),response) from completion_test.calls where label='finish'$s$,'42501','completed replay still requires original token');
reset role;
update public.profiles set preferred_jlpt='N5' where id='e1000000-0000-4000-8000-000000000001';
update public.conversation_scenarios set is_active=true where id='e2000000-0000-4000-8000-000000000001';
set local role service_role;
select completion_test.add('failed-start','start_conversation','{"scenario_id":"e2000000-0000-4000-8000-000000000001","jlpt_level":"N5","client_event_id":"e4000000-0000-4000-8000-000000000004"}');
reset role;
create trigger completion_fail before update on private.ai_conversation_reservations for each row execute function completion_test.fail();
set local role service_role;
select completion_test.reject('select completion_test.complete(''failed-start'')','40001','start release failure after session assistant and receipt writes');
select completion_test.ok((select not exists(select 1 from public.conversation_sessions s where s.id=(c.claim->'context'->>'sessionId')::uuid)
 and o.status='PENDING' and not r.is_completed from completion_test.calls c join public.operation_receipts o on o.client_event_id=(c.request->>'client_event_id')::uuid
 join private.ai_conversation_reservations r on r.receipt_id=o.id where c.label='failed-start'),'failed start leaves no session orphan and retains pending claim');
reset role;
drop trigger completion_fail on private.ai_conversation_reservations;
set local role service_role;
-- A legacy bare receipt completion is insufficient evidence to release anything.
select private.ai_receipt_complete('e1000000-0000-4000-8000-000000000001',op,request,(claim->>'token')::uuid,response) is not null from completion_test.calls where label='failed-start';
select completion_test.reject('select completion_test.complete(''failed-start'')','P0001','legacy bare completion cannot heal or release missing public writes');
select completion_test.ok((select not r.is_completed and not exists(select 1 from public.conversation_sessions s where s.id=r.session_id)
 from private.ai_conversation_reservations r join completion_test.calls c on c.claim->'context'->>'sessionId'=r.session_id::text where c.label='failed-start'),'legacy bare receipt leaves conservative pending reservation');
set local role anon;
select completion_test.reject($s$select private.ai_conversation_complete(null,null,null,null,null)$s$,'42501','anonymous completion denied');
select completion_test.reject($s$select private.validate_ai_conversation_response(null,null,null)$s$,'42501','anonymous output helper denied');
set local role authenticated;
select completion_test.reject($s$select private.ai_conversation_complete(null,null,null,null,null)$s$,'42501','learner completion denied');
select completion_test.reject($s$select private.validate_ai_conversation_response(null,null,null)$s$,'42501','learner output helper denied');
reset role;
rollback;
