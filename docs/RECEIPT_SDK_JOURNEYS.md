# Receipt lifecycle with pinned SDK transport — Issue #17

Eight additive cases in supabase_ai_text_transport_test.dart compose the actual
Supabase2.16.5 client, SupabaseReviewBinding, SupabaseAiTextTransport, receipt
runtime owner/decorator/barrier/store and captured conversation session. Original
SDK setup/teardown/helpers and assertions remain intact. Auth HTTP uses explicitly
unsigned TEST ONLY JWTs; AI HTTP/receipt storage are injected TEST ONLY ports.
No hosted Auth/signature/RLS, provider spend, OS-backed SDK lifecycle or real
learner acceptance is established. The app/default runtime is not activated.

- Hold storage write: zero HTTP before confirmation; observe metadata present at
  actual HTTP send; fixed endpoint/captured bearer/key/no redirects/exact body.
  Close preserves; a fresh owner over the same pending metadata blocks the SAME
  event with zero additional HTTP. Explicit receipt signout clears metadata but
  does not log out the borrowed SDK session.
- Read/write storage failure: HTTP remains untouched, including an ambiguous
  failed write that saved metadata. Runtime signout drains and clears explicitly.
- Hold actual AbortableRequest headers response while deliberately ignoring its
  abort signal: runtime signout signals abort but cannot clear metadata/complete
  until the underlying actual HTTP future settles. Both late valid response and
  private error are consumed; metadata clears afterward. Client stays borrowed;
  explicit SDK local logout remains host-controlled and is tested separately.
- While write is held, actual SDK refresh, other-account login and A-B-A replacement
  retire the captured capability. Runtime remains draining until write settles;
  zero HTTP uses replacement credentials, close preserves pending metadata and
  old session stays revoked.

Held ports are released in finally before owner close. Tests preserve no-retry,
one-pending-command behavior: metadata is not an original command/dispatch grant.
No text/token/bearer is persisted in the receipt; no new event ID, automatic replay,
metadata eviction, server receipt deletion or weakened failure expectation.

Parent330fd0e CI40268065223 raw exact head/latestattempt1 all5/every required step
passed. Windows121394748739 explicitly logged actual receipt lifecycle preserve/
reopen/no-redispatch/drain/signout/isolation PASS. That verifies prior OS/process
composition with TEST ONLY ports; it does not prove these new SDK cases or hosted
learner restoration. New exact-head CI remains required.

Local execution/analysis and exact dependency parity are recorded in PROJECT_STATUS
and PR41. A disposable pure Dart harness may adapt only the flutter_test import
and fixture path; source/old assertions/original fixture bytes stay identical.
It is not the full Flutter runner/build/native OS test suite. No prior denied
Flutter bootstrap is retried or bypassed. No app dependency/lockfile/CI changes.

Next actual owned account startup/profile/Windows secure-store composition around
SDK failure/account/refresh paths; authenticated receipt lookup and verified
conditional release before more commands. All14 hosted release groups remain
pending; learner route still memory-only/default AI unavailable. No frozen API/
SQL/RLS/Auth strategy/provider/collection/spend/content/Pro/release change.


Observed local: all8 new SDK receipt cases PASS in focused execution; focused
changed-test analysis under strict lints6 CLEAN. Initial combined57-case run had
56pass/one unchanged10ms scenario timeout failure; both unchanged timeout variants
PASS in isolation afterward. No old deadline/assertion altered and NO full-suite
pass claimed. Whole-graph strict analysis reports one info at unchanged
supabase_review_binding.dart:47 unnecessary_underscores (harness lints6 versus
original5.1.1); source unchanged/no suppression. Full actual Flutter CI must verify
the retained suite. All shared SDK/HTTP/transitive versions equal original lock;
only harness lints changes to6.0.0 and test runner/import/fixture path adaptation.
