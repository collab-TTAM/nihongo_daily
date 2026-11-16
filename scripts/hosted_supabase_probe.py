#!/usr/bin/env python3
"""Manual-only hosted Supabase staging probe. Never prints credentials or tokens."""
from __future__ import annotations
import base64, binascii, json, math, os, re, sys, urllib.error, urllib.parse, urllib.request, uuid
from datetime import datetime, timezone
from dataclasses import dataclass
MAX_BODY = 1024 * 1024
ENV_KEYS = ("ND_STAGING_SUPABASE_URL","ND_STAGING_SUPABASE_PUBLISHABLE_KEY","ND_STAGING_USER_A_EMAIL","ND_STAGING_USER_A_PASSWORD","ND_STAGING_USER_B_EMAIL","ND_STAGING_USER_B_PASSWORD")

class ProbeFailure(RuntimeError):
    """Fixed, redacted failure; never contains a raw HTTP response."""

def project_origin(value: str) -> str:
    try:
        uri = urllib.parse.urlsplit(value)
        port = uri.port
    except (TypeError, ValueError):
        raise ProbeFailure("invalid Supabase project URL") from None
    host = (uri.hostname or "").lower()
    if (uri.scheme != "https" or uri.username is not None or uri.password is not None
        or port is not None or uri.path not in ("", "/") or uri.query or uri.fragment
        or re.fullmatch(r"[a-z0-9][a-z0-9-]{1,62}\.supabase\.co", host) is None):
        raise ProbeFailure("project URL must be one hosted *.supabase.co origin")
    return f"https://{host}"

def _jwt_object(segment: str) -> dict:
    try:
        raw = base64.urlsafe_b64decode(segment + "=" * (-len(segment) % 4))
        value = json.loads(raw.decode("utf-8"))
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError, binascii.Error):
        raise ProbeFailure("legacy anon key format is invalid") from None
    if not isinstance(value, dict):
        raise ProbeFailure("legacy anon key format is invalid")
    return value

def publishable_key(value: str) -> str:
    if not isinstance(value, str) or not value or len(value) > 4096 or any(ord(c) < 33 or ord(c) > 126 for c in value):
        raise ProbeFailure("publishable/anon key format is invalid")
    if re.fullmatch(r"sb_publishable_[A-Za-z0-9_-]{20,}", value):
        return value
    parts = value.split(".")
    if len(parts) != 3:
        raise ProbeFailure("only a publishable key or legacy anon JWT is allowed")
    header, claims = _jwt_object(parts[0]), _jwt_object(parts[1])
    # Local role guard only; the hosted Supabase server verifies the actual key.
    if header.get("alg") != "HS256" or claims.get("role") != "anon":
        raise ProbeFailure("legacy key must carry the anon role")
    return value

@dataclass(frozen=True)
class Config:
    origin: str
    key: str
    email_a: str
    password_a: str
    email_b: str
    password_b: str

def load_config(env=os.environ) -> Config:
    missing = [name for name in ENV_KEYS if not env.get(name)]
    if missing:
        raise ProbeFailure("missing GitHub environment settings: " + ", ".join(missing))
    email_a, email_b = env[ENV_KEYS[2]].strip(), env[ENV_KEYS[4]].strip()
    pattern = r"[^@\s]+@[^@\s]+\.[^@\s]+"
    if (len(email_a) > 254 or len(email_b) > 254
        or re.fullmatch(pattern, email_a) is None or re.fullmatch(pattern, email_b) is None
        or email_a.casefold() == email_b.casefold()):
        raise ProbeFailure("two distinct valid staging user emails are required")
    password_a, password_b = env[ENV_KEYS[3]], env[ENV_KEYS[5]]
    if any(not isinstance(p, str) or not 1 <= len(p) <= 4096 or "\r" in p or "\n" in p for p in (password_a,password_b)):
        raise ProbeFailure("staging password settings are invalid")
    return Config(project_origin(env[ENV_KEYS[0]].strip()), publishable_key(env[ENV_KEYS[1]].strip()),
                  email_a,password_a,email_b,password_b)

class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def _decode(raw: bytes):
    if len(raw) > MAX_BODY:
        raise ProbeFailure("Supabase response exceeded the bounded response size")
    if not raw:
        return None
    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None

