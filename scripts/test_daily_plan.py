"""Disposable native PG role/wire/concurrency checks, not hosted Auth proof."""
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


output = run((ROOT / 'supabase/tests/daily_plan.sql').read_text())
payloads = [json.loads(line[5:]) for line in output.splitlines() if line.startswith('WIRE:')]
assert len(payloads) == 8, 'Missing actual SQL wire output'
for record in payloads:
    validate_payload('error' if record['label'] == 'failure' else 'get_daily_plan_response', record['payload'])
print('PASS: actual SQL responses satisfy frozen named contracts (7 plans, 1 redacted error)')

owner = 'd1900000-0000-4000-8000-000000000001'
run(f"insert into auth.users(id) values ('{owner}'); insert into public.profiles(id) values ('{owner}');")
auth = f"set local role authenticated; select set_config('request.jwt.claim.sub','{owner}',true);\n"
request = "select 'WIRE:' || public.get_daily_plan('{\"date\":\"2030-01-01\"}')::text;\n"
first = subprocess.Popen(CMD, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
try:
    first.stdin.write('begin;\n' + auth + request + 'select pg_sleep(2);\ncommit;\n')
    first.stdin.close()
    original = None
    for line in first.stdout:
        if line.startswith('WIRE:'):
            original = json.loads(line[5:])
            break
    assert original is not None, 'First transaction did not create a plan'
    validate_payload('get_daily_plan_response', original)
    contender = run('begin;\n' + auth + request + 'commit;\n')
    second = [json.loads(line[5:]) for line in contender.splitlines() if line.startswith('WIRE:')]
    first.wait(timeout=15)
    assert first.returncode == 0, first.stderr.read()
    assert second == [original], 'Concurrent retry did not preserve the committed winner'
    restarted = run('begin;\n' + auth + request + 'commit;\n')
    third = [json.loads(line[5:]) for line in restarted.splitlines() if line.startswith('WIRE:')]
    assert third == [original], 'New connection did not recover the same stored plan'
    assert run(f"select count(*) from public.daily_plans where user_id='{owner}' and plan_date='2030-01-01';").strip() == '1'
    print('PASS: native concurrent first-create/retry/new connection preserve exactly one user/day plan')
finally:
    if first.poll() is None:
        first.kill()
        first.wait()
