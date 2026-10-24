"""Native Auth-role study-submit-v1 wire checks; no hosted JWT proof."""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from contracts.test_study_session_contracts import validate_request  # noqa: E402
from contracts.validate import validate_payload  # noqa: E402

result = subprocess.run(
    ['psql', os.environ['TEST_DATABASE_URL'], '-X', '-v', 'ON_ERROR_STOP=1', '-At'],
    input=(ROOT / 'supabase/tests/study_submit.sql').read_text(),
    capture_output=True, text=True, timeout=45,
)
if result.returncode:
    raise AssertionError(result.stderr)
records = [json.loads(line[5:]) for line in result.stdout.splitlines() if line.startswith('WIRE:')]
assert {row['label'] for row in records} == {'unauthorized', 'first', 'other-owner', 'second'}
for row in records:
    validate_request(row['request'])
    validate_payload('error' if row['label'] == 'unauthorized' else 'get_daily_plan_response', row['payload'])
print('PASS: authenticated submit owns only A/B identity; strict request/UTC/ACL/replay and 4 actual versioned request/response pairs')
