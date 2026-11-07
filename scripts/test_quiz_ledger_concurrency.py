"""Privileged native-session TEST ONLY races; private ledger, not public Auth/RPC."""
import copy
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
COMMAND = ["psql", os.environ["TEST_DATABASE_URL"], "-X", "-v", "ON_ERROR_STOP=1", "-At"]


def run(sql):
    return subprocess.run(COMMAND, input=sql, text=True, capture_output=True, check=True, timeout=20).stdout


def responses(output):
    return [json.loads(line) for line in output.splitlines() if line.startswith('{')]


for index, scenario in enumerate(['identical', 'changed', 'distinct', 'rollback'], 1):
    owner = f'e3500000-0000-4000-8000-{index:012d}'
    run(f"insert into auth.users values ('{owner}');")
    request = copy.deepcopy(json.loads((ROOT / 'contracts/quiz/v1/fixtures.json').read_text())[0]['request'])
    request['client_event_id'] = f'e3600000-0000-4000-8000-{index:012d}'
    request['completed_at'] = '2000-01-01T00:00:00.000001Z'
    changed = copy.deepcopy(request)
    if scenario == 'changed':
        changed['answers'][0]['selected_id'] = changed['answers'][0]['item_id']
    if scenario == 'distinct':
        changed['client_event_id'] = f'e3700000-0000-4000-8000-{index:012d}'
    auth = f"set local statement_timeout='10s';select set_config('request.jwt.claim.sub','{owner}',true);"
    call = lambda value: "select private.store_quiz_report('" + json.dumps(value).replace("'", "''") + "'::jsonb);"
    first = subprocess.Popen(COMMAND, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    second = None
    try:
        first.stdin.write('begin;' + auth + call(request) + "select 'QUIZ_LOCK_HELD';\n")
        first.stdin.flush()
        seen = []
        for line in first.stdout:
            seen.append(line)
            if line.strip() == 'QUIZ_LOCK_HELD':
                break
        else:
            raise AssertionError('First private store did not retain a transaction lock')
        original = responses(''.join(seen))[0]
        assert first.poll() is None
        app = f'nd_quiz_ledger_race_{scenario}'
        second = subprocess.Popen(COMMAND, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  text=True, env={**os.environ, 'PGAPPNAME': app})
        second.stdin.write('begin;' + auth + call(changed) + 'commit;\n')
        second.stdin.close()
        deadline = time.monotonic() + 15
        while True:
            waiting = run("select exists(select 1 from pg_stat_activity "
                          f"where application_name='{app}' and wait_event_type='Lock' and wait_event='advisory');").strip() == 't'
            if waiting:
                break
            assert second.poll() is None, 'Second store ended without observed contention'
            assert time.monotonic() < deadline, 'No observed owner-lock wait'
            time.sleep(0.02)
        first.stdin.write(('rollback' if scenario == 'rollback' else 'commit') + ';\n')
        first.stdin.close()
        first.wait(timeout=20)
        assert first.returncode == 0, first.stderr.read()
        second.wait(timeout=20)
        if scenario == 'changed':
            assert second.returncode != 0 and 'SYNC_CONFLICT' in second.stderr.read()
        else:
            assert second.returncode == 0, second.stderr.read()
            result = responses(second.stdout.read())[0]
            assert result == {**original, 'client_event_id': changed['client_event_id']}
        stored = responses(run(f"select jsonb_build_object('rows',count(*),'answers',sum((response_json->>'answer_count')::int)) "
                               f"from private.quiz_report_receipts where user_id='{owner}';"))[0]
        count = 2 if scenario == 'distinct' else 1
        assert stored == dict(rows=count, answers=count), stored
        saved = responses(run(f"select response_json from private.quiz_report_receipts where user_id='{owner}' "
                              f"and client_event_id='{request['client_event_id']}';"))[0]
        assert saved == original
        print(f'PASS: native private quiz ledger {scenario} observed lock race/original response/atomic row count (TEST ONLY)')
    finally:
        if first.poll() is None:
            first.kill()
            first.wait()
        if second is not None and second.poll() is None:
            second.kill()
            second.wait()
