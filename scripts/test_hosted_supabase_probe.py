#!/usr/bin/env python3
"""Offline regressions for the opt-in hosted Supabase acceptance probe."""
from __future__ import annotations
import base64,json,sys,unittest,urllib.parse
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import hosted_supabase_probe as probe
A="a1000000-0000-4000-8000-000000000001"
B="b2000000-0000-4000-8000-000000000002"

def segment(value):
    return base64.urlsafe_b64encode(json.dumps(value,separators=(",",":")).encode()).decode().rstrip("=")
def legacy_key(role):
    return segment({"alg":"HS256","typ":"JWT"})+"."+segment({"role":role})+".signature"
def config():
    return probe.Config("https://example-ref.supabase.co","sb_publishable_12345678901234567890",
                        "a@example.invalid","TEST_ONLY_PASSWORD_A",
                        "b@example.invalid","TEST_ONLY_PASSWORD_B")

class FakeSupabase:
    def __init__(self,*,leak=False,rotate=True,revoke=True,anonymous=False,fail_login=False):
        self.users={"a@example.invalid":A,"b@example.invalid":B}
        self.passwords={"a@example.invalid":"TEST_ONLY_PASSWORD_A","b@example.invalid":"TEST_ONLY_PASSWORD_B"}
        self.leak,self.rotate,self.revoke=leak,rotate,revoke
        self.anonymous,self.fail_login=anonymous,fail_login
        self.counter,self.refresh_owners,self.access_owners=0,{},{}
    def new_session(self,user,refresh=None):
        self.counter+=1
        access=f"TEST_ONLY_ACCESS_{self.counter}_{user}"
        token=refresh or f"TEST_ONLY_REFRESH_{self.counter}_{user}"
        self.access_owners[access]=user
        self.refresh_owners[token]=user
        return 200,{"user":{"id":user},"access_token":access,"refresh_token":token}
    def __call__(self,method,path,payload=None,access_token=None):
        if method=="POST" and path=="/auth/v1/token?grant_type=password":
            if self.fail_login:
                return 500,{"message":"SENSITIVE_PASSWORD_AND_TOKEN"}
            email=payload["email"]
            if self.passwords.get(email)!=payload["password"]:
                return 400,{"message":"invalid"}
            return self.new_session(self.users[email])
        if method=="POST" and path=="/auth/v1/token?grant_type=refresh_token":
            token=payload["refresh_token"]
            user=self.refresh_owners.get(token)
            if user is None:
                return 400,{"message":"invalid"}
            if self.rotate:
                self.refresh_owners.pop(token,None)
                return self.new_session(user)
            return self.new_session(user,token)
        if method=="POST" and path=="/rest/v1/rpc/ensure_profile":
            user=self.access_owners.get(access_token)
            if user is None:
                return 401,{"message":"unauthorized"}
            return 200,{"id":user,"display_name":"","preferred_jlpt":"N5",
                        "daily_target_minutes":120,"timezone":"Asia/Ho_Chi_Minh"}
        if method=="GET" and path.startswith("/rest/v1/profiles?"):
            if access_token is None:
                return (200,[]) if self.anonymous else (401,{"message":"unauthorized"})
            owner=self.access_owners.get(access_token)
            if owner is None:
                return 401,{"message":"unauthorized"}
            query=urllib.parse.parse_qs(urllib.parse.urlsplit(path).query)
            target=query.get("id",[""])[0].removeprefix("eq.")
            if self.leak and target!=owner:
                return 200,[{"id":target}]
            return 200,[{"id":owner}] if target==owner else []
        if method=="POST" and path=="/auth/v1/logout":
            owner=self.access_owners.get(access_token)
            if owner is None:
                return 401,{"message":"unauthorized"}
            if self.revoke:
                self.refresh_owners={t:u for t,u in self.refresh_owners.items() if u!=owner}
            return 204,None
        return 404,{"message":"not found"}

class HostedProbeTests(unittest.TestCase):
    def test_a_b_refresh_profile_rls_and_logout_flow(self):
        probe.run_probe(config(),FakeSupabase())
    def test_cross_owner_profile_visibility_fails(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"RLS exposed"):
            probe.run_probe(config(),FakeSupabase(leak=True))
    def test_refresh_must_rotate_token(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"did not rotate"):
            probe.run_probe(config(),FakeSupabase(rotate=False))
    def test_logout_must_revoke_rotated_refresh_token(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"remained usable"):
            probe.run_probe(config(),FakeSupabase(revoke=False))
    def test_anonymous_profile_read_must_be_denied(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"unauthenticated"):
            probe.run_probe(config(),FakeSupabase(anonymous=True))
    def test_server_error_body_is_redacted(self):
        with self.assertRaises(probe.ProbeFailure) as caught:
            probe.run_probe(config(),FakeSupabase(fail_login=True))
        self.assertNotIn("SENSITIVE",str(caught.exception))
        self.assertNotIn("TEST_ONLY_PASSWORD",str(caught.exception))

class HostedConfigTests(unittest.TestCase):
    def test_accepts_hosted_origin_and_publishable_or_anon_key(self):
        self.assertEqual(probe.project_origin("https://example-ref.supabase.co/"),"https://example-ref.supabase.co")
        self.assertEqual(probe.publishable_key(config().key),config().key)
        self.assertEqual(probe.publishable_key(legacy_key("anon")),legacy_key("anon"))
    def test_rejects_arbitrary_url_shapes(self):
        for value in ("http://example-ref.supabase.co","https://user:pass@example-ref.supabase.co",
                      "https://example-ref.supabase.co:8443","https://example-ref.supabase.co/path",
                      "https://example-ref.supabase.co?key=value","https://attacker.example","https://supabase.co"):
            with self.subTest(value=value),self.assertRaises(probe.ProbeFailure):
                probe.project_origin(value)
    def test_rejects_service_role_and_malformed_legacy_keys(self):
        with self.assertRaises(probe.ProbeFailure):
            probe.publishable_key(legacy_key("service_role"))
        with self.assertRaises(probe.ProbeFailure):
            probe.publishable_key("not-a-publishable-key")
    def test_environment_requires_distinct_accounts(self):
        values={"ND_STAGING_SUPABASE_URL":"https://example-ref.supabase.co",
                "ND_STAGING_SUPABASE_PUBLISHABLE_KEY":config().key,
                "ND_STAGING_USER_A_EMAIL":"a@example.invalid",
                "ND_STAGING_USER_A_PASSWORD":"TEST_ONLY_PASSWORD_A",
                "ND_STAGING_USER_B_EMAIL":"a@example.invalid",
                "ND_STAGING_USER_B_PASSWORD":"TEST_ONLY_PASSWORD_B"}
        with self.assertRaisesRegex(probe.ProbeFailure,"distinct"):
            probe.load_config(values)
    def test_missing_settings_name_only(self):
        with self.assertRaises(probe.ProbeFailure) as caught:
            probe.load_config({})
        self.assertIn("ND_STAGING_SUPABASE_URL",str(caught.exception))
        self.assertNotIn("TEST_ONLY",str(caught.exception))

if __name__=="__main__":
    unittest.main(verbosity=2)
