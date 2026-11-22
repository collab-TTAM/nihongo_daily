#!/usr/bin/env python3
"""Manual-only hosted Supabase Auth/RLS probe; never prints credentials or payloads."""
from __future__ import annotations

import base64
import json
import os
import re
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
from typing import Callable

REQUIRED_ENV = (
    "ND_STAGING_SUPABASE_URL",
    "ND_STAGING_SUPABASE_PUBLISHABLE_KEY",
    "ND_STAGING_USER_A_EMAIL",
    "ND_STAGING_USER_A_PASSWORD",
    "ND_STAGING_USER_B_EMAIL",
    "ND_STAGING_USER_B_PASSWORD",
)
PROFILE_COLUMNS = "id,display_name,preferred_jlpt,daily_target_minutes,timezone"
MAX_RESPONSE_BYTES = 1024 * 1024
TIMEOUT_SECONDS = 15
UUID_PATTERN = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
)


class ProbeFailure(Exception):
    """Fixed, redacted probe failure. Never attach HTTP bodies or secrets."""

    def __init__(self, code: str):
        self.code = code
        super().__init__(code)


@dataclass(frozen=True)
class RawResponse:
    status: int
    body: bytes


@dataclass(frozen=True)
class HttpResponse:
    status: int
    data: object | None


@dataclass(frozen=True)
class AuthSession:
    user_id: str
    access_token: str = field(repr=False)
    refresh_token: str = field(repr=False)


Transport = Callable[[Request, float], RawResponse]


def _reject_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def decode_json(raw: bytes) -> object:
    try:
        return json.loads(raw.decode("utf-8"), object_pairs_hook=_reject_duplicate_keys)
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError):
        raise ProbeFailure("malformed_response") from None


def validate_origin(value: str) -> str:
    try:
        parsed = urlsplit(value)
        host = parsed.hostname or ""
        if (
            parsed.scheme != "https"
            or parsed.username is not None
            or parsed.password is not None
            or parsed.port is not None
            or parsed.query
            or parsed.fragment
            or parsed.path not in ("", "/")
            or parsed.netloc != host
            or re.fullmatch(r"[a-z0-9-]{1,63}\.supabase\.co", host) is None
        ):
            raise ProbeFailure("invalid_origin")
        return "https://" + host
    except ValueError:
        raise ProbeFailure("invalid_origin") from None


def validate_publishable_key(value: str) -> str:
    if re.fullmatch(r"sb_publishable_[A-Za-z0-9_-]{16,512}", value):
        return value
    parts = value.split(".")
    if len(parts) != 3 or not parts[1]:
        raise ProbeFailure("invalid_public_key")
    try:
        payload = parts[1] + "=" * (-len(parts[1]) % 4)
        claims = json.loads(base64.urlsafe_b64decode(payload.encode("ascii")))
    except (ValueError, UnicodeEncodeError, json.JSONDecodeError):
        raise ProbeFailure("invalid_public_key") from None
    if not isinstance(claims, dict) or claims.get("role") != "anon":
        raise ProbeFailure("invalid_public_key")
    return value


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, file_pointer, code, message, headers, new_url):
        return None


def _default_transport(request: Request, timeout: float) -> RawResponse:
    opener = build_opener(_NoRedirect())
    try:
        with opener.open(request, timeout=timeout) as response:
            body = response.read(MAX_RESPONSE_BYTES + 1)
            if len(body) > MAX_RESPONSE_BYTES:
                raise ProbeFailure("response_too_large")
            return RawResponse(response.status, body)
    except HTTPError as error:
        error.close()
        return RawResponse(error.code, b"")
    except ProbeFailure:
        raise
    except (URLError, TimeoutError, OSError):
        raise ProbeFailure("network_unavailable") from None


