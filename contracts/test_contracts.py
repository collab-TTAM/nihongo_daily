"""Regression cases for client/server disagreements and malformed payloads."""

import copy
import json
import tempfile
import unittest
from pathlib import Path

from contracts.validate import ContractError, ROOT, load_json, validate_baseline, validate_payload


class ContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixtures = load_json(ROOT / "fixtures.json")

    def fixture(self, name):
        return copy.deepcopy(self.fixtures[name])

    def reject(self, name, payload):
        with self.assertRaises(ContractError):
            validate_payload(name, payload)

    def test_baseline_covers_all_endpoints_and_content(self):
        self.assertEqual(validate_baseline(), 20)

    def test_all_ratings_and_correctness(self):
        for rating in range(4):
            with self.subTest(rating=rating):
                payload = self.fixture("submit_review_request")
                payload.update(rating=rating, is_correct=rating != 0)
                validate_payload("submit_review_request", payload)
                payload["is_correct"] = not payload["is_correct"]
                self.reject("submit_review_request", payload)

    def test_rating_and_timing_bounds(self):
        for changes in ({"rating": 4}, {"rating": -1}, {"rating": True}, {"response_ms": -1}):
            with self.subTest(changes=changes):
                payload = self.fixture("submit_review_request")
                payload.update(changes)
                self.reject("submit_review_request", payload)

    def test_forged_ownership_is_rejected(self):
        for model in ("submit_review_request", "start_conversation_request", "conversation_turn_request"):
            with self.subTest(model=model):
                payload = self.fixture(model)
                payload["user_id"] = "22222222-2222-4222-8222-222222222222"
                self.reject(model, payload)

    def test_uuid_and_timestamp_formats_are_assertions(self):
        for changes in ({"item_id": "not-a-uuid"}, {"occurred_at": "2026-10-13T13:00:00"},
                        {"occurred_at": "2026-02-30T13:00:00Z"}, {"occurred_at": "2026-10-13T25:00:00Z"}):
            with self.subTest(changes=changes):
                payload = self.fixture("submit_review_request")
                payload.update(changes)
                self.reject("submit_review_request", payload)
        payload = self.fixture("submit_review_request")
        payload["occurred_at"] = "2026-10-13T20:00:00+07:00"
        validate_payload("submit_review_request", payload)

    def test_local_date_is_a_real_calendar_date(self):
        for value in ("2026-02-30", "2026-10-13T00:00:00Z"):
            self.reject("get_daily_plan_request", {"date": value})

    def test_daily_plan_rejects_wrong_total_and_duplicate_blocks(self):
        payload = self.fixture("get_daily_plan_response")
        payload["blocks"][0]["planned_minutes"] += 1
        self.reject("get_daily_plan_response", payload)
        payload = self.fixture("get_daily_plan_response")
        payload["blocks"][1]["type"] = "SRS"
        self.reject("get_daily_plan_response", payload)

    def test_completed_minutes_can_exceed_the_plan(self):
        payload = self.fixture("get_daily_plan_response")
        payload["completed_minutes"] = 150
        validate_payload("get_daily_plan_response", payload)

    def test_default_plan_cannot_silently_redistribute_minutes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("models.schema.json", "fixtures.json", "contract.json"):
                (root / name).write_text((ROOT / name).read_text())
            config = load_json(root / "contract.json")
            config["default_daily_plan"]["blocks"][0]["planned_minutes"] -= 5
            config["default_daily_plan"]["blocks"][1]["planned_minutes"] += 5
            (root / "contract.json").write_text(json.dumps(config))
            with self.assertRaises(ContractError):
                validate_baseline(root)

    def test_kanji_points_indices_and_time(self):
        payload = self.fixture("evaluate_kanji_request")
        payload["strokes"][0]["points"][0]["x"] = 1.1
        self.reject("evaluate_kanji_request", payload)
        payload = self.fixture("evaluate_kanji_request")
        payload["strokes"][0]["index"] = 1
        self.reject("evaluate_kanji_request", payload)
        payload = self.fixture("evaluate_kanji_request")
        payload["strokes"][0]["points"] += [{"x": 0.5, "y": 0.8, "t": 200}]
        self.reject("evaluate_kanji_request", payload)

    def test_ai_outputs_are_typed_and_bounded(self):
        payload = self.fixture("correct_sentence_response")
        payload["grammar_errors"] = "Everything is fine"
        self.reject("correct_sentence_response", payload)
        payload = self.fixture("tutor_explain_response")
        payload["answer_vi"] = "x" * 10001
        self.reject("tutor_explain_response", payload)
        payload = self.fixture("evaluate_kanji_response")
        payload["score_total"] = 101
        self.reject("evaluate_kanji_response", payload)

    def test_assistant_role_cannot_be_overridden(self):
        payload = self.fixture("conversation_turn_response")
        payload["assistant_message"]["role"] = "system"
        self.reject("conversation_turn_response", payload)

    def test_content_version_and_future_levels(self):
        payload = self.fixture("vocabulary")
        payload["content_version"] = 0
        self.reject("vocabulary", payload)
        payload = self.fixture("vocabulary")
        payload["jlpt_level"] = "N1"
        validate_payload("vocabulary", payload)

    def test_unknown_model_fails_closed(self):
        self.reject("unknown_request", {})

    def test_non_finite_json_numbers_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "payload.json"
            path.write_text('{"value": NaN}')
            with self.assertRaises(ValueError):
                load_json(path)


if __name__ == "__main__":
    unittest.main()
