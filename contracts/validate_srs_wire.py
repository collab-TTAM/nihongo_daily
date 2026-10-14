"""Validate actual Dart scheduler encodings against frozen API and parity cases."""
import sys
from pathlib import Path
from .validate import ContractError, load_json, validate_payload

GOLDEN = Path(__file__).resolve().parent / 'srs/v1/golden.json'


def validate_wire_output(path):
    actual = load_json(path)
    golden = load_json(GOLDEN)
    if set(actual) != {'algorithm', 'cases'} or actual['algorithm'] != golden['algorithm']:
        raise ContractError('SRS output algorithm or fields differ')
    expected = {case['name']: case for case in golden['cases']}
    names = [case['name'] for case in actual['cases']]
    if len(names) != len(set(names)) or set(names) != set(expected):
        raise ContractError('SRS actual-output cases are missing or duplicated')
    for case in actual['cases']:
        if set(case) != {'name', 'request', 'response'}:
            raise ContractError('Unexpected SRS actual-output fields')
        validate_payload('submit_review_request', case['request'])
        validate_payload('submit_review_response', case['response'])
        response = expected[case['name']]['expected_response']
        for field, value in response.items():
            got = case['response'][field]
            if isinstance(value, float):
                if abs(got - value) > 1e-12:
                    raise ContractError(f'SRS output mismatch: {case["name"]}/{field}')
            elif got != value:
                raise ContractError(f'SRS output mismatch: {case["name"]}/{field}')
    return len(names)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: python3 -m contracts.validate_srs_wire OUTPUT.json')
    print(f'Validated {validate_wire_output(sys.argv[1])} actual Dart SRS request/response pairs')
