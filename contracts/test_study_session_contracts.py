"""Separate study-submit-v1 contract; frozen v0.1 files remain unchanged."""
import copy
import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator, ValidationError
from contracts.validate import FORMATS

ROOT = Path(__file__).resolve().parent / 'study/v1'
SCHEMA = json.loads((ROOT / 'request.schema.json').read_text())
VALIDATOR = Draft202012Validator(SCHEMA, format_checker=FORMATS)


def validate_request(payload):
    VALIDATOR.validate(payload)


class StudySessionContractTests(unittest.TestCase):
    def setUp(self):
        self.request = json.loads((ROOT / 'request.fixture.json').read_text())

    def test_schema_fixture_and_explicit_version(self):
        Draft202012Validator.check_schema(SCHEMA)
        validate_request(self.request)
        binding = json.loads((ROOT / 'contract.json').read_text())
        self.assertEqual(binding['version'], 'study-submit-v1')
        self.assertEqual(binding['operation'], 'submit_study_session')
        self.assertEqual(binding['parameter'], 'p_request')
        self.assertTrue(binding['response_definition'].endswith('#/$defs/get_daily_plan_response'))

    def test_owner_minutes_and_unknown_fields_are_forbidden(self):
        for key in ['user_id', 'owner', 'p_owner', 'actual_minutes', 'completed_minutes', 'score', 'metadata']:
            with self.subTest(key=key):
                with self.assertRaises(ValidationError):
                    validate_request(dict(self.request, **{key: 123}))

    def test_all_fields_required_and_typed(self):
        for key in self.request:
            missing = copy.deepcopy(self.request)
            missing.pop(key)
            for payload in [missing, dict(self.request, **{key: None}), dict(self.request, **{key: 1})]:
                with self.subTest(key=key, payload=payload):
                    with self.assertRaises(ValidationError):
                        validate_request(payload)

    def test_uuid_calendar_and_area_are_strict(self):
        for changes in [{'client_event_id': 'bad'}, {'plan_date': '2026-02-30'},
                        {'plan_date': '0000-01-01'}, {'session_type': 'UNKNOWN'}, {'plan_date': '2026-1-1'}]:
            with self.subTest(changes=changes):
                with self.assertRaises(ValidationError):
                    validate_request(dict(self.request, **changes))

    def test_explicit_utc_microseconds_and_real_instants(self):
        for value in ['2026-10-13T00:00:00Z', '2026-10-13T00:00:00.000001Z']:
            validate_request(dict(self.request, started_at=value))
        for value in ['2026-02-30T00:00:00Z', '2026-10-13T24:00:00Z',
                      '2026-10-13T00:00:60Z', '2026-10-13T00:00:00',
                      '2026-10-13T00:00:00+00:00', '2026-10-13T00:00:00z',
                      '2026-10-13T00:00:00.0000001Z', '2026-10-13T00:00:00Z\n']:
            with self.subTest(value=value):
                with self.assertRaises(ValidationError):
                    validate_request(dict(self.request, started_at=value))
