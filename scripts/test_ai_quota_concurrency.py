"""Observed native PostgreSQL quota lock/commit/restart probes, not hosted AI."""
import os
import selectors
import subprocess
import time

COMMAND = ['psql', os.environ['TEST_DATABASE_URL'], '-X', '-v', 'ON_ERROR_STOP=1', '-qAt']


def sql(statement):
    try:
        result = subprocess.run(COMMAND, input=statement, text=True, capture_output=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        raise RuntimeError('Quota SQL probe could not finish') from None
    if result.returncode:
        raise RuntimeError('Quota SQL probe failed')
    return result.stdout.strip()


def ready(process):
    # Bounded binary reads avoid blocking readline or text-buffer/select races.
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
                assert data.splitlines()[:2] == [b't', b'READY'], 'First reservation was not granted'
                return
    raise AssertionError('Quota writer never reached the bounded lock barrier')


for index, scenario in enumerate(['first_create', 'last_daily_slot', 'rollback'], 1):
    owner = f'b3000000-0000-4000-8000-{index:012d}'
    other = f'b4000000-0000-4000-8000-{index:012d}'
    sql(f"insert into auth.users values('{owner}'),('{other}');")
    if scenario != 'first_create':
        sql(f"insert into private.ai_rate_buckets values('{owner}',10,clock_timestamp(),(clock_timestamp() at time zone 'UTC')::date,99);")
    call = f"select private.consume_ai_quota('{owner}','conversation_turn');"
    first = subprocess.Popen(COMMAND, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    second = None
    try:
        first.stdin.write(('begin; set local role service_role; ' + call + " select 'READY';\n").encode())
        first.stdin.flush()
        ready(first)
        name = f'nd-ai-quota-{index}'
        second = subprocess.Popen(COMMAND, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        # Distinct operation deliberately shares the same user quota.
        second.stdin.write((f"set application_name='{name}'; set statement_timeout='12s'; set role service_role; "
                            f"select private.consume_ai_quota('{owner}','tutor_explain');\n").encode())
        second.stdin.close()
        observed = False
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if sql(f"select exists(select 1 from pg_stat_activity where application_name='{name}' and wait_event_type='Lock');") == 't':
                observed = True
                break
            if second.poll() is not None:
                break
            time.sleep(0.05)
        assert observed, 'Second quota worker was not observed waiting on the held row/key lock'
        # A different user must not queue behind the held owner's lock.
        assert sql(f"set role service_role; select private.consume_ai_quota('{other}','finish_conversation');") == 't'
        floor = sql('select extract(epoch from clock_timestamp());')
        first.stdin.write(('rollback;\n' if scenario == 'rollback' else 'commit;\n').encode())
        first.stdin.close()
        first.wait(timeout=15)
        second.wait(timeout=15)
        assert first.returncode == 0 and second.returncode == 0, 'Concurrent quota worker failed'
        expected = 'f' if scenario == 'last_daily_slot' else 't'
        assert second.stdout.read().decode().strip() == expected, 'Quota contender received an incorrect reservation'
        count = 2 if scenario == 'first_create' else 100
        # Every sql() is a fresh connection: persistence is not process memory.
        assert sql(f"select count(*)=1 and min(used_today)={count} from private.ai_rate_buckets where user_id='{owner}';") == 't'
        if scenario != 'last_daily_slot':
            assert sql(f"select extract(epoch from refilled_at)>={floor} from private.ai_rate_buckets where user_id='{owner}';") == 't', 'Quota sampled stale transaction/statement time before its lock wait'
        else:
            assert sql(f"set role service_role; select private.consume_ai_quota('{owner}','finish_conversation');") == 'f', 'Restart/operation switch bypassed the committed daily cap'
        assert sql(f"select used_today=1 from private.ai_rate_buckets where user_id='{other}';") == 't'
        print(f'PASS: native quota {scenario}: observed lock wait, owner isolation and committed fresh-connection state')
    finally:
        for process in [first, second]:
            if process is not None:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)
                for stream in [process.stdin, process.stdout, process.stderr]:
                    if stream is not None and not stream.closed:
                        stream.close()
