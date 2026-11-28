#!/usr/bin/env python3
"""TEST ONLY: exercise a disposable local Supabase GoTrue + PostgREST stack.

This never connects to a hosted project and never prints credentials or tokens.
"""
from __future__ import annotations

import base64
import concurrent.futures
import datetime as dt
import hashlib
import hmac
import json
import os
import re
import subprocess
import sys
import threading
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


API_URL = os.environ["API_URL"].rstrip("/")
ANON_KEY = os.environ["ANON_KEY"]
JWT_SECRET = os.environ["JWT_SECRET"]
TEST_ITEM_ID = "00000000-0000-4000-8000-000000000001"
TEST_DUE_ITEM_ID = "00000000-0000-4000-8000-000000000002"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Local Supabase integration failed: {message}")


def decode(raw: bytes):
    if not raw:
        return None
    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None


def request(method: str, path: str, payload=None, access_token: str | None = None):
    data = None if payload is None else json.dumps(
        payload, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    headers = {"apikey": ANON_KEY, "Accept": "application/json"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    if access_token is not None:
        headers["Authorization"] = f"Bearer {access_token}"
    req = urllib.request.Request(
        f"{API_URL}{path}", data=data, headers=headers, method=method
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            return response.status, decode(response.read())
    except urllib.error.HTTPError as error:
        return error.code, decode(error.read())
    except urllib.error.URLError:
        raise SystemExit("Local Supabase integration failed: service unavailable") from None


def error_code(body) -> str | None:
    if not isinstance(body, dict):
        return None
    value = body.get("code") or body.get("error_code") or body.get("error")
    return value if isinstance(value, str) else None


def password_login(email: str, password: str, label: str):
    status, session = request(
        "POST",
        "/auth/v1/token?grant_type=password",
        {"email": email, "password": password},
    )
    require(status == 200 and isinstance(session, dict), f"{label} password login")
    user = session.get("user")
    require(
        isinstance(user, dict)
        and isinstance(user.get("id"), str)
        and isinstance(session.get("access_token"), str)
        and isinstance(session.get("refresh_token"), str),
        f"{label} session shape",
    )
    return session


def create_user(label: str):
    email = f"{label}-{uuid.uuid4().hex}@example.com"
    password = f"Local-Only-{uuid.uuid4().hex[:20]}!"
    status, _ = request(
        "POST", "/auth/v1/signup", {"email": email, "password": password}
    )
    require(status in (200, 201), f"{label} GoTrue signup ({status})")
    return password_login(email, password, label), email, password


def verify_flutter_sdk_runtime(
    user_a: dict,
    email_a: str,
    password_a: str,
    user_b: dict,
    email_b: str,
    password_b: str,
) -> None:
    payload = {
        "api_url": API_URL,
        "anon_key": ANON_KEY,
        "user_a": {
            "id": user_a["user"]["id"],
            "email": email_a,
            "password": password_a,
        },
        "user_b": {
            "id": user_b["user"]["id"],
            "email": email_b,
            "password": password_b,
        },
    }
    app_dir = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "apps", "flutter_app")
    )
    try:
        with tempfile.TemporaryDirectory(prefix="nihongo-sdk-runtime-") as temp_dir:
            input_path = os.path.join(temp_dir, "input.json")
            descriptor = os.open(
                input_path,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                0o600,
            )
            with os.fdopen(descriptor, "w", encoding="utf-8") as input_file:
                json.dump(payload, input_file, separators=(",", ":"))
            require(
                os.stat(input_path).st_mode & 0o777 == 0o600,
                "local SDK probe input is owner-only",
            )
            child_env = os.environ.copy()
            for key in ("API_URL", "ANON_KEY", "DB_URL", "JWT_SECRET"):
                child_env.pop(key, None)
            child_env["NIHONGO_SUPABASE_SDK_RUNTIME_INPUT_FILE"] = input_path
            child = subprocess.run(
                [
                    "flutter",
                    "test",
                    "--no-pub",
                    "--reporter",
                    "expanded",
                    "tool/verify_supabase_sdk_runtime_test.dart",
                ],
                cwd=app_dir,
                env=child_env,
                text=True,
                capture_output=True,
                timeout=180,
                check=False,
            )
    except (OSError, subprocess.TimeoutExpired):
        require(False, "caller-owned Flutter SDK test-runner probe completed")
        return
    output = child.stdout + child.stderr
    require(
        all(
            secret not in output
            for secret in (email_a, password_a, email_b, password_b, ANON_KEY)
        ),
        "caller-owned Flutter SDK runtime probe redacts input credentials",
    )
    require(
        "eyJ" not in output
        and "Bearer " not in output
        and "Authorization:" not in output,
        "caller-owned Flutter SDK runtime probe does not expose token material",
    )
    safe_lines = []
    for line in child.stdout.splitlines():
        match = re.search(
            r"(LOCAL_SUPABASE_SDK_RUNTIME_(?:OK|FAILED:[a-z0-9-]+))",
            line,
        )
        if match is not None:
            safe_lines.append(match.group(1))
    safe_status = safe_lines[-1] if safe_lines else "missing-safe-status"
    if safe_status != "LOCAL_SUPABASE_SDK_RUNTIME_OK" and not re.fullmatch(
        r"LOCAL_SUPABASE_SDK_RUNTIME_FAILED:[a-z0-9-]+", safe_status
    ):
        safe_status = "invalid-safe-status"
    if safe_status != "LOCAL_SUPABASE_SDK_RUNTIME_OK":
        diagnostics = [
            line.strip()
            for line in (child.stderr + child.stdout).splitlines()
            if re.search(
                r"(^Error:|: Error:|^Error when reading|^Compilation failed|^Unhandled exception)",
                line,
            )
            and not any(
                secret in line
                for secret in (email_a, password_a, email_b, password_b, ANON_KEY)
            )
            and not any(
                marker in line
                for marker in ("eyJ", "Bearer ", "Authorization:")
            )
        ]
        for line in diagnostics[-8:]:
            print("Dart SDK runtime diagnostic (sanitized): " + line[:240])
    require(
        child.returncode == 0
        and safe_status == "LOCAL_SUPABASE_SDK_RUNTIME_OK",
        f"caller-owned Supabase SDK runtime ({safe_status})",
    )
    print(
        "Caller-owned Supabase SDK runtime passed: refresh-before-profile, "
        "NativeReviewJournal reopen/local replay, logout/clear ordering, A/B isolation, "
        "and two isolated runtime bundles for offline/reconnect stale-conflict recovery. LOCAL ONLY."
    )


def rpc(name: str, request_body: dict, access_token: str):
    status, result = request(
        "POST",
        f"/rest/v1/rpc/{name}",
        {"p_request": request_body},
        access_token,
    )
    require(status == 200 and isinstance(result, dict), f"{name} RPC ({status})")
    return result


def restore_child() -> None:
    """TEST ONLY child: restore a GoTrue session without logging its secret."""
    try:
        payload = json.loads(sys.stdin.read())
        if (
            not isinstance(payload, dict)
            or set(payload) != {"refresh_token", "expected_user_id"}
        ):
            raise ValueError()
        refresh_token = payload["refresh_token"]
        expected_user_id = payload["expected_user_id"]
        if (
            not isinstance(refresh_token, str)
            or not refresh_token
            or len(refresh_token) > 2048
            or not isinstance(expected_user_id, str)
        ):
            raise ValueError()
        status, session = request(
            "POST",
            "/auth/v1/token?grant_type=refresh_token",
            {"refresh_token": refresh_token},
        )
        if status != 200 or not isinstance(session, dict):
            raise ValueError()
        user = session.get("user")
        access_token = session.get("access_token")
        rotated_token = session.get("refresh_token")
        if (
            not isinstance(user, dict)
            or user.get("id") != expected_user_id
            or not isinstance(access_token, str)
            or not isinstance(rotated_token, str)
            or not rotated_token
            or rotated_token == refresh_token
        ):
            raise ValueError()
        profile = rpc("ensure_profile", {}, access_token)
        if profile.get("id") != expected_user_id:
            raise ValueError()
        sys.stdout.write(
            json.dumps(
                {
                    "ok": True,
                    "user_id": expected_user_id,
                    "refresh_token": rotated_token,
                },
                separators=(",", ":"),
            )
            + "\n"
        )
    except Exception:
        raise SystemExit("Local Supabase fresh-process restore failed") from None


def restore_in_fresh_process(refresh_token: str, expected_user_id: str) -> str:
    """Pass the test secret only through pipes; never write or print it."""
    try:
        child = subprocess.run(
            [sys.executable, os.path.abspath(__file__), "--restore-child"],
            input=json.dumps(
                {
                    "refresh_token": refresh_token,
                    "expected_user_id": expected_user_id,
                },
                separators=(",", ":"),
            ),
            text=True,
            capture_output=True,
            timeout=20,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        require(False, "fresh-process restore completed")
        return ""
    require(child.returncode == 0, "fresh-process restore completed")
    require(refresh_token not in child.stderr, "child does not log supplied refresh token")
    require(refresh_token not in child.stdout, "child output does not echo supplied refresh token")
    restored = decode(child.stdout.encode("utf-8"))
    require(
        isinstance(restored, dict)
        and set(restored) == {"ok", "user_id", "refresh_token"}
        and restored.get("ok") is True
        and restored.get("user_id") == expected_user_id,
        "fresh process restores rotated session and own profile",
    )
    rotated_token = restored["refresh_token"]
    require(
        isinstance(rotated_token, str)
        and rotated_token
        and rotated_token != refresh_token,
        "fresh process returns only the rotated refresh token",
    )
    return rotated_token


def rows(table: str, select: str, column: str, owner_id: str, access_token: str):
    query = urllib.parse.urlencode(
        {"select": select, column: f"eq.{owner_id}"}
    )
    status, result = request(
        "GET", f"/rest/v1/{table}?{query}", access_token=access_token
    )
    require(status == 200 and isinstance(result, list), f"{table} owner read ({status})")
    return result


def expired_jwt(owner_id: str) -> str:
    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "aud": "authenticated",
        "exp": now - 60,
        "iat": now - 120,
        "iss": "supabase",
        "role": "authenticated",
        "sub": owner_id,
    }

    def segment(value: dict) -> str:
        raw = json.dumps(value, separators=(",", ":")).encode("utf-8")
        return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")

    signing_input = f"{segment(header)}.{segment(payload)}"
    signature = hmac.new(
        JWT_SECRET.encode("utf-8"), signing_input.encode("ascii"), hashlib.sha256
    ).digest()
    encoded = base64.urlsafe_b64encode(signature).rstrip(b"=").decode("ascii")
    return f"{signing_input}.{encoded}"


def review_request(
    item_id: str = TEST_ITEM_ID,
    occurred_at: dt.datetime | None = None,
) -> dict:
    instant = occurred_at or dt.datetime.now(dt.timezone.utc)
    if instant.tzinfo is None or instant.utcoffset() is None:
        raise ValueError("Review event time must include a timezone")
    wire_time = instant.astimezone(dt.timezone.utc).isoformat(
        timespec="microseconds"
    ).replace("+00:00", "Z")
    return {
        "client_event_id": str(uuid.uuid4()),
        "item_type": "VOCABULARY",
        "item_id": item_id,
        "rating": 2,
        "is_correct": True,
        "response_ms": 1250,
        "occurred_at": wire_time,
    }


def main() -> None:
    require(len(JWT_SECRET) >= 32, "local JWT verifier configuration")
    user_a, email_a, password_a = create_user("learner-a")
    user_b, email_b, password_b = create_user("learner-b")
    id_a = user_a["user"]["id"]
    id_b = user_b["user"]["id"]
    token_a = user_a["access_token"]
    token_b = user_b["access_token"]

    profile_a = rpc("ensure_profile", {}, token_a)
    profile_b = rpc("ensure_profile", {}, token_b)
    require(profile_a.get("id") == id_a, "profile A derives verified Auth identity")
    require(profile_b.get("id") == id_b, "profile B derives verified Auth identity")

    status, spoofed = request(
        "POST",
        "/rest/v1/rpc/ensure_profile",
        {"p_request": {"user_id": id_b}},
        token_a,
    )
    require(
        status == 200 and error_code(spoofed) == "VALIDATION_FAILURE",
        "profile bootstrap rejects caller-supplied owner",
    )

    old_refresh = user_a["refresh_token"]
    status, rotated = request(
        "POST",
        "/auth/v1/token?grant_type=refresh_token",
        {"refresh_token": old_refresh},
    )
    require(status == 200 and isinstance(rotated, dict), "GoTrue refresh")
    require(
        isinstance(rotated.get("refresh_token"), str)
        and rotated["refresh_token"] != old_refresh,
        "GoTrue refresh-token rotation",
    )
    token_a = rotated["access_token"]
    require(
        rpc("ensure_profile", {}, token_a).get("id") == id_a,
        "rotated access token retains owner identity",
    )
    device_a = password_login(email_a, password_a, "learner-a second device")
    require(device_a["user"]["id"] == id_a, "two independent sessions share owner")
    token_a_device = device_a["access_token"]
    restart_session = password_login(
        email_a, password_a, "learner-a fresh-process restore"
    )
    restart_refresh = restore_in_fresh_process(
        restart_session["refresh_token"], id_a
    )

    expired = expired_jwt(id_a)
    status, _ = request(
        "GET", "/rest/v1/profiles?select=id", access_token=expired
    )
    require(status in (401, 403), "expired signed JWT rejected by local profile read")

    status, _ = request(
        "POST",
        "/rest/v1/rpc/ensure_profile",
        {"p_request": {}},
        expired,
    )
    require(status in (401, 403), "expired signed JWT rejected by profile bootstrap RPC")

    expired_review = review_request()
    status, _ = request(
        "POST",
        "/rest/v1/rpc/submit_review",
        {"p_request": expired_review},
        expired,
    )
    require(status in (401, 403), "expired signed JWT rejected by review RPC")
    status, _ = request(
        "POST",
        "/rest/v1/rpc/get_review_queue",
        {"p_request": {"jlpt_level": "N5", "limit": 100}},
        expired,
    )
    require(status in (401, 403), "expired signed JWT rejected by review queue RPC")
    require(
        rows(
            "review_events",
            "client_event_id",
            "client_event_id",
            expired_review["client_event_id"],
            token_a,
        ) == [],
        "expired JWT cannot append a review event",
    )
    require(
        rows("user_learning_items", "id", "user_id", id_a, token_a) == [],
        "expired JWT cannot create a learning item",
    )

    request_a = review_request()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as clients:
        first_call = clients.submit(rpc, "submit_review", request_a, token_a)
        second_call = clients.submit(
            rpc, "submit_review", request_a, token_a_device
        )
        first = first_call.result(timeout=20)
        concurrent_replay = second_call.result(timeout=20)
    require(
        first == concurrent_replay and first.get("review_count") == 1,
        "two independent sessions for one owner commit one identical review",
    )
    replay = rpc("submit_review", request_a, token_a_device)
    require(replay == first, "second-session retry returns original receipt")

    # A later review advances the owner's state. A delayed retry from the other
    # device must return the immutable first receipt without restoring old state.
    later_request = review_request()
    first_instant = dt.datetime.fromisoformat(
        request_a["occurred_at"].replace("Z", "+00:00")
    )
    later_instant = dt.datetime.fromisoformat(
        later_request["occurred_at"].replace("Z", "+00:00")
    )
    if later_instant <= first_instant:
        later_request["occurred_at"] = (
            first_instant + dt.timedelta(microseconds=1)
        ).isoformat(timespec="microseconds").replace("+00:00", "Z")
    later_result = rpc("submit_review", later_request, token_a)
    require(
        later_result.get("review_count") == 2,
        "later same-owner review advances authoritative state",
    )
    state_before_historical_replay = rows(
        "user_learning_items",
        "id,user_id,item_id,review_count,correct_count,incorrect_count,last_review_at,next_review_at",
        "user_id",
        id_a,
        token_a,
    )
    historical_replay = rpc("submit_review", request_a, token_a_device)
    require(
        historical_replay == first,
        "second-session historical retry returns original receipt after later review",
    )
    state_after_historical_replay = rows(
        "user_learning_items",
        "id,user_id,item_id,review_count,correct_count,incorrect_count,last_review_at,next_review_at",
        "user_id",
        id_a,
        token_a_device,
    )
    require(
        len(state_after_historical_replay) == 1
        and state_after_historical_replay[0]["review_count"] == 2
        and state_after_historical_replay == state_before_historical_replay,
        "historical retry cannot overwrite later server-authoritative state",
    )

    changed = dict(request_a, rating=3)
    conflict = rpc("submit_review", changed, token_a_device)
    require(
        error_code(conflict) == "SYNC_CONFLICT",
        "changed two-session replay conflicts",
    )
    occurred = dt.datetime.fromisoformat(
        request_a["occurred_at"].replace("Z", "+00:00")
    )
    stale = dict(
        request_a,
        client_event_id=str(uuid.uuid4()),
        occurred_at=(occurred - dt.timedelta(seconds=1))
        .isoformat(timespec="microseconds")
        .replace("+00:00", "Z"),
    )
    stale_result = rpc("submit_review", stale, token_a_device)
    require(
        error_code(stale_result) == "SYNC_CONFLICT",
        "second-session stale offline event is rejected",
    )

    # Two independent sessions for the same owner can race distinct offline
    # events on one item. The newer event always commits; the older event either
    # commits first or is rejected after the newer event advances server state.
    previous_time = dt.datetime.fromisoformat(
        later_request["occurred_at"].replace("Z", "+00:00")
    )
    race_base = max(
        dt.datetime.now(dt.timezone.utc),
        previous_time,
    ) + dt.timedelta(seconds=1)
    older_device_request = review_request(occurred_at=race_base)
    newer_device_request = review_request(
        occurred_at=race_base + dt.timedelta(seconds=1)
    )
    newer_device_request["rating"] = 1
    newer_device_request["response_ms"] = 1750
    device_barrier = threading.Barrier(2)

    def dispatch_device_event(request_body: dict, access_token: str):
        device_barrier.wait(timeout=10)
        return rpc("submit_review", request_body, access_token)

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as devices:
        older_call = devices.submit(
            dispatch_device_event, older_device_request, token_a
        )
        newer_call = devices.submit(
            dispatch_device_event, newer_device_request, token_a_device
        )
        older_device_result = older_call.result(timeout=20)
        newer_device_result = newer_call.result(timeout=20)

    older_device_code = error_code(older_device_result)
    require(
        older_device_code in (None, "SYNC_CONFLICT"),
        "older concurrent device event either commits first or is rejected as stale",
    )
    require(
        error_code(newer_device_result) is None,
        "newer concurrent device event remains authoritative",
    )
    older_device_accepted = older_device_code is None
    expected_device_count = 3 + int(older_device_accepted)
    require(
        (older_device_result.get("review_count") == 3)
        if older_device_accepted
        else older_device_result.get("code") == "SYNC_CONFLICT",
        "older device result reflects the observed lock order",
    )
    require(
        newer_device_result.get("review_count") == expected_device_count,
        "newer device receipt reports the monotonic server review count",
    )

    for device_request, accepted in (
        (older_device_request, older_device_accepted),
        (newer_device_request, True),
    ):
        event_rows = rows(
            "review_events",
            "client_event_id,user_id,rating,occurred_at",
            "client_event_id",
            device_request["client_event_id"],
            token_a,
        )
        require(
            len(event_rows) == (1 if accepted else 0),
            "each concurrent device event has exactly its accepted receipt",
        )
        if accepted:
            event_row = event_rows[0]
            require(
                event_row["user_id"] == id_a
                and event_row["rating"] == device_request["rating"]
                and dt.datetime.fromisoformat(
                    event_row["occurred_at"].replace("Z", "+00:00")
                )
                == dt.datetime.fromisoformat(
                    device_request["occurred_at"].replace("Z", "+00:00")
                ),
                "accepted device receipt preserves its immutable owner, rating and instant",
            )
        require(
            rows(
                "review_events",
                "client_event_id,user_id",
                "client_event_id",
                device_request["client_event_id"],
                token_b,
            )
            == [],
            "other owner cannot read either concurrent device receipt",
        )

    state_after_device_race = rows(
        "user_learning_items",
        "id,user_id,item_id,review_count,correct_count,incorrect_count,last_review_at,next_review_at",
        "user_id",
        id_a,
        token_a,
    )
    device_item_rows = [
        row for row in state_after_device_race if row["item_id"] == TEST_ITEM_ID
    ]
    require(
        len(device_item_rows) == 1
        and device_item_rows[0]["review_count"] == expected_device_count,
        "concurrent devices leave one server-authoritative item projection",
    )
    require(
        dt.datetime.fromisoformat(
            device_item_rows[0]["last_review_at"].replace("Z", "+00:00")
        )
        == dt.datetime.fromisoformat(
            newer_device_request["occurred_at"].replace("Z", "+00:00")
        ),
        "older device event never overwrites the newer authoritative timestamp",
    )
    second_device_state = rows(
        "user_learning_items",
        "id,user_id,item_id,review_count,correct_count,incorrect_count,last_review_at,next_review_at",
        "user_id",
        id_a,
        token_a_device,
    )
    require(
        [row for row in second_device_state if row["item_id"] == TEST_ITEM_ID]
        == device_item_rows,
        "both independent sessions observe the same authoritative review state",
    )

    # The idempotency key is owner-scoped, not global: B may use A's UUID
    # with a different valid payload and must receive B's own receipt.
    request_b = dict(request_a, rating=3)
    result_b = rpc("submit_review", request_b, token_b)
    require(
        error_code(result_b) is None and result_b.get("review_count") == 1,
        "B accepts the same client event UUID in its own owner scope",
    )
    replay_b = rpc("submit_review", request_b, token_b)
    require(replay_b == result_b, "B replay returns B's original receipt")
    changed_b = dict(request_b, rating=1)
    conflict_b = rpc("submit_review", changed_b, token_b)
    require(
        error_code(conflict_b) == "SYNC_CONFLICT",
        "B changed replay conflicts only within B's owner scope",
    )
    b_event_rows = rows(
        "review_events",
        "user_id,client_event_id,rating",
        "user_id",
        id_b,
        token_b,
    )
    require(
        len(b_event_rows) == 1
        and b_event_rows[0]["client_event_id"] == request_a["client_event_id"]
        and b_event_rows[0]["rating"] == 3,
        "B stores its own event under the shared UUID",
    )


    # Distinct owners may race on one client event UUID without sharing receipts.
    # The owner-scoped advisory/unique key must allow both transactions to commit.
    shared_event_id = str(uuid.uuid4())
    shared_time = max(
        dt.datetime.now(dt.timezone.utc),
        dt.datetime.fromisoformat(
            newer_device_request["occurred_at"].replace("Z", "+00:00")
        ),
    ) + dt.timedelta(seconds=1)
    shared_occurred_at = shared_time.isoformat(
        timespec="microseconds"
    ).replace("+00:00", "Z")
    concurrent_request_a = {
        "client_event_id": shared_event_id,
        "item_type": "VOCABULARY",
        "item_id": TEST_ITEM_ID,
        "rating": 2,
        "is_correct": True,
        "response_ms": 900,
        "occurred_at": shared_occurred_at,
    }
    concurrent_request_b = dict(
        concurrent_request_a,
        rating=1,
        response_ms=1750,
    )
    dispatch_barrier = threading.Barrier(2)

    def dispatch_shared(request_body: dict, access_token: str):
        dispatch_barrier.wait(timeout=10)
        return rpc("submit_review", request_body, access_token)

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as clients:
        call_a = clients.submit(
            dispatch_shared, concurrent_request_a, token_a
        )
        call_b = clients.submit(
            dispatch_shared, concurrent_request_b, token_b
        )
        concurrent_result_a = call_a.result(timeout=20)
        concurrent_result_b = call_b.result(timeout=20)
    require(
        error_code(concurrent_result_a) is None
        and concurrent_result_a.get("review_count") == expected_device_count + 1,
        "A commits its own payload while B races on the same event UUID",
    )
    require(
        error_code(concurrent_result_b) is None
        and concurrent_result_b.get("review_count") == 2,
        "B commits its own payload while A races on the same event UUID",
    )
    require(
        concurrent_result_a != concurrent_result_b,
        "both owners commit the shared event UUID concurrently without receipt collision",
    )
    replay_concurrent_a = rpc(
        "submit_review", concurrent_request_a, token_a
    )
    replay_concurrent_b = rpc(
        "submit_review", concurrent_request_b, token_b
    )
    require(
        replay_concurrent_a == concurrent_result_a
        and replay_concurrent_b == concurrent_result_b,
        "concurrent cross-owner retries return each owner's original receipt",
    )
    changed_concurrent_a = dict(concurrent_request_a, rating=3)
    changed_concurrent_b = dict(concurrent_request_b, rating=2)
    require(
        error_code(rpc("submit_review", changed_concurrent_a, token_a))
        == "SYNC_CONFLICT",
        "A changed replay conflicts only within A's owner scope",
    )
    require(
        error_code(rpc("submit_review", changed_concurrent_b, token_b))
        == "SYNC_CONFLICT",
        "B changed replay conflicts only within B's owner scope",
    )
    shared_rows_a = [
        row
        for row in rows(
            "review_events", "user_id,client_event_id,rating",
            "user_id", id_a, token_a
        )
        if row["client_event_id"] == shared_event_id
    ]
    shared_rows_b = [
        row
        for row in rows(
            "review_events", "user_id,client_event_id,rating",
            "user_id", id_b, token_b
        )
        if row["client_event_id"] == shared_event_id
    ]
    require(
        len(shared_rows_a) == 1
        and shared_rows_a[0]["user_id"] == id_a
        and shared_rows_a[0]["rating"] == 2,
        "A stores its own rating under the shared event UUID",
    )
    require(
        len(shared_rows_b) == 1
        and shared_rows_b[0]["user_id"] == id_b
        and shared_rows_b[0]["rating"] == 1,
        "B stores its own rating under the shared event UUID",
    )


    a_rows = rows(
        "user_learning_items",
        "id,user_id,item_id,review_count,correct_count,incorrect_count,last_review_at,next_review_at",
        "user_id",
        id_a,
        token_a,
    )
    a_device_rows = rows(
        "user_learning_items",
        "id,user_id,item_id,review_count,correct_count,incorrect_count,last_review_at,next_review_at",
        "user_id",
        id_a,
        token_a_device,
    )
    b_rows = rows(
        "user_learning_items", "id,user_id,item_id,review_count", "user_id", id_b, token_b
    )
    require(
        len(a_rows) == 1
        and a_rows[0]["review_count"] == expected_device_count + 1,
        "A own latest review row",
    )
    require(
        a_device_rows == a_rows,
        "both same-owner sessions read identical authoritative server state",
    )
    require(len(b_rows) == 1 and b_rows[0]["review_count"] == 2, "B own review row")
    require(
        rows("user_learning_items", "id", "user_id", id_a, token_b) == [],
        "B cannot read A review state",
    )
    require(
        rows("user_learning_items", "id", "user_id", id_b, token_a) == [],
        "A cannot read B review state",
    )
    require(
        rows("profiles", "id", "id", id_a, token_b) == [],
        "B cannot read A profile",
    )
    require(
        rows("profiles", "id", "id", id_b, token_a) == [],
        "A cannot read B profile",
    )

    # A second TEST ONLY vocabulary row lets two independent A sessions prove
    # the real PostgREST due-queue projection without mutating learner data.
    # The event is old enough for its NEW-card ten-minute interval to be due.
    due_instant = dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=2)
    due_request = review_request(TEST_DUE_ITEM_ID, due_instant)
    due_receipt = rpc("submit_review", due_request, token_a)
    require(due_receipt.get("review_count") == 1, "A creates one authoritative due-queue item")
    queue_request = {"jlpt_level": "N5", "limit": 100}
    state_before_queue = rows(
        "user_learning_items",
        "id,item_id,review_count,correct_count,incorrect_count,next_review_at",
        "user_id",
        id_a,
        token_a,
    )
    events_before_queue = rows("review_events", "client_event_id", "user_id", id_a, token_a)
    queue_a = rpc("get_review_queue", queue_request, token_a)
    queue_a_device = rpc("get_review_queue", queue_request, token_a_device)
    queue_b = rpc("get_review_queue", queue_request, token_b)
    queue_n4 = rpc("get_review_queue", {"jlpt_level": "N4", "limit": 100}, token_a)
    queue_limited = rpc("get_review_queue", {"jlpt_level": "N5", "limit": 1}, token_a)
    queue_fields = {"jlpt_level", "server_time", "items"}
    item_fields = {
        "item_type", "item_id", "prompt_ja", "reading_ja", "answer_vi", "next_review_at"
    }
    require(
        isinstance(queue_a, dict)
        and set(queue_a) == queue_fields
        and queue_a["jlpt_level"] == "N5"
        and isinstance(queue_a["server_time"], str)
        and isinstance(queue_a["items"], list),
        "A due-queue response has the exact bounded N5 envelope",
    )
    require(
        len(queue_a["items"]) == 1
        and isinstance(queue_a["items"][0], dict)
        and set(queue_a["items"][0]) == item_fields,
        "A due queue contains exactly one typed item",
    )
    due_item = queue_a["items"][0]
    require(
        due_item["item_type"] == "VOCABULARY"
        and due_item["item_id"] == TEST_DUE_ITEM_ID
        and due_item["prompt_ja"] == "同期テスト"
        and due_item["reading_ja"] == "どうきテスト"
        and due_item["answer_vi"] == "kiểm thử đồng bộ",
        "A due queue maps the original TEST ONLY curriculum projection",
    )
    try:
        server_time = dt.datetime.fromisoformat(queue_a["server_time"].replace("Z", "+00:00"))
        due_time = dt.datetime.fromisoformat(due_item["next_review_at"].replace("Z", "+00:00"))
    except (TypeError, ValueError, OverflowError):
        require(False, "A due-queue instants are parseable")
        server_time = due_time = dt.datetime.min.replace(tzinfo=dt.timezone.utc)
    require(
        server_time.tzinfo is not None and due_time.tzinfo is not None and due_time <= server_time,
        "A due-queue item is due by the captured server time",
    )
    require(
        isinstance(queue_a_device, dict)
        and set(queue_a_device) == queue_fields
        and queue_a_device["items"] == queue_a["items"],
        "A's independent second session reads the same authoritative due queue",
    )
    require(
        isinstance(queue_b, dict)
        and set(queue_b) == queue_fields
        and queue_b["jlpt_level"] == "N5"
        and queue_b["items"] == [],
        "B cannot see A's due queue",
    )
    require(
        isinstance(queue_n4, dict)
        and set(queue_n4) == queue_fields
        and queue_n4["items"] == [],
        "A's N4 queue excludes the N5 due item",
    )
    require(
        isinstance(queue_limited, dict)
        and set(queue_limited) == queue_fields
        and queue_limited["items"] == queue_a["items"],
        "The bounded limit returns the due item without reordering",
    )
    invalid_queue = rpc("get_review_queue", {"jlpt_level": "N5", "limit": 0}, token_a)
    require(error_code(invalid_queue) == "VALIDATION_FAILURE", "Due-queue read rejects an out-of-range limit")
    forged_queue = rpc(
        "get_review_queue", {"jlpt_level": "N5", "limit": 100, "user_id": id_b}, token_a
    )
    require(error_code(forged_queue) == "VALIDATION_FAILURE", "Due-queue read rejects a caller-supplied owner")
    state_after_queue = rows(
        "user_learning_items",
        "id,item_id,review_count,correct_count,incorrect_count,next_review_at",
        "user_id",
        id_a,
        token_a,
    )
    events_after_queue = rows("review_events", "client_event_id", "user_id", id_a, token_a)
    require(
        state_after_queue == state_before_queue and events_after_queue == events_before_queue,
        "Due-queue reads do not mutate scheduling state or review events",
    )

    verify_flutter_sdk_runtime(
        user_a, email_a, password_a, user_b, email_b, password_b
    )

    status, _ = request(
        "POST", "/auth/v1/logout?scope=global", access_token=token_a
    )
    require(status in (200, 204), "GoTrue logout")
    status, _ = request(
        "POST",
        "/auth/v1/token?grant_type=refresh_token",
        {"refresh_token": rotated["refresh_token"]},
    )
    require(status in (400, 401), "logout revokes rotated refresh token")
    status, _ = request(
        "POST",
        "/auth/v1/token?grant_type=refresh_token",
        {"refresh_token": device_a["refresh_token"]},
    )
    require(status in (400, 401), "global logout revokes second-device refresh token")
    status, _ = request(
        "POST",
        "/auth/v1/token?grant_type=refresh_token",
        {"refresh_token": restart_refresh},
    )
    require(
        status in (400, 401),
        "global logout revokes fresh-process rotated refresh token",
    )

    status, _ = request(
        "POST", "/auth/v1/logout?scope=global", access_token=token_b
    )
    require(status in (200, 204), "B GoTrue logout")

    print(
        "Local GoTrue/PostgREST due-queue sync passed: two Auth users, four independent "
        "password sessions, fresh-process refresh restoration, global logout revocation, "
        "profile bootstrap, expired-JWT queue rejection, concurrent same-owner replay, "
        "two-session concurrent distinct-event ordering and stale conflict, "
        "historical replay without state rollback, changed/stale conflicts, owner-scoped "
        "shared event IDs, same-owner cross-session due-queue projection, B isolation, "
        "level/limit filtering and read-only state. LOCAL ONLY."
    )


if __name__ == "__main__":
    if sys.argv[1:] == ["--restore-child"]:
        restore_child()
    elif not sys.argv[1:]:
        main()
    else:
        raise SystemExit("Local Supabase integration failed: invalid test mode")
