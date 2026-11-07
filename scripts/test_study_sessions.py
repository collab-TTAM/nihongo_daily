"""Disposable native sessions/atomic progress/wire/races, not hosted proof."""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from contracts.validate import validate_payload  # noqa: E402

CMD = ['psql', os.environ['TEST_DATABASE_URL'], '-X', '-v', 'ON_ERROR_STOP=1', '-At']


def run(sql):
    result = subprocess.run(CMD, input=sql, text=True, capture_output=True, timeout=45)
    if result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout


def wire(text):
    return [json.loads(line[5:]) for line in text.splitlines() if line.startswith('WIRE:')]


records = wire(run((ROOT / 'supabase/tests/study_sessions.sql').read_text()))
assert {row['label'] for row in records} == {
    'first', 'other-owner', 'over-target', 'replay-old', 'whole-minute',
    'end-boundary', 'read-latest', 'failure', 'dst-short', 'dst-long', 'in-progress', 'adjacent-done',
}, 'Missing native session result'
for row in records:
    validate_payload('error' if row['label'] == 'failure' else 'get_daily_plan_response', row['payload'])
print('PASS: native session ACL/calendar/replay/overlap/DST/rollback; 11 actual frozen plan responses/1 safe error')

owner = 'e1900000-0000-4000-8000-000000000001'
run(f"insert into auth.users(id) values ('{owner}'); insert into public.profiles(id) values ('{owner}');")
run("insert into public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,expression,reading,meaning_vi,part_of_speech,usage_context_vi) "
    "values ('e1900000-0000-4000-8000-000000000002','N5',0.1,1,true,'水','みず','nước','noun','TEST ONLY');")
auth = f"set local role authenticated; select set_config('request.jwt.claim.sub','{owner}',true);\n"
read_plan = "select 'WIRE:'||public.get_daily_plan('{\"date\":\"2026-10-18\"}')::text;\n"
initial = wire(run('begin;\n' + auth + read_plan + 'commit;\n'))
assert len(initial) == 1 and initial[0]['completed_minutes'] == 0, initial


def request(event, start, end):
    return {'client_event_id': f'e1910000-0000-4000-8000-{event:012d}',
            'plan_date': '2026-10-18', 'session_type': 'VOCABULARY',
            'started_at': f'2026-10-18T{start}:00Z', 'ended_at': f'2026-10-18T{end}:00Z'}


def command(payload):
    # Only fixed test-owned values, never credentials or user SQL.
    encoded = json.dumps(payload).replace("'", "''")
    return f"select 'WIRE:'||private.record_study_session('{owner}','{encoded}'::jsonb)::text;\n"


def submit(payload):
    responses = wire(run('begin; set local role service_role;\n' + command(payload) + 'commit;\n'))
    assert len(responses) == 1, responses
    return responses[0]


def race(first_request, next_request):
    process = subprocess.Popen(CMD, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        process.stdin.write('begin; set local role service_role;\n' + command(first_request) + 'select pg_sleep(2);\ncommit;\n')
        process.stdin.close()
        original = None
        for line in process.stdout:
            if line.startswith('WIRE:'):
                original = json.loads(line[5:])
                break
        assert original is not None, 'First transaction produced no response'
        validate_payload('get_daily_plan_response', original)
        contender = submit(next_request)
        process.wait(timeout=15)
        assert process.returncode == 0, process.stderr.read()
        validate_payload('get_daily_plan_response', contender)
        return original, contender
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()


first_request = request(1, '08:00', '08:15')
first, retry = race(first_request, first_request)
assert first == retry and first['completed_minutes'] == 15, (first, retry)
assert submit(first_request) == first, 'New connection failed original replay'
changed = submit(request(1, '08:00', '08:16'))
validate_payload('error', changed)
assert changed['code'] == 'SYNC_CONFLICT', changed
distinct_first, distinct_next = race(request(2, '08:15', '08:30'), request(3, '08:30', '08:45'))
assert distinct_first['completed_minutes'] == 30 and distinct_next['completed_minutes'] == 45, (distinct_first, distinct_next)
overlap = submit(request(4, '08:29', '08:31'))
validate_payload('error', overlap)
assert overlap['code'] == 'SYNC_CONFLICT', overlap
latest = wire(run('begin;\n' + auth + read_plan + 'commit;\n'))
assert latest == [distinct_next], 'Fresh authenticated read lost accepted progress'
assert submit(first_request) == first, 'Later progress overwrote original receipt'
assert run(f"select count(*) from public.study_sessions where user_id='{owner}';").strip() == '3'
assert run(f"select count(*) from private.study_session_receipts where user_id='{owner}';").strip() == '3'
print('PASS: concurrent duplicate creates one session; distinct adjacent events preserve45 minutes; overlap conflicts; restart/read/replay consistent')