class SupabaseHttp:
    def __init__(
        self,
        origin: str,
        public_key: str,
        transport: Transport = _default_transport,
    ):
        self.origin = validate_origin(origin)
        self.public_key = validate_publishable_key(public_key)
        self._transport = transport

    def request(
        self,
        method: str,
        path: str,
        *,
        token: str | None = None,
        payload: object | None = None,
        query: dict[str, str] | None = None,
        extra_headers: dict[str, str] | None = None,
        allowed_status: tuple[int, ...] = (200,),
    ) -> HttpResponse:
        if (
            method not in {"GET", "POST", "PATCH"}
            or not path.startswith(("/auth/v1/", "/rest/v1/"))
            or ".." in path
            or "?" in path
            or "#" in path
        ):
            raise ProbeFailure("invalid_request")
        url = self.origin + path
        if query:
            url += "?" + urlencode(query)
        headers = {
            "apikey": self.public_key,
            "Accept": "application/json",
            "Cache-Control": "no-store",
        }
        if token is not None:
            if not token or len(token) > 8192:
                raise ProbeFailure("invalid_session")
            headers["Authorization"] = "Bearer " + token
        data = None
        if payload is not None:
            try:
                data = json.dumps(
                    payload, ensure_ascii=False, separators=(",", ":")
                ).encode("utf-8")
            except (TypeError, ValueError):
                raise ProbeFailure("invalid_request") from None
            headers["Content-Type"] = "application/json"
        if extra_headers:
            headers.update(extra_headers)
        request = Request(url, data=data, headers=headers, method=method)
        response = self._transport(request, TIMEOUT_SECONDS)
        if response.status in (301, 302, 303, 307, 308):
            raise ProbeFailure("redirect_rejected")
        if response.status not in allowed_status:
            raise ProbeFailure("http_status")
        if len(response.body) > MAX_RESPONSE_BYTES:
            raise ProbeFailure("response_too_large")
        parsed = decode_json(response.body) if response.body else None
        return HttpResponse(response.status, parsed)

    def login(self, email: str, password: str) -> AuthSession:
        response = self.request(
            "POST",
            "/auth/v1/token",
            query={"grant_type": "password"},
            payload={"email": email, "password": password},
        )
        return _auth_session(response.data)

    def refresh(self, session: AuthSession) -> AuthSession:
        response = self.request(
            "POST",
            "/auth/v1/token",
            query={"grant_type": "refresh_token"},
            payload={"refresh_token": session.refresh_token},
        )
        refreshed = _auth_session(response.data)
        if (
            refreshed.user_id != session.user_id
            or refreshed.refresh_token == session.refresh_token
        ):
            raise ProbeFailure("refresh_rotation_failed")
        return refreshed

    def logout_local(self, session: AuthSession) -> None:
        self.request(
            "POST",
            "/auth/v1/logout",
            query={"scope": "local"},
            token=session.access_token,
            allowed_status=(200, 204),
        )


def _auth_session(value: object) -> AuthSession:
    if not isinstance(value, dict):
        raise ProbeFailure("invalid_auth_response")
    user = value.get("user")
    access = value.get("access_token")
    refresh = value.get("refresh_token")
    user_id = user.get("id") if isinstance(user, dict) else None
    if (
        not isinstance(user_id, str)
        or UUID_PATTERN.fullmatch(user_id) is None
        or not isinstance(access, str)
        or not access
        or len(access) > 8192
        or not isinstance(refresh, str)
        or not refresh
        or len(refresh) > 8192
    ):
        raise ProbeFailure("invalid_auth_response")
    return AuthSession(user_id, access, refresh)


