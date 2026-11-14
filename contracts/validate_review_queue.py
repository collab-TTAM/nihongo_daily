"""Additive nd-review-queue-1 contract; native SQL exports are fixture-role evidence."""
from datetime import datetime
import json
from pathlib import Path
import sys

from .validate import ContractError, load_json, validate_payload

VERSION = "nd-review-queue-1"
SCHEMA = Path(__file__).parent / "review_queue/v1/schema.json"
EXPECTED_IDS = {
    "A_N5": ["d3000000-0000-4000-8000-000000000001", "d4000000-0000-4000-8000-000000000001",
             "d5000000-0000-4000-8000-000000000001", "d3000000-0000-4000-8000-000000000002"],
    "A_LIMIT2": ["d3000000-0000-4000-8000-000000000001", "d4000000-0000-4000-8000-000000000001"],
    "A_N4": ["d3000000-0000-4000-8000-000000000003"],
    "B_N5": ["d3000000-0000-4000-8000-000000000001"],
    "C_EMPTY": [],
}


def validate_request(value):
    validate_payload("request", value, load_json(SCHEMA))


def validate_response(request, value):
    if isinstance(value, dict) and "code" in value:
        validate_payload("error", value)
        if value["retryable"] and value["code"] not in {
            "NETWORK_UNAVAILABLE", "PROVIDER_UNAVAILABLE", "RATE_LIMITED"
        }:
            raise ContractError("Nontransient queue error advertised retry")
        return
    validate_request(request)
    validate_payload("response", value, load_json(SCHEMA))
    if value["jlpt_level"] != request["jlpt_level"] or len(value["items"]) > request["limit"]:
        raise ContractError("Queue level/limit mismatch")
    keys, order = set(), []
    server = datetime.fromisoformat(value["server_time"])
    for item in value["items"]:
        key = (item["item_type"], item["item_id"].lower())
        due = datetime.fromisoformat(item["next_review_at"])
        if key in keys or due > server or not item["prompt_ja"].strip() or not item["answer_vi"].strip():
            raise ContractError("Duplicate, future or blank queue item")
        keys.add(key)
        order.append((due, *key))
    if order != sorted(order):
        raise ContractError("Queue order changed")


def validate_export(bundle):
    if set(bundle) != {"version", "cases"} or bundle["version"] != VERSION:
        raise ContractError("Queue export version/fields differ")
    cases = bundle["cases"]
    names = [case["name"] for case in cases]
    if len(names) != 7 or len(set(names)) != 7 or set(names) != set(EXPECTED_IDS) | {"NO_AUTH", "FORGED_OWNER"}:
        raise ContractError("Queue SQL export cases missing/duplicated")
    for case in cases:
        if set(case) != {"name", "request", "response"}:
            raise ContractError("Unexpected SQL export metadata")
        name, request, response = case["name"], case["request"], case["response"]
        expected_request = {"jlpt_level": "N4" if name == "A_N4" else "N5",
                            "limit": 2 if name == "A_LIMIT2" else 100}
        if name == "FORGED_OWNER":
            expected_request["user_id"] = "d1000000-0000-4000-8000-000000000002"
        if request != expected_request:
            raise ContractError("Native fixture request drift")
        validate_response(request, response)
        if name in EXPECTED_IDS:
            if "code" in response or [item["item_id"] for item in response["items"]] != EXPECTED_IDS[name]:
                raise ContractError("Native owner/filter/order projection differs")
            if name == "B_N5" and response["items"][0]["next_review_at"] != "2018-01-01T00:00:00.000000Z":
                raise ContractError("B received a different owner's history")
            if name == "A_N5" and (response["items"][1]["reading_ja"] != "" or
                                     response["items"][2]["reading_ja"] != "ニチ・ひ"):
                raise ContractError("Canonical/absent reading projection differs")
        elif response.get("code") != ("UNAUTHORIZED" if name == "NO_AUTH" else "VALIDATION_FAILURE"):
            raise ContractError("Auth/forged-owner case became success")
    return len(cases)


def read_export(path):
    def unique(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ContractError("Duplicate queue JSON member")
            value[key] = item
        return value
    def invalid_constant(value):
        raise ContractError(f"Invalid JSON constant {value}")
    return json.loads(Path(path).read_text(), object_pairs_hook=unique, parse_constant=invalid_constant)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 -m contracts.validate_review_queue OUTPUT.json")
    print(f"Validated {validate_export(read_export(sys.argv[1]))} queue projections; provenance is not certified by schema validation")
