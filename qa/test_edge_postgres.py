"""Negative TEST ONLY fixture guards; these are not Edge/SQL execution proof."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch, call
from copy import deepcopy

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("edge_pg_probe", ROOT / "scripts/verify_edge_postgres.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class EdgePostgresGuardTests(unittest.TestCase):
    def test_only_exact_disposable_database_is_accepted(self):
        probe.require_disposable_database(probe.DATABASE)
        for value in (None, "", probe.DATABASE + "?sslmode=disable",
                      probe.DATABASE.replace("localhost", "production.example"),
                      probe.DATABASE.replace("nihongo_test", "postgres")):
            with self.subTest(value=value), self.assertRaises(AssertionError):
                probe.require_disposable_database(value)

    def test_wrong_database_is_rejected_before_process_or_container(self):
        with patch.dict(probe.os.environ, {"TEST_DATABASE_URL": "postgresql://private"}), \
                patch.object(probe.subprocess, "run") as run, patch.object(probe, "docker") as docker:
            with self.assertRaises(AssertionError):
                probe.main()
            run.assert_not_called()
            docker.assert_not_called()

    def test_wrong_runtime_cannot_reach_sql_or_post(self):
        metadata = {"fixtureOnly": True, "lane": "postgres-user-worker", "runtime": {"deno": "2.1.4"}}
        with patch.object(probe, "request", return_value=metadata) as request, \
                patch.object(probe, "sql") as sql:
            with self.assertRaisesRegex(AssertionError, "Unexpected user-worker runtime metadata"):
                probe.probe("http://127.0.0.1:8001", "http://127.0.0.1:8002", lambda: None)
            request.assert_called_once_with("http://127.0.0.1:8001", "/__probe", method="GET")
            sql.assert_not_called()

    def test_database_response_uuid_cannot_inject_observation_sql(self):
        for value in (None, {}, "' OR true--", "71000000-0000-4000-8000-000000000001';DELETE"):
            with self.subTest(value=value), self.assertRaises(AssertionError):
                probe.uuid_sql(value)
        self.assertEqual(probe.uuid_sql(probe.OWNERS["A"]), "'" + probe.OWNERS["A"] + "'::uuid")

    def test_phase_snapshots_reject_raw_unknown_fields_unbounded_values_and_categories(self):
        lanes = ("normal", "acquire", "complete", "malformed", "held", "transport")
        good = {name: {"calls": 0, "opened": 1, "closed": 1, "injected": False,
                       "phase": "close", "failures": [{"phase": "connect", "kind": "refused"}]} for name in lanes}
        self.assertEqual(probe.safe_metrics(good), good)
        for field, value in (("token", "PRIVATE"), ("calls", True), ("opened", 1001),
                             ("phase", "PRIVATE SQL"), ("failures", [{"phase": "connect", "kind": "PRIVATE URL"}]),
                             ("failures", [{"phase": "connect", "kind": "unknown", "message": "PRIVATE"}]),
                             ("failures", [{"phase": "connect", "kind": "refused"}] * 9)):
            bad = deepcopy(good)
            bad["transport"][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(AssertionError):
                probe.safe_metrics(bad)
        with patch.object(probe, "metadata", side_effect=RuntimeError("PRIVATE token")), patch("builtins.print") as output:
            probe.print_safe_metrics(["http://127.0.0.1:8001"])
            output.assert_called_once_with("TEST ONLY Edge PostgreSQL phase snapshot unavailable")

    def test_first_diagnostic_failure_still_removes_both_owned_containers(self):
        def docker(*args, **kwargs):
            if args == ("logs", "first"):
                raise RuntimeError("fixture diagnostics unavailable")
            return ""
        with patch.object(probe, "docker", side_effect=docker) as docker, patch("builtins.print"):
            with self.assertRaisesRegex(AssertionError, "Fixture container cleanup"):
                probe.cleanup(["first", "second"], diagnostics=True)
            self.assertIn(call("rm", "--force", "first", timeout=20), docker.call_args_list)
            self.assertIn(call("rm", "--force", "second", timeout=20), docker.call_args_list)

    def test_first_removal_failure_still_attempts_other_owned_container(self):
        def docker(*args, **kwargs):
            if args == ("rm", "--force", "first"):
                raise RuntimeError("fixture cleanup unavailable")
            return ""
        with patch.object(probe, "docker", side_effect=docker) as docker:
            with self.assertRaisesRegex(AssertionError, "Fixture container cleanup"):
                probe.cleanup(["first", "second"], diagnostics=False)
            self.assertEqual(docker.call_args_list, [
                call("rm", "--force", "first", timeout=20),
                call("rm", "--force", "second", timeout=20)])


if __name__ == "__main__":
    unittest.main()
