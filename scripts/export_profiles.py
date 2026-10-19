"""Execute disposable SQL profile tests and export real role-fixture responses."""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    command = ['psql', os.environ['TEST_DATABASE_URL'], '-X', '-v', 'ON_ERROR_STOP=1', '-qAt']
    for name in ['ensure_profile.sql', 'export_profiles.sql']:
        try:
            result = subprocess.run(command + ['-f', str(ROOT / 'supabase/tests' / name)],
                                    text=True, capture_output=True, timeout=60)
        except (OSError, subprocess.TimeoutExpired):
            raise SystemExit('Profile SQL fixture process could not finish') from None
        print(result.stderr, end='')
        if result.returncode:
            raise SystemExit('Profile SQL fixture failed; no artifact exported')
        if name == 'export_profiles.sql':
            lines = [line.removeprefix('PROFILE_WIRE:') for line in result.stdout.splitlines()
                     if line.startswith('PROFILE_WIRE:')]
            if len(lines) != 1:
                raise ValueError('Expected one actual SQL response bundle')
            payload = json.loads(lines[0])
            if payload['version'] != 'nd-own-profile-1' or len(payload['cases']) != 5:
                raise ValueError('Incomplete profile SQL fixture bundle')
            target = Path(sys.argv[1])
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps(payload, ensure_ascii=False), encoding='utf-8')
    print('PASS: five actual profile SQL-role responses; not hosted Auth/JWT evidence')

if __name__ == '__main__':
    main()
