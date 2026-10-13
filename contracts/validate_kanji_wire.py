"""Validate actual typed Dart capture encodings; not a deployed evaluator."""
import sys
from .validate import ContractError, load_json, validate_payload


def validate_wire_output(path):
    actual = load_json(path)
    if set(actual) != {'algorithm', 'requests'} or actual['algorithm'] != 'nd-kanji-synthetic-1':
        raise ContractError('Unexpected synthetic Kanji output version/fields')
    if len(actual['requests']) != 2:
        raise ContractError('Missing actual Kanji capture/reversal outputs')
    for request in actual['requests']:
        validate_payload('evaluate_kanji_request', request)
    original, reversed_ = actual['requests']
    if original['kanji_id'] != reversed_['kanji_id'] or len(original['strokes']) != 2:
        raise ContractError('Unexpected synthetic identity or count')
    for forward, backward in zip(original['strokes'], reversed_['strokes']):
        a = [(p['x'], p['y']) for p in forward['points']]
        b = [(p['x'], p['y']) for p in backward['points']]
        if a != b[::-1]:
            raise ContractError('Synthetic reversed geometry differs')
    return 2


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: python3 -m contracts.validate_kanji_wire OUTPUT.json')
    print(f'Validated {validate_wire_output(sys.argv[1])} actual Dart Kanji requests')
