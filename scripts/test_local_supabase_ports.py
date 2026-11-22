#!/usr/bin/env python3
"""Regression tests for collision-free disposable Supabase CI ports."""
from __future__ import annotations

import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_local_supabase_ports import PORT_SPECS, choose_ports, prepare, rewrite_config

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW_PATH = ROOT / ".github" / "workflows" / "ci.yml"

SAMPLE_CONFIG = """project_id = "nihongo-daily"

[api]
enabled = true
port = 54321
schemas = ["public", "graphql_public"]

[db]
port = 54322
shadow_port = 54320
major_version = 17

[db.seed]
enabled = false
"""

PORTS = {
    "ND_LOCAL_SUPABASE_API_PORT": 21001,
    "ND_LOCAL_SUPABASE_DB_PORT": 21002,
    "ND_LOCAL_SUPABASE_SHADOW_PORT": 21003,
}


class LocalSupabasePortTests(unittest.TestCase):
    def test_kernel_selects_three_distinct_ephemeral_ports(self):
        selected = choose_ports()
        values = list(selected.values())
        self.assertEqual(len(values), 3)
        self.assertEqual(len(set(values)), 3)
        self.assertTrue(all(1024 <= value <= 65535 for value in values))

    def test_choose_ports_skips_invalid_and_duplicate_candidates(self):
        candidates = iter((54321, 54321, 0, 65536, 54322, 54323))
        selected = choose_ports(lambda: next(candidates))
        self.assertEqual(
            selected,
            {
                "ND_LOCAL_SUPABASE_API_PORT": 54321,
                "ND_LOCAL_SUPABASE_DB_PORT": 54322,
                "ND_LOCAL_SUPABASE_SHADOW_PORT": 54323,
            },
        )

    def test_rewrite_changes_only_api_database_and_shadow_ports(self):
        updated = rewrite_config(SAMPLE_CONFIG, PORTS)
        parsed = tomllib.loads(updated)
        self.assertEqual(parsed["api"]["port"], 21001)
        self.assertEqual(parsed["db"]["port"], 21002)
        self.assertEqual(parsed["db"]["shadow_port"], 21003)
        self.assertEqual(parsed["db"]["major_version"], 17)
        self.assertFalse(parsed["db"]["seed"]["enabled"])
        self.assertIn('project_id = "nihongo-daily"', updated)

    def test_rejects_incomplete_or_duplicate_port_selection(self):
        with self.assertRaises(ValueError):
            rewrite_config(SAMPLE_CONFIG, {"ND_LOCAL_SUPABASE_API_PORT": 21001})
        duplicate = dict(PORTS)
        duplicate["ND_LOCAL_SUPABASE_DB_PORT"] = duplicate["ND_LOCAL_SUPABASE_API_PORT"]
        with self.assertRaises(ValueError):
            rewrite_config(SAMPLE_CONFIG, duplicate)

    def test_rejects_missing_or_duplicate_config_entries(self):
        missing = SAMPLE_CONFIG.replace("port = 54321\n", "")
        with self.assertRaises(ValueError):
            rewrite_config(missing, PORTS)
        duplicate = SAMPLE_CONFIG.replace(
            "port = 54321\n",
            "port = 54321\nport = 54324\n",
        )
        with self.assertRaises(ValueError):
            rewrite_config(duplicate, PORTS)

    def test_prepare_writes_config_and_numeric_github_environment_values(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config_path = root / "config.toml"
            env_path = root / "github-env"
            config_path.write_text(SAMPLE_CONFIG, encoding="utf-8")
            env_path.write_text("", encoding="utf-8")
            candidates = iter(PORTS.values())
            selected = prepare(config_path, env_path, lambda: next(candidates))
            self.assertEqual(selected, PORTS)
            self.assertEqual(
                tomllib.loads(config_path.read_text(encoding="utf-8"))["db"]["port"],
                21002,
            )
            self.assertEqual(
                env_path.read_text(encoding="utf-8").splitlines(),
                [f"{name}={PORTS[name]}" for _section, _key, name in PORT_SPECS],
            )
            self.assertFalse((root / ".config.toml.ci-tmp").exists())

    def test_prepare_leaves_config_unchanged_when_selection_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config_path = root / "config.toml"
            env_path = root / "github-env"
            config_path.write_text(SAMPLE_CONFIG, encoding="utf-8")
            original = config_path.read_text(encoding="utf-8")
            with self.assertRaises(ValueError):
                prepare(config_path, env_path, lambda: 0)
            self.assertEqual(config_path.read_text(encoding="utf-8"), original)
            self.assertFalse(env_path.exists())

    def test_ci_runs_port_tests_and_validates_selected_ports(self):
        workflow = WORKFLOW_PATH.read_text(encoding="utf-8")
        self.assertIn(
            "run: python3 scripts/test_local_supabase_ports.py",
            workflow,
        )
        self.assertIn(
            'run: python3 scripts/prepare_local_supabase_ports.py "$GITHUB_ENV"',
            workflow,
        )
        self.assertIn('os.environ["ND_LOCAL_SUPABASE_API_PORT"]', workflow)
        self.assertIn('os.environ["ND_LOCAL_SUPABASE_DB_PORT"]', workflow)
        self.assertIn('os.environ["ND_LOCAL_SUPABASE_SHADOW_PORT"]', workflow)
        self.assertIn('api.port != selected_ports["api"]', workflow)
        self.assertIn('database.port != selected_ports["db"]', workflow)
        self.assertLess(
            workflow.index("Select collision-free local Supabase ports"),
            workflow.index("Start disposable local Supabase services"),
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
