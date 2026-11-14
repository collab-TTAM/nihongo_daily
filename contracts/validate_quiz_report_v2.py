"""Offline nd-quiz-report-2 contract validator; no Auth or content query is performed."""
from __future__ import annotations

import json
from pathlib import Path

from jsonschema import Draft202012Validator
if __package__:
    from .validate import FORMATS
else:
    from validate import FORMATS

ROOT = Path(__file__).resolve().parent / "quiz/v2"
SCHEMA = json.loads((ROOT / "schema.json").read_text(encoding="utf-8"))
MAX_REQUEST_BYTES = 16384
IDENTITY_FIELDS = (
    "client_event_id",
    "quiz_type",
    "practice_kind",
    "jlpt_level",
    "completed_at",
)


def _validate(model, payload):
    validator = Draft202012Validator(
        {**SCHEMA, "$ref": f"#/$defs/{model}"}, format_checker=FORMATS
    )
    if not validator.is_valid(payload):
        raise ValueError("Invalid quiz report v2 shape")


def validate_request(payload):
    _validate("request", payload)
    targets = set()
    for answer in payload["answers"]:
        if type(answer["content_version"]) is not int:
            raise ValueError("Invalid target content version")
        versions = answer["choice_content_versions"]
        if len(versions) != 4 or any(
            type(version) is not int or version < 1 or version > 2147483647
            for version in versions
        ):
            raise ValueError("Invalid choice content versions")
        target = answer["item_id"]
        if target in targets:
            raise ValueError("Repeated quiz target")
        targets.add(target)
        choices = answer["choices"]
        if (
            len(choices) != 4
            or len(set(choices)) != 4
            or target not in choices
            or answer["selected_id"] not in choices
        ):
            raise ValueError("Invalid ordered quiz choices")


def validate_response(payload, request=None):
    _validate("response", payload)
    if type(payload["answer_count"]) is not int or type(payload["correct_count"]) is not int:
        raise ValueError("Invalid quiz counts")
    if payload["correct_count"] > payload["answer_count"]:
        raise ValueError("Inconsistent quiz counts")
    if request is not None:
        validate_request(request)
        if any(payload[key] != request[key] for key in IDENTITY_FIELDS):
            raise ValueError("Mismatched quiz response identity")
        expected = sum(
            answer["item_id"] == answer["selected_id"]
            for answer in request["answers"]
        )
        if (
            payload["answer_count"] != len(request["answers"])
            or payload["correct_count"] != expected
        ):
            raise ValueError("Mismatched quiz response counts")


def validate_lookup_response(payload, request):
    _validate("lookup_response", payload)
    validate_request(request)
    if payload["status"] == "found":
        validate_response(payload["response"], request)
    elif payload["client_event_id"] != request["client_event_id"]:
        raise ValueError("Mismatched unresolved quiz event identity")


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
        payload = json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=_pairs,
            parse_constant=_constant,
        )
        validate_request(payload)
    except (ValueError, RecursionError):
        raise ValueError("Invalid quiz request body") from None
    return payload


def validate_fixtures():
    Draft202012Validator.check_schema(SCHEMA)
    config = json.loads((ROOT / "contract.json").read_text(encoding="utf-8"))
    if (
        config.get("version") != "nd-quiz-report-2"
        or config.get("schema_file") != "schema.json"
        or config.get("max_request_bytes") != MAX_REQUEST_BYTES
    ):
        raise ValueError("Invalid quiz report v2 contract binding")
    cases = json.loads((ROOT / "fixtures.json").read_text(encoding="utf-8"))
    for case in cases:
        parse_request(json.dumps(case["request"]).encode("utf-8"))
        validate_response(case["response"], case["request"])
        validate_lookup_response(
            {"status": "found", "response": case["response"]}, case["request"]
        )
        validate_lookup_response(
            {
                "status": "unresolved",
                "client_event_id": case["request"]["client_event_id"],
            },
            case["request"],
        )
    return len(cases)


if __name__ == "__main__":
    print(
        f"Quiz report v2 fixtures valid: {validate_fixtures()}; "
        "no Auth/content/RPC executed."
    )
