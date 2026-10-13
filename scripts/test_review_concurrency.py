"""Exercise the storage uniqueness boundary using two native PostgreSQL sessions.

This is not submit_review integration: the scheduler transaction is delivered in #22 after scheduler #4.
Only an empty disposable CI database is supported; no production connection is used.
"""
import os
import subprocess

url = os.environ['TEST_DATABASE_URL']
command = ['psql', url, '-X', '-v', 'ON_ERROR_STOP=1', '-At']
user = '91000000-0000-4000-8000-000000000001'
content = '92000000-0000-4000-8000-000000000001'
item = '93000000-0000-4000-8000-000000000001'
event = '94000000-0000-4000-8000-000000000001'
setup = f"""
insert into auth.users values ('{user}');
insert into public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,
 expression,reading,meaning_vi,part_of_speech,usage_context_vi)
values ('{content}','N5',0,1,true,'試験','しけん','kiểm thử','noun','SQL fixture');
insert into public.user_learning_items(id,user_id,item_type,item_id)
values ('{item}','{user}','VOCABULARY','{content}');
"""
insert = f"""
insert into public.review_events(user_id,learning_item_id,rating,response_ms,
 is_correct,occurred_at,client_event_id,request_json,result_json)
values ('{user}','{item}',2,100,true,'2026-10-13T12:00:00Z','{event}',
 '{{"client_event_id":"{event}","rating":2}}','{{"original":true}}');
"""
subprocess.run(command, input=setup, text=True, check=True, capture_output=True)
first = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, text=True)
try:
    first.stdin.write("begin;\nset local role service_role;\n" + insert
                      + "\nselect 'INSERTED';\nselect pg_sleep(2);\ncommit;\n")
    first.stdin.close()
    # psql emits the marker after the first INSERT has acquired the unique-key lock.
    for line in first.stdout:
        if line.strip() == 'INSERTED':
            break
    else:
        raise AssertionError('First transaction never reached its INSERT')
    second = subprocess.run(command, input='set role service_role;\n' + insert,
                            text=True, capture_output=True, timeout=15)
    first.wait(timeout=15)
    assert first.returncode == 0, first.stderr.read()
    assert second.returncode != 0, 'Both concurrent inserts unexpectedly succeeded'
    assert 'review_events_user_id_client_event_id_key' in second.stderr, second.stderr
    count = subprocess.run(command, input=f"select count(*) from public.review_events where user_id='{user}' and client_event_id='{event}';",
                           text=True, capture_output=True, check=True).stdout.strip()
    assert count == '1', f'Expected one committed event, got {count}'
    print('PASS: concurrent duplicate storage writes commit exactly one event')
finally:
    if first.poll() is None:
        first.kill()
        first.wait()
