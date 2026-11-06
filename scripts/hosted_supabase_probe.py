#!/usr/bin/env python3
"""Manual-only hosted Supabase staging probe. Never prints credentials or tokens."""
from __future__ import annotations
import base64, binascii, json, os, re, sys, urllib.error, urllib.parse, urllib.request, uuid
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

def ensure_profile(request,current: Session,label: str) -> None:
    status,body=request("POST","/rest/v1/rpc/ensure_profile",{"p_request":{}},current.access)
    fields={"id","display_name","preferred_jlpt","daily_target_minutes","timezone"}
    require(status==200 and isinstance(body,dict) and set(body)==fields,
            f"{label} own-profile bootstrap response is invalid")
    require(body["id"]==current.user_id,f"{label} profile is not caller-owned")
    require(isinstance(body["display_name"],str) and body["preferred_jlpt"] in {"N5","N4","N3","N2","N1"}
            and type(body["daily_target_minutes"]) is int and 7<=body["daily_target_minutes"]<=1440
            and isinstance(body["timezone"],str),f"{label} profile fields are invalid")

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

def run_probe(config: Config,request) -> None:
    """Use two pre-provisioned staging users; never creates or deletes accounts."""
    status,body=request("POST","/auth/v1/token?grant_type=password",
                        {"email":config.email_a,"password":config.password_a},None)
    initial_a=session(status,body,"User A")
    status,body=request("POST","/auth/v1/token?grant_type=password",
                        {"email":config.email_b,"password":config.password_b},None)
    initial_b=session(status,body,"User B")
    require(initial_a.user_id!=initial_b.user_id,"staging users must be distinct")
    user_a=refresh(request,initial_a,"User A")
    user_b=refresh(request,initial_b,"User B")
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
    anonymous_status,_=request("GET","/rest/v1/profiles?select=id&limit=1",None,None)
    require(anonymous_status in {401,403},"profiles endpoint accepted an unauthenticated request")
    status,_=request("POST","/auth/v1/logout",None,user_a.access)
    require(status in {200,204},"User A logout failed")
    status,_=request("POST","/auth/v1/token?grant_type=refresh_token",{"refresh_token":user_a.refresh},None)
    require(status in {400,401,403},"User A refresh token remained usable after logout")
    require(profile_ids(request,user_b,user_b.user_id,"User B after A logout")==[user_b.user_id],
            "User A logout affected User B")
    require(profile_ids(request,user_b,user_a.user_id,"User B after A logout isolation")==[],
            "User B can read User A profile")

def main() -> int:
    try:
        config=load_config()
        run_probe(config,HttpTransport(config))
    except ProbeFailure as error:
        print("Hosted Supabase acceptance failed: "+str(error),file=sys.stderr)
        return 1
    print("Hosted Supabase acceptance passed: distinct A/B identities, refresh rotation, caller-bound profiles, cross-owner RLS, anonymous denial and logout revocation.")
    return 0

if __name__=="__main__":
    sys.exit(main())
