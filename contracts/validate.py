"""Validate frozen wire contracts and fixtures; this is not a backend service."""

from __future__ import annotations

import json
import re
from datetime import datetime
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parent / "v0.1"
FORMATS = FormatChecker()


@FORMATS.checks("date-time", raises=ValueError)
def timestamp_with_offset(value):
    """Enforce the documented timestamp subset without optional dependencies."""
    if not isinstance(value, str):
        return True  # JSON Schema's type keyword handles non-strings.
    # Do not delegate clock/offset bounds to a host parser that may normalize
    # rollover (24:00) or offset minutes. Calendar validity still uses datetime.
    clock = r"(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]"
    zone = r"(?:Z|[+-](?:[01][0-9]|2[0-3]):[0-5][0-9])"
    pattern = rf"[0-9]{{4}}-[0-9]{{2}}-[0-9]{{2}}T{clock}(?:\.[0-9]+)?{zone}"
    if re.fullmatch(pattern, value) is None:
        return False
    return datetime.fromisoformat(value.replace("Z", "+00:00")).tzinfo is not None


def _invalid_constant(value):
    raise ValueError(f"Non-finite number is not valid JSON: {value}")


def load_json(path):
    with Path(path).open(encoding="utf-8") as source:
        return json.load(source, parse_constant=_invalid_constant)


class ContractError(ValueError):
    """A payload or contract baseline violates the agreed interface."""


def validate_payload(model, payload, schema=None):
    schema = schema if schema is not None else load_json(ROOT / "models.schema.json")
    if model not in schema["$defs"]:
        raise ContractError(f"Unknown contract model: {model}")
    selected = {**schema, "$ref": f"#/$defs/{model}"}
    validator = Draft202012Validator(selected, format_checker=FORMATS)
    errors = sorted(validator.iter_errors(payload), key=lambda e: str(list(e.path)))
    if errors:
        raise ContractError(f"{model}: {errors[0].message}")
    # Cross-field rules not expressible using ordinary JSON Schema keywords.
    if model == "get_daily_plan_response":
        expected = set(schema["$defs"]["daily_plan_block"]["properties"]["type"]["enum"])
        actual = [block["type"] for block in payload["blocks"]]
        if len(set(actual)) != len(actual) or set(actual) != expected:
            raise ContractError("Daily plan must include each block type exactly once")
        if sum(block["planned_minutes"] for block in payload["blocks"]) != payload["target_minutes"]:
            raise ContractError("Daily plan minutes must sum to target_minutes")
    if model == "evaluate_kanji_request":
        strokes = payload["strokes"]
        if [stroke["index"] for stroke in strokes] != list(range(len(strokes))):
            raise ContractError("Stroke indices must be consecutive in capture order")
        for stroke in strokes:
            times = [point["t"] for point in stroke["points"]]
            if times[0] != 0 or times != sorted(times):
                raise ContractError("Stroke time starts at zero and must not decrease")


def validate_baseline(root=ROOT):
    schema = load_json(root / "models.schema.json")
    config = load_json(root / "contract.json")
    fixtures = load_json(root / "fixtures.json")
    Draft202012Validator.check_schema(schema)
    # Keep the bundle offline and fail on broken references, including models
    # not traversed by a fixture. No remote schema resolution is permitted.
    def check_references(value):
        if isinstance(value, dict):
            if "$ref" in value:
                name = value["$ref"].removeprefix("#/$defs/")
                if value["$ref"] != f"#/$defs/{name}" or name not in schema["$defs"]:
                    raise ContractError(f"Unknown or external schema reference: {value['$ref']}")
            for child in value.values():
                check_references(child)
        elif isinstance(value, list):
            for child in value:
                check_references(child)
    check_references(schema)
    if config["version"] != "0.1" or config["schema_file"] != "models.schema.json":
        raise ContractError("Contract version or schema file does not match baseline")
    levels = schema["$defs"]["jlpt_level"]["enum"]
    if config["supported_levels"] != levels or not set(config["release_levels"]) <= set(levels):
        raise ContractError("Release/support levels do not match schema")
    if config["rating_scale"] != {"AGAIN": 0, "HARD": 1, "GOOD": 2, "EASY": 3}:
        raise ContractError("SRS rating scale changed without a version change")
    required = {"vocabulary", "kanji", "grammar", "error"}
    expected_endpoints = {
        "get_daily_plan", "submit_review", "evaluate_kanji", "tutor_explain",
        "correct_sentence", "start_conversation", "conversation_turn", "finish_conversation",
    }
    if set(config["endpoints"]) != expected_endpoints:
        raise ContractError("Endpoint map is incomplete or unexpected")
    for name, endpoint in config["endpoints"].items():
        expected_transport = "SUPABASE_RPC" if name in {"get_daily_plan", "submit_review"} else "EDGE_FUNCTION"
        if endpoint["authenticated"] is not True or endpoint["transport"] != expected_transport:
            raise ContractError(f"Endpoint boundary differs from baseline: {name}")
        for direction in ("request", "response"):
            model = endpoint[direction]
            if model != f"{name}_{direction}" or model not in schema["$defs"]:
                raise ContractError(f"Invalid endpoint model: {name}/{direction}")
            required.add(model)
    if required - fixtures.keys():
        raise ContractError(f"Missing fixtures: {sorted(required - fixtures.keys())}")
    for model, payload in fixtures.items():
        validate_payload(model, payload, schema)
    plan = config["default_daily_plan"]
    validate_payload("get_daily_plan_response", {
        "plan_date": "2026-10-13", "completed_minutes": 0, **plan,
    }, schema)
    if plan["target_minutes"] != 120:
        raise ContractError("Default daily target must remain 120 minutes")
    expected_minutes = {
        "SRS": 20, "VOCABULARY": 15, "KANJI": 20, "GRAMMAR": 15,
        "LISTENING_READING": 15, "AI_CONVERSATION": 25, "QUIZ_REVIEW": 10,
    }
    if {block["type"]: block["planned_minutes"] for block in plan["blocks"]} != expected_minutes:
        raise ContractError("Default block durations differ from PROJECT_SPEC")
    return len(fixtures)


if __name__ == "__main__":
    print(f"Validated v0.1 contracts and {validate_baseline()} fixtures")