class HttpTransport:
    def __init__(self, config: Config):
        self.origin, self.key = config.origin, config.key
        self.opener = urllib.request.build_opener(_NoRedirect())
    def __call__(self, method, path, payload=None, access_token=None):
        if not path.startswith("/") or path.startswith("//") or "\r" in path or "\n" in path:
            raise ProbeFailure("invalid fixed Supabase request path")
        headers = {"apikey": self.key, "Accept": "application/json"}
        if access_token is not None:
            if not isinstance(access_token,str) or not 1 <= len(access_token) <= 8192:
                raise ProbeFailure("invalid captured access token")
            headers["Authorization"] = "Bearer " + access_token
        data = None
        if payload is not None:
            data = json.dumps(payload,separators=(",",":"),ensure_ascii=False).encode()
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(self.origin+path,data=data,headers=headers,method=method)
        try:
            with self.opener.open(request,timeout=15) as response:
                return response.status,_decode(response.read(MAX_BODY+1))
        except urllib.error.HTTPError as error:
            return error.code,_decode(error.read(MAX_BODY+1))
        except ProbeFailure:
            raise
        except (urllib.error.URLError,TimeoutError,OSError):
            raise ProbeFailure("Supabase request unavailable") from None
        except Exception:
            raise ProbeFailure("Supabase request failed") from None

@dataclass(frozen=True)
class Session:
    user_id: str
    access: str
    refresh: str

def require(condition: bool,message: str) -> None:
    if not condition:
        raise ProbeFailure(message)

def session(status: int,body,label: str) -> Session:
    require(status==200 and isinstance(body,dict),f"{label} Auth response failed")
    user=body.get("user")
    raw_id=user.get("id") if isinstance(user,dict) else None
    try:
        user_id=str(uuid.UUID(raw_id)) if isinstance(raw_id,str) else ""
    except (ValueError,AttributeError):
        user_id=""
    access,refresh=body.get("access_token"),body.get("refresh_token")
    require(bool(user_id),f"{label} Auth identity is invalid")
    require(isinstance(access,str) and 1<=len(access)<=8192 and all(32<ord(c)<127 for c in access),
            f"{label} access token is invalid")
    require(isinstance(refresh,str) and 1<=len(refresh)<=2048 and all(32<ord(c)<127 for c in refresh),
            f"{label} refresh token is invalid")
    return Session(user_id,access,refresh)

def refresh(request,previous: Session,label: str) -> Session:
    status,body=request("POST","/auth/v1/token?grant_type=refresh_token",{"refresh_token":previous.refresh},None)
    current=session(status,body,label+" refresh")
    require(current.user_id==previous.user_id,f"{label} refresh changed identity")
    require(current.refresh!=previous.refresh,f"{label} refresh token did not rotate")
    return current

def ensure_profile(request,current: Session,label: str) -> dict:
    status,body=request("POST","/rest/v1/rpc/ensure_profile",{"p_request":{}},current.access)
    fields={"id","display_name","preferred_jlpt","daily_target_minutes","timezone"}
    require(status==200 and isinstance(body,dict) and set(body)==fields,
            f"{label} own-profile bootstrap response is invalid")
    require(body["id"]==current.user_id,f"{label} profile is not caller-owned")
    require(isinstance(body["display_name"],str)
            and isinstance(body["preferred_jlpt"],str)
            and body["preferred_jlpt"] in {"N5","N4","N3","N2","N1"}
            and type(body["daily_target_minutes"]) is int and 7<=body["daily_target_minutes"]<=1440
            and isinstance(body["timezone"],str),f"{label} profile fields are invalid")
    return body

def reject_profile_overrides(request, current: Session, other_user_id: str, label: str) -> None:
    """Require the hosted RPC to reject all caller-controlled profile identity/settings."""
    attempts = (
        ("caller owner", {"id": other_user_id}),
        ("profile metadata", {"display_name": "FORGED_PROFILE_NAME"}),
        ("Auth user metadata", {"user_metadata": {"preferred_jlpt": "N1"}}),
    )
    for field, forged in attempts:
        status, body = request(
            "POST",
            "/rest/v1/rpc/ensure_profile",
            {"p_request": forged},
            current.access,
        )
        require(
            status == 200
            and isinstance(body, dict)
            and set(body) == {"code", "message_vi", "retryable"}
            and body["code"] == "VALIDATION_FAILURE"
            and body["message_vi"] == "Yêu cầu hồ sơ không hợp lệ."
            and body["retryable"] is False,
            f"{label} {field} override was accepted or returned an unsafe error",
        )

