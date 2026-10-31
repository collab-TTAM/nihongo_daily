"""Check QA inventory and observed Actions evidence; never execute matrix commands.

Evidence is an unmodified GitHub workflow-run object plus latest-attempt jobs.
This checks completeness/correlation, not authenticity or live integration.
"""
import argparse
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = "collab-TTAM/nihongo_daily"
REQUIRED_JOBS = {"repo-sanity", "database", "flutter", "windows", "ai-boundary"}
RELEASE_CASES = {
    "auth-live", "review-rpc", "daily-plan", "study-flows", "n5-coverage",
    "n4-coverage", "kanji-real", "ai-runtime", "ai-live", "voice-live",
    "offline-sync", "quiz-progress", "browser-windows-smoke", "learner-journey",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_json(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, f"duplicate JSON key: {key}")
            result[key] = value
        return result
    return json.loads(Path(path).read_text(encoding="utf-8"), object_pairs_hook=unique)


def validate_matrix(matrix, root=ROOT):
    require(matrix["version"] == 1, "unknown QA matrix version")
    require(matrix["repository"] == REPOSITORY, "wrong repository")
    gates = matrix["ci_gates"]
    require(set(gates) == REQUIRED_JOBS, "all five CI jobs must be tracked")
    workflow = (root / ".github/workflows/ci.yml").read_text()
    for job, steps in gates.items():
        # This workflow uses two-space top-level job IDs. Scope checks to the
        # actual job block; a command moved into another job is not coverage.
        blocks = re.findall(rf"^  {re.escape(job)}:\n(.*?)(?=^  [\w-]+:\n|\Z)",
                            workflow, re.MULTILINE | re.DOTALL)
        require(len(blocks) == 1, f"job missing/duplicated in workflow: {job}")
        require(steps and len(steps) == len(set(steps)), f"invalid step list: {job}")
        for step in steps:
            # Named steps and GitHub's generated 'Run <command>' names.
            anchor = step[4:] if step.startswith("Run ") else step
            require(anchor in blocks[0], f"step missing from job {job}: {step}")
    cases = matrix["cases"]
    ids = [case["id"] for case in cases]
    require(len(ids) == len(set(ids)), "duplicate QA case ID")
    require(RELEASE_CASES <= set(ids), "Personal Alpha release coverage omitted")
    for case in cases:
        label = case["id"]
        require(case["status"] in {"automated-baseline", "pending-integration"},
                f"unsupported evidence claim: {label}")
        require(case["scope"] and case["limitation"] and case["reproduce"],
                f"missing scope/limitation/reproduction: {label}")
        require(case["issues"] and all(type(i) is int and i > 0 for i in case["issues"]),
                f"missing issue owner: {label}")
        if label in RELEASE_CASES:
            require(case["status"] == "pending-integration", f"unverified release case: {label}")
        if case["status"] == "automated-baseline":
            require(case["ci_job"] in gates and case["anchors"], f"missing executable coverage: {label}")
            for anchor in case["anchors"]:
                path = (root / anchor["path"]).resolve()
                require(path.is_relative_to(root.resolve()), f"path escapes repository: {label}")
                require(path.is_file(), f"missing test file: {anchor['path']}")
                require(anchor["contains"] and anchor["contains"] in path.read_text(),
                        f"missing test anchor: {label}")
    findings = matrix["findings"]
    require(findings, "ranked security findings/assurance gaps required")
    require(len({f["id"] for f in findings}) == len(findings), "duplicate finding ID")
    for finding in findings:
        require(finding["severity"] in {"critical", "high", "medium", "low"}, "invalid severity")
        require(finding["kind"] in {"coverage-gap", "remediated-dependency"}, "invalid finding kind")
        require(finding["cases"] and set(finding["cases"]) <= set(ids), "untracked finding")
        require(finding["description"] and finding["action"], "finding needs reproducible action")
    return cases


def validate_ci(matrix, evidence, expected_head):
    require(re.fullmatch(r"[0-9a-f]{40}", expected_head or ""), "expected full head SHA required")
    run = evidence["run"]
    require(run["head_sha"] == expected_head, "CI belongs to another head")
    require(run["repository"]["full_name"] == REPOSITORY, "CI belongs to another repository")
    require(run["name"] == "CI" and run["path"] == ".github/workflows/ci.yml", "wrong workflow")
    require(run["event"] in {"pull_request", "push", "workflow_dispatch"}, "unrecognized trigger")
    run_id, attempt = run["id"], run["run_attempt"]
    require(type(run_id) is int and run_id > 0 and type(attempt) is int and attempt > 0, "invalid run identity")
    require(run["html_url"] == f"https://github.com/{REPOSITORY}/actions/runs/{run_id}", "wrong evidence URL")
    require(run["status"] == "completed" and run["conclusion"] == "success", "CI not successful")
    payload = evidence["jobs"]
    jobs = payload["jobs"]
    require(type(payload["total_count"]) is int and payload["total_count"] == len(jobs), "jobs pagination incomplete")
    names = [job["name"] for job in jobs]
    require(len(names) == len(set(names)), "duplicate job names/attempts")
    require(set(names) == set(matrix["ci_gates"]), "missing or unreviewed CI jobs")
    job_ids = [job["id"] for job in jobs]
    require(all(type(job_id) is int and job_id > 0 for job_id in job_ids),
            "invalid job resource identity")
    require(len(job_ids) == len(set(job_ids)), "duplicate job resource identity")
    for job in jobs:
        name = job["name"]
        require(type(job["run_id"]) is int and type(job["run_attempt"]) is int and
                job["run_id"] == run_id and job["run_attempt"] == attempt and
                job["head_sha"] == expected_head, f"mixed run/head/attempt: {name}")
        require(job["run_url"] == f"https://api.github.com/repos/{REPOSITORY}/actions/runs/{run_id}",
                f"wrong job run URL: {name}")
        require(job["html_url"] == f"https://github.com/{REPOSITORY}/actions/runs/{run_id}/job/{job['id']}",
                f"wrong job evidence URL: {name}")
        require(job["status"] == "completed" and job["conclusion"] == "success", f"job not successful: {name}")
        steps = job["steps"]
        step_numbers = [step["number"] for step in steps]
        require(all(type(number) is int and number > 0 for number in step_numbers),
                f"invalid step resource identity: {name}")
        # GitHub numbers each job independently, with possible post-action gaps.
        # A successful name cannot stand in for another or reordered resource.
        require(all(left < right for left, right in zip(step_numbers, step_numbers[1:])),
                f"unordered or duplicate step resources: {name}")
        step_names = [step["name"] for step in steps]
        require(len(step_names) == len(set(step_names)), f"duplicate steps: {name}")
        require(set(matrix["ci_gates"][name]) <= set(step_names), f"missing critical step: {name}")
        for step in steps:
            require(step["status"] == "completed" and step["conclusion"] == "success",
                    f"step not successful: {name}/{step['name']}")
    return run["html_url"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--matrix", type=Path, default=ROOT / "qa/matrix.json")
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--head")
    parser.add_argument("--release", action="store_true", help="fail while integration gates remain open")
    args = parser.parse_args()
    try:
        matrix = read_json(args.matrix)
        cases = validate_matrix(matrix)
        print(f"QA inventory valid: {len(cases)} cases; this does not execute their tests.")
        if args.evidence:
            url = validate_ci(matrix, read_json(args.evidence), args.head)
            print(f"Observed baseline CI complete for {args.head}: {url}")
        elif args.head:
            raise ValueError("--head requires --evidence")
        pending = [c["id"] for c in cases if c["status"] == "pending-integration"]
        print("Personal Alpha integration pending: " + ", ".join(pending))
        if args.release:
            require(args.evidence is not None, "release requires current-head CI evidence")
            require(not pending, "Personal Alpha release blocked by integration evidence")
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(f"QA check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
