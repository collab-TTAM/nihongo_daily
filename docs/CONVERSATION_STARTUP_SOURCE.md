# Borrowed conversation source through owned startup — Issue #17

AiConversationSource exposes only a captured-session factory and a void
availability-hint stream. It is a borrowed owner capability; creating/forwarding
it sends no requests or credentials. Runtime retains one conversation per ready
generation, revokes on lifecycle loss and drains actual I/O before replacement.
Consumers must not reset uncertain work, close borrowed resources or render old
snapshots after revocation. A hint alone is not authority: recheck the factory
and captured session/readiness before publication, replay or sending.

PersistentSupabaseRuntime implements this source using its existing default-off
conversation factory and existing shared AI owner hint stream. The same factory/
stream is forwarded through PersistentAccountStartup and WindowsStagingOwner;
Windows owner returns unavailable once its close begins. AccountStartupController
exposes aiConversationSource only while active and not closed. Idle/loading/open/
restore/cleanup errors and closed startup do not publish a source. An active
source may still return null before Auth/vault/profile readiness or when disabled.
The factory continues to enforce exact ready generation/owner and HTTP drain.

No AccountStartupApp provider override, Riverpod conversation binding, route,
controller/view, learner endpoint/key, dispatch or provider/default activation is
added. The trusted staging build still does not enable conversation. Source
interface is a prerequisite for a future guarded UI binding, not a live feature.
Existing text source/owner, credential writer, resource lifetimes and Auth/REST
allowlists remain unchanged. No source owns or closes the stream/SDK/HTTP/journal.

Two new actual-owned-startup cases are authored in ai_owned_startup_journey_test:
- TEST ONLY conversation opt-in through real SDK/native journal/Windows wrapper/
  startup controller: idle unavailable, active-unready factory null, exact stream
  and cached session identity across all layers, explicit start only, real refresh/
  rotated secret/fresh generation/hints, logout and closed-source fencing.
- Default-off source stays unavailable after ready Windows startup while original
  text factory remains available; source retrieval creates no HTTP request.

They use the existing real-loop cleanup helper/target-release assertion. All nine
prior mounted journey cases/assertions are retained; only fixture helpers accept
an optional conversationEnabled=false parameter. New cases do not mount a new
conversation UI. Observed new full Flutter/analyzer/platform results belong in
PROJECT_STATUS/PR; authored cases are not executed evidence until exact-head CI.
TEST ONLY unsigned Auth/vault/HTTP and native journal prove no hosted JWT/provider/
receipt/voice/learner acceptance. Parent f0d43bf CI40097022865 passed allfive jobs/
every step/no skips,1005 Flutter (allfour runtime cases) and five Chrome. New full
CI is required; all14 hosted release groups/human gates remain pending.
