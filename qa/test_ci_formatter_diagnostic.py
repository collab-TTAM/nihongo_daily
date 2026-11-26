from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "ci.yml"


def job_block(source: str, name: str) -> str:
    pattern = rf"^  {re.escape(name)}:\n(?P<body>.*?)(?=^  [A-Za-z0-9_-]+:\n|\Z)"
    match = re.search(pattern, source, re.MULTILINE | re.DOTALL)
    if match is None:
        raise AssertionError(f"Missing workflow job: {name}")
    return match.group("body")


def step_block(job: str, name: str) -> str:
    lines = job.splitlines()
    marker = f"      - name: {name}"
    matches = [index for index, line in enumerate(lines) if line == marker]
    if len(matches) != 1:
        raise AssertionError(f"Expected one workflow step {name!r}, found {len(matches)}")
    start = matches[0]
    end = next(
        (index for index in range(start + 1, len(lines)) if lines[index].startswith("      - ")),
        len(lines),
    )
    return "\n".join(lines[start:end])


class FormatterDiagnosticWorkflowTest(unittest.TestCase):
    def test_formatter_diagnostic_always_runs_without_weakening_gate(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        flutter = job_block(workflow, "flutter")
        formatter = step_block(flutter, "Run dart format --output=none --set-exit-if-changed .")
        diagnostic = step_block(flutter, "Show Dart formatter diff on failure")

        self.assertIn("        if: always()", diagnostic)
        self.assertIn('if [[ "${{ steps.dart_format.outcome }}" == "failure" ]]; then', diagnostic)
        self.assertIn("git diff -- .", diagnostic)
        self.assertIn("No formatter diff to show.", diagnostic)
        self.assertNotIn("failure() &&", diagnostic)
        self.assertNotIn("continue-on-error", diagnostic)

        self.assertIn("dart format --output=none --set-exit-if-changed .", formatter)
        self.assertIn("git diff --exit-code -- .", formatter)
        self.assertIn("exit 1", formatter)
        self.assertIn("flutter analyze", flutter)
        self.assertIn("flutter test", flutter)


if __name__ == "__main__":
    unittest.main()
