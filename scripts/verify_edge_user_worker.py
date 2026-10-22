#!/usr/bin/env python3
"""Bounded TEST ONLY probe of the official Supabase Edge *user* worker.

No app endpoint, live Auth/provider/DB, secrets, host env forwarding, or retry of
AI operations. Docker owns one disposable container; cleanup never prunes others.
"""
from __future__ import annotations

import hashlib
import http.client
import json
import os
from pathlib import Path
import subprocess
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
IMAGE = "supabase/edge-runtime:v1.77.4"
BUNDLE = ROOT / "build/edge/worker/index.ts"
FIXTURES = json.loads((ROOT / "contracts/v0.1/fixtures.json").read_text())
OPERATIONS = ("tutor_explain", "correct_sentence", "start_conversation",
              "conversation_turn", "finish_conversation")


def docker(*args: str, timeout: int = 90) -> str:
    result = subprocess.run(["docker", *args], check=True, capture_output=True,
                            text=True, timeout=timeout)
    return (result.stdout + (result.stderr if args[0] == "logs" else "")).strip()


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def probe(base: str) -> dict:
    cases: list[str] = []

    def request(path: str, body: object = None, *, token: str | None = "fixture-A",
                method: str = "POST", expected: int = 200) -> object:
        headers = {"Content-Type": "application/json"}
        if token is not None:
            headers["Authorization"] = "Bearer " + token
        data = None if method == "GET" else json.dumps(body, ensure_ascii=False).encode()
        req = Request(base + path, data=data, headers=headers, method=method)
        try:
            response = urlopen(req, timeout=8)
        except HTTPError as error:
            response = error
        with response:
            check(response.status == expected, f"{path}: unexpected HTTP status {response.status}")
            # Native service headers must survive both main and user isolates.
            if not path.startswith("/__probe"):
                check(response.headers.get("cache-control") == "no-store", "Missing no-store")
                check(response.headers.get("x-content-type-options") == "nosniff", "Missing nosniff")
            raw = response.read(1048577)
            check(len(raw) <= 1048576, "Unbounded probe response")
            check(b"TEST ONLY must never escape" not in raw, "Provider error leaked")
            check(b"TEST-ONLY-CLAIM" not in raw, "Internal claim leaked")
            check(b"fixture-A" not in raw and b"fixture-B" not in raw, "Bearer leaked")
            return json.loads(raw)

    metadata = request("/__probe", method="GET")
    check(metadata["fixtureOnly"] is True and metadata["lane"] == "user-worker", "Wrong worker lane")
    check(set(metadata["runtime"]) == {"deno", "v8", "typescript"}, "Missing actual worker runtime version")
    cases.append("actual-user-worker-runtime")
    for op in OPERATIONS:
        result = request("/" + op + "?operation=untrusted", FIXTURES[op + "_request"])
        check(result == FIXTURES[op + "_response"], f"{op}: wire changed")
    cases.append("all-five-original-wire-and-fixed-operation")
    # Same original event replays without another dispatch; A and B stay distinct.
    original = FIXTURES["start_conversation_request"]
    request("/start_conversation", original)
    stats = request("/__probe", method="GET")["metrics"]["/start_conversation"]
    check(stats["calls"] == 1 and stats["completions"] == 1, "Replay redispatched")
    request("/start_conversation", original, token="fixture-B")
    stats = request("/__probe", method="GET")["metrics"]["/start_conversation"]
    check(stats["calls"] == 2 and stats["completions"] == 2, "A/B receipt isolation failed")
    cases.append("fixture-replay-and-owner-isolation")
    request("/start_conversation", original, token=None, expected=401)
    request("/start_conversation", original, token="invalid", expected=401)
    request("/start_conversation", method="GET", expected=405)
    result = request("/start_conversation", {**original, "user_id": "forged"}, expected=400)
    check(result["code"] == "VALIDATION_FAILURE", "Unknown owner field accepted")
    cases.append("unauthorized-method-and-strict-schema")
    # Real chunked multibyte body, no content length; reject before Auth/dispatch.
    before = request("/__probe", method="GET")["metrics"]["/start_conversation"]
    connection = http.client.HTTPConnection(base.removeprefix("http://"), timeout=8)
    try:
        connection.request("POST", "/start_conversation", body=iter([("界" * 100).encode()] * 120),
                           headers={"Content-Type": "application/json", "Authorization": "Bearer fixture-A"},
                           encode_chunked=True)
        response = connection.getresponse()
        check(response.status == 413, "Chunked byte bound failed")
        check(json.loads(response.read(4096))["code"] == "VALIDATION_FAILURE", "Wrong oversized-body error")
    finally:
        connection.close()
    after = request("/__probe", method="GET")["metrics"]["/start_conversation"]
    check(before == after, "Oversize reached Auth/provider/receipts")
    cases.append("chunked-multibyte-32KiB-before-auth")
    result = request("/malformed", original, expected=503)
    check(result["code"] == "PROVIDER_UNAVAILABLE", "Malformed output accepted")
    stats = request("/__probe", method="GET")["metrics"]["/malformed"]
    check(stats["calls"] == 1 and stats["completions"] == 0, "Malformed output committed")
    cases.append("strict-provider-schema-and-safe-error")
    result = request("/late", original, expected=504)
    check(result["code"] == "PROVIDER_UNAVAILABLE", "Deadline lost across isolates")
    stats = request("/__probe/release-late", method="GET")["metrics"]["/late"]
    check(stats["aborted"] is True and stats["completions"] == 0, "Late result crossed completion fence")
    request("/late", original, expected=503)
    stats = request("/__probe", method="GET")["metrics"]["/late"]
    check(stats["calls"] == 1 and stats["completions"] == 0, "Pending retry redispatched")
    cases.append("deadline-private-abort-late-result-no-redispatch")
    return {"fixture_only": True, "runtime": metadata["runtime"], "cases": cases}