def _profile(value: object, owner_id: str) -> dict[str, object]:
    expected = {"id", "display_name", "preferred_jlpt", "daily_target_minutes", "timezone"}
    if not isinstance(value, dict) or set(value) != expected or value.get("id") != owner_id:
        raise ProbeFailure("profile_contract_mismatch")
    if (
        value["preferred_jlpt"] not in {"N5", "N4", "N3", "N2", "N1"}
        or isinstance(value["daily_target_minutes"], bool)
        or not isinstance(value["daily_target_minutes"], int)
        or not 1 <= value["daily_target_minutes"] <= 1440
        or not isinstance(value["timezone"], str)
        or not value["timezone"]
        or (value["display_name"] is not None and not isinstance(value["display_name"], str))
    ):
        raise ProbeFailure("profile_contract_mismatch")
    return value


def ensure_profile(client: SupabaseHttp, session: AuthSession) -> dict[str, object]:
    response = client.request(
        "POST", "/rest/v1/rpc/ensure_profile", token=session.access_token, payload={}
    )
    return _profile(response.data, session.user_id)


def read_profile(
    client: SupabaseHttp, session: AuthSession, target_user_id: str
) -> list[dict[str, object]]:
    response = client.request(
        "GET",
        "/rest/v1/profiles",
        token=session.access_token,
        query={"select": PROFILE_COLUMNS, "id": "eq." + target_user_id},
    )
    if not isinstance(response.data, list):
        raise ProbeFailure("profile_read_malformed")
    return [_profile(row, target_user_id) for row in response.data]


def patch_preferred(
    client: SupabaseHttp,
    session: AuthSession,
    target_user_id: str,
    value: str,
    *,
    expect_row: bool,
) -> None:
    response = client.request(
        "PATCH",
        "/rest/v1/profiles",
        token=session.access_token,
        query={"id": "eq." + target_user_id},
        payload={"preferred_jlpt": value},
        extra_headers={"Prefer": "return=representation"},
        allowed_status=(200, 204),
    )
    if response.status == 204:
        return
    if expect_row:
        if not isinstance(response.data, list) or len(response.data) != 1:
            raise ProbeFailure("own_profile_update_failed")
        _profile(response.data[0], target_user_id)
    elif response.data not in (None, []):
        raise ProbeFailure("cross_owner_profile_update_visible")


def _read_learning_item(
    client: SupabaseHttp,
    session: AuthSession,
    owner_filter: str,
    item_id: str,
) -> dict[str, object] | None:
    response = client.request(
        "GET",
        "/rest/v1/user_learning_items",
        token=session.access_token,
        query={
            "select": "id,user_id,item_type,item_id,review_count,correct_count,incorrect_count",
            "user_id": "eq." + owner_filter,
            "item_type": "eq.VOCABULARY",
            "item_id": "eq." + item_id,
        },
    )
    if not isinstance(response.data, list) or len(response.data) > 1:
        raise ProbeFailure("learning_item_read_malformed")
    if not response.data:
        return None
    row = response.data[0]
    expected = {
        "id", "user_id", "item_type", "item_id",
        "review_count", "correct_count", "incorrect_count",
    }
    if (
        not isinstance(row, dict)
        or set(row) != expected
        or row["user_id"] != owner_filter
        or row["item_type"] != "VOCABULARY"
        or row["item_id"] != item_id
        or any(
            isinstance(row[name], bool) or not isinstance(row[name], int) or row[name] < 0
            for name in ("review_count", "correct_count", "incorrect_count")
        )
        or row["correct_count"] + row["incorrect_count"] != row["review_count"]
    ):
        raise ProbeFailure("learning_item_read_malformed")
    return row


def _read_review_events(
    client: SupabaseHttp,
    session: AuthSession,
    event_id: str,
) -> list[dict[str, object]]:
    response = client.request(
        "GET",
        "/rest/v1/review_events",
        token=session.access_token,
        query={
            "select": "user_id,client_event_id,learning_item_id,rating,is_correct",
            "client_event_id": "eq." + event_id,
        },
    )
    if not isinstance(response.data, list):
        raise ProbeFailure("review_event_read_malformed")
    for row in response.data:
        if (
            not isinstance(row, dict)
            or set(row) != {
                "user_id", "client_event_id", "learning_item_id", "rating", "is_correct"
            }
            or row["client_event_id"] != event_id
        ):
            raise ProbeFailure("review_event_read_malformed")
    return response.data


