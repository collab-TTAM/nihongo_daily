-- Disposable SQL-role/content fixtures only, not hosted Auth/AI proof.
begin;
create schema text_context_test;
create function text_context_test.ok(value boolean,label text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',label; end if;
raise notice 'PASS TEXT CONTEXT: %',label; end $$;
create function text_context_test.reject(statement text,code text,label text) returns void language plpgsql as $$
declare got text; begin
begin execute statement; exception when others then get stacked diagnostics got=returned_sqlstate; end;
perform text_context_test.ok(got=code,label || ' got ' || coalesce(got,'SUCCESS')); end $$;
grant usage on schema text_context_test to anon,authenticated,service_role;
grant execute on all functions in schema text_context_test to anon,authenticated,service_role;
-- Prior native review probes intentionally leave committed active content. Isolate
-- this catalog fixture within the rolled-back transaction; preserve its rows/FKs.
update public.grammar set is_active=false where is_active;
update public.vocabulary set is_active=false where is_active;
insert into auth.users values('c1000000-0000-4000-8000-000000000001'),('c1000000-0000-4000-8000-000000000002'),('c1000000-0000-4000-8000-000000000003');
insert into public.profiles(id,preferred_jlpt) values('c1000000-0000-4000-8000-000000000001','N5'),('c1000000-0000-4000-8000-000000000002','N4');
insert into public.grammar(id,jlpt_level,difficulty,content_version,is_active,title,pattern,meaning_vi,explanation_vi)
select ('c2000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
  case when i=3 then 'N4'::public.jlpt_level else 'N5'::public.jlpt_level end,0.2,1,i<>2,'文法','～です','nghĩa','giải thích'
from generate_series(1,3) i;
insert into public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,expression,reading,meaning_vi,part_of_speech,usage_context_vi)
select ('c3000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
  case when i=3 then 'N4'::public.jlpt_level else 'N5'::public.jlpt_level end,0.2,1,i<>2,'猫','ねこ','mèo','danh từ','ngữ cảnh'
from generate_series(1,3) i;
create table text_context_test.captured(op text,request jsonb,prepared jsonb);
grant all on text_context_test.captured to service_role;
create function text_context_test.write_counts() returns jsonb language sql stable as $$
 select jsonb_build_array((select count(*) from public.operation_receipts),(select count(*) from public.conversation_sessions),
 (select count(*) from public.learning_errors),(select count(*) from public.user_learning_items),
 (select count(*) from public.conversation_messages),(select count(*) from public.daily_plans))
$$;
grant execute on function text_context_test.write_counts() to service_role;
create table text_context_test.before_counts as select text_context_test.write_counts() as counts;
grant select on text_context_test.before_counts to service_role;
insert into text_context_test.captured values
 ('tutor_explain','{"jlpt_level":"N5","question_vi":"Giải thích","context":{"recent_grammar_ids":["C2000000-0000-4000-8000-000000000001"],"recent_vocabulary_ids":["c3000000-0000-4000-8000-000000000001"]}}',null),
 ('correct_sentence','{"jlpt_level":"N5","sentence_ja":"猫です"}',null);
select text_context_test.ok((select count(*)=2 and bool_and(not prosecdef and provolatile='s' and proconfig @> array['search_path=""'])
 from pg_proc where oid in ('private.ai_text_context(uuid,text,jsonb)'::regprocedure,'private.ai_validate_text_context(uuid,text,jsonb,jsonb)'::regprocedure)),
 'both helpers are snapshot-stable invoker functions with empty search path');
select text_context_test.ok(not exists(select 1 from pg_proc p,lateral aclexplode(p.proacl) a where p.oid in
 ('private.ai_text_context(uuid,text,jsonb)'::regprocedure,'private.ai_validate_text_context(uuid,text,jsonb,jsonb)'::regprocedure)
 and a.grantee=0 and a.privilege_type='EXECUTE'),'PUBLIC has no execution grant');
set local role service_role;
update text_context_test.captured set prepared=private.ai_text_context('c1000000-0000-4000-8000-000000000001',op,request);
select text_context_test.ok((select bool_and(prepared - array['instruction','transcript','allowedRefs']='{}' and prepared->'transcript'='[]'
 and jsonb_array_length(prepared->'allowedRefs')=2 and char_length(prepared->>'instruction')<=10000
 and octet_length(convert_to(prepared::text,'UTF8'))<=65536) from text_context_test.captured),'bounded PreparedContext contains only expected fields and two active refs');
select text_context_test.ok((select (prepared->>'instruction')::jsonb->>'jlpt_level'='N5'
 and ((prepared->>'instruction')::jsonb->'curriculum'->0->>'item_type')='GRAMMAR'
 and prepared->'allowedRefs'->0->>'item_id'='c2000000-0000-4000-8000-000000000001'
 and position('question_vi' in (prepared->>'instruction'))=0 from text_context_test.captured where op='tutor_explain'),
 'canonical IDs, grammar-first order and curriculum data separate from learner question');
select text_context_test.ok(jsonb_array_length(private.ai_text_context('c1000000-0000-4000-8000-000000000002','correct_sentence',
 '{"jlpt_level":"N4","sentence_ja":"文"}')->'allowedRefs')=2,'user B selects only own N4 level');
select private.ai_validate_text_context('c1000000-0000-4000-8000-000000000001',op,request,prepared) from text_context_test.captured;
select text_context_test.ok((select counts=text_context_test.write_counts() from text_context_test.before_counts),
 'preparation and validation do not persist learning or receipt state');
do $$ declare req jsonb; begin
for req in select value from jsonb_array_elements('[null,[],{},
 {"jlpt_level":null,"sentence_ja":"文"},{"jlpt_level":"N6","sentence_ja":"文"},
 {"jlpt_level":"N5","sentence_ja":null},{"jlpt_level":"N5","sentence_ja":1},
 {"jlpt_level":"N5","sentence_ja":""},{"jlpt_level":"N5","sentence_ja":"文","user_id":"forged"},
 {"jlpt_level":"N5","sentence_ja":"文","role":"assistant"}]') loop
  perform text_context_test.reject(format('select private.ai_text_context(%L,%L,%L::jsonb)',
    'c1000000-0000-4000-8000-000000000001','correct_sentence',req),'22023','malformed/forged correction request');
end loop;
for req in select value from jsonb_array_elements('[{},null,[],{"recent_grammar_ids":[],"recent_vocabulary_ids":null},
 {"recent_grammar_ids":[],"recent_vocabulary_ids":[],"extra":true},
 {"recent_grammar_ids":[null],"recent_vocabulary_ids":[]},
 {"recent_grammar_ids":[1],"recent_vocabulary_ids":[]},
 {"recent_grammar_ids":["bad"],"recent_vocabulary_ids":[]},
 {"recent_grammar_ids":["c2000000-0000-4000-8000-000000000001","C2000000-0000-4000-8000-000000000001"],"recent_vocabulary_ids":[]}]') loop
  perform text_context_test.reject(format('select private.ai_text_context(%L,%L,%L::jsonb)',
    'c1000000-0000-4000-8000-000000000001','tutor_explain',jsonb_build_object('jlpt_level','N5','question_vi','hỏi','context',req)),
    '22023','malformed/missing/duplicate canonical context IDs');
end loop;
end $$;
select text_context_test.reject($s$select private.ai_text_context(null,'correct_sentence','{"jlpt_level":"N5","sentence_ja":"文"}')$s$,'22023','no owner');
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000001','conversation_turn','{}')$s$,'22023','conversation operations cannot use read context');
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000001',null,'{}')$s$,'22023','null operation');
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000001','correct_sentence',null)$s$,'22023','SQL null request');
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000003','correct_sentence','{"jlpt_level":"N5","sentence_ja":"文"}')$s$,'P0002','unprovisioned profile is not fabricated');
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000001','correct_sentence','{"jlpt_level":"N4","sentence_ja":"文"}')$s$,'42501','learner cannot override own profile level');
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000002',op,request) from text_context_test.captured where op='tutor_explain'$s$,'42501','A request cannot select N5 for N4 user B');
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000001','correct_sentence',jsonb_build_object('jlpt_level','N5','sentence_ja',repeat('文',5001)))$s$,'22023','5001 character sentence rejected');
select text_context_test.ok(jsonb_array_length(private.ai_text_context('c1000000-0000-4000-8000-000000000001','tutor_explain',
 '{"jlpt_level":"N5","question_vi":"hỏi","context":{"recent_grammar_ids":[],"recent_vocabulary_ids":[]}}')->'allowedRefs')=0,'empty recent IDs is a valid context');
do $$ declare bad_id text; begin
foreach bad_id in array array['c2000000-0000-4000-8000-000000000002','c2000000-0000-4000-8000-000000000003',
 'c2000000-0000-4000-8000-000000000099','c3000000-0000-4000-8000-000000000001'] loop
 perform text_context_test.reject(format('select private.ai_text_context(%L,op,jsonb_set(request,%L,%L::jsonb)) from text_context_test.captured where op=%L',
  'c1000000-0000-4000-8000-000000000001','{context,recent_grammar_ids}',jsonb_build_array(bad_id),'tutor_explain'),
  'P0002','inactive/wrong-level/missing/wrong-table grammar ref');
end loop; end $$;
do $$ declare bad_id text; begin
foreach bad_id in array array['c3000000-0000-4000-8000-000000000002','c3000000-0000-4000-8000-000000000003',
 'c3000000-0000-4000-8000-000000000099','c2000000-0000-4000-8000-000000000001'] loop
 perform text_context_test.reject(format('select private.ai_text_context(%L,op,jsonb_set(request,%L,%L::jsonb)) from text_context_test.captured where op=%L',
  'c1000000-0000-4000-8000-000000000001','{context,recent_vocabulary_ids}',jsonb_build_array(bad_id),'tutor_explain'),
  'P0002','inactive/wrong-level/missing/wrong-table vocabulary ref');
end loop; end $$;
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000001',op,request||'{"question_vi":null}') from text_context_test.captured where op='tutor_explain'$s$,'22023','null tutor question');
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000001',op,request||jsonb_build_object('question_vi',repeat('文',5001))) from text_context_test.captured where op='tutor_explain'$s$,'22023','oversized tutor question');
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000001',op,request||'{"user_id":"forged"}') from text_context_test.captured where op='tutor_explain'$s$,'22023','forged tutor owner field');
select text_context_test.reject($s$select private.ai_validate_text_context('c1000000-0000-4000-8000-000000000001',op,request,prepared||'{"sessionId":"forged"}') from text_context_test.captured$s$,'P0001','forged prepared context rejected');
update public.grammar set meaning_vi='đã cập nhật',content_version=2 where id='c2000000-0000-4000-8000-000000000001';
select text_context_test.reject($s$select private.ai_validate_text_context('c1000000-0000-4000-8000-000000000001',op,request,prepared) from text_context_test.captured where op='tutor_explain'$s$,'P0001','late provider result cannot reuse changed curriculum snapshot');
update text_context_test.captured set prepared=private.ai_text_context('c1000000-0000-4000-8000-000000000001',op,request);
update public.grammar set is_active=false where id='c2000000-0000-4000-8000-000000000001';
select text_context_test.reject($s$select private.ai_validate_text_context('c1000000-0000-4000-8000-000000000001',op,request,prepared) from text_context_test.captured where op='tutor_explain'$s$,'P0002','late result cannot authorize retired reference');
update public.grammar set is_active=true where id='c2000000-0000-4000-8000-000000000001';
update public.profiles set preferred_jlpt='N4' where id='c1000000-0000-4000-8000-000000000001';
select text_context_test.reject($s$select private.ai_validate_text_context('c1000000-0000-4000-8000-000000000001',op,request,prepared) from text_context_test.captured$s$,'42501','late result after profile level switch rejected');
update public.profiles set preferred_jlpt='N5' where id='c1000000-0000-4000-8000-000000000001';
-- Large catalog: correction admits whole entries only within fixed byte budget.
insert into public.grammar(id,jlpt_level,difficulty,content_version,is_active,title,pattern,meaning_vi,explanation_vi)
select ('c4000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'N5',0.2,1,true,'文法','～です',repeat('漢',500),'説明'
from generate_series(1,101) i;
select text_context_test.reject($s$select private.ai_validate_text_context('c1000000-0000-4000-8000-000000000001',op,request,prepared) from text_context_test.captured where op='correct_sentence'$s$,'P0001','late correction cannot reuse a changed selection');
select text_context_test.ok(
 private.ai_text_context('c1000000-0000-4000-8000-000000000001','tutor_explain',
 '{"jlpt_level":"N5","question_vi":"hỏi","context":{"recent_grammar_ids":["c4000000-0000-4000-8000-000000000001","c2000000-0000-4000-8000-000000000001"],"recent_vocabulary_ids":[]}}')=
 private.ai_text_context('c1000000-0000-4000-8000-000000000001','tutor_explain',
 '{"jlpt_level":"N5","question_vi":"hỏi","context":{"recent_grammar_ids":["C2000000-0000-4000-8000-000000000001","c4000000-0000-4000-8000-000000000001"],"recent_vocabulary_ids":[]}}'),
 'tutor context ordering and UUID casing do not change the selected snapshot');
update text_context_test.captured set prepared=private.ai_text_context('c1000000-0000-4000-8000-000000000001',op,request) where op='correct_sentence';
select text_context_test.ok((select jsonb_array_length(prepared->'allowedRefs') between 2 and 10
 and jsonb_array_length(prepared->'allowedRefs')=jsonb_array_length((prepared->>'instruction')::jsonb->'curriculum')
 and octet_length(convert_to(((prepared->>'instruction')::jsonb->'curriculum')::text,'UTF8'))<=8000
 and prepared=private.ai_text_context('c1000000-0000-4000-8000-000000000001',op,request)
 from text_context_test.captured where op='correct_sentence'),'large multibyte catalog has deterministic whole-entry bounded allowlist');
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000001','tutor_explain',
 jsonb_build_object('jlpt_level','N5','question_vi','hỏi','context',jsonb_build_object('recent_vocabulary_ids','[]'::jsonb,
 'recent_grammar_ids',(select jsonb_agg(id) from public.grammar where id::text like 'c4000000%' and id::text < 'c4000000-0000-4000-8000-000000000010'))))$s$,'22023','oversized required tutor context fails without silent truncation');
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000001','tutor_explain',
 jsonb_build_object('jlpt_level','N5','question_vi','hỏi','context',jsonb_build_object('recent_vocabulary_ids','[]'::jsonb,
 'recent_grammar_ids',(select jsonb_agg(id) from public.grammar where id::text like 'c4000000%'))))$s$,'22023','101 recent IDs rejected before querying curriculum');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000001',true);
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000001','correct_sentence','{}')$s$,'42501','authenticated cannot execute own private projection');
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000002','correct_sentence','{}')$s$,'42501','authenticated cannot forge other owner');
select text_context_test.reject($s$select private.ai_validate_text_context('c1000000-0000-4000-8000-000000000001','correct_sentence','{}','{}')$s$,'42501','authenticated cannot execute revalidation');
reset role;
set local role anon;
select text_context_test.reject($s$select private.ai_text_context('c1000000-0000-4000-8000-000000000001','correct_sentence','{}')$s$,'42501','anon cannot execute projection');
select text_context_test.reject($s$select private.ai_validate_text_context('c1000000-0000-4000-8000-000000000001','correct_sentence','{}','{}')$s$,'42501','anon cannot execute revalidation');
reset role;
rollback;
