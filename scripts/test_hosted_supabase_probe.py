#!/usr/bin/env python3
"""Offline regressions for the opt-in hosted Supabase acceptance probe."""
from __future__ import annotations
import base64,json,re,sys,unittest,urllib.parse
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
    def __init__(self,*,leak=False,rotate=True,revoke=True,anonymous=False,fail_login=False,
                 refresh_identity_mismatch=False,accepted_overrides=(),cross_update=False,
                 reset_profile_settings=False,review_leak=False,no_active_content=False,
                 accept_changed_review=False,mutate_review_replay=False,anonymous_review=False):
        self.users={"a@example.invalid":A,"b@example.invalid":B}
        self.passwords={"a@example.invalid":"TEST_ONLY_PASSWORD_A","b@example.invalid":"TEST_ONLY_PASSWORD_B"}
        self.leak,self.rotate,self.revoke=leak,rotate,revoke
        self.anonymous,self.fail_login=anonymous,fail_login
        self.refresh_identity_mismatch=refresh_identity_mismatch
        self.refresh_identity_mismatch_used=False
        self.accepted_overrides=set(accepted_overrides)
        self.cross_update,self.reset_profile_settings=cross_update,reset_profile_settings
        self.profiles=set()
        self.preferences={}
        self.counter,self.refresh_owners,self.access_owners=0,{},{}
        self.logout_scopes=[]
        self.review_leak=review_leak
        self.no_active_content=no_active_content
        self.accept_changed_review=accept_changed_review
        self.mutate_review_replay=mutate_review_replay
        self.anonymous_review=anonymous_review
        self.review_item="c3000000-0000-4000-8000-000000000003"
        self.review_cards={}
        self.review_events={}
    def new_session(self,user,refresh=None,session_id=None):
        self.counter+=1
        session_id=session_id or f"TEST_ONLY_SESSION_{self.counter}"
        access=f"TEST_ONLY_ACCESS_{self.counter}_{user}"
        token=refresh or f"TEST_ONLY_REFRESH_{self.counter}_{user}"
        self.access_owners[access]=(user,session_id)
        self.refresh_owners[token]=(user,session_id)
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
            identity=self.refresh_owners.get(token)
            if identity is None:
                return 400,{"message":"invalid"}
            user,session_id=identity
            if self.refresh_identity_mismatch and not self.refresh_identity_mismatch_used:
                self.refresh_identity_mismatch_used=True
                self.refresh_owners.pop(token,None)
                return self.new_session(B)
            if self.rotate:
                self.refresh_owners.pop(token,None)
                return self.new_session(user,session_id=session_id)
            return self.new_session(user,token,session_id)
        if method=="GET" and path.startswith("/rest/v1/vocabulary?"):
            identity=self.access_owners.get(access_token)
            if identity is None:
                return 401,{"message":"unauthorized"}
            if self.no_active_content:
                return 200,[]
            return 200,[{"id":self.review_item}]
        if method=="POST" and path=="/rest/v1/rpc/submit_review":
            identity=self.access_owners.get(access_token)
            if identity is None:
                if self.anonymous_review:
                    return 200,{"srs_state":"LEARNING","next_review_at":"2026-01-01T00:10:00.000000Z",
                                "interval_days":10.0/1440,"difficulty":0.48,"review_count":1}
                return 401,{"message":"unauthorized"}
            owner=identity[0]
            payload=payload.get("p_request") if isinstance(payload,dict) else None
            if not isinstance(payload,dict):
                return 200,{"code":"VALIDATION_FAILURE","message_vi":"Dữ liệu ôn tập không hợp lệ.","retryable":False}
            event_key=(owner,payload.get("client_event_id"))
            previous=self.review_events.get(event_key)
            if previous is not None:
                previous_request,previous_response=previous
                if previous_request!=payload:
                    if self.accept_changed_review:
                        return 200,dict(previous_response)
                    return 200,{"code":"SYNC_CONFLICT",
                                "message_vi":"Lượt ôn tập xung đột với dữ liệu đã lưu.","retryable":False}
                response=dict(previous_response)
                if self.mutate_review_replay:
                    response["review_count"]+=1
                return 200,response
            card_key=(owner,payload.get("item_type"),payload.get("item_id"))
            card=self.review_cards.get(card_key,{"review_count":0,"correct_count":0,"incorrect_count":0})
            next_card={
                "review_count":card["review_count"]+1,
                "correct_count":card["correct_count"]+(1 if payload.get("is_correct") is True else 0),
                "incorrect_count":card["incorrect_count"]+(1 if payload.get("is_correct") is False else 0),
            }
            response={
                "srs_state":"LEARNING",
                "next_review_at":"2026-01-01T00:10:00.000000Z",
                "interval_days":10.0/1440,
                "difficulty":0.48,
                "review_count":next_card["review_count"],
            }
            self.review_cards[card_key]=next_card
            self.review_events[event_key]=(dict(payload),dict(response))
            return 200,response
        if method=="POST" and path=="/rest/v1/rpc/ensure_profile":
            identity=self.access_owners.get(access_token)
            if identity is None:
                return 401,{"message":"unauthorized"}
            user=identity[0]
            p_request=payload.get("p_request") if isinstance(payload,dict) else None
            if p_request!={}:
                fields=set(p_request) if isinstance(p_request,dict) else set()
                if fields.intersection(self.accepted_overrides):
                    owner=p_request.get("id",user)
                    metadata=p_request.get("user_metadata")
                    display=p_request.get("display_name","")
                    if isinstance(metadata,dict):
                        display=metadata.get("display_name",display)
                    self.profiles.add(owner)
                    return 200,{"id":owner,"display_name":display,"preferred_jlpt":"N5",
                                "daily_target_minutes":120,"timezone":"Asia/Ho_Chi_Minh"}
                return 200,{"code":"VALIDATION_FAILURE",
                            "message_vi":"Yêu cầu hồ sơ không hợp lệ.","retryable":False}
            if user not in self.profiles:
                self.profiles.add(user)
                self.preferences[user]="N5"
            elif self.reset_profile_settings:
                self.preferences[user]="N5"
            return 200,{"id":user,"display_name":"","preferred_jlpt":self.preferences[user],
                        "daily_target_minutes":120,"timezone":"Asia/Ho_Chi_Minh"}
        if method=="GET" and path.startswith("/rest/v1/user_learning_items?"):
            identity=self.access_owners.get(access_token)
            if identity is None:
                return 401,{"message":"unauthorized"}
            actor=identity[0]
            query=urllib.parse.parse_qs(urllib.parse.urlsplit(path).query)
            item_id=query.get("item_id",[""])[0].removeprefix("eq.")
            item_type=query.get("item_type",[""])[0].removeprefix("eq.")
            user_filter=query.get("user_id",[""])[0].removeprefix("eq.")
            rows=[]
            for (owner,kind,content_id),card in self.review_cards.items():
                if content_id!=item_id or kind!=item_type:
                    continue
                if user_filter and owner!=user_filter:
                    continue
                if not self.review_leak and owner!=actor:
                    continue
                rows.append({"user_id":owner,"item_type":kind,"item_id":content_id,**card})
            return 200,rows
        if method=="GET" and path.startswith("/rest/v1/review_events?"):
            identity=self.access_owners.get(access_token)
            if identity is None:
                return 401,{"message":"unauthorized"}
            actor=identity[0]
            query=urllib.parse.parse_qs(urllib.parse.urlsplit(path).query)
            event_id=query.get("client_event_id",[""])[0].removeprefix("eq.")
            rows=[]
            for (owner,stored_event_id),_ in self.review_events.items():
                if stored_event_id!=event_id:
                    continue
                if not self.review_leak and owner!=actor:
                    continue
                rows.append({"user_id":owner,"client_event_id":stored_event_id})
            return 200,rows
        if method=="PATCH" and path.startswith("/rest/v1/profiles?"):
            identity=self.access_owners.get(access_token)
            actor=identity[0] if identity is not None else None
            if actor is None:
                return 401,{"message":"unauthorized"}
            query=urllib.parse.parse_qs(urllib.parse.urlsplit(path).query)
            target=query.get("id",[""])[0].removeprefix("eq.")
            if target in self.profiles and (actor==target or self.cross_update):
                self.preferences[target]=payload.get("preferred_jlpt")
            return 204,None
        if method=="GET" and path.startswith("/rest/v1/profiles?"):
            if access_token is None:
                return (200,[]) if self.anonymous else (401,{"message":"unauthorized"})
            identity=self.access_owners.get(access_token)
            owner=identity[0] if identity is not None else None
            if owner is None:
                return 401,{"message":"unauthorized"}
            query=urllib.parse.parse_qs(urllib.parse.urlsplit(path).query)
            target=query.get("id",[""])[0].removeprefix("eq.")
            if self.leak and target!=owner:
                return 200,[{"id":target}]
            if target==owner and target in self.profiles:
                if query.get("select")==["id,preferred_jlpt"]:
                    return 200,[{"id":owner,"preferred_jlpt":self.preferences[owner]}]
                return 200,[{"id":owner}]
            return 200,[]
        if method=="POST" and path.startswith("/auth/v1/logout"):
            identity=self.access_owners.get(access_token)
            if identity is None:
                return 401,{"message":"unauthorized"}
            owner,session_id=identity
            query=urllib.parse.parse_qs(urllib.parse.urlsplit(path).query)
            scope=query.get("scope",["global"])[0]
            self.logout_scopes.append(scope)
            if scope not in {"local","global"}:
                return 400,{"message":"invalid scope"}
            if self.revoke:
                if scope=="local":
                    self.refresh_owners={t:value for t,value in self.refresh_owners.items()
                                         if value[1]!=session_id}
                else:
                    self.refresh_owners={t:value for t,value in self.refresh_owners.items()
                                         if value[0]!=owner}
            return 204,None
        return 404,{"message":"not found"}