def _submit_review(
    client: SupabaseHttp, session: AuthSession, request: dict[str, object]
) -> dict[str, object]:
    response = client.request(
        "POST",
        "/rest/v1/rpc/submit_review",
        token=session.access_token,
        payload={"p_request": request},
    )
    if not isinstance(response.data, dict):
        raise ProbeFailure("review_response_malformed")
    return response.data


def _review_response(value: dict[str, object]) -> None:
    expected = {"srs_state", "next_review_at", "interval_days", "difficulty", "review_count"}
    if (
        set(value) != expected
        or value["srs_state"] not in {"LEARNING", "REVIEW", "RELEARNING"}
        or not isinstance(value["next_review_at"], str)
        or isinstance(value["review_count"], bool)
        or not isinstance(value["review_count"], int)
        or value["review_count"] < 1
        or isinstance(value["interval_days"], bool)
        or not isinstance(value["interval_days"], (int, float))
        or value["interval_days"] <= 0
        or isinstance(value["difficulty"], bool)
        or not isinstance(value["difficulty"], (int, float))
        or not 0 <= value["difficulty"] <= 1
    ):
        raise ProbeFailure("review_response_malformed")


def _restore_profile_preferences(
    client: SupabaseHttp,
    a2: AuthSession,
    b: AuthSession,
    original_a: object,
    original_b: object,
) -> None:
    restore_failed = False
    for session, original in ((a2, original_a), (b, original_b)):
        try:
            patch_preferred(
                client, session, session.user_id, str(original), expect_row=True
            )
            restored = read_profile(client, session, session.user_id)
            if len(restored) != 1 or restored[0]["preferred_jlpt"] != original:
                restore_failed = True
        except ProbeFailure:
            restore_failed = True
    if restore_failed:
        raise ProbeFailure("profile_restore_failed")


def _profile_settings_probe(
    client: SupabaseHttp,
    a1: AuthSession,
    a2: AuthSession,
    b: AuthSession,
) -> None:
    original_a = ensure_profile(client, a1)["preferred_jlpt"]
    original_b = ensure_profile(client, b)["preferred_jlpt"]
    restore_failed = False
    try:
        patch_preferred(client, a1, a1.user_id, "N4", expect_row=True)
        patch_preferred(client, b, b.user_id, "N4", expect_row=True)
        if read_profile(client, a1, a1.user_id)[0]["preferred_jlpt"] != "N4":
            raise ProbeFailure("own_profile_update_failed")
        if read_profile(client, b, b.user_id)[0]["preferred_jlpt"] != "N4":
            raise ProbeFailure("own_profile_update_failed")
        if ensure_profile(client, a1)["preferred_jlpt"] != "N4":
            raise ProbeFailure("profile_bootstrap_reset_setting")
        if ensure_profile(client, b)["preferred_jlpt"] != "N4":
            raise ProbeFailure("profile_bootstrap_reset_setting")

        patch_preferred(client, a1, b.user_id, "N5", expect_row=False)
        patch_preferred(client, b, a1.user_id, "N5", expect_row=False)
        if read_profile(client, b, b.user_id)[0]["preferred_jlpt"] != "N4":
            raise ProbeFailure("cross_owner_profile_update_succeeded")
        if read_profile(client, a1, a1.user_id)[0]["preferred_jlpt"] != "N4":
            raise ProbeFailure("cross_owner_profile_update_succeeded")
    finally:
        _restore_profile_preferences(client, a2, b, original_a, original_b)


