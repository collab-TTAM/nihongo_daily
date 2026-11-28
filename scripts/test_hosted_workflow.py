#!/usr/bin/env python3
"""Offline safety regressions for the manual hosted Supabase workflow."""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW_PATH = ROOT / ".github" / "workflows" / "hosted-supabase-acceptance.yml"
EXPECTED_SECRETS = {
    "ND_STAGING_SUPABASE_URL",
    "ND_STAGING_SUPABASE_PUBLISHABLE_KEY",
    "ND_STAGING_USER_A_EMAIL",
    "ND_STAGING_USER_A_PASSWORD",
    "ND_STAGING_USER_B_EMAIL",
    "ND_STAGING_USER_B_PASSWORD",
}
SECRET_STEPS = {
    "Verify hosted Auth, profile ownership and A/B RLS",
    "Verify Windows Credential Manager restore and account switch",
}


class HostedWorkflowSafetyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = WORKFLOW_PATH.read_text(encoding="utf-8")

    def test_only_manual_dispatch_is_enabled_and_confirmation_defaults_false(self):
        trigger = self.workflow.split("on:\n", 1)[1].split("\npermissions:", 1)[0]
        event_lines = [
            line.strip()[:-1]
            for line in trigger.splitlines()
            if line.startswith("  ") and not line.startswith("    ") and line.strip().endswith(":")
        ]
        self.assertEqual(event_lines, ["workflow_dispatch"])
        self.assertIn("type: boolean", trigger)
        self.assertIn("required: true", trigger)
        self.assertIn("default: false", trigger)
        self.assertNotIn("push:", trigger)
        self.assertNotIn("pull_request:", trigger)
        self.assertNotIn("schedule:", trigger)

    def test_confirmation_gates_the_protected_staging_job(self):
        self.assertIn(
            "  auth-a-b:\n"
            "    if: ${{ inputs.confirm_non_production }}\n"
            "    environment: supabase-staging\n"
            "    runs-on: windows-2022\n",
            self.workflow,
        )
        self.assertEqual(self.workflow.count("environment: supabase-staging"), 1)

    def test_permissions_and_concurrency_are_minimal_and_non_cancelling(self):
        self.assertIn("permissions:\n  contents: read\n", self.workflow)
        self.assertIn(
            "concurrency:\n"
            "  group: hosted-supabase-acceptance\n"
            "  cancel-in-progress: false\n",
            self.workflow,
        )
        self.assertNotIn("contents: write", self.workflow)
        self.assertNotIn("actions: write", self.workflow)

    def test_checkout_uses_the_selected_dispatch_ref_and_hosted_windows_runner(self):
        self.assertIn(
            "      - uses: actions/checkout@v4\n"
            "        with:\n"
            "          ref: ${{ github.ref }}\n",
            self.workflow,
        )
        self.assertIn("runs-on: windows-2022", self.workflow)
        self.assertIn('python-version: "3.12"', self.workflow)
        self.assertIn('flutter-version: "3.35.4"', self.workflow)
        self.assertIn(
            "flutter build windows --release -t tool/windows_hosted_runtime_fixture.dart",
            self.workflow,
        )
        self.assertIn(r"run: .\tool\verify_windows_hosted_runtime.ps1", self.workflow)

    def test_exact_six_secrets_are_scoped_to_the_two_probe_steps(self):
        references = re.findall(r"secrets\.([A-Z0-9_]+)", self.workflow)
        self.assertEqual(len(references), 12)
        self.assertEqual(set(references), EXPECTED_SECRETS)
        for name in EXPECTED_SECRETS:
            self.assertEqual(references.count(name), 2)

        secret_steps = []
        for block in self.workflow.split("      - "):
            refs = re.findall(r"secrets\.([A-Z0-9_]+)", block)
            if not refs:
                continue
            first_line = block.splitlines()[0]
            self.assertTrue(first_line.startswith("name: "))
            step_name = first_line[len("name: "):]
            self.assertIn(step_name, SECRET_STEPS)
            self.assertEqual(len(refs), 6)
            self.assertEqual(set(refs), EXPECTED_SECRETS)
            secret_steps.append(step_name)
        self.assertEqual(set(secret_steps), SECRET_STEPS)
        self.assertEqual(len(secret_steps), 2)
        self.assertNotIn("SUPABASE_SERVICE_ROLE_KEY", self.workflow)
        self.assertNotIn("JWT_SECRET", self.workflow)


    def test_referenced_probe_exists_and_uses_only_documented_staging_secrets(self):
        probe_path = ROOT / "scripts" / "hosted_supabase_probe.py"
        self.assertTrue(probe_path.is_file())
        source = probe_path.read_text(encoding="utf-8")
        self.assertIn("REQUIRED_ENV = (", source)
        for name in EXPECTED_SECRETS:
            self.assertIn(f'"{name}"', source)
        self.assertNotIn("SUPABASE_SERVICE_ROLE_KEY", source)
        self.assertNotIn("JWT_SECRET", source)
        self.assertIn('"/auth/v1/logout"', source)
        self.assertIn('{"scope": "local"}', source)
        self.assertIn('"/rest/v1/rpc/submit_review"', source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
