# Local spaced quiz evidence (nd-quiz-recall-1)

Issue #13 separates practiced items from mastery. This increment adds an explicit
local quiz milestone to vocabulary's pure projection. It does not claim certified
mastery, update SRS MASTERED, grant study time or populate server snapshots.
The dashboard and grammar projection do not expose this milestone yet.

## Rules reviewed before implementation

The pre-code policy and edge review were saved in PR41 and Issue13 under marker
core-20261031-spaced-quiz-evidence on 2026-10-31 UTC. This is an engineering product
rule, not an empirically validated learning or linguistic threshold.

1. Existing projection checks the owner for the entire history, rejects conflicting
   event IDs, deduplicates identical events and selects the level. Only answers
   matching the current target ID/version and exact ordered choice IDs participate.
2. Existing timestamp/event-ID order determines observation order. First correct
   counts one. Another correct counts only after at least 24 elapsed hours since
   the last counted correct. Additional rapid correct reports do not move that
   anchor or add credit. The counter caps at three; reaching it requires at least
   48 elapsed hours from the first counted answer.
3. Every matching wrong answer resets the count and anchor, including a wrong at
   the same instant or after reaching three. A following correct starts at one.
   Tied events follow the existing lexicographic UUID order, not arrival order.
4. Obsolete target version/choice order or other-level history remains historical
   only. It neither earns nor resets current evidence. Removing/changing current
   content recomputes evidence using the same existing matching rule.
5. The immutable helper rejects non-UTC or backwards observations. Owner/event
   validation belongs to the caller; the vocabulary projection supplies it before
   invoking the helper. Empty/unpracticed items contribute zero milestones.

`VocabularyQuizItemProgress.recallEvidence` describes each matched item;
`VocabularyQuizProgress.recallMilestoneCurrentItemCount` counts reached items.
Existing score, latest-correct/needs-review policy, coverage, history serialization,
repository/readiness guards and manual loading are unchanged. The new property
has an empty default for existing explicit item constructors. No new storage or
wire field is added; evidence is always recomputed from existing reports.

Vocabulary focused practice follows the existing same-report policy, so spaced
focused answers can count. These client timestamps and answers are self-reported;
changing a clock, repeated source exposure or guessing can satisfy the rule.
There is no claim of independent unaided recall, trusted time, current retention,
attention, lifetime mastery or full JLPT coverage. There is no expiry heuristic;
a reached milestone describes past reports until a matching wrong resets it.

## Validation and remaining work

Five authored tests cover exact 24-hour boundary/one-microsecond-short/rapid ties/
cap/immutable snapshots; wrong and tied reset; backwards/non-UTC rejection; and
both-level actual projection ordering, replay/conflict, owner/level/version fences
and practiced versus reached separation. Existing tests remain intact.
A standalone fresh-Dart smoke executes the actual helper/builder/projection for
both levels, spacing/reset/deduplication. It is narrower than the Flutter suite.
Full exact-head CI execution is tracked in PR41 and PROJECT_STATUS.

Parent 3c14fd1cba7be18a39abad8ad8956e85d30473f5 passed
[CI41159141294](https://github.com/collab-TTAM/nihongo_daily/actions/runs/41159141294),
latest attempt1/all five jobs/every step. Raw Flutter124412989301 confirms the
new dual-store and both old real-disk journeys; Windows124412605141 confirms
retained grammar/evidence/persistent SDK markers. Parent CI does not execute the
new policy tests. Fixtures/unsigned JWT/native files/builds are not hosted proof.

Next: verify new exact-head CI and review grammar-kind policy before extending
this evidence to grammar. Any future UI must explain the threshold and limits
and distinguish this local milestone from mastered/attention/server progress.
Issue13 and all14 hosted release gates remain open; no Alpha acceptance.