class HostedProbeTests(unittest.TestCase):
    def test_a_b_refresh_profile_rls_and_logout_flow(self):
        fake=FakeSupabase()
        probe.run_probe(config(),fake)
        self.assertEqual(fake.profiles,{A,B})
        self.assertEqual(fake.preferences,{A:"N5",B:"N5"})
        self.assertEqual(fake.logout_scopes,["local","local","local"])
        self.assertEqual(fake.refresh_owners,{})

    def test_probe_failure_still_cleans_all_remaining_local_sessions(self):
        fake=FakeSupabase(no_active_content=True)
        with self.assertRaisesRegex(probe.ProbeFailure,"active N5 vocabulary is unavailable"):
            probe.run_probe(config(),fake)
        self.assertEqual(fake.logout_scopes,["local","local","local"])
        self.assertEqual(fake.refresh_owners,{})
        self.assertEqual(fake.profiles,{A,B})

    def test_rotated_session_is_registered_before_identity_guard_and_cleaned(self):
        fake=FakeSupabase(refresh_identity_mismatch=True)
        with self.assertRaisesRegex(probe.ProbeFailure,"User A refresh changed identity"):
            probe.run_probe(config(),fake)
        self.assertTrue(fake.refresh_identity_mismatch_used)
        self.assertEqual(fake.logout_scopes,["local","local","local"])
        self.assertEqual(fake.refresh_owners,{})

    def test_cleanup_failure_preserves_primary_probe_failure(self):
        fake=FakeSupabase()
        def fail_logout(method,path,payload=None,access_token=None):
            if method=="POST" and path=="/auth/v1/logout?scope=local":
                return 503,{"message":"SENSITIVE_STAGING_RESPONSE"}
            return fake(method,path,payload,access_token)

        with self.assertRaisesRegex(
            probe.ProbeFailure,
            "User A local logout failed; local staging-session cleanup could not be verified",
        ) as raised:
            probe.run_probe(config(),fail_logout)
        self.assertNotIn("SENSITIVE_STAGING_RESPONSE",str(raised.exception))
        self.assertNotIn("TEST_ONLY_PASSWORD_A",str(raised.exception))
        self.assertNotIn("TEST_ONLY_ACCESS",str(raised.exception))

    def test_hosted_review_rpc_replay_conflict_and_owner_isolation(self):
        fake=FakeSupabase()
        probe.run_probe(config(),fake)
        self.assertEqual(
            set(fake.review_cards),
            {(A,"VOCABULARY",fake.review_item),(B,"VOCABULARY",fake.review_item)},
        )
        self.assertEqual(len(fake.review_events),2)
        self.assertTrue(all(card["review_count"]==1 for card in fake.review_cards.values()))

    def test_hosted_review_rpc_requires_active_n5_content(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"active N5 vocabulary is unavailable"):
            probe.run_probe(config(),FakeSupabase(no_active_content=True))

    def test_hosted_review_rpc_rejects_cross_owner_review_visibility(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"RLS exposed another user's review"):
            probe.run_probe(config(),FakeSupabase(review_leak=True))

    def test_hosted_review_rpc_requires_changed_payload_conflict(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"changed replay did not return a safe SYNC_CONFLICT"):
            probe.run_probe(config(),FakeSupabase(accept_changed_review=True))

    def test_hosted_review_rpc_requires_original_replay(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"identical replay did not return the original response"):
            probe.run_probe(config(),FakeSupabase(mutate_review_replay=True))

    def test_hosted_review_rpc_rejects_anonymous_execution(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"unauthenticated submit_review was accepted"):
            probe.run_probe(config(),FakeSupabase(anonymous_review=True))

    def test_global_logout_cannot_pass_local_session_acceptance(self):
        fake=FakeSupabase()
        def force_global_logout(method,path,payload=None,access_token=None):
            if method=="POST" and path=="/auth/v1/logout?scope=local":
                path="/auth/v1/logout?scope=global"
            return fake(method,path,payload,access_token)
        with self.assertRaisesRegex(
            probe.ProbeFailure,
            "User A second session after local logout refresh Auth response failed",
        ):
            probe.run_probe(config(),force_global_logout)

    def test_caller_owner_override_is_rejected_by_the_probe(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"caller owner override was accepted"):
            probe.run_probe(config(),FakeSupabase(accepted_overrides={"id"}))

    def test_profile_metadata_override_is_rejected_by_the_probe(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"profile metadata override was accepted"):
            probe.run_probe(config(),FakeSupabase(accepted_overrides={"display_name"}))

    def test_auth_user_metadata_override_is_rejected_by_the_probe(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"Auth user metadata override was accepted"):
            probe.run_probe(config(),FakeSupabase(accepted_overrides={"user_metadata"}))
    def test_cross_owner_profile_update_is_rejected_by_the_probe(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"cross-owner profile update changed"):
            probe.run_probe(config(),FakeSupabase(cross_update=True))
    def test_bootstrap_does_not_reset_existing_preference(self):
        with self.assertRaisesRegex(probe.ProbeFailure,"ensure_profile reset an existing preference"):
            probe.run_probe(config(),FakeSupabase(reset_profile_settings=True))
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