def main() -> None:
    check(BUNDLE.is_file() and (BUNDLE.parents[1] / "main/index.ts").is_file(), "Build Edge bundle and main first")
    # Test-only image tag is fixed; resolve then launch the immutable local image ID.
    docker("pull", IMAGE, timeout=180)
    info = json.loads(docker("image", "inspect", IMAGE))[0]
    check(info["RepoDigests"], "Missing registry image digest")
    version = docker("run", "--rm", "--network=none", info["Id"], "--version")
    check("1.77.4" in version, "Unexpected Edge Runtime binary")
    container = ""
    passed = False
    try:
        container = docker("run", "-d", "--cap-drop=ALL", "--security-opt=no-new-privileges",
                           "--memory=512m", "--cpus=2", "--pids-limit=128",
                           "--publish=127.0.0.1::9000", "--mount",
                           f"type=bind,src={BUNDLE.parents[1]},dst=/probe,readonly",
                           info["Id"], "start", "--policy", "per_worker", "--main-service", "/probe/main")
        port = docker("port", container, "9000/tcp")
        check(port.startswith("127.0.0.1:") and "\n" not in port, "Unexpected exposed port")
        base = "http://" + port
        deadline = time.monotonic() + 45
        while True:
            try:
                with urlopen(base + "/__probe", timeout=2) as response:
                    check(response.status == 200, "Worker readiness failed")
                    break
            except (URLError, TimeoutError, ConnectionError):
                if time.monotonic() >= deadline:
                    raise AssertionError("Edge user worker not ready within 45 seconds") from None
                time.sleep(0.25)
        evidence = probe(base)
        checkout_head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, check=True,
                                       capture_output=True, text=True, timeout=5).stdout.strip()
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text()) if "GITHUB_EVENT_PATH" in os.environ else {}
        source_head = event.get("pull_request", {}).get("head", {}).get("sha") or os.environ.get("GITHUB_SHA", checkout_head)
        check(len(source_head) == 40 and all(c in "0123456789abcdef" for c in source_head), "Missing source head")
        evidence.update(source_head=source_head, checkout_head=checkout_head)
        evidence.update(image=IMAGE, image_id=info["Id"], repo_digests=info["RepoDigests"],
                        edge_binary=version, bundle_sha256=hashlib.sha256(BUNDLE.read_bytes()).hexdigest())
        destination = ROOT / "build/edge/evidence.json"
        destination.write_text(json.dumps(evidence, indent=2) + "\n")
        passed = True
        print(json.dumps(evidence, indent=2))
        print(f"Supabase Edge user-worker probe: {len(evidence['cases'])} cases passed (TEST ONLY)")
    finally:
        if container:
            try:
                if not passed:
                    # Fixture constants only; redact even those from startup diagnostics.
                    logs = docker("logs", container, timeout=10)[-8000:]
                    for marker in ("fixture-A", "fixture-B", "TEST-ONLY-CLAIM",
                                   "TEST ONLY must never escape"):
                        logs = logs.replace(marker, "[redacted fixture]")
                    print("TEST ONLY bounded Edge startup diagnostics:\n" + logs)
            finally:
                docker("rm", "--force", container, timeout=20)


if __name__ == "__main__":
    main()
