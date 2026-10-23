#!/usr/bin/env python3
"""TEST ONLY actual Edge user-isolate -> full assembly -> disposable PostgreSQL.

No live project/JWT/provider, production TLS override or arbitrary configuration.
Two capped containers plus a fresh restart, fixed loopback DB and no host env.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from uuid import uuid4

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_edge_user_worker import (  # noqa: E402
    docker, check, verify_runtime_metadata, EDGE_RUNTIME_METADATA, IMAGE,
)

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build/edge-postgres"
DATABASE = "postgresql://postgres:postgres@localhost:5432/nihongo_test"
OWNERS = {name: f"71000000-0000-4000-8000-00000000000{i + 1}"
          for i, name in enumerate(("A", "B", "text", "acquire", "complete", "malformed", "held", "serial"))}
SCENARIO = "72000000-0000-4000-8000-000000000001"
OTHER_SCENARIO = "72000000-0000-4000-8000-000000000002"
GRAMMAR = "73000000-0000-4000-8000-000000000001"
FIXTURES = json.loads((ROOT / "contracts/v0.1/fixtures.json").read_text())


def require_disposable_database(value: str | None) -> None:
    check(value == DATABASE, "Edge PostgreSQL probe requires the fixed disposable CI database")


def uuid_sql(value: object) -> str:
    check(type(value) is str and re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", value) is not None,
          "Invalid fixture UUID")
    return "'" + value + "'::uuid"


def sql(text: str) -> str:
    require_disposable_database(os.environ.get("TEST_DATABASE_URL"))
    result = subprocess.run(["psql", DATABASE, "-X", "-q", "-tA", "-v", "ON_ERROR_STOP=1"],
                            input=text, capture_output=True, text=True, timeout=10)
    check(result.returncode == 0, "Disposable PostgreSQL assertion command failed")
    return result.stdout.strip()


def seed() -> None:
    for owner in OWNERS.values():
        sql(f"INSERT INTO auth.users(id) VALUES({uuid_sql(owner)});"
            f"INSERT INTO public.profiles(id,preferred_jlpt) VALUES({uuid_sql(owner)},'N5');")
    for scenario in (SCENARIO, OTHER_SCENARIO):
        sql("INSERT INTO public.conversation_scenarios(id,jlpt_level,difficulty,content_version,is_active,title_vi,title_ja,description_vi,system_context) "
            f"VALUES({uuid_sql(scenario)},'N5',0,1,true,'fixture','会話','fixture','固定文脈');")
    sql("INSERT INTO public.grammar(id,jlpt_level,difficulty,content_version,is_active,title,pattern,meaning_vi,explanation_vi) "
        f"VALUES({uuid_sql(GRAMMAR)},'N5',0.2,1,true,'文法','～です','nghĩa','giải thích');")


def request(base: str, path: str, body: object = None, *, token: str = "A",
            expected: int = 200, method: str = "POST") -> object:
    check(re.fullmatch(r"http://127\.0\.0\.1:[0-9]{1,5}", base) is not None, "Probe requires loopback HTTP")
    headers = {"Content-Type": "application/json", "Authorization": "Bearer fixture-" + token}
    data = None if method == "GET" else json.dumps(body, ensure_ascii=False).encode()
    req = Request(base + path, data=data, headers=headers, method=method)
    try:
        response = urlopen(req, timeout=8)
    except HTTPError as error:
        response = error
    with response:
        check(response.status == expected, f"{path}: unexpected fixture HTTP status {response.status}")
        if not path.startswith("/__probe"):
            check(response.headers.get("cache-control") == "no-store", "Missing no-store")
            check(response.headers.get("x-content-type-options") == "nosniff", "Missing nosniff")
        raw = response.read(1048577)
        check(len(raw) <= 1048576, "Unbounded fixture response")
        check(b"PRIVATE" not in raw and b"fixture-" not in raw, "Private fixture detail leaked")
        return json.loads(raw)


def metadata(base: str) -> dict:
    value = request(base, "/__probe", method="GET")
    check(value["fixtureOnly"] is True and value["lane"] == "postgres-user-worker", "Wrong PostgreSQL worker lane")
    verify_runtime_metadata(value["runtime"], EDGE_RUNTIME_METADATA)
    return value


PHASES = {"none", "construct", "connect", "begin", "setup", "quota", "lookup", "reserve", "complete", "text", "commit", "probe", "query", "close", "idle"}
KINDS = {"unknown", "refused", "reset", "timeout", "permission", "unsupported", "missing-global", "auth", "protocol", "injected"}


def safe_metrics(value: object) -> dict:
    check(type(value) is dict and set(value) == {"normal", "acquire", "complete", "malformed", "held", "transport"}, "Invalid fixture metric lanes")
    for row in value.values():
        check(type(row) is dict and set(row) == {"calls", "opened", "closed", "injected", "phase", "failures"}, "Invalid fixture metric fields")
        check(all(type(row[k]) is int and 0 <= row[k] <= 1000 for k in ("calls", "opened", "closed")), "Invalid fixture metric counters")
        check(type(row["injected"]) is bool and type(row["phase"]) is str and row["phase"] in PHASES, "Invalid fixture metric phase")
        check(type(row["failures"]) is list and len(row["failures"]) <= 8, "Invalid fixture failure bound")
        for failure in row["failures"]:
            check(type(failure) is dict and set(failure) == {"phase", "kind"}, "Invalid fixture failure fields")
            check(type(failure["phase"]) is str and failure["phase"] in PHASES and type(failure["kind"]) is str and failure["kind"] in KINDS, "Invalid fixture failure category")
    return value


def print_safe_metrics(bases: list[str]) -> None:
    for base in bases:
        try:
            snapshot = safe_metrics(metadata(base)["metrics"])
            print("TEST ONLY allowlisted Edge PostgreSQL phases: " + json.dumps(snapshot, sort_keys=True))
        except Exception:
            # Never echo an exception/response/header/unknown metadata field.
            print("TEST ONLY Edge PostgreSQL phase snapshot unavailable")


def start(scenario: str = OTHER_SCENARIO) -> dict:
    return {"scenario_id": scenario, "jlpt_level": "N5", "client_event_id": str(uuid4())}


def receipt(owner: str, event: str) -> dict:
    return json.loads(sql("SELECT json_build_object('status',status,'response',response_json) "
                          f"FROM public.operation_receipts WHERE user_id={uuid_sql(OWNERS[owner])} "
                          f"AND client_event_id={uuid_sql(event)};"))


def distinct_events(a: str, b: str) -> list[tuple[str, dict, dict]]:
    """Actual held turn barrier, separate instance conflicts and durable order.

    Nine total HTTP quota attempts including three fresh-worker replays;
    no quota reset/refill timing or automatic AI mutation retry is required.
    """
    owner = uuid_sql(OWNERS["serial"])
    initial = request(a, "/start_conversation", start(), token="serial")
    session = uuid_sql(initial["session_id"])
    first = {"session_id": initial["session_id"], "client_event_id": str(uuid4()), "text_ja": "先の発言"}
    second = {**first, "client_event_id": str(uuid4()), "text_ja": "次の発言"}
    finish = {"session_id": initial["session_id"], "client_event_id": str(uuid4())}
    before = metadata(a)["metrics"]["held"]["calls"]
    other_calls = metadata(b)["metrics"]["normal"]["calls"]
    with ThreadPoolExecutor(max_workers=1) as pool:
        work = pool.submit(request, a, "/held_turn", first, token="serial")
        try:
            deadline = time.monotonic() + 3
            while metadata(a)["metrics"]["held"]["calls"] != before + 1:
                check(time.monotonic() < deadline, "Distinct-event held provider not reached")
                time.sleep(0.01)
            check(receipt("serial", first["client_event_id"])["status"] == "PENDING", "Held turn not durably reserved")
            for operation, body in (("conversation_turn", second), ("finish_conversation", finish)):
                error = request(b, "/" + operation, body, token="serial", expected=409)
                check(error["code"] == "SYNC_CONFLICT", "Distinct event bypassed pending session fence")
            check(metadata(b)["metrics"]["normal"]["calls"] == other_calls, "Distinct event dispatched before prior completion")
            # Observe through a separate admin connection while provider is held.
            state = json.loads(sql("SELECT json_build_object('slots',"
                                   "(SELECT array_agg(sequence_no ORDER BY sequence_no) FROM public.conversation_messages WHERE conversation_session_id=s.id),"
                                   "'ended',s.ended_at IS NOT NULL,'pending',"
                                   "(SELECT count(*) FROM private.ai_conversation_reservations WHERE session_id=s.id AND NOT is_completed),"
                                   "'rejected',(SELECT count(*) FROM public.operation_receipts "
                                   f"WHERE user_id={owner} AND client_event_id IN ({uuid_sql(second['client_event_id'])},{uuid_sql(finish['client_event_id'])}))) "
                                   f"FROM public.conversation_sessions s WHERE s.id={session};"))
            check(state == {"slots": [0], "ended": False, "pending": 1, "rejected": 0}, "Rejected distinct event left receipt or public mutation")
            check(sql("SELECT count(*) FROM pg_stat_activity WHERE application_name='nd-edge-pg' AND xact_start IS NOT NULL;") == "0", "Distinct-event provider held SQL transaction")
        finally:
            request(a, "/__probe/release", method="GET")
        first_result = work.result(timeout=8)
    check(first_result["assistant_message"]["sequence_no"] == 2, "Held turn sequence changed")
    # Explicit retry of the same formerly rejected IDs, only after prior COMMIT.
    second_result = request(b, "/conversation_turn", second, token="serial")
    check(second_result["assistant_message"]["sequence_no"] == 4, "Distinct retry skipped or reused sequence slots")
    final_result = request(b, "/finish_conversation", finish, token="serial")
    state = json.loads(sql("SELECT json_build_object('slots',"
                           "(SELECT array_agg(sequence_no ORDER BY sequence_no) FROM public.conversation_messages WHERE conversation_session_id=s.id),"
                           "'user_texts',(SELECT array_agg(text_ja ORDER BY sequence_no) FROM public.conversation_messages WHERE conversation_session_id=s.id AND role='user'),"
                           "'ended',s.ended_at IS NOT NULL,'completed',"
                           f"(SELECT count(*) FROM public.operation_receipts o JOIN private.ai_conversation_reservations r ON r.receipt_id=o.id WHERE o.user_id={owner} AND o.status='COMPLETED' AND r.is_completed),"
                           "'pending',(SELECT count(*) FROM private.ai_conversation_reservations WHERE session_id=s.id AND NOT is_completed)) "
                           f"FROM public.conversation_sessions s WHERE s.id={session};"))
    check(state == {"slots": [0, 1, 2, 3, 4], "user_texts": [first["text_ja"], second["text_ja"]], "ended": True, "completed": 4, "pending": 0}, "Distinct-event final committed state differs")
    check(metadata(a)["metrics"]["held"]["calls"] == before + 1 and metadata(b)["metrics"]["normal"]["calls"] == other_calls + 2, "Distinct-event dispatch count differs")
    return [("conversation_turn", first, first_result), ("conversation_turn", second, second_result), ("finish_conversation", finish, final_result)]


def probe(a: str, b: str, restart) -> dict:
    cases = []
    metadata(a)
    metadata(b)
    cases.append("actual-two-user-isolates-pinned-runtime")
    for base in (a, b):
        check(request(base, "/__probe/transport", method="GET") == {"fixtureOnly": True, "transport": True}, "PostgreSQL preflight failed")
    cases.append("actual-user-isolate-select1-idle-transport-preflight")
    tutor = request(a, "/tutor_explain?operation=forged", {
        "jlpt_level": "N5", "question_vi": "Giải thích",
        "context": {"recent_grammar_ids": [GRAMMAR], "recent_vocabulary_ids": []}}, token="text")
    check(tutor == FIXTURES["tutor_explain_response"], "Tutor wire changed")
    correction = request(a, "/correct_sentence", {"jlpt_level": "N5", "sentence_ja": "水を飲みます。"}, token="text")
    check(correction == FIXTURES["correct_sentence_response"], "Correction wire changed")
    req = start(SCENARIO)
    first = request(a, "/start_conversation", req)
    session = uuid_sql(first["session_id"])
    turn = {"session_id": first["session_id"], "client_event_id": str(uuid4()), "text_ja": "猫です"}
    second = request(a, "/conversation_turn", turn)
    check(second["assistant_message"]["sequence_no"] == 2, "Wrong assembled sequence")
    finish = {"session_id": first["session_id"], "client_event_id": str(uuid4())}
    third = request(a, "/finish_conversation", finish)
    lifecycle = [("start_conversation", req, first), ("conversation_turn", turn, second), ("finish_conversation", finish, third)]
    state = json.loads(sql("SELECT json_build_object('ended',s.ended_at IS NOT NULL,'slots',"
                           "(SELECT array_agg(sequence_no ORDER BY sequence_no) FROM public.conversation_messages WHERE conversation_session_id=s.id),"
                           "'receipts',(SELECT count(*) FROM public.operation_receipts o JOIN private.ai_conversation_reservations r ON r.receipt_id=o.id "
                           f"WHERE o.user_id=s.user_id AND o.status='COMPLETED' AND r.is_completed)) FROM public.conversation_sessions s WHERE s.id={session};"))
    check(state == {"ended": True, "slots": [0, 1, 2], "receipts": 3}, "Durable lifecycle differs")
    cases.append("all-five-http-operations-actual-committed-lifecycle")
    request(b, "/conversation_turn", turn, token="B", expected=404)
    request(b, "/start_conversation", {**start(), "user_id": OWNERS["B"]}, expected=400)
    request(b, "/start_conversation", start(), token="invalid", expected=401)
    sql(f"UPDATE public.conversation_scenarios SET is_active=false WHERE id={uuid_sql(SCENARIO)};"
        f"UPDATE public.profiles SET preferred_jlpt='N4' WHERE id={uuid_sql(OWNERS['A'])};")
    for op, body, value in lifecycle:
        check(request(b, "/" + op, body) == value, "Cross-instance original replay changed")
    check(all(x["calls"] == 0 for x in metadata(b)["metrics"].values()), "Cross-instance replay dispatched")
    cases.append("owner-denial-and-independent-instance-retired-source-replay")
    uncertain = {}
    for mode in ("acquire", "complete"):
        body = start()
        request(a, "/" + mode, body, token=mode, expected=503)
        saved = receipt(mode, body["client_event_id"])
        check(saved["status"] == ("PENDING" if mode == "acquire" else "COMPLETED"), "COMMIT durability ambiguity lost")
        stats = metadata(a)["metrics"][mode]
        check(stats["injected"] is True and stats["calls"] == (0 if mode == "acquire" else 1), "Wrong COMMIT dispatch fence")
        uncertain[mode] = (body, saved)
    cases.append("real-acquire-complete-commit-lost-delivery")
    malformed = start()
    request(a, "/malformed", malformed, token="malformed", expected=503)
    check(receipt("malformed", malformed["client_event_id"])["status"] == "PENDING", "Malformed result completed")
    check(sql(f"SELECT count(*) FROM public.conversation_sessions WHERE user_id={uuid_sql(OWNERS['malformed'])};") == "0", "Malformed public write")
    cases.append("malformed-result-durable-pending-safe-error")
    held = start()
    with ThreadPoolExecutor(max_workers=1) as pool:
        work = pool.submit(request, a, "/held", held, token="held")
        try:
            deadline = time.monotonic() + 3
            while metadata(a)["metrics"]["held"]["calls"] != 1:
                check(time.monotonic() < deadline, "Held fixture provider not reached")
                time.sleep(0.01)
            check(receipt("held", held["client_event_id"])["status"] == "PENDING", "Dispatch before durable reservation")
            check(sql("SELECT count(*) FROM pg_stat_activity WHERE application_name='nd-edge-pg' AND xact_start IS NOT NULL;") == "0", "Transaction held during provider")
            request(b, "/held", held, token="held", expected=503)
            check(metadata(b)["metrics"]["held"]["calls"] == 0, "Concurrent duplicate redispatched")
        finally:
            request(a, "/__probe/release", method="GET")
        held_result = work.result(timeout=8)
    check(request(b, "/held", held, token="held") == held_result, "Other instance failed durable replay")
    cases.append("actual-concurrent-isolates-one-dispatch-no-open-transaction")
    serial = distinct_events(a, b)
    cases.append("actual-distinct-events-pending-fence-rollback-ordered-retry")
    fresh = restart()
    check(all(x["calls"] == 0 for x in metadata(fresh)["metrics"].values()), "Restart did not create fresh worker")
    for op, body, value in lifecycle:
        check(request(fresh, "/" + op, body) == value, "Fresh worker lost lifecycle replay")
    for mode, (body, saved) in uncertain.items():
        value = request(fresh, "/" + mode, body, token=mode, expected=503 if mode == "acquire" else 200)
        if mode == "complete":
            check(value == saved["response"], "Fresh worker did not return committed original")
    request(fresh, "/malformed", malformed, token="malformed", expected=503)
    check(request(fresh, "/held", held, token="held") == held_result, "Fresh worker held replay changed")
    for op, body, value in serial:
        check(request(fresh, "/" + op, body, token="serial") == value, "Fresh worker distinct-event replay changed")
    stats = metadata(fresh)["metrics"]
    check(all(x["calls"] == 0 and x["opened"] == x["closed"] for x in stats.values()), "Restart redispatched or leaked connection")
    cases.append("fresh-container-restart-original-replay-pending-no-redispatch")
    return {"fixture_only": True, "runtime": EDGE_RUNTIME_METADATA, "cases": cases}


def cleanup(containers: list[str], *, diagnostics: bool) -> None:
    failed = False
    for container in containers:
        if diagnostics:
            try:
                logs = docker("logs", container, timeout=10)[-8000:]
                logs = re.sub(r"fixture-[A-Za-z]+|PRIVATE[^\n]*", "[redacted fixture]", logs)
                print("TEST ONLY bounded Edge PostgreSQL diagnostics:\n" + logs)
            except Exception:
                failed = True
        try:
            docker("rm", "--force", container, timeout=20)
        except Exception:
            failed = True
    check(not failed, "Fixture container cleanup or diagnostics failed")


def main() -> None:
    require_disposable_database(os.environ.get("TEST_DATABASE_URL"))
    bundle = BUILD / "worker/index.ts"
    check(bundle.is_file() and (BUILD / "main/index.ts").is_file(), "Build Edge PostgreSQL bundle/main first")
    docker("pull", IMAGE, timeout=180)
    info = json.loads(docker("image", "inspect", IMAGE))[0]
    check(info["RepoDigests"], "Missing registry image digest")
    version = docker("run", "--rm", "--network=none", info["Id"], "--version")
    check(re.fullmatch(r"edge-runtime 0\.1\.0\ndeno 2\.1\.4 \([^\n]+\)", version) is not None, "Wrong Edge binary")
    containers = []
    bases = []
    passed = False

    def launch() -> str:
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        # Isolated Actions job only. Host network reaches the fixed loopback pg
        # service; the HTTP listener is explicitly loopback, never all interfaces.
        container = docker("run", "-d", "--cap-drop=ALL", "--security-opt=no-new-privileges",
                           "--memory=512m", "--cpus=2", "--pids-limit=128", "--network=host", "--mount",
                           f"type=bind,src={BUILD},dst=/probe,readonly", info["Id"], "start", "--ip", "127.0.0.1",
                           "--port", str(port), "--policy", "per_worker", "--main-service", "/probe/main")
        containers.append(container)
        base = f"http://127.0.0.1:{port}"
        bases.append(base)
        deadline = time.monotonic() + 45
        while True:
            try:
                metadata(base)
                check(request(base, "/__probe/transport", method="GET") == {"fixtureOnly": True, "transport": True}, "PostgreSQL preflight failed")
                return base
            except (URLError, TimeoutError, ConnectionError):
                check(time.monotonic() < deadline, "Edge PostgreSQL worker not ready within bound")
                time.sleep(0.25)

    try:
        a, b = launch(), launch()
        seed()

        def restart() -> str:
            docker("rm", "--force", containers[0], timeout=20)
            containers.pop(0)
            bases.pop(0)
            return launch()

        evidence = probe(a, b, restart)
        checkout = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, check=True,
                                  capture_output=True, text=True, timeout=5).stdout.strip()
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text()) if "GITHUB_EVENT_PATH" in os.environ else {}
        source = event.get("pull_request", {}).get("head", {}).get("sha") or os.environ.get("GITHUB_SHA", checkout)
        check(re.fullmatch(r"[0-9a-f]{40}", source) is not None, "Missing source head")
        evidence.update(source_head=source, checkout_head=checkout, image=IMAGE, image_id=info["Id"],
                        repo_digests=info["RepoDigests"], edge_binary=version,
                        bundle_sha256=hashlib.sha256(bundle.read_bytes()).hexdigest(),
                        transport="TEST ONLY loopback plaintext PostgreSQL17; fixture Auth HTTP/provider")
        (BUILD / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
        passed = True
        print(json.dumps(evidence, indent=2))
        print(f"Supabase Edge PostgreSQL assembly: {len(evidence['cases'])} groups passed (TEST ONLY)")
    finally:
        try:
            if not passed:
                print_safe_metrics(bases)
        finally:
            cleanup(containers, diagnostics=not passed)


if __name__ == "__main__":
    main()
