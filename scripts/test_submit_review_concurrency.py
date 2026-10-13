"""Native-session RPC race tests on a fresh disposable PostgreSQL database only."""
import json
import os
import subprocess

COMMAND = ["psql", os.environ["TEST_DATABASE_URL"], "-X", "-v", "ON_ERROR_STOP=1", "-At"]


def run(sql):
    return subprocess.run(COMMAND, input=sql, text=True, capture_output=True, check=True, timeout=20).stdout


def responses(output):
    return [json.loads(line) for line in output.splitlines() if line.startswith('{')]


for index, scenario in enumerate(['identical', 'changed', 'distinct', 'different_item', 'rollback'], 1):
    owner = f'c1000000-0000-4000-8000-{index:012d}'
    item = f'c3000000-0000-4000-8000-{index:012d}'
    other = f'c4000000-0000-4000-8000-{index:012d}'
    event = f'c2000000-0000-4000-8000-{index:012d}'
    run(f"insert into auth.users values ('{owner}');" +
        ''.join(f"insert into public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,expression,reading,meaning_vi,part_of_speech,usage_context_vi) "
                f"values ('{content}','N5',0.1,1,true,'試験','しけん','test','noun','native RPC fixture');" for content in [item, other]))
    instant = run("select to_char((clock_timestamp()-interval '1 hour') at time zone 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.US\"Z\"');").strip()
    request = dict(client_event_id=event, item_type='VOCABULARY', item_id=item,
                   rating=2, is_correct=True, response_ms=100, occurred_at=instant)
    changed = dict(request)
    if scenario == 'changed':
        changed['rating'] = 3
    if scenario == 'different_item':
        changed['item_id'] = other
    if scenario == 'distinct':
        changed['client_event_id'] = f'c5000000-0000-4000-8000-{index:012d}'
    auth = f"set local role authenticated;select set_config('request.jwt.claim.sub','{owner}',true);"
    first_call = "select public.submit_review('" + json.dumps(request).replace("'", "''") + "'::jsonb);"
    second_call = "select public.submit_review('" + json.dumps(changed).replace("'", "''") + "'::jsonb);"
    first = subprocess.Popen(COMMAND, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        end = 'rollback' if scenario == 'rollback' else 'commit'
        first.stdin.write('begin;' + auth + first_call + "select 'RPC_LOCK_HELD';select pg_sleep(2);" + end + ';')
        first.stdin.close()
        seen = []
        for line in first.stdout:
            seen.append(line)
            if line.strip() == 'RPC_LOCK_HELD':
                break
        else:
            raise AssertionError('First RPC never returned while holding transaction lock')
        first_response = responses(''.join(seen))[0]
        assert 'code' not in first_response, first_response
        second_response = responses(run('begin;' + auth + second_call + 'commit;'))[0]
        first.wait(timeout=20)
        assert first.returncode == 0, first.stderr.read()
        stored = responses(run(f"select jsonb_build_object('events',(select count(*) from public.review_events where user_id='{owner}'),"
                               f"'items',(select count(*) from public.user_learning_items where user_id='{owner}'),"
                               f"'reviews',(select sum(review_count) from public.user_learning_items where user_id='{owner}'));"))[0]
        if scenario in ['identical', 'rollback']:
            assert first_response == second_response, (first_response, second_response)
            assert stored == dict(events=1, items=1, reviews=1), stored
        elif scenario in ['changed', 'different_item']:
            assert second_response['code'] == 'SYNC_CONFLICT', second_response
            assert stored == dict(events=1, items=1, reviews=1), stored
        else:
            assert second_response['review_count'] == 2, second_response
            assert stored == dict(events=2, items=1, reviews=2), stored
        print(f'PASS: native submit_review {scenario} race preserves original responses and atomic counters')
    finally:
        if first.poll() is None:
            first.kill()
            first.wait()