def _review_probe(client: SupabaseHttp, a: AuthSession, b: AuthSession) -> None:
    item_response = client.request(
        "GET",
        "/rest/v1/vocabulary",
        token=a.access_token,
        query={
            "select": "id",
            "jlpt_level": "eq.N5",
            "is_active": "eq.true",
            "order": "id.asc",
            "limit": "1",
        },
    )
    if (
        not isinstance(item_response.data, list)
        or not item_response.data
        or not isinstance(item_response.data[0], dict)
        or set(item_response.data[0]) != {"id"}
        or not isinstance(item_response.data[0]["id"], str)
        or UUID_PATTERN.fullmatch(item_response.data[0]["id"]) is None
    ):
        raise ProbeFailure("active_n5_content_missing")
    item_id = item_response.data[0]["id"]

    before_a = _read_learning_item(client, a, a.user_id, item_id)
    before_b = _read_learning_item(client, b, b.user_id, item_id)
    count_a = 0 if before_a is None else int(before_a["review_count"])
    count_b = 0 if before_b is None else int(before_b["review_count"])
    correct_a = 0 if before_a is None else int(before_a["correct_count"])
    correct_b = 0 if before_b is None else int(before_b["correct_count"])
    incorrect_a = 0 if before_a is None else int(before_a["incorrect_count"])
    incorrect_b = 0 if before_b is None else int(before_b["incorrect_count"])
    event_id = str(uuid.uuid4())
    occurred_at = (
        datetime.now(timezone.utc) - timedelta(seconds=2)
    ).isoformat(timespec="microseconds").replace("+00:00", "Z")
    request = {
        "client_event_id": event_id,
        "item_type": "VOCABULARY",
        "item_id": item_id,
        "rating": 2,
        "is_correct": True,
        "response_ms": 100,
        "occurred_at": occurred_at,
    }

    first_a = _submit_review(client, a, request)
    _review_response(first_a)
    if first_a["review_count"] != count_a + 1:
        raise ProbeFailure("review_counter_not_incremented")
    if _submit_review(client, a, request) != first_a:
        raise ProbeFailure("review_replay_changed")
    changed = dict(request, rating=3)
    conflict = _submit_review(client, a, changed)
    if conflict.get("code") != "SYNC_CONFLICT":
        raise ProbeFailure("changed_review_replay_not_rejected")
    after_a = _read_learning_item(client, a, a.user_id, item_id)
    if (
        after_a is None
        or after_a["review_count"] != count_a + 1
        or after_a["correct_count"] != correct_a + 1
        or after_a["incorrect_count"] != incorrect_a
    ):
        raise ProbeFailure("review_replay_double_counted")

    first_b = _submit_review(client, b, request)
    _review_response(first_b)
    if first_b["review_count"] != count_b + 1:
        raise ProbeFailure("review_owner_isolation_failed")
    if _submit_review(client, b, request) != first_b:
        raise ProbeFailure("review_b_replay_changed")
    after_b = _read_learning_item(client, b, b.user_id, item_id)
    if (
        after_b is None
        or after_b["review_count"] != count_b + 1
        or after_b["correct_count"] != correct_b + 1
        or after_b["incorrect_count"] != incorrect_b
    ):
        raise ProbeFailure("review_b_counter_mismatch")

    events_a = _read_review_events(client, a, event_id)
    events_b = _read_review_events(client, b, event_id)
    if len(events_a) != 1 or events_a[0]["user_id"] != a.user_id:
        raise ProbeFailure("review_a_rls_failed")
    if len(events_b) != 1 or events_b[0]["user_id"] != b.user_id:
        raise ProbeFailure("review_b_rls_failed")
    if _read_learning_item(client, a, b.user_id, item_id) is not None:
        raise ProbeFailure("learning_item_cross_owner_read")
    if _read_learning_item(client, b, a.user_id, item_id) is not None:
        raise ProbeFailure("learning_item_cross_owner_read")

    unauthenticated = client.request(
        "POST",
        "/rest/v1/rpc/submit_review",
        payload={"p_request": request},
        allowed_status=(401, 403),
    )
    if unauthenticated.status not in (401, 403):
        raise ProbeFailure("unauthenticated_review_rpc_allowed")


