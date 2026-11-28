"""Regression tests for the separate nd-quiz-report-2 contract."""
import copy
import json
import unittest

from contracts import validate_quiz_report_v2 as quiz


class QuizReportV2ContractTests(unittest.TestCase):
    def setUp(self):
        self.cases = json.loads((quiz.ROOT / "fixtures.json").read_text())
        self.request = copy.deepcopy(self.cases[1]["request"])
        self.response = copy.deepcopy(self.cases[1]["response"])

    def bad_request(self, payload):
        with self.assertRaises(ValueError):
            quiz.validate_request(payload)

    def test_v2_fixtures_and_binding_keep_v1_separate(self):
        self.assertEqual(quiz.validate_fixtures(), 3)
        binding = json.loads((quiz.ROOT / "contract.json").read_text())
        self.assertEqual(binding["version"], "nd-quiz-report-2")
        self.assertEqual(binding["operation"], "submit_quiz_report")
        self.assertEqual(binding["parameter"], "p_request")
        self.assertIn("choice_content_versions", quiz.SCHEMA["$defs"]["answer"]["required"])
        for case in self.cases:
            for level in ("N5", "N4"):
                request = copy.deepcopy(case["request"])
                response = copy.deepcopy(case["response"])
                request["jlpt_level"] = level
                response["jlpt_level"] = level
                quiz.validate_request(request)
                quiz.validate_response(response, request)

    def test_exact_fields_reject_unknown_owner_and_derived_values(self):
        for key in self.request:
            payload = copy.deepcopy(self.request)
            payload.pop(key)
            self.bad_request(payload)
        for key in ("user_id", "owner", "score", "is_correct", "mastery", "duration_ms", "metadata"):
            self.bad_request(dict(self.request, **{key: 1}))
        for key in self.request["answers"][0]:
            payload = copy.deepcopy(self.request)
            payload["answers"][0].pop(key)
            self.bad_request(payload)
        payload = copy.deepcopy(self.request)
        payload["answers"][0]["extra"] = True
        self.bad_request(payload)

    def test_choice_versions_are_four_positive_int32_values(self):
        for versions in (
            [1, 1, 1],
            [1, 1, 1, 1, 1],
            [0, 1, 1, 1],
            [-1, 1, 1, 1],
            [2147483648, 1, 1, 1],
            [True, 1, 1, 1],
            [1.0, 1, 1, 1],
            ["1", 1, 1, 1],
        ):
            payload = copy.deepcopy(self.request)
            payload["answers"][0]["choice_content_versions"] = versions
            self.bad_request(payload)

    def test_target_and_selected_ids_must_be_in_four_unique_choices(self):
        base = self.request["answers"][0]["choices"]
        for choices in (base[:3], base + [base[0]], [base[0]] * 4):
            payload = copy.deepcopy(self.request)
            payload["answers"][0]["choices"] = choices
            self.bad_request(payload)
        for field in ("item_id", "selected_id"):
            payload = copy.deepcopy(self.request)
            payload["answers"][0][field] = "b2000000-0000-4000-8000-000000000099"
            self.bad_request(payload)

    def test_structurally_valid_choice_reordering_is_not_a_schema_error(self):
        payload = copy.deepcopy(self.request)
        payload["answers"][0]["choices"].reverse()
        payload["answers"][0]["choice_content_versions"].reverse()
        quiz.validate_request(payload)
        self.assertNotEqual(payload, self.request)

    def test_unique_targets_and_vocabulary_grammar_kind_rules(self):
        payload = copy.deepcopy(self.request)
        payload["answers"].append(copy.deepcopy(payload["answers"][0]))
        self.bad_request(payload)
        vocabulary = copy.deepcopy(self.cases[0]["request"])
        for kind in ("primary", "correction", "reading"):
            vocabulary["practice_kind"] = kind
            self.bad_request(vocabulary)
        grammar = copy.deepcopy(self.request)
        for kind in (None, "focused", "PRIMARY"):
            grammar["practice_kind"] = kind
            self.bad_request(grammar)

    def test_utc_time_and_response_are_bound_to_the_captured_request(self):
        quiz.validate_response(self.response, self.request)
        for timestamp in (
            "1999-12-31T23:59:59Z",
            "2101-01-01T00:00:00Z",
            "2026-02-30T00:00:00Z",
            "2026-10-31T24:00:00Z",
            "2026-10-31T00:00:60Z",
            "2026-10-31T00:00:00+00:00",
        ):
            payload = copy.deepcopy(self.request)
            payload["completed_at"] = timestamp
            self.bad_request(payload)
        with self.assertRaises(ValueError):
            quiz.validate_response(dict(self.response, correct_count=0), self.request)
        with self.assertRaises(ValueError):
            quiz.validate_response(
                dict(self.response, client_event_id="a3000000-0000-4000-8000-000000000099"),
                self.request,
            )

    def test_lookup_response_contract_is_strict_and_correlated(self):
        found = {"status": "found", "response": copy.deepcopy(self.response)}
        unresolved = {
            "status": "unresolved",
            "client_event_id": self.request["client_event_id"],
        }
        quiz.validate_lookup_response(found, self.request)
        quiz.validate_lookup_response(unresolved, self.request)

        invalid = [
            {"status": "unknown", "client_event_id": self.request["client_event_id"]},
            {"status": "unresolved", "client_event_id": "a3000000-0000-4000-8000-000000000099"},
            dict(unresolved, response=copy.deepcopy(self.response)),
            dict(unresolved, user_id="forged"),
            {"status": "found", "response": dict(self.response, client_event_id="a3000000-0000-4000-8000-000000000099")},
            {"status": "found", "response": dict(self.response, correct_count=0)},
            {"status": "found", "response": dict(self.response, user_id="forged")},
            dict(found, client_event_id=self.request["client_event_id"]),
        ]
        for payload in invalid:
            with self.subTest(payload=payload):
                with self.assertRaises(ValueError):
                    quiz.validate_lookup_response(payload, self.request)

    def test_bounded_duplicate_aware_raw_json(self):
        raw = json.dumps(self.request).encode()
        padded = raw + b" " * (quiz.MAX_REQUEST_BYTES - len(raw))
        self.assertEqual(quiz.parse_request(padded), self.request)
        invalid = [
            padded + b" ",
            b"\xff",
            raw[:-1] + b',"quiz_type":"grammar_meaning"}',
            raw.replace(b'"content_version": 1', b'"content_version": 1, "content_version": 1'),
            raw.replace(b'"content_version": 1', b'"content_version": NaN'),
        ]
        for body in invalid:
            with self.subTest(body=body[:24]):
                with self.assertRaisesRegex(ValueError, "^Invalid quiz request body$"):
                    quiz.parse_request(body)


if __name__ == "__main__":
    unittest.main()