class HostedWorkflowSafetyTests(unittest.TestCase):
    """Protect the manual staging boundary from accidental CI secret exposure."""

    @classmethod
    def setUpClass(cls):
        cls.workflow = (
            Path(__file__).resolve().parents[1]
            / ".github"
            / "workflows"
            / "hosted-supabase-acceptance.yml"
        ).read_text(encoding="utf-8")

    def test_staging_workflow_requires_explicit_non_production_confirmation(self):
        workflow = self.workflow
        self.assertRegex(workflow, r"(?m)^on:\s*$")
        self.assertRegex(workflow, r"(?m)^  workflow_dispatch:\s*$")
        self.assertNotRegex(workflow, r"(?m)^  (?:pull_request|push|schedule):")
        match = re.search(
            r"(?ms)^      confirm_non_production:\n(?P<body>(?:        .*\n)+)",
            workflow,
        )
        self.assertIsNotNone(match)
        self.assertIn("type: boolean", match.group("body"))
        self.assertIn("required: true", match.group("body"))
        self.assertIn("default: false", match.group("body"))
        self.assertRegex(
            workflow,
            r"(?m)^    if: \$\{\{ inputs\.confirm_non_production \}\}$",
        )

    def test_staging_workflow_uses_only_protected_staging_secrets(self):
        workflow = self.workflow
        self.assertRegex(workflow, r"(?m)^    environment: supabase-staging$")
        expected = {
            "ND_STAGING_SUPABASE_URL",
            "ND_STAGING_SUPABASE_PUBLISHABLE_KEY",
            "ND_STAGING_USER_A_EMAIL",
            "ND_STAGING_USER_A_PASSWORD",
            "ND_STAGING_USER_B_EMAIL",
            "ND_STAGING_USER_B_PASSWORD",
        }
        referenced = set(
            re.findall(r"\$\{\{\s*secrets\.([A-Z0-9_]+)\s*\}\}", workflow)
        )
        self.assertEqual(referenced, expected)
        for name in expected:
            self.assertRegex(
                workflow,
                rf"(?m)^\s+{name}:\s*\$\{{\{{\s*secrets\.{name}\s*\}}\}}$",
            )
        self.assertNotRegex(workflow, r"(?i)service[_-]?role|jwt[_-]?secret")
        self.assertEqual(
            re.findall(r"(?m)^\s+- uses: ([^\s]+)$", workflow),
            ["actions/checkout@v4", "actions/setup-python@v5", "subosito/flutter-action@v2"],
        )
        self.assertIn("run: python scripts/hosted_supabase_probe.py", workflow)
        self.assertRegex(workflow, r"(?m)^    runs-on: windows-2022$")
        self.assertIn("flutter build windows --release -t tool/windows_hosted_runtime_fixture.dart", workflow)
        self.assertIn("run: .\\tool\\verify_windows_hosted_runtime.ps1", workflow)

    def test_staging_workflow_is_read_only_and_does_not_auto_cancel(self):
        workflow = self.workflow
        self.assertRegex(workflow, r"(?ms)^permissions:\n  contents: read\n")
        self.assertRegex(
            workflow,
            r"(?ms)^concurrency:\n"
            r"  group: hosted-supabase-acceptance\n"
            r"  cancel-in-progress: false\n",
        )
        self.assertRegex(workflow, r"(?m)^    timeout-minutes: 30$")

    def test_windows_hosted_runtime_fixture_is_live_and_redacted(self):
        root = Path(__file__).resolve().parents[1]
        fixture = (root / "apps" / "flutter_app" / "tool" / "windows_hosted_runtime_fixture.dart").read_text(encoding="utf-8")
        proof = (root / "apps" / "flutter_app" / "tool" / "hosted_session_token_proof.dart").read_text(encoding="utf-8")
        script = (root / "apps" / "flutter_app" / "tool" / "verify_windows_hosted_runtime.ps1").read_text(encoding="utf-8")
        for marker in (
            "Platform.environment",
            "createWindowsSessionCredentialVault",
            "PersistentSupabaseRuntime",
            "_verifyWindowsHostedRuntimePhase",
            "runtime.account.signIn",
            "runtime.account.signOut",
            "waitForCurrentProfile",
            "SessionPersistencePhase.ready",
            "login-a",
            "restore-a",
            "auth.refresh.response",
            "vault.rotated-before-profile",
            "logout-a",
            "prepare-revoked-a",
            "restore-revoked-a",
            "login-b",
            "cleanup",
        ):
            self.assertIn(marker, fixture)
        self.assertNotIn("MockClient", fixture)
        self.assertNotIn("TEST_ONLY_", fixture)
        self.assertNotRegex(
            fixture,
            r"(?i)(?:stdout|stderr)\.writeln\([^)]*(?:email|password|refresh|token|secret)",
        )
        self.assertNotIn("Future<void> verifyWindowsHostedRuntimePhase(", fixture)
        restore = fixture.split("case 'restore-a':", 1)[1].split(
            "case 'logout-a':", 1
        )[0]
        self.assertIn("request is! http.Request", fixture)
        self.assertIn("jsonDecode(request.body)", fixture)
        self.assertIn("_readBounded(response.stream)", fixture)
        self.assertIn("if (length > 256 * 1024)", fixture)
        self.assertIn("if (grant == 'refresh_token' || grant == 'password')", fixture)
        self.assertIn("'auth.refresh.response'", fixture)
        self.assertIn("'auth.password.response'", fixture)
        self.assertIn("verifyPersistedPasswordToken(persisted)", fixture)
        self.assertIn("submittedRefreshToken == returnedRefreshToken", proof)
        self.assertIn("persisted == returned", proof)
        self.assertIn("_grant == 'refresh_token'", proof)
        self.assertNotIn("print(", proof)
        self.assertNotIn("log(", proof)
        self.assertIn("verifyRotatedRefreshToken(persisted)", restore)
        self.assertIn("rotationPersistedBeforeProfile", restore)
        self.assertNotIn("rotatedRefreshToken", restore)
        self.assertNotIn("response.stream.toBytes()", fixture)
        self.assertIn("final responseIndex = events.indexOf('auth.refresh.response');", restore)
        self.assertIn("final persistedIndex = events.indexOf('vault.rotated-before-profile');", restore)
        self.assertIn("responseIndex > refreshIndex", restore)
        self.assertIn("persistedIndex > responseIndex", restore)
        self.assertIn("profileIndex > persistedIndex", restore)
        self.assertNotIn("events.add(_rotatedRefreshToken", fixture)
        self.assertNotIn("events.add(submittedRefreshToken", fixture)
        self.assertNotIn("print(_rotatedRefreshToken", fixture)
        self.assertNotIn("debugPrint(_rotatedRefreshToken", fixture)
        self.assertNotIn("print(request.body)", fixture)
        self.assertNotIn("debugPrint(request.body)", fixture)
        self.assertIn("ArgumentList @($phase)", script)
        self.assertIn("WaitForExit(90000)", script)
        self.assertIn("Invoke-HostedPhase 'restore-a'", script)
        self.assertIn("Invoke-HostedPhase 'cleanup'", script)
        self.assertNotIn("ND_STAGING_", script)

    def test_windows_hosted_runtime_runs_after_the_http_probe_without_build_secrets(self):
        workflow = self.workflow
        http_probe = workflow.index("run: python scripts/hosted_supabase_probe.py")
        build = workflow.index("flutter build windows --release -t tool/windows_hosted_runtime_fixture.dart")
        runtime = workflow.index(r"run: .\tool\verify_windows_hosted_runtime.ps1")
        self.assertLess(http_probe, build)
        self.assertLess(build, runtime)
        self.assertRegex(workflow, r"(?m)^    runs-on: windows-2022$")
        self.assertNotRegex(workflow, r"(?m)^    env:\s*$")
        self.assertEqual(
            len(re.findall(r"secrets\.ND_STAGING_[A-Z0-9_]+", workflow)),
            12,
        )



    def test_windows_harness_runs_the_exact_fresh_process_sequence_and_always_cleans_up(self):
        script = (
            Path(__file__).resolve().parents[1]
            / "apps"
            / "flutter_app"
            / "tool"
            / "verify_windows_hosted_runtime.ps1"
        ).read_text(encoding="utf-8")
        phases = re.findall(r"(?m)^\s*Invoke-HostedPhase '([^']+)'$", script)
        self.assertEqual(
            phases,
            ["cleanup", "login-a", "restore-a", "logout-a", "prepare-revoked-a", "restore-revoked-a", "login-b", "cleanup"],
        )
        self.assertIn(
            "Start-Process -FilePath $exe -ArgumentList @($phase)", script
        )
        self.assertIn("$process.WaitForExit(90000)", script)
        self.assertIn("$process.Kill($true)", script)
        self.assertIn("$process.WaitForExit(15000)", script)
        self.assertNotRegex(script, r"\$process\.WaitForExit\(\s*\)")
        self.assertIn("$process.Dispose()", script)
        self.assertIn(
            """} finally {
    try {
        # Always retry exact-project cleanup after the process sequence.
        Invoke-HostedPhase 'cleanup'
    } catch {
        $cleanupFailure = $true
    }
}""",
            script,
        )

    def test_windows_harness_terminates_timed_out_process_tree_with_bounded_reap(self):
        script = (
            Path(__file__).resolve().parents[1]
            / "apps"
            / "flutter_app"
            / "tool"
            / "verify_windows_hosted_runtime.ps1"
        ).read_text(encoding="utf-8")
        timeout = script.index("if (-not $process.WaitForExit(90000))")
        refresh = script.index("$process.Refresh()", timeout)
        alive = script.index("if (-not $process.HasExited)", refresh)
        kill_tree = script.index("$process.Kill($true)", alive)
        bounded_reap = script.index(
            "if (-not $process.WaitForExit(15000))", kill_tree
        )
        self.assertLess(timeout, refresh)
        self.assertLess(refresh, alive)
        self.assertLess(alive, kill_tree)
        self.assertLess(kill_tree, bounded_reap)
        self.assertIn("child termination could not be requested", script)
        self.assertIn("child termination could not be verified", script)
        self.assertNotRegex(script, r"\$process\.WaitForExit\(\s*\)")
        self.assertIn("$process.Dispose()", script)
        self.assertIn("Invoke-HostedPhase 'cleanup'", script)

    def test_windows_harness_preserves_primary_phase_and_redacts_cleanup_errors(self):
        script = (
            Path(__file__).resolve().parents[1]
            / "apps"
            / "flutter_app"
            / "tool"
            / "verify_windows_hosted_runtime.ps1"
        ).read_text(encoding="utf-8")
        self.assertIn("$phaseFailure = $currentPhase", script)
        self.assertIn("$cleanupFailure = $true", script)
        self.assertIn("Windows hosted runtime phase '$phaseFailure' failed", script)
        self.assertIn("final cleanup could not be verified", script)
        self.assertIn(
            "Windows hosted runtime final cleanup could not be verified", script
        )
        self.assertNotRegex(
            script, r"(?im)^\s*Write-(?:Output|Host|Error)\s+\$_"
        )
        self.assertNotRegex(script, r"(?i)\$env:ND_STAGING_")


    def test_revoked_refresh_restore_requires_explicit_password_recovery(self):
        root = Path(__file__).resolve().parents[1]
        fixture = (root / "apps" / "flutter_app" / "tool" / "windows_hosted_runtime_fixture.dart").read_text(encoding="utf-8")
        for marker in (
            "case 'prepare-revoked-a':",
            "case 'restore-revoked-a':",
            "await vault.writeRefreshToken(revoked)",
            "SessionPersistencePhase.failed",
            "AccountPhase.signedOut",
            "httpClient.beforePasswordAuth",
            "vault.empty-before-password",
            "httpClient.beforeProfile",
            "vault.password-persisted-before-profile",
            "verifyPersistedPasswordToken(persisted)",
            "auth.password.response",
            "responseIndex > emptyIndex",
            "persistedIndex > responseIndex",
            "events.indexOf('auth.refresh')",
            "events.indexOf('auth.password')",
        ):
            self.assertIn(marker, fixture)
        driver = (root / "apps" / "flutter_app" / "tool" / "verify_windows_hosted_runtime.ps1").read_text(encoding="utf-8")
        self.assertIn("Invoke-HostedPhase 'prepare-revoked-a'", driver)
        self.assertIn("Invoke-HostedPhase 'restore-revoked-a'", driver)


class LocalSupabaseWorkflowSafetyTests(unittest.TestCase):
    def test_disposable_local_secrets_are_masked_before_github_env_export(self):
        root = Path(__file__).resolve().parents[1]
        workflow = (root / ".github" / "workflows" / "ci.yml").read_text(
            encoding="utf-8"
        )
        start = workflow.index(
            "      - name: Export only validated local integration settings"
        )
        end = workflow.index("      - name: Install PostgreSQL client", start)
        block = workflow[start:end]

        self.assertIn(
            'for key in ("ANON_KEY", "DB_URL", "JWT_SECRET"):',
            block,
        )
        self.assertIn("def escape_workflow_command(value):", block)
        for expression in (
            'value.replace("%", "%25")',
            r'.replace("\r", "%0D")',
            r'.replace("\n", "%0A")',
        ):
            self.assertIn(expression, block)

        mask = block.index(
            'print(f"::add-mask::{escape_workflow_command(values[key])}")'
        )
        export = block.index('with target.open("a", encoding="utf-8")')
        self.assertLess(mask, export)
        self.assertIn("for key in sorted(allowed):", block[export:])



if __name__=="__main__":
    unittest.main(verbosity=2)