def run_probe(environment: dict[str, str] | None = None) -> None:
    env = os.environ if environment is None else environment
    missing = [name for name in REQUIRED_ENV if not env.get(name)]
    if missing:
        raise ProbeFailure("configuration_missing")
    client = SupabaseHttp(
        env["ND_STAGING_SUPABASE_URL"],
        env["ND_STAGING_SUPABASE_PUBLISHABLE_KEY"],
    )
    sessions: dict[str, AuthSession | None] = {"a1": None, "a2": None, "b": None}
    cleanup_failed = False
    try:
        sessions["a1"] = client.login(
            env["ND_STAGING_USER_A_EMAIL"], env["ND_STAGING_USER_A_PASSWORD"]
        )
        sessions["a2"] = client.login(
            env["ND_STAGING_USER_A_EMAIL"], env["ND_STAGING_USER_A_PASSWORD"]
        )
        sessions["b"] = client.login(
            env["ND_STAGING_USER_B_EMAIL"], env["ND_STAGING_USER_B_PASSWORD"]
        )
        a1 = sessions["a1"]
        a2 = sessions["a2"]
        b = sessions["b"]
        if a1 is None or a2 is None or b is None:
            raise ProbeFailure("invalid_auth_response")
        if a1.user_id != a2.user_id or a1.user_id == b.user_id:
            raise ProbeFailure("test_accounts_not_distinct")

        sessions["a1"] = client.refresh(a1)
        sessions["a2"] = client.refresh(a2)
        sessions["b"] = client.refresh(b)
        a1 = sessions["a1"]
        a2 = sessions["a2"]
        b = sessions["b"]
        if a1 is None or a2 is None or b is None:
            raise ProbeFailure("invalid_auth_response")

        ensure_profile(client, a1)
        ensure_profile(client, b)
        if len(read_profile(client, a1, a1.user_id)) != 1:
            raise ProbeFailure("own_profile_read_failed")
        if len(read_profile(client, b, b.user_id)) != 1:
            raise ProbeFailure("own_profile_read_failed")
        if read_profile(client, a1, b.user_id) or read_profile(client, b, a1.user_id):
            raise ProbeFailure("cross_owner_profile_read")
        client.request(
            "GET",
            "/rest/v1/profiles",
            query={"select": "id", "id": "eq." + a1.user_id},
            allowed_status=(401, 403),
        )

        _profile_settings_probe(client, a1, a2, b)
        _review_probe(client, a1, b)

        client.logout_local(a1)
        sessions["a1"] = None
        sessions["a2"] = client.refresh(a2)
        sessions["b"] = client.refresh(b)
        a2 = sessions["a2"]
        b = sessions["b"]
        if a2 is None or b is None:
            raise ProbeFailure("invalid_auth_response")
        if len(read_profile(client, a2, a2.user_id)) != 1:
            raise ProbeFailure("second_a_session_invalidated")
        if len(read_profile(client, b, b.user_id)) != 1:
            raise ProbeFailure("user_b_session_invalidated")
    finally:
        for name in ("a1", "a2", "b"):
            session = sessions[name]
            if session is not None:
                try:
                    client.logout_local(session)
                except ProbeFailure:
                    cleanup_failed = True
                sessions[name] = None
        if cleanup_failed:
            raise ProbeFailure("session_cleanup_failed")


def main() -> int:
    try:
        run_probe()
    except ProbeFailure as failure:
        print("FAIL: hosted Supabase probe (" + failure.code + ")")
        return 1
    except Exception:
        print("FAIL: hosted Supabase probe (unexpected safe failure)")
        return 1
    print(
        "PASS: hosted Auth A/B, profile ownership/settings, refresh rotation, "
        "local logout isolation, submit_review idempotency and owner-only reads"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
