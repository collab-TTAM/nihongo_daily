# Single-account scheduled development

## Execution

One ChatGPT scheduled task runs hourly in the Asia/Saigon timezone. Each invocation performs a bounded development iteration using the connected GitHub app and the available execution environment. The schedule starts work; it is not a continuously running process and does not guarantee a completion date.

The worker re-reads GitHub on every run. Temporary local files are disposable. Repository commits, issues, PRs, CI results, and this document are the durable handoff. No API key or paid AI provider is required to schedule the worker.

## Existing queue and order

Do not duplicate the existing issues. Check their actual state and acceptance criteria:

| Issue | Work | Prerequisite |
| --- | --- | --- |
| #1 | Architecture and shared contracts | Setup baseline |
| #2 | Flutter shell | #1 |
| #3 | Supabase schema and RLS | #1 |
| #4 | Deterministic SRS | #1 and usable Dart package from #2 |
| #5 | Original N5 seed content | Content contracts from #1/#3 |
| #6 | Kanji capture and scoring primitives | #2 |
| #7 | AI tutor interfaces and validation | #3 |
| #8 | QA and security regression matrix | First implementation PRs |

Titles marked READY are not proof that dependencies are satisfied. First finish #1, then #2/#3/#4/#5, then #6/#7/#8. Select one issue at a time; resume incomplete work first. The eight starter issues are not the complete Personal Alpha. Create scoped follow-up issues for missing PROJECT_SPEC modules, N4 content, offline/sync, integration, and release validation when evidence identifies gaps.

## Worker iteration

1. Read current main, AGENTS.md, canonical docs, open issues/PRs, and CI. Resume an open automation PR first; do not overlap another active run or human-owned work.
2. Select the highest-priority unblocked issue. Record the implementation plan, dependency evidence, and current branch in its body. Preserve existing user text.
3. Implement a complete small increment on an isolated branch. Fetch repository files through GitHub tools if cloning is unavailable. Do not reconstruct a repository from only snippets or drop unrelated files.
4. Run relevant formatting, analysis, tests, and builds. If a local SDK/network is unavailable, persist the change as a draft PR and use GitHub Actions for verification; identify unrun checks explicitly.
5. Update/open the PR with acceptance evidence, changed behavior, tests, remaining work, and the next action. Update PROJECT_STATUS accurately. Persist before the runtime ends.
6. Review the diff separately from writing it. Integrate a routine development PR only if the issue criteria are satisfied, current-head relevant CI passes, conflicts are resolved, and no user review or human gate is pending. Otherwise fix failures, wait for pending checks, or report the blocker. Never merge incomplete drafts or interpret missing/skipped required checks as success.
7. After integration, close only the completed issue and pick the next unblocked task in a subsequent iteration. If one task is externally blocked, continue independent ready tasks.

## Completion and blockers

Supabase deployment, real multi-device sync, live AI/voice, and iPhone release need external configuration and validation. Implement interfaces and tests first; mark mocks/demo data visibly and do not count them as live integrations. Do not ask for secrets in chat; use the destination's supported secret configuration.

Personal Alpha is complete only when PROJECT_SPEC acceptance criteria have observed build/test evidence and user-facing critical flows work. Do not mark it complete because the starter issues are closed. When all work is complete, persist release evidence and pause this scheduled task. If a runtime cannot modify its own schedule, report completion and request pausing through Scheduled.

Human approval gates are defined in AUTOMATION.md. Report concrete required decisions without repeating them each hour. Pause the task on a persistent access failure or when all remaining work depends on human input; resume when resolved.

## Run report

Return a short Vietnamese update only for material progress, failure, or a new decision: completed work, issue/PR link, observed checks, blocker, next task. Never report only a plan when an authorized implementation can be completed.

Manage the schedule at https://chatgpt.com/scheduled. Pause stops future invocations; it does not undo commits or cancel an invocation already executing.
