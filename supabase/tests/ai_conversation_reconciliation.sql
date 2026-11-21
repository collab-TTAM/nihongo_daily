-- Disposable SQL Auth roles/model results; not genuine upstream or hosted proof.
begin;
create schema recovery_test;
create function recovery_test.ok(value boolean,label text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',label; end if;
raise notice 'PASS RECONCILIATION: %',label; end $$;
create function recovery_test.reject(statement text,code text,label text) returns void language plpgsql as $$
declare got text; begin
begin execute statement; exception when others then get stacked diagnostics got=returned_sqlstate; end;
perform recovery_test.ok(got=code,label||' got '||coalesce(got,'SUCCESS')); end $$;
create table recovery_test.calls(label text primary key,op text,request jsonb,metadata jsonb,response jsonb);
create function recovery_test.add(label text,op text,req jsonb) returns void language plpgsql as $$
declare claim jsonb; metadata jsonb; response jsonb; begin
claim:=private.ai_conversation_reserve('c1000000-0000-4000-8000-000000000001',op,req)-'token';
metadata:=private.ai_conversation_recovery_lookup('c1000000-0000-4000-8000-000000000001',op,req);
if op='finish_conversation' then response:='{"scores":{"grammar":85,"vocabulary":90,"fluency":75},"errors":[],"strengths_vi":[],"focus_next_vi":[],"srs_recommendations":[]}';
else
 response:=jsonb_build_object('assistant_message',jsonb_build_object('id',claim->'context'->'messageId','role','assistant',
 'text_ja','こんにちは','text_vi',null,'audio_ref',null,'sequence_no',claim->'context'->'sequenceNo'));
 if op='start_conversation' then response:=response||jsonb_build_object('session_id',claim->'context'->'sessionId'); end if;
end if;
insert into recovery_test.calls values(label,op,req,metadata,response); end $$;
create function recovery_test.reconcile(label text) returns jsonb language sql as $$
 select private.ai_conversation_reconcile('c1000000-0000-4000-8000-000000000001',c.op,c.request,
 (c.metadata->'correlation'->>'receipt_id')::uuid,c.metadata->'correlation'->>'idempotency_key',c.metadata->'context',c.response)
 from recovery_test.calls c where c.label=reconcile.label $$;
create function recovery_test.state() returns jsonb language sql stable as $$
 select jsonb_build_array((select count(*) from public.operation_receipts),(select count(*) from private.ai_receipt_claims),
 (select count(*) from private.ai_conversation_reservations),(select count(*) from private.ai_conversation_reservations where is_completed),
 (select count(*) from public.conversation_sessions),(select count(*) from public.conversation_messages),
 (select count(*) from public.operation_receipts where status='COMPLETED')) $$;
grant usage on schema recovery_test to anon,authenticated,service_role;
grant all on recovery_test.calls to service_role;
grant execute on all functions in schema recovery_test to anon,authenticated,service_role;
insert into auth.users values('c1000000-0000-4000-8000-000000000001'),('c1000000-0000-4000-8000-000000000002');
insert into public.profiles(id) values('c1000000-0000-4000-8000-000000000001'),('c1000000-0000-4000-8000-000000000002');
insert into public.conversation_scenarios(id,jlpt_level,difficulty,content_version,is_active,title_vi,title_ja,description_vi,system_context)
 values('c2000000-0000-4000-8000-000000000001','N5',0,1,true,'fixture','会話','fixture','固定文脈');
insert into public.conversation_sessions(id,user_id,scenario_id,jlpt_level)
 select ('c3000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 case when i=3 then 'c1000000-0000-4000-8000-000000000002'::uuid else 'c1000000-0000-4000-8000-000000000001'::uuid end,
 'c2000000-0000-4000-8000-000000000001','N5' from generate_series(1,3) i;
insert into public.conversation_messages(conversation_session_id,role,text_ja,sequence_no)
 select ('c3000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'assistant','こんにちは',0 from generate_series(1,3) i;
select recovery_test.ok((select provolatile='s' and not prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='private.ai_conversation_recovery_lookup(uuid,text,jsonb)'::regprocedure),'lookup stable invoker fixed empty search path');
select recovery_test.ok((select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='private.ai_conversation_reconcile(uuid,text,jsonb,uuid,text,jsonb,jsonb)'::regprocedure),'reconciliation narrow definer fixed empty search path');
select recovery_test.ok(not exists(select 1 from pg_proc p,lateral aclexplode(p.proacl) a where p.oid in
 ('private.ai_conversation_recovery_lookup(uuid,text,jsonb)'::regprocedure,'private.ai_conversation_reconcile(uuid,text,jsonb,uuid,text,jsonb,jsonb)'::regprocedure)
 and a.grantee=0 and a.privilege_type='EXECUTE'),'neither new helper grants PUBLIC execution');
set local role service_role;
do $$ declare before jsonb:=recovery_test.state(); req jsonb:='{"scenario_id":"c2000000-0000-4000-8000-000000000001","jlpt_level":"N5","client_event_id":"c4000000-0000-4000-8000-000000000099"}'; begin
perform recovery_test.ok(private.ai_conversation_recovery_lookup('c1000000-0000-4000-8000-000000000001','start_conversation',req)='{"kind":"missing"}','lookup missing never creates receipt token context or claim');
perform recovery_test.reject(format('select private.ai_conversation_reconcile(%L,%L,%L::jsonb,%L,%L,%L::jsonb,%L::jsonb)',
 'c1000000-0000-4000-8000-000000000001','start_conversation',req,gen_random_uuid(),'missing','{}','{}'),'P0002','reconcile missing never creates a claim');
perform recovery_test.ok(before=recovery_test.state(),'all missing operations leave durable state unchanged'); end $$;
select recovery_test.add('start','start_conversation','{"scenario_id":"c2000000-0000-4000-8000-000000000001","jlpt_level":"N5","client_event_id":"c4000000-0000-4000-8000-000000000001"}');
select recovery_test.add('turn','conversation_turn','{"session_id":"c3000000-0000-4000-8000-000000000001","text_ja":"猫です","client_event_id":"C4000000-0000-4000-8000-000000000002"}');
select recovery_test.add('finish','finish_conversation','{"session_id":"c3000000-0000-4000-8000-000000000002","client_event_id":"c4000000-0000-4000-8000-000000000003"}');
do $$ declare before jsonb:=recovery_test.state(); c recovery_test.calls%rowtype; value jsonb; begin
for c in select * from recovery_test.calls loop
 value:=private.ai_conversation_recovery_lookup('c1000000-0000-4000-8000-000000000001',c.op,c.request);
 perform recovery_test.ok(value=c.metadata and value->>'kind'='pending' and jsonb_typeof(value->'context')='object','stable saved context replay '||c.label);
 perform recovery_test.ok(value-array['kind','correlation','context']='{}' and (value->'correlation')-array['receipt_id','user_id','operation','client_event_id','idempotency_key']='{}','exact lookup fields '||c.label);
 perform recovery_test.ok(value->'correlation'->>'user_id'='c1000000-0000-4000-8000-000000000001' and value->'correlation'->>'operation'=c.op
 and value->'correlation'->>'client_event_id'=lower(c.request->>'client_event_id') and value->'correlation'->>'idempotency_key'='c1000000-0000-4000-8000-000000000001/'||c.op||'/'||lower(c.request->>'client_event_id'),'canonical complete owner operation event correlation '||c.label);
 perform recovery_test.ok(not (value ? 'token') and not exists(select 1 from private.ai_receipt_claims t where position(t.dispatch_token::text in value::text)>0),'lookup never returns any dispatch token '||c.label);
end loop;
perform recovery_test.ok(before=recovery_test.state(),'repeated lookup never writes sessions messages receipts tokens or releases'); end $$;
select recovery_test.ok((select metadata->'correlation'->>'client_event_id'=lower(request->>'client_event_id') and request->>'client_event_id'<>lower(request->>'client_event_id') from recovery_test.calls where label='turn'),'canonical key retains original uppercase request identity separately');
select recovery_test.ok((select private.ai_conversation_recovery_lookup('c1000000-0000-4000-8000-000000000002',op,request)='{"kind":"missing"}' from recovery_test.calls where label='start'),'owner B cannot inspect owner A start context');
select recovery_test.reject($s$select private.ai_conversation_recovery_lookup('c1000000-0000-4000-8000-000000000001',op,request||'{"jlpt_level":"N4"}') from recovery_test.calls where label='start'$s$,'P0001','changed same-event lookup conflicts');
select recovery_test.reject($s$select private.ai_conversation_reconcile('c1000000-0000-4000-8000-000000000002',op,request,(metadata->'correlation'->>'receipt_id')::uuid,metadata->'correlation'->>'idempotency_key',metadata->'context',response) from recovery_test.calls where label='start'$s$,'P0002','foreign owner cannot reconcile A receipt');
do $$ declare c recovery_test.calls%rowtype; value jsonb; before jsonb:=recovery_test.state(); begin
select * into c from recovery_test.calls where label='turn';
perform recovery_test.reject(format('select private.ai_conversation_reconcile(%L,%L,%L::jsonb,%L,%L,%L::jsonb,%L::jsonb)',
 'c1000000-0000-4000-8000-000000000001',c.op,c.request,gen_random_uuid(),c.metadata->'correlation'->>'idempotency_key',c.metadata->'context',c.response),'42501','wrong receipt UUID cannot borrow valid event');
foreach value in array array['null'::jsonb,'{}'::jsonb,c.metadata->'context'||'{"instruction":"changed"}',c.metadata->'context'||jsonb_build_object('sessionId',gen_random_uuid()),c.metadata->'context'||'{"extra":true}'] loop
 perform recovery_test.reject(format('select private.ai_conversation_reconcile(%L,%L,%L::jsonb,%L,%L,%L::jsonb,%L::jsonb)',
 'c1000000-0000-4000-8000-000000000001',c.op,c.request,c.metadata->'correlation'->>'receipt_id',c.metadata->'correlation'->>'idempotency_key',value,c.response),case when value='null' then '22023' else 'P0001' end,'captured context must match original exactly'); end loop;
perform recovery_test.ok(before=recovery_test.state(),'all rejected correlations leave public and private state unchanged'); end $$;
do $$ declare c recovery_test.calls%rowtype; k text; begin
select * into c from recovery_test.calls where label='start';
foreach k in array array['','unknown','c1000000-0000-4000-8000-000000000002/start_conversation/c4000000-0000-4000-8000-000000000001',
 'c1000000-0000-4000-8000-000000000001/conversation_turn/c4000000-0000-4000-8000-000000000001',
 'c1000000-0000-4000-8000-000000000001/start_conversation/c4000000-0000-4000-8000-000000000002'] loop
 perform recovery_test.reject(format('select private.ai_conversation_reconcile(%L,%L,%L::jsonb,%L,%L,%L::jsonb,%L::jsonb)',
 'c1000000-0000-4000-8000-000000000001',c.op,c.request,c.metadata->'correlation'->>'receipt_id',k,c.metadata->'context',c.response),'42501','wrong full idempotency key rejected'); end loop;
end $$;
select recovery_test.reject($s$select private.ai_conversation_reconcile('c1000000-0000-4000-8000-000000000001',op,request,null,metadata->'correlation'->>'idempotency_key',metadata->'context',response) from recovery_test.calls where label='start'$s$,'22023','null receipt id');
select recovery_test.reject($s$select private.ai_conversation_reconcile('c1000000-0000-4000-8000-000000000001',op,request,(metadata->'correlation'->>'receipt_id')::uuid,null,metadata->'context',response) from recovery_test.calls where label='start'$s$,'22023','null key');
select recovery_test.reject($s$select private.ai_conversation_reconcile('c1000000-0000-4000-8000-000000000001',op,request,(metadata->'correlation'->>'receipt_id')::uuid,repeat('k',129),metadata->'context',response) from recovery_test.calls where label='start'$s$,'22023','oversized correlation key');
select recovery_test.reject($s$select private.ai_conversation_reconcile('c1000000-0000-4000-8000-000000000001',op,request,(metadata->'correlation'->>'receipt_id')::uuid,metadata->'correlation'->>'idempotency_key',jsonb_build_object('instruction',repeat('x',65536)),response) from recovery_test.calls where label='start'$s$,'22023','oversized context');
select recovery_test.reject($s$select private.ai_conversation_reconcile('c1000000-0000-4000-8000-000000000001',op,request,(metadata->'correlation'->>'receipt_id')::uuid,metadata->'correlation'->>'idempotency_key',metadata->'context',response||'{"extra":true}') from recovery_test.calls where label='start'$s$,'22023','recovered response still uses strict original schema');
select recovery_test.reject($s$select private.ai_conversation_reconcile('c1000000-0000-4000-8000-000000000001',op,request,(metadata->'correlation'->>'receipt_id')::uuid,metadata->'correlation'->>'idempotency_key',metadata->'context',jsonb_set(response,'{assistant_message,id}',to_jsonb(gen_random_uuid()))) from recovery_test.calls where label='turn'$s$,'22023','recovery cannot choose another server assistant identity');
select recovery_test.reject($s$update private.ai_conversation_reservations set is_completed=true$s$,'42501','service direct release remains denied');
-- Legacy bare claim has no saved context/correlation here and cannot be recovered.
select private.ai_receipt_claim('c1000000-0000-4000-8000-000000000001','finish_conversation','{"session_id":"c3000000-0000-4000-8000-000000000003","client_event_id":"c4000000-0000-4000-8000-000000000004"}')->>'kind';
select recovery_test.ok(private.ai_conversation_recovery_lookup('c1000000-0000-4000-8000-000000000001','finish_conversation','{"session_id":"c3000000-0000-4000-8000-000000000003","client_event_id":"c4000000-0000-4000-8000-000000000004"}')='{"kind":"pending"}','legacy pending exposes no context correlation or token');
select recovery_test.reject($s$select private.ai_conversation_reconcile('c1000000-0000-4000-8000-000000000001','finish_conversation',r.request_json,r.id,'c1000000-0000-4000-8000-000000000001/finish_conversation/c4000000-0000-4000-8000-000000000004','{}','{}') from public.operation_receipts r where r.client_event_id='c4000000-0000-4000-8000-000000000004'$s$,'P0002','legacy pending cannot invent saved reservation');
reset role;
-- Storage error after all public/receipt writes must undo reconciliation as well.
create function recovery_test.fail() returns trigger language plpgsql as $$ begin raise exception 'TEST_ONLY_STORAGE_FAILURE' using errcode='40001'; end $$;
create trigger recovery_fault before update on private.ai_conversation_reservations for each row execute function recovery_test.fail();
set local role service_role;
do $$ declare before jsonb:=recovery_test.state(); c recovery_test.calls%rowtype; begin
for c in select * from recovery_test.calls loop perform recovery_test.reject(format('select recovery_test.reconcile(%L)',c.label),'40001','storage failure after public and receipt writes '||c.label); end loop;
perform recovery_test.ok(before=recovery_test.state(),'storage failure rolls back all sessions messages receipt and release state');
perform recovery_test.ok((select ended_at is null and summary_json is null and score_json is null from public.conversation_sessions where id='c3000000-0000-4000-8000-000000000002'),'failed finish rolls back end time scores and summary'); end $$;
reset role;
drop trigger recovery_fault on private.ai_conversation_reservations;
update public.conversation_scenarios set content_version=2 where id='c2000000-0000-4000-8000-000000000001';
set local role service_role;
select recovery_test.ok((select private.ai_conversation_recovery_lookup('c1000000-0000-4000-8000-000000000001',op,request)=metadata from recovery_test.calls where label='turn'),'lookup retains saved context rather than replacing changed source');
select recovery_test.reject('select recovery_test.reconcile(''turn'')','P0001','reconciliation rechecks actual source version before persistence');
reset role;
update public.conversation_scenarios set content_version=1 where id='c2000000-0000-4000-8000-000000000001';
set local role service_role;
do $$ declare before_tokens bigint; c recovery_test.calls%rowtype; begin
select count(*) into before_tokens from private.ai_receipt_claims;
for c in select * from recovery_test.calls loop
 perform recovery_test.ok(recovery_test.reconcile(c.label)=c.response,'all three operations reconcile exact original result '||c.label);
 perform recovery_test.ok((select o.status='COMPLETED' and r.is_completed and o.response_json=c.response from public.operation_receipts o join private.ai_conversation_reservations r on r.receipt_id=o.id where o.id=(c.metadata->'correlation'->>'receipt_id')::uuid),'receipt release and response committed together '||c.label);
end loop;
perform recovery_test.ok(before_tokens=(select count(*) from private.ai_receipt_claims),'reconciliation never creates or replaces dispatch tokens'); end $$;
select recovery_test.ok((select count(*)=3 from public.conversation_messages where conversation_session_id='c3000000-0000-4000-8000-000000000001'),'recovered turn appends exactly one user assistant pair');
select recovery_test.ok((select ended_at>=started_at and isfinite(ended_at) from public.conversation_sessions where id='c3000000-0000-4000-8000-000000000002'),'recovered finish uses server close clock');
reset role;
update public.conversation_scenarios set is_active=false where id='c2000000-0000-4000-8000-000000000001';
update public.profiles set preferred_jlpt='N4' where id='c1000000-0000-4000-8000-000000000001';
set local role service_role;
do $$ declare before jsonb:=recovery_test.state(); c recovery_test.calls%rowtype; begin
for c in select * from recovery_test.calls loop
 perform recovery_test.ok(recovery_test.reconcile(c.label)=c.response,'original reconciliation replay after retirement profile change and closure '||c.label);
 perform recovery_test.ok(private.ai_conversation_recovery_lookup('c1000000-0000-4000-8000-000000000001',c.op,c.request)=jsonb_build_object('kind','completed','response',c.response),'completed lookup returns only original result without capability/context '||c.label);
end loop;
perform recovery_test.ok(before=recovery_test.state(),'fresh replay never duplicates messages sessions tokens or releases'); end $$;
select recovery_test.reject($s$select private.ai_conversation_reconcile('c1000000-0000-4000-8000-000000000001',op,request,(metadata->'correlation'->>'receipt_id')::uuid,metadata->'correlation'->>'idempotency_key',metadata->'context',response||'{"changed":true}') from recovery_test.calls where label='start'$s$,'P0001','changed completed result conflicts');
set local role anon;
select recovery_test.reject($s$select private.ai_conversation_recovery_lookup(null,null,null)$s$,'42501','anon lookup denied');
select recovery_test.reject($s$select private.ai_conversation_reconcile(null,null,null,null,null,null,null)$s$,'42501','anon reconcile denied');
set local role authenticated;
select recovery_test.reject($s$select private.ai_conversation_recovery_lookup(null,null,null)$s$,'42501','learner lookup denied');
select recovery_test.reject($s$select private.ai_conversation_reconcile(null,null,null,null,null,null,null)$s$,'42501','learner reconcile denied');
reset role;
rollback;
