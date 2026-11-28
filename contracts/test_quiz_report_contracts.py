"""Executable draft quiz-report boundary; no identity, RLS or hosted proof."""
import copy
import json
import unittest

from contracts import validate_quiz_report as quiz


class QuizReportContractTests(unittest.TestCase):
    def setUp(self):
        self.cases = json.loads((quiz.ROOT / "fixtures.json").read_text())
        self.request = copy.deepcopy(self.cases[1]["request"])
        self.response = copy.deepcopy(self.cases[1]["response"])

    def bad_request(self, payload):
        with self.assertRaises(ValueError):
            quiz.validate_request(payload)

    def test_schema_fixtures_binding_and_all_level_kind_pairs(self):
        self.assertEqual(quiz.validate_fixtures(), 3)
        binding = json.loads((quiz.ROOT / "contract.json").read_text())
        self.assertEqual(binding["version"], "nd-quiz-report-1")
        self.assertEqual(binding["operation"], "submit_quiz_report")
        self.assertEqual(binding["parameter"], "p_request")
        self.assertEqual(binding["max_request_bytes"], quiz.MAX_REQUEST_BYTES)
        for case in self.cases:
            for level in ("N5", "N4"):
                request = dict(case["request"], jlpt_level=level)
                response = dict(case["response"], jlpt_level=level)
                quiz.validate_request(request)
                quiz.validate_response(response, request)

    def test_required_fields_and_unknown_owner_or_derived_values(self):
        for key in self.request:
            payload = copy.deepcopy(self.request)
            payload.pop(key)
            self.bad_request(payload)
        for key in ("user_id", "owner", "score", "is_correct", "mastery", "duration_ms", "metadata", "format_version"):
            self.bad_request(dict(self.request, **{key: 1}))
        for key in self.request:
            self.bad_request(dict(self.request, **{key: None}))

    def test_target_version_choice_membership_and_extra_answer_fields(self):
        for version in (0, -1, 2147483648, True, 1.0, "1", None):
            payload = copy.deepcopy(self.request)
            payload["answers"][0]["content_version"] = version
            self.bad_request(payload)
        for field in ("selected_id", "item_id"):
            payload = copy.deepcopy(self.request)
            payload["answers"][0][field] = "b2000000-0000-4000-8000-000000000099"
            self.bad_request(payload)
        for field in ("score", "owner", "is_correct"):
            payload = copy.deepcopy(self.request)
            payload["answers"][0][field] = False
            self.bad_request(payload)
        for field in self.request["answers"][0]:
            payload = copy.deepcopy(self.request)
            payload["answers"][0].pop(field)
            self.bad_request(payload)

    def test_unique_target_even_if_selection_differs(self):
        payload = copy.deepcopy(self.request)
        duplicate = copy.deepcopy(payload["answers"][0])
        duplicate["selected_id"] = duplicate["choices"][1]
        payload["answers"].append(duplicate)
        self.bad_request(payload)

    def test_four_unique_ordered_uuid_choices(self):
        base = self.request["answers"][0]["choices"]
        for choices in (base[:3], base + [base[0]], [base[0]] * 4, ["bad"] + base[1:], None):
            payload = copy.deepcopy(self.request)
            payload["answers"][0]["choices"] = choices
            self.bad_request(payload)
        for value in ("BAD", "A3000000-0000-4000-8000-000000000001", "a3000000-0000-0000-8000-000000000001", "a3000000-0000-4000-8000-000000000001\n"):
            self.bad_request(dict(self.request, client_event_id=value))
        # Choice order is identity, but different order is still a valid report.
        payload = copy.deepcopy(self.request)
        payload["answers"][0]["choices"].reverse()
        quiz.validate_request(payload)
        self.assertNotEqual(payload, self.request)

    def test_report_bounds_one_to_ten_unique_targets(self):
        payload = copy.deepcopy(self.request)
        payload["answers"] = []
        self.bad_request(payload)
        for size in (1, 10, 11):
            answers = []
            for i in range(size):
                target = f"b2000000-0000-4000-8000-{100 + i:012}"
                answer = copy.deepcopy(self.request["answers"][0])
                answer.update(item_id=target, selected_id=target)
                answer["choices"][0] = target
                answers.append(answer)
            payload["answers"] = answers
            if size <= 10:
                quiz.validate_request(payload)
                quiz.validate_response(dict(self.response, answer_count=size, correct_count=size), payload)
            else:
                self.bad_request(payload)

    def test_vocabulary_null_kind_and_grammar_explicit_kind(self):
        for kind in ("primary", "correction", "reading", "PRIMARY", 1):
            self.bad_request(dict(self.cases[0]["request"], practice_kind=kind))
        for kind in (None, "focused", "PRIMARY", 1):
            self.bad_request(dict(self.request, practice_kind=kind))
        for field, value in (("quiz_type", "kanji"), ("jlpt_level", "N3"), ("jlpt_level", "n5")):
            self.bad_request(dict(self.request, **{field: value}))

    def test_utc_microseconds_real_calendar_and_timestamp_range(self):
        for value in ("2000-01-01T00:00:00Z", "2100-12-31T23:59:59.999999Z", "2024-02-29T00:00:00.000Z"):
            quiz.validate_request(dict(self.request, completed_at=value))
        for value in ("1999-12-31T23:59:59Z", "2101-01-01T00:00:00Z", "2026-02-30T00:00:00Z", "2026-10-31T24:00:00Z", "2026-10-31T00:00:60Z", "2026-10-31T00:00:00+00:00", "2026-10-31T00:00:00.1234567Z", "2026-10-31T00:00:00Z\n"):
            self.bad_request(dict(self.request, completed_at=value))

    def test_response_is_strict_bounded_and_correlated_with_request(self):
        quiz.validate_response(self.response, self.request)
        for counts in ({"answer_count": 0}, {"correct_count": 11}, {"answer_count": 1.0}, {"correct_count": True}, {"answer_count": 1, "correct_count": 2}):
            with self.assertRaises(ValueError):
                quiz.validate_response(dict(self.response, **counts))
        for field in self.response:
            response = copy.deepcopy(self.response)
            response.pop(field)
            with self.assertRaises(ValueError):
                quiz.validate_response(response)
        with self.assertRaises(ValueError):
            quiz.validate_response(dict(self.response, user_id="forged"))
        for changes in ({"quiz_type": "vocabulary_reading", "practice_kind": None}, {"client_event_id": "b3000000-0000-4000-8000-000000000099"}, {"practice_kind": "correction"}, {"jlpt_level": "N4"}, {"completed_at": "2026-10-30T00:00:00Z"}, {"answer_count": 2}, {"correct_count": 1 - self.response["correct_count"]}):
            with self.assertRaises(ValueError):
                quiz.validate_response(dict(self.response, **changes), self.request)

    def test_bounded_strict_json_duplicate_nested_keys_utf8_and_nonfinite(self):
        raw = json.dumps(self.request).encode()
        padded = raw + b" " * (quiz.MAX_REQUEST_BYTES - len(raw))
        self.assertEqual(quiz.parse_request(padded), self.request)
        invalid = [padded + b" ", b"\xff", b"[]", b"null", raw[:-1] + b',"quiz_type":"grammar_meaning"}', raw.replace(b'"content_version": 1', b'"content_version": 1, "content_version": 1'), raw.replace(b'"content_version": 1', b'"content_version": NaN'), b"[" * 1500 + b"]" * 1500]
        for body in invalid:
            with self.subTest(body=body[:25]):
                with self.assertRaisesRegex(ValueError, "^Invalid quiz request body$"):
                    quiz.parse_request(body)


if __name__ == "__main__":
    unittest.main()
