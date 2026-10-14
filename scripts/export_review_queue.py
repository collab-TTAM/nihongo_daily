"""Execute the read-only queue SQL suite, export its actual fixture-role responses."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from contracts.validate_review_queue import VERSION, validate_export


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = subprocess.run(["psql", os.environ["TEST_DATABASE_URL"], "-X", "-v", "ON_ERROR_STOP=1",
                             "-qAt", "-f", str(ROOT / "supabase/tests/review_queue.sql")],
                            text=True, capture_output=True, timeout=60, check=True)
    print(result.stderr, end="")
    lines = [line.removeprefix("QUEUE_WIRE:") for line in result.stdout.splitlines() if line.startswith("QUEUE_WIRE:")]
    if len(lines) != 1:
        raise ValueError("Expected exactly one actual SQL output bundle")
    bundle = {"version": VERSION, "cases": json.loads(lines[0])}
    count = validate_export(bundle)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(bundle, ensure_ascii=False), encoding="utf-8")
    print(f"PASS: {count} actual native SQL queue fixture projections exported; not JWT/PostgREST evidence")


if __name__ == "__main__":
    main()
