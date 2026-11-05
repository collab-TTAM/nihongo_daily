"""Regression tests for redacted disposable Supabase startup diagnostics."""
import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from redact_supabase_start_log import format_log, redact_text  # noqa: E402


class SupabaseStartLogRedactionTests(unittest.TestCase):
    def test_redacts_credentials_and_preserves_failure_context(self):
        log = "\n".join((
            "Starting disposable services",
            "anon key: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.signaturepart1234",
            "SUPABASE_SERVICE_ROLE_KEY=service-secret-value",
            "JWT_SECRET = jwt-secret-value",
            "DB password: db-secret-value",
            "Authorization: Bearer bearer-secret-value",
            "postgresql://postgres:database-secret-value@127.0.0.1:54322/postgres",
            "Error: container exited with status 1",
        ))

        safe = redact_text(log)

        for secret in (
            "signaturepart1234",
            "service-secret-value",
            "jwt-secret-value",
            "db-secret-value",
            "bearer-secret-value",
            "database-secret-value",
        ):
            with self.subTest(secret=secret):
                self.assertNotIn(secret, safe)
        self.assertIn("[REDACTED_JWT]", safe)
        self.assertIn("Bearer [REDACTED]", safe)
        self.assertIn("Error: container exited with status 1", safe)

    def test_tail_is_bounded_and_redaction_happens_before_output(self):
        log = "first line\nTOKEN=do-not-print\nthird line\nfourth line"
        self.assertEqual(format_log(log, max_lines=2), "third line\nfourth line")

    def test_rejects_unbounded_or_empty_tail(self):
        for count in (0, 501):
            with self.subTest(count=count), self.assertRaises(ValueError):
                format_log("diagnostic", max_lines=count)

    def test_empty_log_has_safe_placeholder(self):
        self.assertEqual(format_log(""), "(no startup output captured)")


if __name__ == "__main__":
    unittest.main()
