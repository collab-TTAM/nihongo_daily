"""TEST ONLY output mutations; real SQL output is verified in the database job."""
import copy
import json
from pathlib import Path
import unittest
from scripts.verify_review_parity import check

ROOT = Path(__file__).resolve().parents[1]


class SqlParityTests(unittest.TestCase):
    def setUp(self):
        cases = json.loads((ROOT / 'contracts/srs/v1/golden.json').read_text())['cases']
        self.fixture = [dict(name=c['name'], state=copy.deepcopy(c['expected_state'])) for c in cases]

    def test_complete_reference_shape_is_accepted(self):
        self.assertEqual(check(self.fixture), 26)

    def test_missing_duplicate_or_renamed_case_is_rejected(self):
        for mutation in ('missing', 'duplicate', 'renamed'):
            value = copy.deepcopy(self.fixture)
            if mutation == 'missing':
                value.pop()
            elif mutation == 'duplicate':
                value[-1] = value[0]
            else:
                value[0]['name'] = 'unknown-case'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                check(value)

    def test_microsecond_due_drift_is_rejected(self):
        self.fixture[0]['state']['next_review_at'] = '2026-10-13T12:01:00.000001Z'
        with self.assertRaises(ValueError):
            check(self.fixture)

    def test_wrong_state_counters_or_interval_are_rejected(self):
        for field, value in [('correct_count', 1), ('interval_days', 2), ('difficulty', 0.5),
                             ('review_count', True), ('srs_state', 'MASTERED')]:
            changed = copy.deepcopy(self.fixture)
            changed[0]['state'][field] = value
            with self.subTest(field=field), self.assertRaises((ValueError, AssertionError)):
                check(changed)

    def test_extra_owner_or_missing_state_fields_are_rejected(self):
        changed = copy.deepcopy(self.fixture)
        changed[0]['state']['user_id'] = 'forged'
        with self.assertRaises(ValueError):
            check(changed)
        del self.fixture[0]['state']['last_review_at']
        with self.assertRaises(ValueError):
            check(self.fixture)

    def test_equivalent_timezone_does_not_create_false_drift(self):
        self.fixture[0]['state']['next_review_at'] = '2026-10-13T19:01:00+07:00'
        self.assertEqual(check(self.fixture), 26)


if __name__ == '__main__':
    unittest.main()
