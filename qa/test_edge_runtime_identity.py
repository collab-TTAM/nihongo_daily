"""TEST ONLY upstream-reported identity fixtures; not container execution evidence."""
from copy import deepcopy
import importlib.util
import io
import json
from pathlib import Path
from unittest.mock import patch
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("edge_probe", ROOT / "scripts/verify_edge_user_worker.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
# Pinned upstream bootstrap.js blob1a98593cee8882faa9206b8a274496b5e8166935.
REPORTED = {"deno": "supabase-edge-runtime-1.77.4 (compatible with Deno v2.1.4)",
            "v8": "11.6.189.12", "typescript": "5.1.6"}


class EdgeRuntimeIdentityTests(unittest.TestCase):
    def test_pinned_branded_worker_report_accepts_without_confusing_cli_crate_version(self):
        probe.verify_runtime_metadata(deepcopy(REPORTED), probe.EDGE_RUNTIME_METADATA)
        # JSON object member order does not change the fingerprint.
        probe.verify_runtime_metadata(dict(reversed(list(REPORTED.items()))), probe.EDGE_RUNTIME_METADATA)

    def test_other_image_plain_deno_and_changed_compatibility_cannot_pass(self):
        for deno in ("2.1.4", "2.9.6", "0.1.0", "1.77.4",
                     "supabase-edge-runtime-1.77.3 (compatible with Deno v2.1.4)",
                     "supabase-edge-runtime-v1.77.4 (compatible with Deno v2.1.4)",
                     "supabase-edge-runtime-1.77.4 (compatible with Deno v2.1.5)",
                     REPORTED["deno"] + " untrusted", REPORTED["deno"] + "\n"):
            with self.subTest(deno=deno), self.assertRaisesRegex(AssertionError, "^Unexpected user-worker runtime metadata$"):
                probe.verify_runtime_metadata({**REPORTED, "deno": deno}, probe.EDGE_RUNTIME_METADATA)

    def test_missing_extra_mixed_or_malformed_metadata_is_rejected_without_echo(self):
        values = [None, True, 42, "fixture-secret", [], list(REPORTED.items()),
                  {**REPORTED, "secret": "fixture-secret"}]
        for key in REPORTED:
            value = deepcopy(REPORTED)
            del value[key]
            values.append(value)
            for invalid in (None, 42, "fixture-secret", {}):
                values.append({**REPORTED, key: invalid})
        for value in values:
            with self.subTest(value=value), self.assertRaises(AssertionError) as error:
                probe.verify_runtime_metadata(value, probe.EDGE_RUNTIME_METADATA)
            self.assertEqual(str(error.exception), "Unexpected user-worker runtime metadata")

    def test_wrong_runtime_rejects_before_any_ai_request_or_docker_call(self):
        class Response(io.BytesIO):
            status = 200
            headers = {}
        data = {"fixtureOnly": True, "lane": "user-worker",
                "runtime": {**REPORTED, "deno": "2.1.4"}, "metrics": {}}
        with patch.object(probe, "urlopen", return_value=Response(json.dumps(data).encode())) as http, \
             patch.object(probe, "docker") as docker:
            with self.assertRaisesRegex(AssertionError, "^Unexpected user-worker runtime metadata$"):
                probe.probe("http://127.0.0.1:1")
            self.assertEqual(http.call_count, 1)
            self.assertEqual(http.call_args.args[0].get_method(), "GET")
            self.assertEqual(http.call_args.args[0].full_url, "http://127.0.0.1:1/__probe")
            docker.assert_not_called()


if __name__ == "__main__":
    unittest.main()
