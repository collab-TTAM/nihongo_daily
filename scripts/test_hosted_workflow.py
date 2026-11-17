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
        trigger = re.search(
            r"(?ms)^on:\n(.*?)(?=^[A-Za-z0-9_-]+:|\\Z)", self.workflow
        )
        self.assertIsNotNone(trigger)
        events = re.findall(r"(?m)^  ([A-Za-z0-9_-]+):", trigger.group(1))
        self.assertEqual(events, ["workflow_dispatch"])
        self.assertRegex(
            self.workflow,
            r"(?ms)^      confirm_non_production:\n"
            r"(?:(?!^      [A-Za-z0-9_-]+:).)*"
            r"^        type: boolean$",
        )
        self.assertRegex(
            self.workflow,
            r"(?ms)^        required: true\n        default: false$",
        )
        self.assertNotRegex(
            self.workflow, r"(?m)^  (?:push|pull_request|schedule|workflow_run):"
        )

    def test_confirmation_gates_the_protected_staging_job(self):
        self.assertRegex(
            self.workflow,
            r"(?ms)^  auth-a-b:\n"
            r"    if: \\$\\{\\{ inputs\\.confirm_non_production \\}\\}\n"
            r"    environment: supabase-staging\n"
            r"    runs-on: windows-2022$",
        )
        self.assertEqual(self.workflow.count("environment: supabase-staging"), 1)

    def test_permissions_and_concurrency_are_minimal_and_non_cancelling(self):
        self.assertRegex(self.workflow, r"(?m)^permissions:\n  contents: read$")
        self.assertRegex(
            self.workflow,
            r"(?m)^concurrency:\n  group: hosted-supabase-acceptance\n"
            r"  cancel-in-progress: false$",
        )
        self.assertNotRegex(self.workflow, r"(?m)^\s+[A-Za-z_-]+: write$")

    def test_checkout_uses_the_selected_dispatch_ref_and_hosted_windows_runner(self):
        self.assertRegex(
            self.workflow,
            r"(?ms)^      - uses: actions/checkout@v4\n"
            r"        with:\n          ref: \\$\\{\\{ github\\.ref \\}\\}",
        )
        self.assertIn("runs-on: windows-2022", self.workflow)
        self.assertIn('python-version: "3.12"', self.workflow)
        self.assertIn('flutter-version: "3.35.4"', self.workflow)
        self.assertIn("flutter build windows --release -t tool/windows_hosted_runtime_fixture.dart", self.workflow)
        self.assertIn(r"run: .\\tool\\verify_windows_hosted_runtime.ps1", self.workflow)

    def test_exact_six_secrets_are_scoped_to_the_two_probe_steps(self):
        references = re.findall(
            r"\\$\\{\\{\\s*secrets\\.([A-Z0-9_]+)\\s*\\}\\}", self.workflow
        )
        self.assertEqual(len(references), 12)
        self.assertEqual(set(references), EXPECTED_SECRETS)
        for name in EXPECTED_SECRETS:
            self.assertEqual(references.count(name), 2)

        secret_steps = []
        for block in re.split(r"(?m)^      - ", self.workflow):
            refs = re.findall(r"\\$\\{\\{\\s*secrets\\.([A-Z0-9_]+)\\s*\\}\\}", block)
            if not refs:
                continue
            name = re.search(r"(?m)^name: (.+)$", block)
            self.assertIsNotNone(name)
            self.assertIn(name.group(1), SECRET_STEPS)
            self.assertEqual(len(refs), 6)
            self.assertEqual(set(refs), EXPECTED_SECRETS)
            secret_steps.append(name.group(1))
        self.assertEqual(set(secret_steps), SECRET_STEPS)
        self.assertEqual(len(secret_steps), 2)
        self.assertNotIn("SUPABASE_SERVICE_ROLE_KEY", self.workflow)
        self.assertNotIn("JWT_SECRET", self.workflow)


if __name__ == "__main__":
    unittest.main(verbosity=2)