def profile_ids(request,current: Session,target: str,label: str) -> list[str]:
    query=urllib.parse.urlencode({"id":"eq."+target,"select":"id"})
    status,body=request("GET","/rest/v1/profiles?"+query,None,current.access)
    require(status==200 and isinstance(body,list),f"{label} profile read failed")
    result=[]
    for row in body:
        require(isinstance(row,dict) and set(row)=={"id"} and isinstance(row["id"],str),
                f"{label} profile row is invalid")
        try:
            result.append(str(uuid.UUID(row["id"])))
        except ValueError:
            raise ProbeFailure(f"{label} profile row identity is invalid") from None
    return result

def profile_preference(request,current: Session,target: str,label: str) -> str:
    query=urllib.parse.urlencode({"id":"eq."+target,"select":"id,preferred_jlpt"})
    status,body=request("GET","/rest/v1/profiles?"+query,None,current.access)
    require(status==200 and isinstance(body,list) and len(body)==1,
            f"{label} profile preference read failed")
    row=body[0]
    require(isinstance(row,dict) and set(row)=={"id","preferred_jlpt"}
            and row["id"]==target and isinstance(row["preferred_jlpt"],str)
            and row["preferred_jlpt"] in {"N5","N4","N3","N2","N1"},
            f"{label} profile preference response is invalid")
    return row["preferred_jlpt"]

def patch_profile_preference(request,current: Session,target: str,level: str,label: str) -> int:
    status,_=request("PATCH","/rest/v1/profiles?"+urllib.parse.urlencode({"id":"eq."+target}),
                     {"preferred_jlpt":level},current.access)
    return status

def reject_cross_owner_profile_update(request,actor: Session,target: Session,label: str) -> None:
    status=patch_profile_preference(request,actor,target.user_id,"N1",label)
    require(status in {200,204,401,403},f"{label} cross-owner profile update returned an unexpected status")
    require(profile_preference(request,target,target.user_id,label+" target")=="N5",
            f"{label} cross-owner profile update changed another user's profile")

def verify_profile_preference_preserved(request,current: Session,label: str) -> None:
    original=profile_preference(request,current,current.user_id,label+" before update")
    require(original=="N5",f"{label} newly provisioned profile did not start at the N5 default")
    try:
        status=patch_profile_preference(request,current,current.user_id,"N4",label)
        require(status in {200,204},f"{label} own profile preference update failed")
        require(profile_preference(request,current,current.user_id,label+" updated")=="N4",
                f"{label} own profile preference update was not persisted")
        repeated=ensure_profile(request,current,label+" repeated bootstrap")
        require(repeated["preferred_jlpt"]=="N4"
                and profile_preference(request,current,current.user_id,label+" after bootstrap")=="N4",
                f"{label} ensure_profile reset an existing preference")
    finally:
        restore_status=patch_profile_preference(request,current,current.user_id,original,label+" restore")
        require(restore_status in {200,204},f"{label} could not restore the original profile preference")
        require(profile_preference(request,current,current.user_id,label+" restored")==original,
                f"{label} original profile preference was not restored")

def active_n5_vocabulary_id(request, current: Session, label: str) -> str:
    query=urllib.parse.urlencode({
        "select":"id","jlpt_level":"eq.N5","is_active":"eq.true","order":"id.asc","limit":"1"
    })
    status,body=request("GET","/rest/v1/vocabulary?"+query,None,current.access)
    require(status==200 and isinstance(body,list) and len(body)>=1,
            f"{label} active N5 vocabulary is unavailable in staging")
    row=body[0]
    require(isinstance(row,dict) and set(row)=={"id"} and isinstance(row["id"],str),
            f"{label} active N5 vocabulary row is invalid")
    try:
        return str(uuid.UUID(row["id"]))
    except (ValueError,TypeError,AttributeError):
        raise ProbeFailure(f"{label} active N5 vocabulary identity is invalid") from None

