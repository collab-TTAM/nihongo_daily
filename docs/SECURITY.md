# SECURITY BASELINE

Priorities:
1. User A cannot read or mutate User B data.
2. Auth/session tokens do not leak.
3. AI provider secrets never ship in client.
4. AI backend endpoints are authenticated, validated and rate-limited.
5. Model output never authorizes arbitrary writes.

Use Supabase Auth, RLS on user-owned tables, secure token storage, safe logs, input-size limits, timeouts and structured validation. Test forged user_id, expired/missing token, malformed JSON, duplicate events, stale offline writes and repeated rapid AI requests.
