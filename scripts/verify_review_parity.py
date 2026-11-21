"""Compare actual private SQL scheduler output with frozen Dart policy cases."""
import argparse
from datetime import datetime
import json
import math
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from contracts.validate import validate_payload


def sql_query():
    cases = json.loads((ROOT / "contracts/srs/v1/golden.json").read_text())["cases"]
    text = json.dumps(cases).replace("'", "''")
    return f"""select jsonb_agg(jsonb_build_object('name',value->>'name','state',
      private.schedule_review(jsonb_populate_record(null::public.user_learning_items,
        (value->'before')||jsonb_build_object('item_type',value->>'item_type','item_id',value->>'item_id')),
        (value->'request'->>'rating')::integer,
        (private.review_instant(value->'request'->>'occurred_at')->>'instant')::timestamptz)))
      from jsonb_array_elements('{text}'::jsonb);"""


def check(actual):
    expected = json.loads((ROOT / "contracts/srs/v1/golden.json").read_text())["cases"]
    if not isinstance(actual, list) or len(actual) != len(expected):
        raise ValueError("SQL parity case count mismatch")
    names = [row["name"] for row in actual]
    if len(set(names)) != len(names) or set(names) != {c["name"] for c in expected}:
        raise ValueError("SQL parity cases missing/duplicated/unrecognized")
    by_name = {row["name"]: row["state"] for row in actual}
    for case in expected:
        state = by_name[case["name"]]
        wanted = case["expected_state"]
        if set(state) != set(wanted):
            raise ValueError(f"SQL state fields mismatch: {case['name']}")
        response = {key: state[key] for key in case["expected_response"]}
        validate_payload("submit_review_response", response)
        for key, value in wanted.items():
            got = state[key]
            if key.endswith("_at"):
                equal = datetime.fromisoformat(got) == datetime.fromisoformat(value)
            elif key in {"difficulty", "interval_days"}:
                equal = type(got) in (int, float) and math.isfinite(got) and math.isclose(got, value, rel_tol=0, abs_tol=1e-12)
            else:
                equal = type(got) is type(value) and got == value
            if not equal:
                raise ValueError(f"SQL/Dart policy mismatch: {case['name']}/{key}: {got} != {value}")
    return len(expected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sql-output", type=Path)
    parser.add_argument("--result", type=Path)
    args = parser.parse_args()
    if args.sql_output:
        args.sql_output.write_text(sql_query(), encoding="utf-8")
        return
    if args.result:
        actual = json.loads(args.result.read_text())
    else:
        result = subprocess.run(["psql", os.environ["TEST_DATABASE_URL"], "-X", "-v", "ON_ERROR_STOP=1", "-At"],
                                input=sql_query(), text=True, capture_output=True, check=True, timeout=30)
        actual = json.loads(result.stdout)
    print(f"PASS: actual SQL scheduler matches all {check(actual)} frozen Dart policy cases")


if __name__ == "__main__":
    main()
