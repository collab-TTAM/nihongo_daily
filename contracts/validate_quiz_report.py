"""Offline nd-quiz-report-1 validator; not an Auth/content/RPC implementation."""
from __future__ import annotations

import json
from pathlib import Path

from jsonschema import Draft202012Validator
from contracts.validate import FORMATS

ROOT = Path(__file__).resolve().parent / "quiz/v1"
SCHEMA = json.loads((ROOT / "schema.json").read_text(encoding="utf-8"))
MAX_REQUEST_BYTES = 16384
IDENTITY_FIELDS = ("client_event_id", "quiz_type", "practice_kind", "jlpt_level", "completed_at")


def _validate(model, payload):
    validator = Draft202012Validator(
        {**SCHEMA, "$ref": f"#/$defs/{model}"}, format_checker=FORMATS
    )
    if not validator.is_valid(payload):
        raise ValueError("Invalid quiz report shape")


def validate_request(payload):
    _validate("request", payload)
    targets = set()
    for answer in payload["answers"]:
        if type(answer["content_version"]) is not int:
            raise ValueError("Invalid content version")
        target = answer["item_id"]
        if target in targets:
            raise ValueError("Repeated quiz target")
        targets.add(target)
        if target not in answer["choices"] or answer["selected_id"] not in answer["choices"]:
            raise ValueError("Invalid quiz choice membership")


def validate_response(payload, request=None):
    _validate("response", payload)
    if any(type(payload[key]) is not int for key in ("answer_count", "correct_count")):
        raise ValueError("Invalid quiz counts")
    if payload["correct_count"] > payload["answer_count"]:
        raise ValueError("Inconsistent quiz counts")
    if request is not None:
        validate_request(request)
        if any(payload[key] != request[key] for key in IDENTITY_FIELDS):
            raise ValueError("Mismatched quiz response identity")
        expected = sum(a["item_id"] == a["selected_id"] for a in request["answers"])
        if payload["answer_count"] != len(request["answers"]) or payload["correct_count"] != expected:
            raise ValueError("Mismatched quiz response counts")


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate quiz JSON key")
        result[key] = value
    return result


def _constant(_value):
    raise ValueError("Non-finite quiz JSON number")


def parse_request(raw):
    """Bounded strict UTF-8 JSON; no raw request or parser detail in errors."""
    if not isinstance(raw, bytes) or len(raw) > MAX_REQUEST_BYTES:
        raise ValueError("Invalid quiz request body")
    try:
        payload = json.loads(raw.decode("utf-8"), object_pairs_hook=_pairs, parse_constant=_constant)
        validate_request(payload)
    except (ValueError, RecursionError):
        raise ValueError("Invalid quiz request body") from None
    return payload


def validate_fixtures():
    Draft202012Validator.check_schema(SCHEMA)
    cases = json.loads((ROOT / "fixtures.json").read_text(encoding="utf-8"))
    for case in cases:
        parse_request(json.dumps(case["request"]).encode("utf-8"))
        validate_response(case["response"], case["request"])
    return len(cases)


if __name__ == "__main__":
    print(f"Quiz report fixtures valid: {validate_fixtures()}; no hosted service executed.")