def review_card_rows(request,current: Session,item_id: str,label: str) -> list[dict]:
    query=urllib.parse.urlencode({
        "select":"user_id,item_type,item_id,review_count,correct_count,incorrect_count",
        "item_type":"eq.VOCABULARY","item_id":"eq."+item_id,
    })
    status,body=request("GET","/rest/v1/user_learning_items?"+query,None,current.access)
    require(status==200 and isinstance(body,list),f"{label} review-state read failed")
    rows=[]
    for row in body:
        fields={"user_id","item_type","item_id","review_count","correct_count","incorrect_count"}
        require(isinstance(row,dict) and set(row)==fields,
                f"{label} review-state row is invalid")
        require(row["user_id"]==current.user_id,
                f"{label} RLS exposed another user's review state")
        require(row["item_type"]=="VOCABULARY" and row["item_id"]==item_id,
                f"{label} review-state item identity is invalid")
        counts=(row["review_count"],row["correct_count"],row["incorrect_count"])
        require(all(type(value) is int and value>=0 for value in counts)
                and row["correct_count"]+row["incorrect_count"]==row["review_count"],
                f"{label} review-state counters are invalid")
        rows.append(row)
    require(len(rows)<=1,f"{label} review-state uniqueness is invalid")
    return rows

def review_event_rows(request,current: Session,event_id: str,label: str) -> list[dict]:
    query=urllib.parse.urlencode({
        "select":"user_id,client_event_id","client_event_id":"eq."+event_id,
    })
    status,body=request("GET","/rest/v1/review_events?"+query,None,current.access)
    require(status==200 and isinstance(body,list),f"{label} review-event read failed")
    rows=[]
    for row in body:
        require(isinstance(row,dict) and set(row)=={"user_id","client_event_id"},
                f"{label} review-event row is invalid")
        require(row["user_id"]==current.user_id,
                f"{label} RLS exposed another user's review event")
        require(row["client_event_id"]==event_id,
                f"{label} review-event identity is invalid")
        rows.append(row)
    require(len(rows)<=1,f"{label} review-event uniqueness is invalid")
    return rows

def _review_success(status: int,body,label: str) -> dict:
    fields={"srs_state","next_review_at","interval_days","difficulty","review_count"}
    require(status==200 and isinstance(body,dict) and set(body)==fields,
            f"{label} submit_review response shape is invalid")
    require(body["srs_state"] in {"LEARNING","REVIEW","RELEARNING"},
            f"{label} submit_review state is invalid")
    due=body["next_review_at"]
    require(isinstance(due,str) and 1<=len(due)<=64,
            f"{label} submit_review due time is invalid")
    try:
        parsed=datetime.fromisoformat(due.replace("Z","+00:00"))
    except (TypeError,ValueError,OverflowError):
        raise ProbeFailure(f"{label} submit_review due time is invalid") from None
    require(parsed.tzinfo is not None and parsed.utcoffset() is not None,
            f"{label} submit_review due time is not timezone-aware")
    try:
        interval=float(body["interval_days"])
        difficulty=float(body["difficulty"])
    except (TypeError,ValueError,OverflowError):
        raise ProbeFailure(f"{label} submit_review numeric fields are invalid") from None
    require(type(body["interval_days"]) in (int,float) and math.isfinite(interval)
            and 0<interval<=365,
            f"{label} submit_review interval is invalid")
    require(type(body["difficulty"]) in (int,float) and math.isfinite(difficulty)
            and 0<=difficulty<=1,
            f"{label} submit_review difficulty is invalid")
    require(type(body["review_count"]) is int and body["review_count"]>=1,
            f"{label} submit_review count is invalid")
    return body

def _new_review_request(item_id: str) -> dict:
    return {
        "client_event_id":str(uuid.uuid4()),
        "item_type":"VOCABULARY",
        "item_id":item_id,
        "rating":2,
        "is_correct":True,
        "response_ms":1234,
        "occurred_at":datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00","Z"),
    }

