"""TEST ONLY read-queue contract mutation regressions; native output comes from CI."""
import copy
import unittest

from contracts.validate import ContractError
from contracts.validate_review_queue import SCHEMA, read_export, validate_export, validate_request, validate_response


def request():
    return {"jlpt_level": "N5", "limit": 100}


def response():
    return {"jlpt_level": "N5", "server_time": "2026-10-14T00:00:00.000000Z", "items": [{
        "item_type": "GRAMMAR", "item_id": "d4000000-0000-4000-8000-000000000001",
        "prompt_ja": "～です", "reading_ja": "", "answer_vi": "là",
        "next_review_at": "2020-01-02T00:00:00.000000Z"}]}


class ReviewQueueTests(unittest.TestCase):
    def test_hand_authored_fixture_shape_is_not_certified_native_evidence(self):
        fixture = read_export(SCHEMA.parent / 'fixtures.json')
        self.assertEqual(validate_export(fixture), 7)

    def test_export_missing_duplicate_changed_request_or_wrong_owner_history_rejected(self):
        base = read_export(SCHEMA.parent / 'fixtures.json')
        for mutation in ('missing', 'duplicate', 'request', 'history'):
            changed = copy.deepcopy(base)
            if mutation == 'missing':
                changed['cases'].pop()
            elif mutation == 'duplicate':
                changed['cases'][-1] = changed['cases'][0]
            elif mutation == 'request':
                changed['cases'][0]['request']['limit'] = 90
            else:
                next(c for c in changed['cases'] if c['name'] == 'B_N5')['response']['items'][0]['next_review_at'] = '2020-01-01T00:00:00.000000Z'
            with self.subTest(mutation=mutation), self.assertRaises(ContractError):
                validate_export(changed)

    def test_valid_queue_and_empty_reading_or_empty_account(self):
        validate_response(request(), response())
        validate_response(request(), {**response(), "items": []})

    def test_request_owner_clock_unknown_null_and_limit_bounds_rejected(self):
        for value in [None, [], {**request(), "user_id": "forged"},
                      {**request(), "server_time": "2030-01-01T00:00:00Z"},
                      {"limit": 10}, {"jlpt_level": "N6", "limit": 10}]:
            with self.subTest(value=value), self.assertRaises(ContractError):
                validate_request(value)
        for value in [0, 101, 1.5, True, "10", None]:
            with self.subTest(value=value), self.assertRaises(ContractError):
                validate_request({**request(), "limit": value})

    def test_extra_private_fields_or_wrong_level_never_become_success(self):
        for key, value in [("user_id", "forged"), ("jlpt_level", "N4"), ("code", "UNAUTHORIZED")]:
            with self.subTest(key=key), self.assertRaises(ContractError):
                validate_response(request(), {**response(), key: value})

    def test_future_duplicate_unsorted_or_excessive_items_rejected(self):
        value = response()
        row = value["items"][0]
        for rows in [[row, row], [{**row, "next_review_at": "2026-10-14T00:00:00.000001Z"}],
                     [{**row, "next_review_at": "2020-01-03T00:00:00Z"},
                      {**row, "item_id": "d4000000-0000-4000-8000-000000000002"}]]:
            with self.subTest(rows=rows), self.assertRaises(ContractError):
                validate_response(request(), {**value, "items": rows})
        with self.assertRaises(ContractError):
            validate_response({"jlpt_level": "N5", "limit": 1}, {**value, "items": [row, row]})

    def test_blank_oversize_invalid_types_or_unknown_item_fields_rejected(self):
        for key, values in {"prompt_ja": ["", " ", "x" * 5001], "answer_vi": ["", " ", None],
                            "reading_ja": [None, "x" * 5001], "item_type": ["QUIZ"],
                            "item_id": ["bad"], "private_context": ["forged"]}.items():
            for value in values:
                changed = copy.deepcopy(response())
                changed["items"][0][key] = value
                with self.subTest(key=key), self.assertRaises(ContractError):
                    validate_response(request(), changed)

    def test_invalid_calendar_offsets_and_submicrosecond_precision_rejected(self):
        for value in ["2026-02-30T00:00:00Z", "2026-10-14T24:00:00Z", "2026-10-14T00:00:60Z",
                      "2026-10-14T00:00:00", "2026-10-14T07:00:00+07:00",
                      "2026-10-14T00:00:00.0000001Z"]:
            with self.subTest(value=value), self.assertRaises(ContractError):
                validate_response(request(), {**response(), "server_time": value})

    def test_error_uses_frozen_codes_fields_and_retry_policy(self):
        validate_response(request(), {"code": "UNAUTHORIZED", "message_vi": "Cần đăng nhập", "retryable": False})
        for value in [{"code": "UNAUTHORIZED", "message_vi": "Cần đăng nhập", "retryable": True},
                      {"code": "NOPE", "message_vi": "Lỗi", "retryable": False},
                      {"code": "INTERNAL_ERROR", "message_vi": "Lỗi", "retryable": False, "sql": "private"}]:
            with self.assertRaises(ContractError):
                validate_response(request(), value)


if __name__ == "__main__":
    unittest.main()
