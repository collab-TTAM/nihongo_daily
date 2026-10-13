"""SRS corpus is shared with future backend parity tests, not a server/RLS test."""
import copy
import tempfile
import unittest
import json
from contracts.validate import ContractError, load_json, validate_payload
from contracts.validate_srs_wire import GOLDEN, validate_wire_output


class SrsWireTests(unittest.TestCase):
    def test_every_policy_pair_matches_frozen_api(self):
        bundle = load_json(GOLDEN)
        self.assertEqual(bundle['algorithm'], 'nd-srs-1')
        names = [case['name'] for case in bundle['cases']]
        self.assertEqual(len(set(names)), len(names))
        self.assertGreaterEqual(len(names), 26)
        for case in bundle['cases']:
            with self.subTest(case=case['name']):
                validate_payload('submit_review_request', case['request'])
                validate_payload('submit_review_response', case['expected_response'])
                state = case['expected_state']
                self.assertNotEqual(state['srs_state'], 'MASTERED')
                self.assertEqual(state['correct_count'] + state['incorrect_count'], state['review_count'])
                self.assertGreater(state['interval_days'], 0)
                self.assertLessEqual(state['interval_days'], 365)
                self.assertEqual(case['expected_response'], {k: state[k] for k in case['expected_response']})

    def test_actual_output_validator_rejects_omissions_and_extra_owner(self):
        golden = load_json(GOLDEN)
        valid = {'algorithm': golden['algorithm'], 'cases': [
            {'name': c['name'], 'request': c['request'], 'response': c['expected_response']}
            for c in golden['cases']]}
        invalid = []
        missing = copy.deepcopy(valid)
        missing['cases'].pop()
        invalid.append(missing)
        duplicate = copy.deepcopy(valid)
        duplicate['cases'].append(duplicate['cases'][0])
        invalid.append(duplicate)
        forged = copy.deepcopy(valid)
        forged['cases'][0]['request']['user_id'] = '10000000-0000-4000-8000-000000000001'
        invalid.append(forged)
        changed = copy.deepcopy(valid)
        changed['cases'][0]['response']['interval_days'] = 10
        invalid.append(changed)
        with tempfile.TemporaryDirectory() as folder:
            path = folder + '/wire.json'
            with open(path, 'w') as target:
                json.dump(valid, target)
            self.assertEqual(validate_wire_output(path), 26)
            for value in invalid:
                with open(path, 'w') as target:
                    json.dump(value, target)
                with self.assertRaises(ContractError):
                    validate_wire_output(path)


if __name__ == '__main__':
    unittest.main()
