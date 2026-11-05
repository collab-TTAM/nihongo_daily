"""Print a bounded, redacted Supabase CLI startup log for CI failures only."""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


_SECRET_ASSIGNMENT = re.compile(
    r"(?i)(\b(?:[A-Z0-9_]*(?:KEY|TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL)[A-Z0-9_]*|"
    r"(?:anon|service[_ -]?role|jwt|db|access|refresh|api)\s+"
    r"(?:key|token|secret|password))\b\s*[:=]\s*)"
    r'("[^"]*"|\'[^\']*\'|[^\s,;]+)'
)
_JWT = re.compile(
    r"(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]{10,}\."
    r"[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{8,}(?![A-Za-z0-9_-])"
)
_BEARER = re.compile(r"(?i)\b(Bearer\s+)[A-Za-z0-9._~+/=-]+")
_POSTGRES_URL = re.compile(
    r"(?i)\b((?:postgres(?:ql)?://)[^:/\s@]+:)[^@\s/]+(@)"
)


def redact_text(value: str) -> str:
    """Redact common CLI credential assignments, JWTs, bearer values and DB URLs."""
    redacted = _SECRET_ASSIGNMENT.sub(
        lambda match: match.group(1) + "[REDACTED]", value
    )
    redacted = _BEARER.sub(lambda match: match.group(1) + "[REDACTED]", redacted)
    redacted = _JWT.sub("[REDACTED_JWT]", redacted)
    return _POSTGRES_URL.sub(
        lambda match: match.group(1) + "[REDACTED]" + match.group(2), redacted
    )


def format_log(value: str, max_lines: int = 120) -> str:
    """Redact before returning only the final bounded number of lines."""
    if not 1 <= max_lines <= 500:
        raise ValueError("max_lines must be between 1 and 500")
    lines = redact_text(value).splitlines()
    if not lines:
        return "(no startup output captured)"
    return "\n".join(lines[-max_lines:])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log_path", type=Path)
    parser.add_argument("--tail", type=int, default=120)
    args = parser.parse_args()
    if not 1 <= args.tail <= 500:
        parser.error("--tail must be between 1 and 500")
    try:
        output = format_log(
            args.log_path.read_text(encoding="utf-8", errors="replace"),
            args.tail,
        )
    except OSError:
        print("Unable to read captured Supabase startup log.", file=sys.stderr)
        return 2
    sys.stdout.write(output + ("" if output.endswith("\n") else "\n"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
