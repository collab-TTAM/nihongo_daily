"""Native profile-study-day role/calendar output against additive schemas."""
import json
import os
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from contracts.test_study_day_contracts import response_validator  # noqa: E402
from contracts.validate import validate_payload  # noqa: E402
result = subprocess.run(['psql', os.environ['TEST_DATABASE_URL'], '-X', '-v', 'ON_ERROR_STOP=1', '-At'],
                        input=(ROOT / 'supabase/tests/study_day.sql').read_text(), capture_output=True, text=True, timeout=45)
assert result.returncode == 0, result.stderr
rows = [json.loads(line[5:]) for line in result.stdout.splitlines() if line.startswith('WIRE:')]
assert {r['label'] for r in rows} == {'unauthorized', 'owner-a', 'owner-b', 'changed-profile'}
for row in rows:
    if row['label'] == 'unauthorized':
        validate_payload('error', row['payload'])
    else:
        response_validator.validate(row['payload'])
print('PASS study day: own server date, midnight/DST/calendar/ACL/no writes and 4 actual wire responses')
