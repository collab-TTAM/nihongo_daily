"""Native lookup-only SQL reconciliation races. No genuine provider/Auth proof."""
import json
import os
import selectors
import subprocess
import time
import uuid

DATABASE_URL = os.environ['TEST_DATABASE_URL']
if DATABASE_URL != 'postgresql://postgres:postgres@localhost:5432/nihongo_test':
    raise RuntimeError('Reconciliation races require the fixed disposable CI database')
COMMAND = ['psql', DATABASE_URL, '-X', '-v', 'ON_ERROR_STOP=1', '-qAt']


def sql(statement):
    try:
        result = subprocess.run(COMMAND, input=statement, text=True, capture_output=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        raise RuntimeError('Reconciliation SQL probe could not finish') from None
    if result.returncode:
        raise RuntimeError('Reconciliation SQL probe failed')
    return result.stdout.strip()


def literal(value):
    return "'" + json.dumps(value, ensure_ascii=False).replace("'", "''") + "'::jsonb"


def reserve(owner, operation, request):
    return f"private.ai_conversation_reserve('{owner}','{operation}',{literal(request)})"


def lookup(owner, operation, request):
    return f"private.ai_conversation_recovery_lookup('{owner}','{operation}',{literal(request)})"


def reconcile(owner, operation, request, metadata, response):
    correlation = metadata['correlation']
    return f"private.ai_conversation_reconcile('{owner}','{operation}',{literal(request)},'{correlation['receipt_id']}','{correlation['idempotency_key']}',{literal(metadata['context'])},{literal(response)})"


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
                assert data.splitlines()[:2] == [b'completed', b'READY'], 'Reconciliation did not reach the held transaction barrier'
                return
    raise AssertionError('Reconciliation writer never reached its bounded barrier')


for index, case in enumerate(['same_result', 'changed_result', 'normal_complete', 'rollback', 'next_turn', 'finish_closure', 'wrong_context', 'wrong_key'], 1):
    a, b, scenario, other_scenario, session, other_session, event = [str(uuid.uuid4()) for _ in range(7)]
    sql(f"""insert into auth.users values('{a}'),('{b}');
    insert into public.profiles(id) values('{a}'),('{b}');
    insert into public.conversation_scenarios(id,jlpt_level,difficulty,content_version,is_active,title_vi,title_ja,description_vi,system_context)
    values('{scenario}','N5',0,1,true,'fixture','会話','fixture','固定文脈'),('{other_scenario}','N5',0,1,true,'fixture','会話','fixture','固定文脈');
    insert into public.conversation_sessions(id,user_id,scenario_id,jlpt_level) values('{session}','{a}','{scenario}','N5'),('{other_session}','{b}','{other_scenario}','N5');
    insert into public.conversation_messages(conversation_session_id,role,text_ja,sequence_no) values('{session}','assistant','こんにちは',0),('{other_session}','assistant','こんにちは',0);""")
    operation = 'finish_conversation' if case == 'finish_closure' else 'conversation_turn'
    request = {'session_id': session, 'client_event_id': event}
    if operation == 'conversation_turn':
        request['text_ja'] = '猫です'
    # Capability never enters Python: discard original token in SQL and inspect
    # only the new lookup-only result. This does not verify an actual upstream.
    assert sql('set role service_role; select ' + reserve(a, operation, request) + "->>'kind';") == 'acquired'
    metadata = json.loads(sql('set role service_role; select ' + lookup(a, operation, request) + ';'))
    assert set(metadata) == {'kind', 'correlation', 'context'} and metadata['kind'] == 'pending', 'Pending lookup did not return exact correlation/context'
    if operation == 'finish_conversation':
        response = {'scores': {'grammar': 85, 'vocabulary': 90, 'fluency': 75}, 'errors': [], 'strengths_vi': [], 'focus_next_vi': [], 'srs_recommendations': []}
    else:
        response = {'assistant_message': {'id': metadata['context']['messageId'], 'role': 'assistant', 'text_ja': 'そうです', 'text_vi': None, 'audio_ref': None, 'sequence_no': metadata['context']['sequenceNo']}}
    first_call = reconcile(a, operation, request, metadata, response)
    second_metadata = json.loads(json.dumps(metadata))
    second_response = json.loads(json.dumps(response))
    if case == 'changed_result':
        second_response['assistant_message']['text_ja'] = '変更'
    elif case == 'wrong_context':
        second_metadata['context']['instruction'] = 'different original'
    elif case == 'wrong_key':
        second_metadata['correlation']['idempotency_key'] = b + '/' + operation + '/' + event
    next_request = {'session_id': session, 'client_event_id': str(uuid.uuid4()), 'text_ja': '次です'}
    if case in ('next_turn', 'finish_closure'):
        second_call = reserve(a, 'conversation_turn', next_request)
        query = f"with result as materialized (select {second_call} as r) select jsonb_build_object('kind',r->>'kind','leaks',r ? 'token' or r ? 'context') from result;"
    elif case == 'normal_complete':
        # Original worker's SQL-only capability path races reconciliation; the
        # existing token remains inside PostgreSQL and is never printed/read here.
        second_call = f"private.ai_conversation_complete('{a}','{operation}',{literal(request)},(select dispatch_token from private.ai_receipt_claims where receipt_id='{metadata['correlation']['receipt_id']}'),{literal(response)})"
        query = f'select ({second_call}={literal(response)})::text;'
    else:
        second_call = reconcile(a, operation, request, second_metadata, second_response)
        query = f'select ({second_call}={literal(response)})::text;'
    first = subprocess.Popen(COMMAND, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    second = None
    try:
        first.stdin.write((f"begin isolation level read committed; set local role service_role; select case when {first_call}={literal(response)} then 'completed' end; select 'READY';\n").encode())
        first.stdin.flush()
        ready(first)
        # A separate read snapshot sees only the old coherent pending state, even
        # after first has locally written messages/receipt/release but not COMMIT.
        assert json.loads(sql('set role service_role; select ' + lookup(a, operation, request) + ';')) == metadata, 'Lookup observed uncommitted or mixed completion state'
        assert sql(f"select count(*) from public.conversation_messages where conversation_session_id='{session}';") == '1', 'Uncommitted reconciliation exposed partial public messages'
        name = f'nd-reconciliation-race-{index}'
        second = subprocess.Popen(COMMAND, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        second.stdin.write((f"set application_name='{name}'; set statement_timeout='12s'; set role service_role; {query}\n").encode())
        second.stdin.close()
        observed = False
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if sql(f"select exists(select 1 from pg_stat_activity a join pg_locks l on l.pid=a.pid where a.application_name='{name}' and a.wait_event_type='Lock' and l.locktype='advisory' and not l.granted);") == 't':
                observed = True
                break
            if second.poll() is not None:
                break
            time.sleep(0.05)
        assert observed, 'Second reconciliation worker was not observed waiting on the held owner lock'
        other = {'session_id': other_session, 'client_event_id': event, 'text_ja': '文'}
        assert sql('set role service_role; select ' + reserve(b, 'conversation_turn', other) + "->>'kind';") == 'acquired', 'Unrelated owner queued behind reconciliation'
        other_metadata = json.loads(sql('set role service_role; select '+lookup(b, 'conversation_turn', other)+';'))
        assert other_metadata['correlation']['user_id'] == b and other_metadata['correlation']['receipt_id'] != metadata['correlation']['receipt_id'], 'Same event crossed owners'
        first.stdin.write(('rollback;\n' if case == 'rollback' else 'commit;\n').encode())
        first.stdin.close()
        first.wait(timeout=15)
        second.wait(timeout=15)
        assert first.returncode == 0, 'Original reconciliation transaction failed'
        output, error = second.stdout.read().decode().strip(), second.stderr.read().decode()
        if case in ('changed_result', 'wrong_context', 'finish_closure', 'wrong_key'):
            expected = 'FORBIDDEN' if case == 'wrong_key' else 'SYNC_CONFLICT'
            assert second.returncode != 0 and expected in error, 'Mismatched recovery worker did not fail closed'
        elif case == 'next_turn':
            assert second.returncode == 0 and json.loads(output) == {'kind': 'acquired', 'leaks': True}, 'Completed guard did not allow exactly the next event'
        else:
            assert second.returncode == 0 and output == 'true', 'Concurrent original result did not replay exactly'
        state = json.loads(sql(f"""select jsonb_build_object('messages',(select count(*) from public.conversation_messages where conversation_session_id='{session}'),
        'receipts',(select count(*) from public.operation_receipts where user_id='{a}' and client_event_id='{event}'),
        'tokens',(select count(*) from private.ai_receipt_claims c join public.operation_receipts o on o.id=c.receipt_id where o.user_id='{a}' and o.client_event_id='{event}'),
        'completed',o.status='COMPLETED','response',o.response_json,'released',r.is_completed,'closed',s.ended_at is not null)
        from public.operation_receipts o join private.ai_conversation_reservations r on r.receipt_id=o.id join public.conversation_sessions s on s.id=r.session_id
        where o.user_id='{a}' and o.client_event_id='{event}';"""))
        assert state == {'messages': 1 if case == 'finish_closure' else 3, 'receipts': 1, 'tokens': 1, 'completed': True, 'response': response, 'released': True, 'closed': case == 'finish_closure'}, 'Reconciliation changed token count or left non-atomic state'
        assert json.loads(sql('set role service_role; select '+lookup(a, operation, request)+';')) == {'kind': 'completed', 'response': response}, 'Fresh lookup did not replay only original result'
        assert sql('set role service_role; select ('+first_call+'='+literal(response)+')::text;') == 'true', 'Fresh reconciliation retry was not exactly once'
        if case == 'next_turn':
            assert sql(f"select user_sequence_no=3 and assistant_sequence_no=4 from private.ai_conversation_reservations r join public.operation_receipts o on o.id=r.receipt_id where o.user_id='{a}' and o.client_event_id='{next_request['client_event_id']}';") == 't', 'Next event did not reserve consecutive slots'
        print('PASS native conversation reconciliation:', case)
    finally:
        for process in (first, second):
            if process is not None:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)
                for stream in (process.stdin, process.stdout, process.stderr):
                    if stream is not None and not stream.closed:
                        stream.close()
