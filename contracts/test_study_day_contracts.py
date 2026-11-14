"""Additive profile-study-day-v1; no frozen wire changes."""
import json
from pathlib import Path
import unittest
from jsonschema import Draft202012Validator, ValidationError
from contracts.validate import FORMATS

ROOT = Path(__file__).parent / 'calendar/v1'
REQUEST = json.loads((ROOT / 'request.schema.json').read_text())
RESPONSE = json.loads((ROOT / 'response.schema.json').read_text())
request_validator = Draft202012Validator(REQUEST, format_checker=FORMATS)
response_validator = Draft202012Validator(RESPONSE, format_checker=FORMATS)

class StudyDayContracts(unittest.TestCase):
    def test_binding_and_schemas(self):
        for schema in [REQUEST, RESPONSE]:
            Draft202012Validator.check_schema(schema)
        binding = json.loads((ROOT / 'contract.json').read_text())
        self.assertEqual(binding['version'], 'profile-study-day-v1')
        self.assertEqual(binding['operation'], 'get_study_day')
        self.assertEqual(binding['parameter'], 'p_request')
        request_validator.validate({})
        response_validator.validate({'date': '2026-10-20', 'timezone': 'Asia/Ho_Chi_Minh'})

    def test_no_client_clock_zone_or_owner(self):
        for raw in [None, [], '', 1, {'user_id': 'other'}, {'date': '2026-10-20'},
                    {'timezone': 'UTC'}, {'now': '2026-10-20T00:00:00Z'}]:
            with self.subTest(raw=raw), self.assertRaises(ValidationError):
                request_validator.validate(raw)

    def test_response_strict_calendar_and_fields(self):
        canonical = {'date': '2026-10-20', 'timezone': 'America/New_York'}
        for raw in [None, [], {}, {'date': canonical['date']},
                    dict(canonical, extra=1), dict(canonical, date='0000-01-01'),
                    dict(canonical, date='2026-02-30'), dict(canonical, date='2026-1-1'),
                    dict(canonical, timezone=''), dict(canonical, timezone=1),
                    dict(canonical, timezone='UTC\n')]:
            with self.subTest(raw=raw), self.assertRaises(ValidationError):
                response_validator.validate(raw)
