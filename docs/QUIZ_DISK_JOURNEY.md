# Local quiz disk/UI integration — Issues #13 and #18

The new quiz_disk_journey_widget_test.dart exercises an actual composed local
path, extending the separate memory-port widget and SDK/native-file tests. It
uses production UUID/UTC capture, bundled original N5 vocabulary, the pinned
Supabase SDK, persistent runtime, WindowsStagingOwner/AccountStartupApp, captured
quiz repository, native journals and actual quiz/history/progress widgets.

HTTP responses, unsigned JWTs and the credential backend are explicitly TEST
ONLY. This does not establish hosted Auth/JWT/RLS, live learner acceptance,
multi-device sync, real Windows vault operation or a Windows artifact launch.
The test runs on the existing Flutter job's native host. Public default startup,
production policy, storage format, API/schema/RLS and scoring rules are unchanged.

## Asserted journey

1. Open disposable real review/quiz journals and the owned runtime on the real
   event loop. Login through the SDK fixture; require own-profile/ready-history
   barriers before rendering. Preload and retain the real bundled N5 deck.
2. Answer ten actual quiz questions, one wrong and nine correct. Explicit save
   must reach the native append/flush before the UI claims saved. Invoke a stale
   save callback and require one dispatch/one stored immutable event, UUIDv4/UTC
   and the original nine-of-ten answers.
3. Explicit history read must show9/10. Explicit progress read must show one
   saved round,9/10 canonical answers, ten current practiced items and one
   original-source recommendation. No additional Auth/RPC endpoint is dispatched
   by the quiz/history/progress actions.
4. Await owned shutdown before unmounting. Reopen the same files with a fresh
   SDK/runtime/controller and the retained TEST ONLY vault backend. Require a
   refresh request and profile readiness; no manual login or seeded quiz data.
   The new UI starts without cached counters and explicitly recovers the same
   event/payload and recommendation from the journal.
5. Logout/login as B: old counters must clear before explicit empty B history is
   projected. Logout/login as A: the original counters/recommendation return only
   after another explicit read. Require no extra appends, B's journal view empty,
   complete journal bytes unchanged, and no owner/token text in the view.

## Test execution and limits

The widget fake clock cannot drive native filesystem futures. SDK/storage setup,
actual UI dispatches performing disk work and awaited shutdown run through
tester.runAsync. A TEST ONLY forwarding store observes completion of the actual
journal operation; it neither supplies rows nor manufactures success. Bounded
real-loop readiness/completion waits fail when work does not settle. One event
turn after disk completion lets repository/UI continuations settle, followed by
normal frame pumping and independent visible-result assertions. UI answer taps
still scroll, settle and require real hit-testability.

This is graceful close/reopen inside one test process. It does not claim forced
process/hardware loss, physical Windows credential persistence, injected native
write/flush failures, hosted identity authorization or a complete learner journey.
The existing real child-process store cases and separate Windows native checks
remain; all14 hosted release groups remain pending. No mastery or study credit.

Exact parent03cda71f CI39726504614 latest attempt1 passed allfive jobs/every
required step,683 Flutter including allten progress cases, five Chrome and
Web/Windows builds. That confirms the progress format correction. This new test
requires new exact-head format/analyze/test/build evidence; local Dart/Flutter
SDK is unavailable. Source review and Python QA are not execution of this test.

### Observed component execution

At49ee8fb93631eefed974ffc59ed4299ea552f4bf, CI39733485647 latest attempt1
completed allfive jobs/every required step successfully. Flutter logs explicitly
show the new composed native-file journey passed;684 Flutter/five Chrome and
Web/Windows/retained gates passed. The authored scenario above is now observed
local component evidence; all stated simulated Auth/vault, same-process reopen
and hosted/Windows/power-loss limitations remain.

### Focused correction across another owned restart

The same real-file journey now continues from A's restored needs-review item.
It opens focused practice through the actual progress control, verifies the
original full-deck choices, answers correctly and checks that completing a round
alone changes neither the journal bytes nor append count. Explicit save must
append exactly one new UUIDv4/UTC event, even after a retained save callback.
The original9/10 event remains byte-for-byte intact; the new1/1 event must contain
the original target/version/choice order. No attempt factory or history row is
replaced by a fixture.

Back initially retains the previous statistics snapshot. Only explicit reload
shows two saved rounds,10/11 correct answers, ten current practiced items and
zero needs-review candidates. The complete original file must be the unchanged
prefix of the appended journal. Quiz/progress actions dispatch no HTTP request.

Await shutdown again and create a third fresh SDK/runtime/controller on the same
files and retained TEST ONLY vault. Require exactly one startup refresh plus
own-profile readiness without manual login. Explicit history/progress reads must
recover both identical events,9/10 and1/1 history rows and the cleared review
candidate. B must see empty history/progress, then returning to A must explicitly
recover10/11 and no review action. Restoration/account changes append nothing,
preserve the complete corrected journal bytes and show no owner/token text.

All original fixture/helper/journey/assertion bytes before this continuation are
unchanged. The extension adds58 assertion statements; existing real-loop IO,
bounded completion/readiness, hit-tested controls and cleanup are reused. It
does not simulate storage success, extend timeouts or change production code.

Exact parenta396b146 CI39968283133/latest attempt1 completed allfive jobs/every
required step successfully:777 full Flutter/five Chrome, allnine focused widgets
including the corrected version case, Web/Windows and retained native/SQL/Edge
gates. The evidence verifier accepted the complete unmodified parent snapshot.
This proves prior components, not the newly extended journey. New exact-head
Flutter/analyze/full-platform execution remains required; no local Flutter
bootstrap review rejection workaround. Same-process graceful reopen, TEST ONLY
HTTP/JWT/vault and all hosted learner/sync/mastery/Windows/power-loss limitations
above remain. All14 Personal Alpha release groups stay pending.
