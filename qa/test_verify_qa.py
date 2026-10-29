"""Negative release-assurance regressions. Synthetic evidence is TEST ONLY."""
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("verify_qa", ROOT / "scripts/verify_qa.py")
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)
HEAD = "a" * 40


def fixture(matrix):
    # Generated metadata cannot count as CI evidence for the application.
    return {"run": {
        "id": 123, "run_attempt": 2, "head_sha": HEAD,
        "repository": {"full_name": qa.REPOSITORY}, "name": "CI",
        "path": ".github/workflows/ci.yml", "event": "pull_request",
        "html_url": f"https://github.com/{qa.REPOSITORY}/actions/runs/123",
        "status": "completed", "conclusion": "success",
    }, "jobs": {"total_count": len(matrix["ci_gates"]), "jobs": [
        {"id": index, "name": name, "run_id": 123, "run_attempt": 2, "head_sha": HEAD,
         "run_url": f"https://api.github.com/repos/{qa.REPOSITORY}/actions/runs/123",
         "html_url": f"https://github.com/{qa.REPOSITORY}/actions/runs/123/job/{index}",
         "status": "completed", "conclusion": "success", "steps": [
             {"name": step, "status": "completed", "conclusion": "success"}
             for step in steps]}
        for index, (name, steps) in enumerate(matrix["ci_gates"].items(), start=1)]}}


class QaEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.matrix = qa.read_json(ROOT / "qa/matrix.json")
        self.evidence = fixture(self.matrix)

    def rejected(self):
        with self.assertRaises((ValueError, KeyError, TypeError)):
            qa.validate_ci(self.matrix, self.evidence, HEAD)

    def test_inventory_has_executable_anchors_and_open_release_gates(self):
        cases = qa.validate_matrix(self.matrix)
        self.assertTrue(qa.RELEASE_CASES <= {c["id"] for c in cases
                                            if c["status"] == "pending-integration"})

    def test_complete_same_head_latest_attempt_is_accepted_as_baseline_only(self):
        self.assertEqual(qa.validate_ci(self.matrix, self.evidence, HEAD),
                         f"https://github.com/{qa.REPOSITORY}/actions/runs/123")

    def test_saved_native_rerun_snapshot_has_one_complete_latest_attempt(self):
        # Captured Actions metadata, not generated success or hosted acceptance.
        evidence = qa.read_json(
            ROOT / "qa/evidence/20261029-native-receipts-9c986e0-attempt2.json")
        head = "9c986e0401d37ee13cee139280ecd23b33ce077d"
        self.assertEqual(evidence["run"]["run_attempt"], 2)
        self.assertEqual(qa.validate_ci(self.matrix, evidence, head),
                         "https://github.com/collab-TTAM/nihongo_daily/actions/runs/40840683867")
        for job in evidence["jobs"]["jobs"]:
            with self.subTest(job=job["name"]):
                mixed = deepcopy(evidence)
                next(j for j in mixed["jobs"]["jobs"]
                     if j["name"] == job["name"])["run_attempt"] = 1
                with self.assertRaisesRegex(ValueError, "mixed run/head/attempt"):
                    qa.validate_ci(self.matrix, mixed, head)

    def test_job_resource_ids_are_positive_integers_and_unique(self):
        for slot in range(5):
            for value in (None, False, 0, -1, 1.0, "1"):
                with self.subTest(slot=slot, value=value):
                    evidence = deepcopy(self.evidence)
                    evidence["jobs"]["jobs"][slot]["id"] = value
                    with self.assertRaises(ValueError):
                        qa.validate_ci(self.matrix, evidence, HEAD)
        self.evidence["jobs"]["jobs"][1]["id"] = self.evidence["jobs"]["jobs"][0]["id"]
        self.rejected()

    def test_job_resource_links_bind_repository_run_and_job(self):
        for slot in range(5):
            for key, value in (
                ("run_url", "https://api.github.com/repos/foreign/repo/actions/runs/123"),
                ("run_url", f"https://api.github.com/repos/{qa.REPOSITORY}/actions/runs/124"),
                ("html_url", f"https://github.com/{qa.REPOSITORY}/actions/runs/123/job/999"),
                ("html_url", f"https://github.com/{qa.REPOSITORY}/actions/runs/124/job/{slot + 1}"),
                ("html_url", "https://github.com/foreign/repo/actions/runs/123/job/1"),
            ):
                with self.subTest(slot=slot, field=key, value=value):
                    evidence = deepcopy(self.evidence)
                    evidence["jobs"]["jobs"][slot][key] = value
                    with self.assertRaises(ValueError):
                        qa.validate_ci(self.matrix, evidence, HEAD)

    def test_job_run_identity_rejects_numeric_aliases(self):
        for slot in range(5):
            for key, value in (("run_id", 123.0), ("run_attempt", 2.0)):
                with self.subTest(slot=slot, field=key):
                    evidence = deepcopy(self.evidence)
                    evidence["jobs"]["jobs"][slot][key] = value
                    with self.assertRaises(ValueError):
                        qa.validate_ci(self.matrix, evidence, HEAD)

    def test_saved_native_snapshot_rejects_mixed_job_resource_links(self):
        evidence = qa.read_json(
            ROOT / "qa/evidence/20261029-native-receipts-9c986e0-attempt2.json")
        head = "9c986e0401d37ee13cee139280ecd23b33ce077d"
        qa.validate_ci(self.matrix, evidence, head)
        for slot in range(5):
            with self.subTest(slot=slot):
                mixed = deepcopy(evidence)
                mixed["jobs"]["jobs"][slot]["html_url"] = (
                    evidence["jobs"]["jobs"][(slot + 1) % 5]["html_url"])
                with self.assertRaisesRegex(ValueError, "wrong job evidence URL"):
                    qa.validate_ci(self.matrix, mixed, head)

    def test_rejects_stale_head(self):
        self.evidence["run"]["head_sha"] = "b" * 40
        self.rejected()

    def test_requires_explicit_full_expected_head(self):
        for head in (None, "", "a" * 7):
            with self.subTest(head=head), self.assertRaises(ValueError):
                qa.validate_ci(self.matrix, self.evidence, head)

    def test_missing_failed_pending_skipped_jobs_are_not_success(self):
        original = deepcopy(self.evidence)
        for status, conclusion in (("queued", None), ("in_progress", None),
                                   ("completed", "failure"), ("completed", "skipped"),
                                   ("completed", "cancelled")):
            self.evidence = deepcopy(original)
            self.evidence["jobs"]["jobs"][0].update(status=status, conclusion=conclusion)
            self.rejected()
        self.evidence = deepcopy(original)
        self.evidence["jobs"]["jobs"].pop()
        self.evidence["jobs"]["total_count"] -= 1
        self.rejected()

    def test_skipped_or_missing_critical_step_cannot_hide_behind_green_job(self):
        step = self.evidence["jobs"]["jobs"][0]["steps"][0]
        step["conclusion"] = "skipped"
        self.rejected()
        step["conclusion"] = "success"
        self.evidence["jobs"]["jobs"][0]["steps"].pop(0)
        self.rejected()

    def test_each_missing_skipped_failed_or_pending_deno_gate_rejects_green_job(self):
        # Synthetic metadata only: new runtime gates cannot disappear behind a green job.
        for name, gate in (
            ("database", "Verify AI PostgreSQL adapters with pinned Deno"),
            ("ai-boundary", "Check AI modules with pinned Deno"),
            ("ai-boundary", "Verify AI boundary with pinned Deno"),
            ("ai-boundary", "Verify Deno native HTTP and permission boundaries"),
        ):
            self.assertIn(gate, self.matrix["ci_gates"][name])
            for mode in ("missing", "skipped", "failure", "pending"):
                with self.subTest(job=name, gate=gate, mode=mode):
                    evidence = deepcopy(self.evidence)
                    job = next(j for j in evidence["jobs"]["jobs"] if j["name"] == name)
                    step = next(s for s in job["steps"] if s["name"] == gate)
                    if mode == "missing":
                        job["steps"].remove(step)
                    else:
                        step.update(status="pending" if mode == "pending" else "completed",
                                    conclusion=None if mode == "pending" else mode)
                    with self.assertRaises(ValueError):
                        qa.validate_ci(self.matrix, evidence, HEAD)

    def test_missing_skipped_failed_or_pending_edge_user_worker_gate_rejects_green_job(self):
        for gate in ("Verify bundled Supabase Edge user worker",
                     "Publish Edge user-worker compatibility evidence"):
            self.assertIn(gate, self.matrix["ci_gates"]["ai-boundary"])
            for mode in ("missing", "skipped", "failure", "pending"):
                with self.subTest(mode=mode):
                    evidence = deepcopy(self.evidence)
                    job = next(j for j in evidence["jobs"]["jobs"] if j["name"] == "ai-boundary")
                    step = next(s for s in job["steps"] if s["name"] == gate)
                    if mode == "missing":
                        job["steps"].remove(step)
                    else:
                        step.update(status="pending" if mode == "pending" else "completed",
                                    conclusion=None if mode == "pending" else mode)
                    with self.assertRaises(ValueError):
                        qa.validate_ci(self.matrix, evidence, HEAD)


    def test_missing_skipped_failed_or_pending_native_assembly_gate_rejects_green_job(self):
        gate = "Verify trusted AI assembly with native PostgreSQL"
        self.assertIn(gate, self.matrix["ci_gates"]["database"])
        for mode in ("missing", "skipped", "failure", "pending"):
            with self.subTest(mode=mode):
                evidence = deepcopy(self.evidence)
                job = next(j for j in evidence["jobs"]["jobs"] if j["name"] == "database")
                step = next(s for s in job["steps"] if s["name"] == gate)
                if mode == "missing":
                    job["steps"].remove(step)
                else:
                    step.update(status="pending" if mode == "pending" else "completed",
                                conclusion=None if mode == "pending" else mode)
                with self.assertRaises(ValueError):
                    qa.validate_ci(self.matrix, evidence, HEAD)

    def test_missing_skipped_failed_or_pending_edge_postgres_gate_rejects_green_job(self):
        for gate in ("Verify bundled Edge PostgreSQL assembly",
                     "Publish Edge PostgreSQL assembly evidence"):
            self.assertIn(gate, self.matrix["ci_gates"]["database"])
            for mode in ("missing", "skipped", "failure", "pending"):
                with self.subTest(gate=gate, mode=mode):
                    evidence = deepcopy(self.evidence)
                    job = next(j for j in evidence["jobs"]["jobs"] if j["name"] == "database")
                    step = next(s for s in job["steps"] if s["name"] == gate)
                    if mode == "missing":
                        job["steps"].remove(step)
                    else:
                        step.update(status="pending" if mode == "pending" else "completed",
                                    conclusion=None if mode == "pending" else mode)
                    with self.assertRaises(ValueError):
                        qa.validate_ci(self.matrix, evidence, HEAD)

    def test_mixed_run_attempt_head_or_repository_is_rejected(self):
        for key, value in (("run_id", 124), ("run_attempt", 1), ("head_sha", "b" * 40)):
            evidence = deepcopy(self.evidence)
            evidence["jobs"]["jobs"][0][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                qa.validate_ci(self.matrix, evidence, HEAD)
        self.evidence["run"]["repository"]["full_name"] = "elsewhere/repo"
        self.rejected()

    def test_wrong_workflow_trigger_link_or_failed_run_is_rejected(self):
        for key, value in (("path", "other.yml"), ("event", "pull_request_target"),
                           ("name", "Other"), ("html_url", "https://example.com"),
                           ("status", "in_progress"), ("conclusion", "failure")):
            evidence = deepcopy(self.evidence)
            evidence["run"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                qa.validate_ci(self.matrix, evidence, HEAD)

    def test_paginated_duplicate_or_unreviewed_jobs_are_rejected(self):
        self.evidence["jobs"]["total_count"] += 1
        self.rejected()
        self.evidence["jobs"]["jobs"].append(deepcopy(self.evidence["jobs"]["jobs"][0]))
        self.rejected()
        self.evidence["jobs"]["jobs"][-1]["name"] = "new-unreviewed-job"
        self.rejected()

    def test_duplicate_steps_and_job_identity_omissions_are_rejected(self):
        steps = self.evidence["jobs"]["jobs"][0]["steps"]
        steps.append(deepcopy(steps[0]))
        self.rejected()
        steps.pop()
        del self.evidence["jobs"]["jobs"][0]["run_attempt"]
        self.rejected()

    def test_inventory_cannot_omit_or_claim_live_release_coverage(self):
        matrix = deepcopy(self.matrix)
        matrix["cases"] = [c for c in matrix["cases"] if c["id"] != "auth-live"]
        with self.assertRaises(ValueError):
            qa.validate_matrix(matrix)
        matrix = deepcopy(self.matrix)
        next(c for c in matrix["cases"] if c["id"] == "auth-live")["status"] = "passed"
        with self.assertRaises(ValueError):
            qa.validate_matrix(matrix)

    def test_deleted_test_anchor_or_dropped_ci_job_fails_inventory(self):
        self.matrix["cases"][0]["anchors"][0]["contains"] = "missing regression case"
        with self.assertRaises(ValueError):
            qa.validate_matrix(self.matrix)

        self.matrix = qa.read_json(ROOT / "qa/matrix.json")
        del self.matrix["ci_gates"]["windows"]
        with self.assertRaises(ValueError):
            qa.validate_matrix(self.matrix)

    def test_command_in_wrong_job_does_not_count_as_coverage(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for case in self.matrix["cases"]:
                for anchor in case.get("anchors", []):
                    path = root / anchor["path"]
                    path.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(ROOT / anchor["path"], path)
            workflow = root / ".github/workflows/ci.yml"
            workflow.parent.mkdir(parents=True)
            source = (ROOT / ".github/workflows/ci.yml").read_text()
            command = "      - run: npm audit --omit=dev --audit-level=moderate\n"
            self.assertIn(command, source)
            source = source.replace(command, "").replace("  flutter:\n", command + "\n  flutter:\n")
            workflow.write_text(source)
            with self.assertRaisesRegex(ValueError, "step missing from job ai-boundary"):
                qa.validate_matrix(self.matrix, root)

    def test_external_file_cannot_be_a_repository_test_anchor(self):
        self.matrix["cases"][0]["anchors"][0]["path"] = "../outside-test.py"
        with self.assertRaisesRegex(ValueError, "escapes repository"):
            qa.validate_matrix(self.matrix)

    def test_security_findings_cannot_be_dropped(self):
        self.matrix["findings"] = []
        with self.assertRaisesRegex(ValueError, "ranked security"):
            qa.validate_matrix(self.matrix)

    def test_duplicate_json_keys_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate.json"
            path.write_text('{"head_sha":"old", "head_sha":"new"}')
            with self.assertRaises(ValueError):
                qa.read_json(path)

    def test_release_cli_fails_even_when_all_baseline_ci_is_green(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test-only-evidence.json"
            path.write_text(json.dumps(self.evidence))
            result = subprocess.run([sys.executable, str(ROOT / "scripts/verify_qa.py"),
                                     "--evidence", str(path), "--head", HEAD, "--release"],
                                    text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("release blocked", result.stderr)


if __name__ == "__main__":
    unittest.main()
