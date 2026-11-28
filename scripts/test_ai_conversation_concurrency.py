"""Native PostgreSQL reservation/claim races. No Auth/provider/learner proof."""
import json
import os
import selectors
import subprocess
import time
import uuid

DATABASE_URL = os.environ['TEST_DATABASE_URL']
if DATABASE_URL != 'postgresql://postgres:postgres@localhost:5432/nihongo_test':
    raise RuntimeError('Conversation race requires the fixed disposable CI database')
COMMAND = ['psql', DATABASE_URL, '-X', '-v', 'ON_ERROR_STOP=1', '-qAt']


def sql(statement):
    try:
        result = subprocess.run(COMMAND, input=statement, text=True, capture_output=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        raise RuntimeError('Conversation SQL probe could not finish') from None
    if result.returncode:
        raise RuntimeError('Conversation SQL probe failed')
    return result.stdout.strip()


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
                assert data.splitlines()[:2] == [b'acquired', b'READY'], 'First reservation did not acquire dispatch'
                return
    raise AssertionError('Reservation writer never reached the bounded lock barrier')


def reserve(owner, operation, request):
    # These are generated UUIDs/fixed fixture text, never learner SQL or secrets.
    body = json.dumps(request, ensure_ascii=False)
    return f"private.ai_conversation_reserve('{owner}','{operation}','{body}'::jsonb)"


for index, case in enumerate(['same_event', 'changed_event', 'distinct_event', 'finish_overtake', 'rollback'], 1):
    a, b, scenario, session_a, session_b, event = [str(uuid.uuid4()) for _ in range(6)]
    sql(f"""insert into auth.users values('{a}'),('{b}');
    insert into public.profiles(id) values('{a}'),('{b}');
    insert into public.conversation_scenarios(id,jlpt_level,difficulty,content_version,is_active,title_vi,title_ja,description_vi,system_context)
    values('{scenario}','N5',0,1,true,'fixture','会話','fixture','固定文脈');
    insert into public.conversation_sessions(id,user_id,scenario_id,jlpt_level) values('{session_a}','{a}','{scenario}','N5'),('{session_b}','{b}','{scenario}','N5');
    insert into public.conversation_messages(conversation_session_id,role,text_ja,sequence_no) values('{session_a}','assistant','こんにちは',0),('{session_b}','assistant','こんにちは',0);""")
    request = {'session_id': session_a, 'client_event_id': event, 'text_ja': '猫です'}
    second_request = dict(request)
    operation = 'conversation_turn'
    if case == 'changed_event':
        second_request['text_ja'] = '変更'
    elif case == 'distinct_event':
        second_request['client_event_id'] = str(uuid.uuid4())
    elif case == 'finish_overtake':
        operation = 'finish_conversation'
        second_request = {'session_id': session_a, 'client_event_id': str(uuid.uuid4())}
    first = subprocess.Popen(COMMAND, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    second = None
    try:
        first.stdin.write(("begin isolation level read committed; set local role service_role; select " + reserve(a, 'conversation_turn', request) + "->>'kind'; select 'READY';\n").encode())
        first.stdin.flush()
        ready(first)
        name = f'nd-conversation-race-{index}'
        second = subprocess.Popen(COMMAND, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        call = reserve(a, operation, second_request)
        second.stdin.write((f"set application_name='{name}'; set statement_timeout='12s'; set role service_role; "
                            f"with result as materialized (select {call} as r) select jsonb_build_object('kind',r->>'kind','leaks',r ? 'token' or r ? 'context') from result;\n").encode())
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
        assert observed, 'Second conversation worker was not observed waiting on the held owner lock'
        other = {'session_id': session_b, 'client_event_id': event, 'text_ja': '文'}
        assert sql('set role service_role; select ' + reserve(b, 'conversation_turn', other) + "->>'kind';") == 'acquired', 'User B queued behind owner A'
        first.stdin.write(('rollback;\n' if case == 'rollback' else 'commit;\n').encode())
        first.stdin.close()
        first.wait(timeout=15)
        second.wait(timeout=15)
        assert first.returncode == 0, 'First reservation transaction failed'
        if case in ['same_event', 'rollback']:
            assert second.returncode == 0, 'Reservation contender failed'
            actual = json.loads(second.stdout.read().decode().strip())
            assert actual == {'kind': 'acquired' if case == 'rollback' else 'pending', 'leaks': case == 'rollback'}, 'Incorrect replay or leaked dispatch capability'
        else:
            assert second.returncode != 0 and 'SYNC_CONFLICT' in second.stderr.read().decode(), 'Changed/distinct/finish contender was not rejected'
        # Every sql() is a fresh process/connection, including unknown-outcome retry.
        assert sql(f"select count(*) from public.operation_receipts where user_id='{a}';") == '1'
        assert sql(f"select count(*) from private.ai_receipt_claims c join public.operation_receipts r on r.id=c.receipt_id where r.user_id='{a}';") == '1'
        assert sql(f"select count(*) from private.ai_conversation_reservations s join public.operation_receipts r on r.id=s.receipt_id where r.user_id='{a}';") == '1'
        assert sql(f"select user_sequence_no=1 and assistant_sequence_no=2 and not is_completed from private.ai_conversation_reservations where session_id='{session_a}';") == 't'
        assert sql(f"select count(*)=1 from public.conversation_messages where conversation_session_id='{session_a}';") == 't'
        pending_call = reserve(a, 'conversation_turn', request)
        assert sql(f"""set role service_role; select {pending_call}='{{"kind":"pending"}}'::jsonb;""") == 't', 'Restart/lost-delivery retry renewed dispatch'
        print(f'PASS: native conversation {case}: observed lock wait, A/B independence, atomic claim/reservation and restart-safe pending')
    finally:
        for process in [first, second]:
            if process is not None:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)
                for stream in [process.stdin, process.stdout, process.stderr]:
                    if stream is not None and not stream.closed:
                        stream.close()
