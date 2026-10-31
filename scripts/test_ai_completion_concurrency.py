"""Native SQL completion barriers/restart. No Auth/provider/hosted learner proof."""
import json
import os
import selectors
import subprocess
import time
import uuid

DATABASE_URL = os.environ['TEST_DATABASE_URL']
if DATABASE_URL != 'postgresql://postgres:postgres@localhost:5432/nihongo_test':
    raise RuntimeError('Completion races require the fixed disposable CI database')
COMMAND = ['psql', DATABASE_URL, '-X', '-v', 'ON_ERROR_STOP=1', '-qAt']


def sql(statement):
    try:
        result = subprocess.run(COMMAND, input=statement, text=True, capture_output=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        raise RuntimeError('Completion SQL probe could not finish') from None
    if result.returncode:
        raise RuntimeError('Completion SQL probe failed')
    return result.stdout.strip()


def literal(value):
    return "'" + json.dumps(value, ensure_ascii=False).replace("'", "''") + "'::jsonb"


def reserve(owner, operation, request):
    return f"private.ai_conversation_reserve('{owner}','{operation}',{literal(request)})"


def complete(owner, operation, request, claim, response):
    return f"private.ai_conversation_complete('{owner}','{operation}',{literal(request)},'{claim['token']}',{literal(response)})"


def ready(process):
    data = b''
    deadline = time.monotonic() + 10
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        while time.monotonic() < deadline:
            events = selector.select(max(0, deadline-time.monotonic()))
            if not events:
                break
            chunk = os.read(process.stdout.fileno(), 4096)
            if not chunk:
                break
            data += chunk
            if b'READY\n' in data:
                assert data.splitlines()[:2] == [b'completed', b'READY'], 'Completion did not reach the transaction barrier'
                return
    raise AssertionError('Completion writer never reached the bounded barrier')


for index, case in enumerate(['same_completion', 'changed_completion', 'next_turn', 'rollback', 'finish_closure', 'target_update', 'link_insert', 'transcript_update'], 1):
    a, b, scenario, other_scenario, session, other_session, event, grammar, extra_grammar = [str(uuid.uuid4()) for _ in range(9)]
    sql(f"""insert into auth.users values('{a}'),('{b}');
    insert into public.profiles(id) values('{a}'),('{b}');
    insert into public.conversation_scenarios(id,jlpt_level,difficulty,content_version,is_active,title_vi,title_ja,description_vi,system_context)
    values('{scenario}','N5',0,1,true,'fixture','会話','fixture','固定文脈'),('{other_scenario}','N5',0,1,true,'fixture','会話','fixture','固定文脈');
    insert into public.conversation_sessions(id,user_id,scenario_id,jlpt_level) values('{session}','{a}','{scenario}','N5'),('{other_session}','{b}','{other_scenario}','N5');
    insert into public.conversation_messages(conversation_session_id,role,text_ja,sequence_no) values('{session}','assistant','こんにちは',0),('{other_session}','assistant','こんにちは',0);
    insert into public.grammar(id,jlpt_level,difficulty,content_version,is_active,title,pattern,meaning_vi,explanation_vi)
    values('{grammar}','N5',0,1,true,'文法','です','nghĩa','fixture'),('{extra_grammar}','N5',0,1,true,'文法','ます','nghĩa','fixture');
    insert into public.scenario_grammar(scenario_id,grammar_id) values('{scenario}','{grammar}');""")
    operation = 'finish_conversation' if case == 'finish_closure' else 'conversation_turn'
    request = {'session_id': session, 'client_event_id': event}
    if operation == 'conversation_turn':
        request['text_ja'] = '猫です'
    claim = json.loads(sql('set role service_role; select ' + reserve(a, operation, request) + ';'))
    assert claim['kind'] == 'acquired', 'Initial reservation did not acquire'
    if operation == 'finish_conversation':
        response = {'scores': {'grammar': 85, 'vocabulary': 90, 'fluency': 75}, 'errors': [], 'strengths_vi': [], 'focus_next_vi': [], 'srs_recommendations': []}
    else:
        response = {'assistant_message': {'id': claim['context']['messageId'], 'role': 'assistant', 'text_ja': 'そうです', 'text_vi': None, 'audio_ref': None, 'sequence_no': claim['context']['sequenceNo']}}
    first_call = complete(a, operation, request, claim, response)
    next_request = {'session_id': session, 'client_event_id': str(uuid.uuid4()), 'text_ja': '次です'}
    if case in ('same_completion', 'changed_completion'):
        changed = json.loads(json.dumps(response))
        if case == 'changed_completion':
            changed['assistant_message']['text_ja'] = '変更'
        second_call = complete(a, operation, request, claim, changed)
        expression = f"({second_call}={literal(response)})::text"
    else:
        second_call = reserve(a, 'conversation_turn', request if case == 'rollback' else next_request)
        expression = f"jsonb_build_object('kind',r->>'kind','leaks',r ? 'token' or r ? 'context')::text"
    source_queries = {
        'target_update': f"update public.grammar set content_version=2 where id='{grammar}' returning 'true';",
        'link_insert': f"insert into public.scenario_grammar(scenario_id,grammar_id) values('{scenario}','{extra_grammar}') returning 'true';",
        'transcript_update': f"update public.conversation_messages set text_ja='変更' where conversation_session_id='{session}' and sequence_no=0 returning 'true';",
    }
    if case in source_queries:
        query = source_queries[case]
    else:
        query = f'select {expression};' if case in ('same_completion', 'changed_completion') else f'with result as materialized (select {second_call} as r) select {expression} from result;'
    first = subprocess.Popen(COMMAND, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    second = None
    try:
        first.stdin.write((f"begin isolation level read committed; set local role service_role; select case when {first_call}={literal(response)} then 'completed' end; select 'READY';\n").encode())
        first.stdin.flush()
        ready(first)
        name = f'nd-completion-race-{index}'
        second = subprocess.Popen(COMMAND, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        second.stdin.write((f"set application_name='{name}'; set statement_timeout='12s'; set role service_role; {query}\n").encode())
        second.stdin.close()
        observed = False
        deadline = time.monotonic() + 10
        lock_filter = "and l.locktype='advisory'" if case not in source_queries else ''
        while time.monotonic() < deadline:
            if sql(f"select exists(select 1 from pg_stat_activity a join pg_locks l on l.pid=a.pid where a.application_name='{name}' and a.wait_event_type='Lock' {lock_filter} and not l.granted);") == 't':
                observed = True
                break
            if second.poll() is not None:
                break
            time.sleep(0.05)
        assert observed, 'Second completion worker was not observed waiting on the held transaction lock'
        # Separate owners/scenarios are independent; shared source locks may briefly queue.
        other = {'session_id': other_session, 'client_event_id': event, 'text_ja': '文'}
        assert sql('set role service_role; select ' + reserve(b, 'conversation_turn', other) + "->>'kind';") == 'acquired', 'Unrelated owner/source queued behind A'
        first.stdin.write(('rollback;\n' if case == 'rollback' else 'commit;\n').encode())
        first.stdin.close()
        first.wait(timeout=15)
        second.wait(timeout=15)
        assert first.returncode == 0, 'First completion transaction failed'
        output, error = second.stdout.read().decode().strip(), second.stderr.read().decode()
        if case in ('changed_completion', 'finish_closure'):
            assert second.returncode != 0 and 'SYNC_CONFLICT' in error, 'Conflicting worker did not fail closed'
        else:
            assert second.returncode == 0, 'Waiting worker failed'
            if case == 'same_completion' or case in source_queries:
                assert output == 'true', 'Duplicate completion did not replay exact original'
            else:
                expected = {'kind': 'pending', 'leaks': False} if case == 'rollback' else {'kind': 'acquired', 'leaks': True}
                assert json.loads(output) == expected, 'Waiting reservation observed an invalid release state'
        state = json.loads(sql(f"""select jsonb_build_object('messages',(select count(*) from public.conversation_messages where conversation_session_id='{session}'),
        'completed',o.status='COMPLETED','response',o.response_json,'released',r.is_completed,'closed',s.ended_at is not null)
        from public.operation_receipts o join private.ai_conversation_reservations r on r.receipt_id=o.id
        join public.conversation_sessions s on s.id=r.session_id where o.user_id='{a}' and o.client_event_id='{event}';"""))
        if case == 'rollback':
            assert state == {'messages': 1, 'completed': False, 'response': None, 'released': False, 'closed': False}, 'Rollback left partial messages receipt release or closure'
            assert json.loads(sql('set role service_role; select '+reserve(a, operation, request)+';')) == {'kind': 'pending'}, 'Rollback restart renewed dispatch'
        else:
            assert state == {'messages': 1 if case == 'finish_closure' else 3, 'completed': True, 'response': response, 'released': True, 'closed': case == 'finish_closure'}, 'Completion was not one atomic original result'
            # New process ignores the original transaction delivery and reads durable receipt.
            assert json.loads(sql('set role service_role; select '+reserve(a, operation, request)+';')) == {'kind': 'completed', 'response': response}, 'Fresh restart did not replay original durable result'
            assert sql('set role service_role; select ('+first_call+'='+literal(response)+')::text;') == 'true', 'Fresh token completion replay changed original'
            if case == 'next_turn':
                assert sql(f"select user_sequence_no=3 and assistant_sequence_no=4 from private.ai_conversation_reservations r join public.operation_receipts o on o.id=r.receipt_id where o.user_id='{a}' and o.client_event_id='{next_request['client_event_id']}';") == 't', 'Released next turn did not reserve consecutive new slots'
        print('PASS native conversation completion:', case)
    finally:
        for process in (first, second):
            if process is not None:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)
                for stream in (process.stdin, process.stdout, process.stderr):
                    if stream is not None and not stream.closed:
                        stream.close()
