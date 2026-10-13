"""Native PG READ COMMITTED claim race. Not a live provider/auth integration."""
import os
import subprocess

cmd = ['psql', os.environ['TEST_DATABASE_URL'], '-X', '-v', 'ON_ERROR_STOP=1', '-At']
user = 'aa100000-0000-4000-8000-000000000001'
event = 'aa200000-0000-4000-8000-000000000001'
subprocess.run(cmd, input=f"insert into auth.users values ('{user}');", text=True, check=True, capture_output=True)
request = '{"client_event_id":"' + event + '","jlpt_level":"N5"}'
claim = f"select private.ai_receipt_claim('{user}','start_conversation','{request}')->>'kind';"
first = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
try:
    first.stdin.write('begin;\nset local role service_role;\n' + claim + '\nselect pg_sleep(2);\ncommit;\n')
    first.stdin.close()
    for line in first.stdout:
        if line.strip() == 'acquired':
            break
    else:
        raise AssertionError('First claim did not acquire dispatch')
    second = subprocess.run(cmd, input='set role service_role;\n' + claim, text=True, capture_output=True, timeout=15)
    first.wait(timeout=15)
    assert first.returncode == 0, first.stderr.read()
    assert second.returncode == 0, second.stderr
    assert second.stdout.splitlines()[-1] == 'pending', second.stdout
    changed = request.replace('N5', 'N4')
    conflict = subprocess.run(cmd, input=f"set role service_role; select private.ai_receipt_claim('{user}','start_conversation','{changed}');", text=True, capture_output=True, timeout=15)
    assert conflict.returncode != 0 and 'SYNC_CONFLICT' in conflict.stderr, conflict.stderr
    count = subprocess.run(cmd, input=f"select count(*) from private.ai_receipt_claims c join public.operation_receipts r on r.id=c.receipt_id where r.user_id='{user}' and r.client_event_id='{event}';", text=True, capture_output=True, check=True).stdout.strip()
    assert count == '1', count
    print('PASS: concurrent AI claims grant exactly one dispatch owner; changed retry conflicts')
finally:
    if first.poll() is None:
        first.kill()
        first.wait()