def verify_hosted_review_rpc(request,user_a: Session,user_b: Session) -> None:
    """Exercise the deployed atomic RPC and owner RLS with dedicated staging users."""
    item_id=active_n5_vocabulary_id(request,user_a,"User A")
    require(active_n5_vocabulary_id(request,user_b,"User B")==item_id,
            "A/B staging users do not share the same active N5 vocabulary item")
    event_a=_new_review_request(item_id)
    anonymous_status,_=request(
        "POST","/rest/v1/rpc/submit_review",{"p_request":event_a},None
    )
    require(anonymous_status in {401,403},
            "unauthenticated submit_review was accepted")

    def submit_once(current: Session,label: str) -> str:
        before_rows=review_card_rows(request,current,item_id,label+" before")
        before=before_rows[0] if before_rows else {
            "review_count":0,"correct_count":0,"incorrect_count":0
        }
        payload=_new_review_request(item_id)
        status,body=request(
            "POST","/rest/v1/rpc/submit_review",{"p_request":payload},current.access
        )
        saved=_review_success(status,body,label+" first submit")
        require(saved["review_count"]==before["review_count"]+1,
                f"{label} first submit did not increment exactly once")

        replay_status,replay_body=request(
            "POST","/rest/v1/rpc/submit_review",{"p_request":payload},current.access
        )
        replay=_review_success(replay_status,replay_body,label+" identical replay")
        require(replay==saved,
                f"{label} identical replay did not return the original response")

        changed=dict(payload)
        changed["response_ms"]+=1
        conflict_status,conflict_body=request(
            "POST","/rest/v1/rpc/submit_review",{"p_request":changed},current.access
        )
        expected_error={
            "code":"SYNC_CONFLICT",
            "message_vi":"Lượt ôn tập xung đột với dữ liệu đã lưu.",
            "retryable":False,
        }
        require(conflict_status==200 and conflict_body==expected_error,
                f"{label} changed replay did not return a safe SYNC_CONFLICT")

        after_rows=review_card_rows(request,current,item_id,label+" after")
        require(len(after_rows)==1,f"{label} review state was not persisted exactly once")
        after=after_rows[0]
        require(after["review_count"]==before["review_count"]+1
                and after["correct_count"]==before["correct_count"]+1
                and after["incorrect_count"]==before["incorrect_count"],
                f"{label} replay changed authoritative review counters")
        event_rows=review_event_rows(request,current,payload["client_event_id"],label)
        require(len(event_rows)==1,
                f"{label} review event was not persisted exactly once")
        return payload["client_event_id"]

    # User A's second independent Auth session must share only A's review state.
    event_a_id=submit_once(user_a,"User A")
    event_b_id=submit_once(user_b,"User B")
    require(review_card_rows(request,user_a,item_id,"User A after B submit"),
            "User A review state disappeared after User B submit")
    require(review_card_rows(request,user_b,item_id,"User B after A submit"),
            "User B review state disappeared after User A submit")
    require(review_event_rows(request,user_a,event_b_id,"User A cross-owner event")==[],
            "RLS exposed User B review event to User A")
    require(review_event_rows(request,user_b,event_a_id,"User B cross-owner event")==[],
            "RLS exposed User A review event to User B")

def _cleanup_staging_sessions(request, sessions: dict[str, Session]) -> tuple[str, ...]:
    """Best-effort local logout for every still-owned staging session."""
    failures = []
    for label, current in reversed(tuple(sessions.items())):
        try:
            status, _ = request(
                "POST",
                "/auth/v1/logout?scope=local",
                None,
                current.access,
            )
            if status not in {200, 204}:
                failures.append(label)
        except Exception:
            failures.append(label)
    return tuple(failures)


