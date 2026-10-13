-- Trusted SQL helpers; real auth/provider/transaction adapter remains integration.
begin;
create schema ai_test;
create function ai_test.ok(value boolean,label text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',label; end if;
raise notice 'PASS AI: %',label; end $$;
create function ai_test.reject(statement text,code text,label text) returns void language plpgsql as $$
declare got text; begin
begin execute statement; exception when others then get stacked diagnostics got=returned_sqlstate; end;
perform ai_test.ok(got=code,label || ' got ' || coalesce(got,'SUCCESS')); end $$;
grant usage on schema ai_test to anon,authenticated,service_role;
grant execute on all functions in schema ai_test to anon,authenticated,service_role;
insert into auth.users values ('a1000000-0000-4000-8000-000000000001'),('a1000000-0000-4000-8000-000000000002');
create table ai_test.results(owner uuid,op text,request jsonb,claimed jsonb);
grant all on table ai_test.results to service_role;
set local role service_role;
insert into ai_test.results values('a1000000-0000-4000-8000-000000000001','start_conversation',
 '{"client_event_id":"a2000000-0000-4000-8000-000000000001","scenario_id":"a3000000-0000-4000-8000-000000000001","jlpt_level":"N5"}',null);
update ai_test.results set claimed=private.ai_receipt_claim(owner,op,request);
select ai_test.ok((select claimed->>'kind'='acquired' from ai_test.results),'first request owns dispatch');
select ai_test.ok((select private.ai_receipt_claim(owner,op,request)->>'kind'='pending' from ai_test.results),'duplicate pending never acquires dispatch');
select ai_test.ok((select private.ai_receipt_lookup(owner,op,request)->>'kind'='pending' from ai_test.results),'pending lookup');
select ai_test.ok((select count(*)=1 from private.ai_receipt_claims),'one private dispatch token');
select ai_test.reject($s$select private.ai_receipt_claim('a1000000-0000-4000-8000-000000000001','start_conversation','{"client_event_id":"a2000000-0000-4000-8000-000000000001","jlpt_level":"N4"}')$s$,'P0001','changed request conflicts');
select ai_test.reject($s$select private.ai_receipt_claim(null,'start_conversation','{}')$s$,'22023','missing owner rejected');
select ai_test.reject($s$select private.ai_receipt_claim('a1000000-0000-4000-8000-000000000001','other','{}')$s$,'22023','unknown operation rejected');
select ai_test.reject($s$select private.ai_receipt_claim('a1000000-0000-4000-8000-000000000001','start_conversation','{"client_event_id":null}')$s$,'22023','null event rejected');
select ai_test.reject($s$select private.ai_receipt_claim('a1000000-0000-4000-8000-000000000001','start_conversation','{"client_event_id":"bad"}')$s$,'22023','malformed event rejected');
select ai_test.reject($s$select private.ai_receipt_claim('a1000000-0000-4000-8000-000000000001','start_conversation','{"client_event_id":"a2000000-0000-4000-8000-000000000004","user_id":"forged"}')$s$,'22023','request owner field rejected');
select ai_test.reject($s$select private.ai_receipt_complete(owner,op,request,'a9000000-0000-4000-8000-000000000001','{}') from ai_test.results$s$,'42501','wrong token rejected');
select ai_test.reject($s$select private.ai_receipt_complete(owner,op,request,(claimed->>'token')::uuid,'[]') from ai_test.results$s$,'22023','non-object response rejected');
select ai_test.ok((select private.ai_receipt_complete(owner,op,request,(claimed->>'token')::uuid,'{"validated_fixture":true}')='{"validated_fixture":true}' from ai_test.results),'owner completes receipt');
select ai_test.ok((select private.ai_receipt_claim(owner,op,request)=jsonb_build_object('kind','completed','response','{"validated_fixture":true}'::jsonb) from ai_test.results),'completed replay includes original response');
select ai_test.ok((select private.ai_receipt_complete(owner,op,request,(claimed->>'token')::uuid,'{"validated_fixture":true}')='{"validated_fixture":true}' from ai_test.results),'identical completion retries');
select ai_test.reject($s$select private.ai_receipt_complete(owner,op,request,(claimed->>'token')::uuid,'{"changed":true}') from ai_test.results$s$,'P0001','changed completion conflicts');
select ai_test.ok((select private.ai_receipt_claim('a1000000-0000-4000-8000-000000000002',op,request)->>'kind'='acquired' from ai_test.results),'second account independent claim');
select ai_test.ok((select private.ai_receipt_claim(owner,'finish_conversation',request)->>'kind'='acquired' from ai_test.results),'different operation independent claim');
select ai_test.ok((select count(*)=3 from private.ai_receipt_claims),'scoped three tokens');
select ai_test.reject($s$delete from private.ai_receipt_claims$s$,'42501','backend cannot delete claim token');
reset role;
select ai_test.ok((select bool_and(prosecdef=false and proconfig @> ARRAY['search_path=""']) from pg_proc where oid in ('private.ai_receipt_lookup(uuid,text,jsonb)'::regprocedure,'private.ai_receipt_claim(uuid,text,jsonb)'::regprocedure,'private.ai_receipt_complete(uuid,text,jsonb,uuid,jsonb)'::regprocedure)),'invoker and fixed empty search path');
set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
select ai_test.ok((select count(*)=2 from public.operation_receipts),'caller sees only own public receipts');
select ai_test.reject($s$select * from private.ai_receipt_claims$s$,'42501','client cannot inspect dispatch tokens');
select ai_test.reject($s$select private.ai_receipt_claim('a1000000-0000-4000-8000-000000000002','start_conversation','{}')$s$,'42501','client cannot claim arbitrary owner');
select ai_test.reject($s$select private.ai_receipt_complete('a1000000-0000-4000-8000-000000000001','start_conversation','{}',null,'{}')$s$,'42501','client cannot complete');
reset role;
set local role anon;
select ai_test.reject($s$select private.ai_receipt_lookup('a1000000-0000-4000-8000-000000000001','start_conversation','{}')$s$,'42501','anon cannot lookup');
reset role;
-- A rolled-back claim never leaves a public receipt or private token.
savepoint cancelled_claim;
set local role service_role;
select private.ai_receipt_claim('a1000000-0000-4000-8000-000000000001','start_conversation','{"client_event_id":"a2000000-0000-4000-8000-000000000099"}');
rollback to savepoint cancelled_claim;
select ai_test.ok((select count(*)=3 from private.ai_receipt_claims),'rolled-back claim has no orphan token');
select ai_test.ok((select count(*)=0 from public.operation_receipts where client_event_id='a2000000-0000-4000-8000-000000000099'),'rolled-back claim has no receipt');
rollback;
