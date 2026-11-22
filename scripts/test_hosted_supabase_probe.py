"""Offline safety and protocol regressions for the manual hosted probe."""
from __future__ import annotations

import base64
import json
import unittest
from urllib.request import Request

from scripts.hosted_supabase_probe import (
    MAX_RESPONSE_BYTES,
    AuthSession,
    ProbeFailure,
    RawResponse,
    SupabaseHttp,
    decode_json,
    validate_origin,
    validate_publishable_key,
)


def legacy_key(role: str) -> str:
    payload = base64.urlsafe_b64encode(
        json.dumps({"role": role}).encode("utf-8")
    ).decode("ascii").rstrip("=")
    return "header." + payload + ".signature"


class HostedProbeValidationTests(unittest.TestCase):
    def test_origin_is_exact_https_supabase_host(self):
        self.assertEqual(
            validate_origin("https://example-ref.supabase.co"),
            "https://example-ref.supabase.co",
        )
        self.assertEqual(
            validate_origin("https://example-ref.supabase.co/"),
            "https://example-ref.supabase.co",
        )
        for value in (
            "http://example-ref.supabase.co",
            "https://example-ref.supabase.co.evil.test",
            "https://user@example-ref.supabase.co",
            "https://example-ref.supabase.co:443",
            "https://example-ref.supabase.co/path",
            "https://example-ref.supabase.co?next=evil",
        ):
            with self.subTest(value=value), self.assertRaises(ProbeFailure):
                validate_origin(value)

    def test_public_key_accepts_publishable_or_legacy_anon_only(self):
        publishable = "sb_publishable_" + "a" * 24
        anon = legacy_key("anon")
        self.assertEqual(validate_publishable_key(publishable), publishable)
        self.assertEqual(validate_publishable_key(anon), anon)
        for value in (legacy_key("service_role"), "not-a-key", "sb_publishable_short"):
            with self.subTest(value=value), self.assertRaises(ProbeFailure):
                validate_publishable_key(value)

    def test_duplicate_json_keys_are_rejected(self):
        with self.assertRaises(ProbeFailure):
            decode_json(b'{"role":"anon","role":"service_role"}')

    def test_session_repr_never_contains_token_values(self):
        session = AuthSession(
            "11111111-1111-4111-8111-111111111111",
            "ACCESS_TOKEN_SECRET",
            "REFRESH_TOKEN_SECRET",
        )
        rendered = repr(session)
        self.assertNotIn("ACCESS_TOKEN_SECRET", rendered)
        self.assertNotIn("REFRESH_TOKEN_SECRET", rendered)


class _FakeTransport:
    def __init__(self, response: RawResponse):
        self.response = response
        self.request: Request | None = None
        self.timeout: float | None = None

    def __call__(self, request: Request, timeout: float) -> RawResponse:
        self.request = request
        self.timeout = timeout
        return self.response


class HostedProbeHttpTests(unittest.TestCase):
    def test_request_binds_only_public_key_and_explicit_bearer(self):
        key = "sb_publishable_" + "a" * 24
        transport = _FakeTransport(RawResponse(200, b'{"ok":true}'))
        client = SupabaseHttp("https://example-ref.supabase.co", key, transport)
        response = client.request(
            "POST",
            "/rest/v1/rpc/ensure_profile",
            token="CAPTURED_ACCESS_TOKEN",
            payload={},
        )
        self.assertEqual(response.data, {"ok": True})
        assert transport.request is not None
        self.assertEqual(
            transport.request.get_header("Authorization"),
            "Bearer CAPTURED_ACCESS_TOKEN",
        )
        self.assertEqual(transport.request.get_header("Apikey"), key)
        self.assertEqual(transport.timeout, 15)

    def test_unauthenticated_request_has_no_bearer_header(self):
        transport = _FakeTransport(RawResponse(401, b""))
        client = SupabaseHttp(
            "https://example-ref.supabase.co",
            "sb_publishable_" + "a" * 24,
            transport,
        )
        response = client.request(
            "GET", "/rest/v1/profiles", allowed_status=(401, 403)
        )
        self.assertEqual(response.status, 401)
        assert transport.request is not None
        self.assertIsNone(transport.request.get_header("Authorization"))

    def test_redirect_is_rejected_without_following(self):
        transport = _FakeTransport(RawResponse(302, b""))
        client = SupabaseHttp(
            "https://example-ref.supabase.co",
            "sb_publishable_" + "a" * 24,
            transport,
        )
        with self.assertRaises(ProbeFailure) as caught:
            client.request("GET", "/rest/v1/profiles")
        self.assertEqual(caught.exception.code, "redirect_rejected")

    def test_http_error_body_is_never_exposed(self):
        secret = b"PRIVATE_TOKEN_MUST_NOT_APPEAR"
        transport = _FakeTransport(RawResponse(500, secret))
        client = SupabaseHttp(
            "https://example-ref.supabase.co",
            "sb_publishable_" + "a" * 24,
            transport,
        )
        with self.assertRaises(ProbeFailure) as caught:
            client.request("GET", "/rest/v1/profiles")
        self.assertNotIn(secret.decode(), str(caught.exception))

    def test_response_body_is_bounded(self):
        transport = _FakeTransport(RawResponse(200, b"x" * (MAX_RESPONSE_BYTES + 1)))
        client = SupabaseHttp(
            "https://example-ref.supabase.co",
            "sb_publishable_" + "a" * 24,
            transport,
        )
        with self.assertRaises(ProbeFailure) as caught:
            client.request("GET", "/rest/v1/profiles")
        self.assertEqual(caught.exception.code, "response_too_large")

    def test_arbitrary_hosts_and_paths_are_not_accepted(self):
        client = SupabaseHttp(
            "https://example-ref.supabase.co",
            "sb_publishable_" + "a" * 24,
            _FakeTransport(RawResponse(200, b"{}")),
        )
        with self.assertRaises(ProbeFailure):
            client.request("GET", "https://evil.example/profiles")
        with self.assertRaises(ProbeFailure):
            client.request("GET", "/rest/v1/../profiles")

    def test_http_error_message_contains_no_response_data(self):
        transport = _FakeTransport(RawResponse(503, b"password=not-for-logs"))
        client = SupabaseHttp(
            "https://example-ref.supabase.co",
            "sb_publishable_" + "a" * 24,
            transport,
        )
        with self.assertRaises(ProbeFailure) as caught:
            client.request("GET", "/rest/v1/profiles")
        self.assertEqual(str(caught.exception), "http_status")
        self.assertNotIn("not-for-logs", str(caught.exception))


if __name__ == "__main__":
    unittest.main(verbosity=2)
