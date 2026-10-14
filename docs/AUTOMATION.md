# AUTOMATION — Single-account multi-task workflow

GitHub is the source of truth:
- Issues = task queue
- Branches = isolated work
- Pull Requests = review boundary
- Actions = deterministic verification
- main = integrated state

## Labels
Agents: agent:lead, agent:flutter, agent:backend, agent:learning, agent:kanji, agent:ai, agent:content, agent:qa
Status: status:ready, status:in-progress, status:review, status:blocked, status:done
Priority: priority:p0, p1, p2, p3

## Worker loop
1. Read canonical docs and latest main.
2. Resume in-progress work first; otherwise claim highest-priority ready Issue for your agent label.
3. Verify dependencies.
4. Work on isolated branch.
5. Implement minimal complete change.
6. Run formatter/analyzer/tests.
7. Fix failures or document a real blocker.
8. Push and open/update PR.
9. Respond to review/CI feedback.
10. After merge, close issue and continue to next ready issue when runtime permits.

## Human approval gates
Destructive DB migration, production deployment, App Store release, auth strategy changes, broader data collection, materially higher paid AI spend, production data deletion, or weakened RLS/security.
