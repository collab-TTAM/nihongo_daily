"""Observe concurrent authenticated bootstrap waiting on native PostgreSQL lock."""
import os
import subprocess
import time

command = ['psql', os.environ['TEST_DATABASE_URL'], '-X', '-v', 'ON_ERROR_STOP=1', '-qAt']
owner = 'e3000000-0000-4000-8000-000000000001'

def sql(text):
    try:
        result = subprocess.run(command, input=text, text=True, capture_output=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        raise RuntimeError('Profile SQL probe could not finish') from None
    if result.returncode:
        raise RuntimeError('Profile SQL probe failed')
    return result.stdout.strip()

sql(f"insert into auth.users values('{owner}');")
first = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, text=True)
second = None
try:
    first.stdin.write(f"begin; set local role authenticated; select set_config('request.jwt.claim.sub','{owner}',true); select public.ensure_profile('{{}}'); select 'READY';\n")
    first.stdin.flush()
    for line in first.stdout:
        if line.strip() == 'READY':
            break
    else:
        raise AssertionError('First bootstrap never reached the lock barrier')
    second = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, text=True)
    second.stdin.write(f"set application_name='nd-profile-race'; set role authenticated; select set_config('request.jwt.claim.sub','{owner}',false); select public.ensure_profile('{{}}')->>'id';\n")
    second.stdin.close()
    deadline = time.monotonic() + 10
    observed = False
    while time.monotonic() < deadline:
        if sql("select exists(select 1 from pg_stat_activity where application_name='nd-profile-race' and wait_event_type='Lock');") == 't':
            observed = True
            break
        if second.poll() is not None:
            break
        time.sleep(0.1)
    if not observed:
        raise AssertionError('Second bootstrap was not observed waiting on its lock')
    first.stdin.write('commit;\n')
    first.stdin.close()
    first.wait(timeout=15)
    second.wait(timeout=15)
    if first.returncode or second.returncode:
        raise AssertionError('Concurrent bootstrap session failed')
    if second.stdout.read().splitlines()[-1] != owner:
        raise AssertionError('Second bootstrap did not return original caller profile')
    if sql(f"select count(*) from public.profiles where id='{owner}';") != '1':
        raise AssertionError('Concurrent bootstrap created duplicate profiles')
    print('PASS: observed native bootstrap lock wait; both callers succeed with one profile')
finally:
    for process in [first, second]:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait(timeout=5)
