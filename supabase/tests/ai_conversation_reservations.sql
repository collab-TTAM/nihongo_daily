-- Disposable Auth/role/session fixtures; not hosted or completed conversation proof.
begin;
create schema reservation_test;
create function reservation_test.ok(value boolean,label text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',label; end if;
raise notice 'PASS RESERVATION: %',label; end $$;
create function reservation_test.reject(statement text,code text,label text) returns void language plpgsql as $$
declare got text; begin
begin execute statement; exception when others then get stacked diagnostics got=returned_sqlstate; end;
perform reservation_test.ok(got=code,label||' got '||coalesce(got,'SUCCESS')); end $$;
grant usage on schema reservation_test to anon,authenticated,service_role;
grant execute on all functions in schema reservation_test to anon,authenticated,service_role;
insert into auth.users values('d1000000-0000-4000-8000-000000000001'),('d1000000-0000-4000-8000-000000000002'),('d1000000-0000-4000-8000-000000000003');
insert into public.profiles(id,preferred_jlpt) values('d1000000-0000-4000-8000-000000000001','N5'),('d1000000-0000-4000-8000-000000000002','N4');
insert into public.grammar(id,jlpt_level,difficulty,content_version,is_active,title,pattern,meaning_vi,explanation_vi)
select ('d2000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 case when i=2 then 'N4'::public.jlpt_level else 'N5'::public.jlpt_level end,0.2,1,i<>3,'文法','～です','nghĩa','giải thích' from generate_series(1,3) i;
insert into public.conversation_scenarios(id,jlpt_level,difficulty,content_version,is_active,title_vi,title_ja,description_vi,system_context)
select ('d3000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 case when i=2 then 'N4'::public.jlpt_level else 'N5'::public.jlpt_level end,0.2,1,i<>3,'Tình huống','会話','mô tả','固定した文脈' from generate_series(1,3) i;
insert into public.scenario_grammar(scenario_id,grammar_id) values('d3000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001'),('d3000000-0000-4000-8000-000000000002','d2000000-0000-4000-8000-000000000002');
insert into public.conversation_sessions(id,user_id,scenario_id,jlpt_level,ended_at)
select ('d4000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 case when i=2 then 'd1000000-0000-4000-8000-000000000002'::uuid else 'd1000000-0000-4000-8000-000000000001'::uuid end,
 case when i=2 then 'd3000000-0000-4000-8000-000000000002'::uuid else 'd3000000-0000-4000-8000-000000000001'::uuid end,
 case when i=2 then 'N4'::public.jlpt_level else 'N5'::public.jlpt_level end,
 case when i=3 then now() else null end from generate_series(1,11) i;
insert into public.conversation_messages(conversation_session_id,role,text_ja,sequence_no)
select ('d4000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 case when i=5 then 'user' else 'assistant' end,case when i=6 then repeat('文',5001) else 'こんにちは' end,
 case when i=4 then 1 else 0 end from unnest(array[1,2,3,4,5,6,9,11]) i;
insert into public.conversation_messages(conversation_session_id,role,text_ja,sequence_no)
select 'd4000000-0000-4000-8000-000000000007',case when i%2=0 then 'assistant' else 'user' end,'文',i from generate_series(0,98) i;
insert into public.conversation_messages(conversation_session_id,role,text_ja,sequence_no)
select 'd4000000-0000-4000-8000-000000000010',case when i%2=0 then 'assistant' else 'user' end,repeat('文',5000),i from generate_series(0,10) i;
create table reservation_test.calls(op text,request jsonb,result jsonb);
grant all on reservation_test.calls to service_role;
insert into reservation_test.calls values
 ('start_conversation','{"scenario_id":"d3000000-0000-4000-8000-000000000001","jlpt_level":"N5","client_event_id":"d5000000-0000-4000-8000-000000000001"}',null),
 ('conversation_turn','{"session_id":"d4000000-0000-4000-8000-000000000001","text_ja":"猫です","client_event_id":"d5000000-0000-4000-8000-000000000002"}',null),
 ('finish_conversation','{"session_id":"d4000000-0000-4000-8000-000000000009","client_event_id":"d5000000-0000-4000-8000-000000000003"}',null);
create function reservation_test.counts() returns jsonb language sql stable as $$
 select jsonb_build_array((select count(*) from public.operation_receipts),(select count(*) from private.ai_receipt_claims),
 (select count(*) from private.ai_conversation_reservations)) $$;
grant execute on function reservation_test.counts() to service_role;
create table reservation_test.before_counts as select (select count(*) from public.conversation_sessions) as sessions,(select count(*) from public.conversation_messages) as messages;
grant select on reservation_test.before_counts to service_role;
select reservation_test.ok((select relrowsecurity from pg_class where oid='private.ai_conversation_reservations'::regclass),'private reservations RLS enabled');
select reservation_test.ok((select count(*)=3 and bool_and(not prosecdef and proconfig @> array['search_path=""']) from pg_proc where oid in
 ('private.validate_ai_conversation_request(uuid,text,jsonb)'::regprocedure,'private.ai_conversation_context(uuid,text,jsonb,uuid,uuid,integer)'::regprocedure,'private.ai_conversation_reserve(uuid,text,jsonb)'::regprocedure)),
 'all helpers invoker and empty fixed search path');
select reservation_test.ok(not exists(select 1 from pg_proc p,lateral aclexplode(p.proacl) a where p.oid in
 ('private.validate_ai_conversation_request(uuid,text,jsonb)'::regprocedure,'private.ai_conversation_context(uuid,text,jsonb,uuid,uuid,integer)'::regprocedure,'private.ai_conversation_reserve(uuid,text,jsonb)'::regprocedure)
 and a.grantee=0 and a.privilege_type='EXECUTE'),'PUBLIC execution absent');
set local role service_role;
update reservation_test.calls set result=private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001',op,request);
select reservation_test.ok((select bool_and(result->>'kind'='acquired' and result ? 'token' and result ? 'context') from reservation_test.calls),'all three operations acquire one context and dispatch token');
select reservation_test.ok((select result->'context'->>'sequenceNo'='0' and result->'context'->'transcript'='[]'
 and result->'context'->>'sessionId'<>request->>'scenario_id' from reservation_test.calls where op='start_conversation'),'start reserves server session assistant id and sequence zero');
select reservation_test.ok((select result->'context'->>'sequenceNo'='2' and jsonb_array_length(result->'context'->'transcript')=1
 and result->'context'->'allowedRefs'='[{"item_type":"GRAMMAR","item_id":"d2000000-0000-4000-8000-000000000001"}]' from reservation_test.calls where op='conversation_turn'),'turn captures owned transcript and active typed allowlist with next assistant sequence');
select reservation_test.ok((select r.user_message_id is not null and r.user_sequence_no=1 and r.assistant_sequence_no=2 and not r.is_completed
 from private.ai_conversation_reservations r join reservation_test.calls c on c.result->'context'->>'sessionId'=r.session_id::text where c.op='conversation_turn'),'user id and sequence reserved privately without message write');
select reservation_test.ok((select not (result->'context' ? 'messageId') and not (result->'context' ? 'sequenceNo') from reservation_test.calls where op='finish_conversation'),'finish has no fabricated assistant identity');
select reservation_test.ok((select sessions=(select count(*) from public.conversation_sessions) and messages=(select count(*) from public.conversation_messages) from reservation_test.before_counts),'reservation never creates public sessions messages or success responses');
select reservation_test.ok((select bool_and(private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001',op,request)='{"kind":"pending"}') from reservation_test.calls),'identical pending replay exposes neither token nor context');
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001',op,request||'{"text_ja":"変更"}') from reservation_test.calls where op='conversation_turn'$s$,'P0001','changed same event conflicts');
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001',op,jsonb_set(request,'{client_event_id}','"d5000000-0000-4000-8000-000000000099"')) from reservation_test.calls where op='conversation_turn'$s$,'P0001','distinct event cannot enter pending session');
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001','finish_conversation','{"session_id":"d4000000-0000-4000-8000-000000000001","client_event_id":"d5000000-0000-4000-8000-000000000098"}')$s$,'P0001','finish cannot overtake pending turn');
select reservation_test.ok((select count(*)=0 from public.operation_receipts where client_event_id in ('d5000000-0000-4000-8000-000000000099','d5000000-0000-4000-8000-000000000098')),'denied distinct events create no orphan receipt');
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000002',op,request) from reservation_test.calls where op='conversation_turn'$s$,'P0002','other-owner session hidden');
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000002',op,request) from reservation_test.calls where op='start_conversation'$s$,'42501','profile level override denied');
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000003',op,request) from reservation_test.calls where op='start_conversation'$s$,'P0002','unprovisioned profile not fabricated');
select reservation_test.ok(private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000002','conversation_turn',
 '{"session_id":"d4000000-0000-4000-8000-000000000002","text_ja":"文","client_event_id":"d5000000-0000-4000-8000-000000000002"}')->>'kind'='acquired','same event user B owns independent N4 session');
do $$ declare req jsonb; before jsonb:=reservation_test.counts(); begin
for req in select value from jsonb_array_elements('[null,[],{},
 {"session_id":null,"client_event_id":"d5000000-0000-4000-8000-000000000011","text_ja":"文"},
 {"session_id":"bad","client_event_id":"d5000000-0000-4000-8000-000000000011","text_ja":"文"},
 {"session_id":"d4000000-0000-4000-8000-000000000001","client_event_id":null,"text_ja":"文"},
 {"session_id":"d4000000-0000-4000-8000-000000000001","client_event_id":"bad","text_ja":"文"},
 {"session_id":"d4000000-0000-4000-8000-000000000001","client_event_id":"d5000000-0000-4000-8000-000000000011","text_ja":null},
 {"session_id":"d4000000-0000-4000-8000-000000000001","client_event_id":"d5000000-0000-4000-8000-000000000011","text_ja":""},
 {"session_id":"d4000000-0000-4000-8000-000000000001","client_event_id":"d5000000-0000-4000-8000-000000000011","text_ja":"文","role":"assistant"},
 {"session_id":"d4000000-0000-4000-8000-000000000001","client_event_id":"d5000000-0000-4000-8000-000000000011","text_ja":"文","user_id":"forged"}]') loop
 perform reservation_test.reject(format('select private.ai_conversation_reserve(%L,%L,%L::jsonb)',
 'd1000000-0000-4000-8000-000000000001','conversation_turn',req),'22023','malformed forged turn request');
end loop;
perform reservation_test.ok(before=reservation_test.counts(),'invalid requests leave receipts tokens reservations unchanged');
end $$;
select reservation_test.reject($s$select private.ai_conversation_reserve(null,'start_conversation','{}')$s$,'22023','null owner');
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001',null,'{}')$s$,'22023','null operation');
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001','tutor_explain','{}')$s$,'22023','nonmutation operation');
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001','start_conversation',null)$s$,'22023','SQL null request');
do $$ declare i integer; expected text; req jsonb; begin
foreach i in array array[3,4,5,6,7,8,10] loop
 expected:=case when i in (6,7,10) then '22023' else 'P0001' end;
 req:=jsonb_build_object('session_id','d4000000-0000-4000-8000-'||lpad(i::text,12,'0'),'client_event_id','d5000000-0000-4000-8000-000000000020','text_ja','文');
 perform reservation_test.reject(format('select private.ai_conversation_reserve(%L,%L,%L::jsonb)','d1000000-0000-4000-8000-000000000001','conversation_turn',req),expected,'closed gapped role oversized or exhausted transcript '||i);
end loop; end $$;
select reservation_test.ok(private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001','finish_conversation',
 '{"session_id":"d4000000-0000-4000-8000-000000000007","client_event_id":"d5000000-0000-4000-8000-000000000021"}')->>'kind'='acquired','99-message cap still permits finishing');
select reservation_test.reject($s$update private.ai_conversation_reservations set is_completed=true$s$,'42501','service cannot release pending reservations');
select reservation_test.reject($s$delete from private.ai_conversation_reservations$s$,'42501','service cannot delete reservations');
select reservation_test.reject($s$truncate private.ai_conversation_reservations$s$,'42501','service cannot truncate reservations');
select reservation_test.reject($s$insert into private.ai_conversation_reservations(receipt_id,session_id,context_json,is_completed) select receipt_id,session_id,context_json,true from private.ai_conversation_reservations limit 1$s$,'42501','service cannot insert a pre-released reservation');
do $$ declare before jsonb:=reservation_test.counts(); req jsonb; i integer; begin
for i in 2..4 loop
 req:=jsonb_build_object('scenario_id','d3000000-0000-4000-8000-'||lpad(i::text,12,'0'),'jlpt_level','N5','client_event_id','d5000000-0000-4000-8000-000000000041');
 perform reservation_test.reject(format('select private.ai_conversation_reserve(%L,%L,%L::jsonb)','d1000000-0000-4000-8000-000000000001','start_conversation',req),'P0002','wrong-level inactive or missing scenario');
end loop;
perform reservation_test.ok(before=reservation_test.counts(),'invalid scenarios leave no partial claims');
end $$;
update public.grammar set is_active=false where id='d2000000-0000-4000-8000-000000000001';
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001',op,jsonb_set(request,'{client_event_id}','"d5000000-0000-4000-8000-000000000042"')) from reservation_test.calls where op='start_conversation'$s$,'P0002','inactive target curriculum rejected');
select reservation_test.ok((select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001',op,request)='{"kind":"pending"}' from reservation_test.calls where op='start_conversation'),'pending replay survives target retirement without fresh dispatch');
update public.grammar set is_active=true,jlpt_level='N4' where id='d2000000-0000-4000-8000-000000000001';
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001',op,jsonb_set(request,'{client_event_id}','"d5000000-0000-4000-8000-000000000042"')) from reservation_test.calls where op='start_conversation'$s$,'P0002','wrong-level target curriculum rejected');
update public.grammar set jlpt_level='N5' where id='d2000000-0000-4000-8000-000000000001';
update public.conversation_scenarios set system_context=repeat('漢',2667) where id='d3000000-0000-4000-8000-000000000001';
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001',op,jsonb_set(request,'{client_event_id}','"d5000000-0000-4000-8000-000000000042"')) from reservation_test.calls where op='start_conversation'$s$,'22023','oversized multibyte scenario context rejected');
update public.conversation_scenarios set system_context='固定した文脈' where id='d3000000-0000-4000-8000-000000000001';
do $$ declare before jsonb:=reservation_test.counts(); req jsonb; begin
select jsonb_set(request,'{client_event_id}','"d5000000-0000-4000-8000-000000000088"') into req from reservation_test.calls where op='start_conversation';
begin
 perform private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001','start_conversation',req);
 raise exception 'TEST_ONLY rollback after full reservation' using errcode='ZX001';
exception when sqlstate 'ZX001' then null; end;
perform reservation_test.ok(before=reservation_test.counts(),'rollback removes receipt token and reservation together');
perform reservation_test.ok(private.ai_receipt_lookup('d1000000-0000-4000-8000-000000000001','start_conversation',req)='{"kind":"missing"}','rolled-back event never becomes pending');
end $$;
do $$ declare before bigint; req jsonb; begin
select count(*) into before from private.ai_conversation_reservations;
select jsonb_set(request,'{client_event_id}','"d5000000-0000-4000-8000-000000000089"') into req from reservation_test.calls where op='start_conversation';
perform reservation_test.ok(private.ai_receipt_claim('d1000000-0000-4000-8000-000000000001','start_conversation',req)->>'kind'='acquired','legacy bare claim fixture owns original token');
perform reservation_test.ok(private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001','start_conversation',req)='{"kind":"pending"}','legacy pending receipt cannot acquire replacement dispatch');
perform reservation_test.ok(before=(select count(*) from private.ai_conversation_reservations),'legacy pending receipt allocates no reservation snapshot');
end $$;
do $$ begin
perform private.ai_receipt_claim('d1000000-0000-4000-8000-000000000001','conversation_turn',
 '{"session_id":"D4000000-0000-4000-8000-000000000011","text_ja":"文","client_event_id":"d5000000-0000-4000-8000-000000000091"}');
perform reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001','conversation_turn',
 '{"session_id":"d4000000-0000-4000-8000-000000000011","text_ja":"文","client_event_id":"d5000000-0000-4000-8000-000000000092"}')$s$,'P0001','distinct event cannot overtake legacy pending session without a reservation');
end $$;
reset role;
-- Failure injection exists only inside this rolled-back test transaction.
create function reservation_test.write_failure() returns trigger language plpgsql as $$
begin raise exception 'TEST_ONLY storage fault' using errcode='40001'; end $$;
create trigger reservation_storage_fault before insert on private.ai_conversation_reservations
 for each row execute function reservation_test.write_failure();
set local role service_role;
do $$ declare before jsonb:=reservation_test.counts(); begin
perform reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001',op,jsonb_set(request,'{client_event_id}','"d5000000-0000-4000-8000-000000000070"')) from reservation_test.calls where op='start_conversation'$s$,'40001','storage failure after claim fails whole reservation');
perform reservation_test.ok(before=reservation_test.counts(),'storage failure leaves no orphan receipt token or reservation');
end $$;
reset role;
drop trigger reservation_storage_fault on private.ai_conversation_reservations;
set local role service_role;
-- TEST ONLY legacy receipt completion proves replay ordering, not message writes.
update reservation_test.calls set result=private.ai_receipt_complete('d1000000-0000-4000-8000-000000000001',op,request,(result->>'token')::uuid,'{"TEST_ONLY_completed":true}');
update public.conversation_sessions set ended_at=clock_timestamp() where id in ('d4000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000009');
update public.conversation_scenarios set is_active=false where id='d3000000-0000-4000-8000-000000000001';
update public.profiles set preferred_jlpt='N4' where id='d1000000-0000-4000-8000-000000000001';
select reservation_test.ok((select bool_and(private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001',op,request)='{"kind":"completed","response":{"TEST_ONLY_completed":true}}') from reservation_test.calls),'completed replay precedes closure retirement and profile checks');
select reservation_test.ok((select bool_and(not is_completed) from private.ai_conversation_reservations),'bare legacy completion never frees pending session guard');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000001',true);
select reservation_test.reject($s$select * from private.ai_conversation_reservations$s$,'42501','authenticated cannot read reservation or context');
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000002','start_conversation','{}')$s$,'42501','authenticated cannot reserve any owner');
reset role;
set local role anon;
select reservation_test.reject($s$select private.ai_conversation_reserve('d1000000-0000-4000-8000-000000000001','start_conversation','{}')$s$,'42501','anon cannot reserve');
select reservation_test.reject($s$select * from private.ai_conversation_reservations$s$,'42501','anon cannot read private snapshots');
reset role;
rollback;
