#!/usr/bin/env python3
"""TEST ONLY: exercise a disposable local Supabase GoTrue + PostgREST stack.

This never connects to a hosted project and never prints credentials or tokens.
"""
from __future__ import annotations

import base64
import datetime as dt
import hashlib
import hmac
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


API_URL = os.environ["API_URL"].rstrip("/")
ANON_KEY = os.environ["ANON_KEY"]
JWT_SECRET = os.environ["JWT_SECRET"]
TEST_ITEM_ID = "00000000-0000-4000-8000-000000000001"


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


def create_user(label: str):
    email = f"{label}-{uuid.uuid4().hex}@example.com"
    password = f"Local-Only-{uuid.uuid4().hex[:20]}!"
    status, _ = request(
        "POST", "/auth/v1/signup", {"email": email, "password": password}
    )
    require(status in (200, 201), f"{label} GoTrue signup ({status})")
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


def rpc(name: str, request_body: dict, access_token: str):
    status, result = request(
        "POST",
        f"/rest/v1/rpc/{name}",
        {"p_request": request_body},
        access_token,
    )
    require(status == 200 and isinstance(result, dict), f"{name} RPC ({status})")
    return result


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


def review_request() -> dict:
    occurred_at = dt.datetime.now(dt.timezone.utc).isoformat(
        timespec="microseconds"
    ).replace("+00:00", "Z")
    return {
        "client_event_id": str(uuid.uuid4()),
        "item_type": "VOCABULARY",
        "item_id": TEST_ITEM_ID,
        "rating": 2,
        "is_correct": True,
        "response_ms": 1250,
        "occurred_at": occurred_at,
    }


def main() -> None:
    require(len(JWT_SECRET) >= 32, "local JWT verifier configuration")
    user_a = create_user("learner-a")
    user_b = create_user("learner-b")
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

    expired = expired_jwt(id_a)
    status, _ = request(
        "GET", "/rest/v1/profiles?select=id", access_token=expired
    )
    require(status in (401, 403), "expired signed JWT rejected by local API")

    request_a = review_request()
    first = rpc("submit_review", request_a, token_a)
    replay = rpc("submit_review", request_a, token_a)
    require(first == replay and first.get("review_count") == 1, "atomic replay")
    changed = dict(request_a, rating=3)
    conflict = rpc("submit_review", changed, token_a)
    require(error_code(conflict) == "SYNC_CONFLICT", "changed replay conflicts")

    request_b = review_request()
    result_b = rpc("submit_review", request_b, token_b)
    require(result_b.get("review_count") == 1, "independent B review")

    a_rows = rows(
        "user_learning_items", "id,user_id,item_id,review_count", "user_id", id_a, token_a
    )
    b_rows = rows(
        "user_learning_items", "id,user_id,item_id,review_count", "user_id", id_b, token_b
    )
    require(len(a_rows) == 1 and a_rows[0]["review_count"] == 1, "A own review row")
    require(len(b_rows) == 1 and b_rows[0]["review_count"] == 1, "B own review row")
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
        "POST", "/auth/v1/logout?scope=global", access_token=token_b
    )
    require(status in (200, 204), "B GoTrue logout")

    print(
        "Local Supabase GoTrue/PostgREST passed: two Auth users, refresh rotation, "
        "logout revocation, own-profile bootstrap, signed-expired JWT rejection, "
        "atomic review replay/conflict and A/B RLS isolation. LOCAL ONLY."
    )


if __name__ == "__main__":
    main()