def run_probe(config: Config,request) -> None:
    """Use two pre-provisioned staging users; never creates or deletes accounts."""
    active_sessions: dict[str, Session] = {}
    primary_failure = None
    cleanup_failures: tuple[str, ...] = ()
    try:
        status,body=request("POST","/auth/v1/token?grant_type=password",
                            {"email":config.email_a,"password":config.password_a},None)
        initial_a=session(status,body,"User A")
        active_sessions["User A"] = initial_a
        status,body=request("POST","/auth/v1/token?grant_type=password",
                            {"email":config.email_a,"password":config.password_a},None)
        initial_a_other=session(status,body,"User A second session")
        active_sessions["User A second session"] = initial_a_other
        status,body=request("POST","/auth/v1/token?grant_type=password",
                            {"email":config.email_b,"password":config.password_b},None)
        initial_b=session(status,body,"User B")
        active_sessions["User B"] = initial_b
        require(initial_a.user_id==initial_a_other.user_id and initial_a.user_id!=initial_b.user_id,
                "staging users must be distinct and User A must have two sessions")
        require(initial_a.refresh!=initial_a_other.refresh,
                "User A sessions must have independent refresh tokens")
        user_a=refresh(request,initial_a,"User A")
        active_sessions["User A"] = user_a
        other_a=refresh(request,initial_a_other,"User A second session")
        active_sessions["User A second session"] = other_a
        user_b=refresh(request,initial_b,"User B")
        active_sessions["User B"] = user_b
        require(user_a.refresh!=other_a.refresh,
                "User A refresh sessions must remain independent")
        # Before legitimate bootstrap, neither caller may choose the owner or profile settings.
        reject_profile_overrides(request,user_a,user_b.user_id,"User A")
        reject_profile_overrides(request,user_b,user_a.user_id,"User B")
        require(profile_ids(request,user_a,user_a.user_id,"User A before bootstrap")==[],
                "forged User A bootstrap created a profile")
        require(profile_ids(request,user_b,user_b.user_id,"User B before bootstrap")==[],
                "forged User B bootstrap created a profile")
        ensure_profile(request,user_a,"User A")
        ensure_profile(request,user_b,"User B")
        require(profile_ids(request,user_a,user_a.user_id,"User A own read")==[user_a.user_id],
                "User A cannot read its own profile")
        require(profile_ids(request,user_b,user_b.user_id,"User B own read")==[user_b.user_id],
                "User B cannot read its own profile")
        require(profile_ids(request,user_a,user_b.user_id,"User A cross read")==[],
                "RLS exposed User B profile to User A")
        require(profile_ids(request,user_b,user_a.user_id,"User B cross read")==[],
                "RLS exposed User A profile to User B")
        reject_cross_owner_profile_update(request,user_a,user_b,"User A -> User B")
        reject_cross_owner_profile_update(request,user_b,user_a,"User B -> User A")
        verify_profile_preference_preserved(request,user_a,"User A")
        verify_profile_preference_preserved(request,user_b,"User B")
        verify_hosted_review_rpc(request,other_a,user_b)
        anonymous_status,_=request("GET","/rest/v1/profiles?select=id&limit=1",None,None)
        require(anonymous_status in {401,403},"profiles endpoint accepted an unauthenticated request")
        status,_=request("POST","/auth/v1/logout?scope=local",None,user_a.access)
        require(status in {200,204},"User A local logout failed")
        status,_=request("POST","/auth/v1/token?grant_type=refresh_token",{"refresh_token":user_a.refresh},None)
        require(status in {400,401,403},"User A current refresh token remained usable after local logout")
        active_sessions.pop("User A", None)
        other_a=refresh(request,other_a,"User A second session after local logout")
        active_sessions["User A second session"] = other_a
        require(profile_ids(request,other_a,user_a.user_id,"User A second session after local logout")==[user_a.user_id],
                "User A local logout revoked its other session")
        user_b=refresh(request,user_b,"User B after User A local logout")
        active_sessions["User B"] = user_b
        require(profile_ids(request,user_b,user_b.user_id,"User B after A local logout")==[user_b.user_id],
                "User A local logout affected User B")
        require(profile_ids(request,user_b,user_a.user_id,"User B after A logout isolation")==[],
                "User B can read User A profile")
    except ProbeFailure as error:
        primary_failure = error
    finally:
        cleanup_failures = _cleanup_staging_sessions(request, active_sessions)

    if primary_failure is not None:
        if cleanup_failures:
            raise ProbeFailure(
                f"{primary_failure}; local staging-session cleanup could not be verified"
            ) from None
        raise primary_failure
    require(
        not cleanup_failures,
        "local staging-session cleanup could not be verified",
    )

def main() -> int:
    try:
        config=load_config()
        run_probe(config,HttpTransport(config))
    except ProbeFailure as error:
        print("Hosted Supabase acceptance failed: "+str(error),file=sys.stderr)
        return 1
    print("Hosted Supabase acceptance passed: distinct A/B identities, two independent A sessions, refresh rotation, caller-bound profiles, authenticated A/B review replay/conflict, review/event RLS, anonymous denial and local logout isolation.")
    return 0

if __name__=="__main__":
    sys.exit(main())
