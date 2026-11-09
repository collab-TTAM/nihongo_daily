#!/usr/bin/env python3
"""Build a read-only source-order projection for the quiz report importer.

The projection never writes to Supabase or changes canonical curriculum files.
Ordinals are original zero-based array positions, including inactive rows.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Sequence

SUPPORTED_LEVELS = ("N5", "N4")
KINDS = ("vocabulary", "grammar")
UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
MAX_ROWS = 5000
MAX_SOURCE_BYTES = 8 * 1024 * 1024


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _read_json(path: Path) -> tuple[Any, bytes]:
    raw = path.read_bytes()
    if len(raw) > MAX_SOURCE_BYTES:
        raise ValueError(f"oversized source file: {path.as_posix()}")
    try:
        return json.loads(raw.decode("utf-8"), object_pairs_hook=_unique_object), raw
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid UTF-8 JSON source: {path.as_posix()}") from error


def _positive_int(value: Any) -> bool:
    return type(value) is int and 1 <= value <= 2_147_483_647


def _manifest(root: Path) -> tuple[dict[str, Any], bytes]:
    value, raw = _read_json(root / "data" / "manifest.json")
    if not isinstance(value, dict) or value.get("schema_version") != "0.1":
        raise ValueError("unsupported curriculum manifest")
    levels = value.get("levels")
    if (
        not isinstance(levels, list)
        or not levels
        or any(type(level) is not str or level not in SUPPORTED_LEVELS for level in levels)
        or len(set(levels)) != len(levels)
    ):
        raise ValueError("invalid curriculum manifest levels")
    if not isinstance(value.get("counts"), dict):
        raise ValueError("missing curriculum manifest counts")
    return value, raw


def build_projection(root: Path, requested_levels: Sequence[str] | None = None) -> dict[str, Any]:
    root = Path(root)
    manifest, manifest_raw = _manifest(root)
    manifest_levels: list[str] = manifest["levels"]
    if requested_levels is None:
        levels = manifest_levels
    else:
        if (
            not requested_levels
            or any(type(level) is not str for level in requested_levels)
            or len(set(requested_levels)) != len(requested_levels)
            or any(level not in manifest_levels for level in requested_levels)
        ):
            raise ValueError("requested level is absent or duplicated")
        selected = set(requested_levels)
        levels = [level for level in manifest_levels if level in selected]

    sources: list[dict[str, Any]] = []
    for level in levels:
        level_counts = manifest["counts"].get(level)
        if not isinstance(level_counts, dict):
            raise ValueError(f"missing manifest counts for {level}")
        for kind in KINDS:
            expected_count = level_counts.get(kind)
            if type(expected_count) is not int or not 0 <= expected_count <= MAX_ROWS:
                raise ValueError(f"invalid manifest {kind} count for {level}")
            path = root / "data" / level.lower() / f"{kind}.json"
            data, raw = _read_json(path)
            if not isinstance(data, list) or len(data) != expected_count:
                raise ValueError(f"{level} {kind} count does not match manifest")
            if len(data) > MAX_ROWS:
                raise ValueError(f"{level} {kind} source is too large")
            seen: set[str] = set()
            rows: list[dict[str, Any]] = []
            for ordinal, record in enumerate(data):
                if not isinstance(record, dict):
                    raise ValueError(f"invalid {level} {kind} row at {ordinal}")
                item_id = record.get("id")
                if (
                    not isinstance(item_id, str)
                    or UUID.fullmatch(item_id) is None
                    or item_id in seen
                    or record.get("jlpt_level") != level
                    or type(record.get("is_active")) is not bool
                    or not _positive_int(record.get("content_version"))
                    or "source_ordinal" in record
                ):
                    raise ValueError(f"invalid {level} {kind} identity/metadata at {ordinal}")
                seen.add(item_id)
                rows.append({
                    "id": item_id,
                    "jlpt_level": level,
                    "source_ordinal": ordinal,
                    "content_version": record["content_version"],
                    "is_active": record["is_active"],
                })
            sources.append({
                "table": kind,
                "jlpt_level": level,
                "source_sha256": hashlib.sha256(raw).hexdigest(),
                "row_count": len(rows),
                "active_count": sum(row["is_active"] for row in rows),
                "rows": rows,
            })
    return {
        "schema_version": "nd-quiz-source-order-1",
        "manifest_sha256": hashlib.sha256(manifest_raw).hexdigest(),
        "sources": sources,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1],
                        help="repository root (defaults to this script's parent repository)")
    parser.add_argument("--level", action="append", choices=SUPPORTED_LEVELS,
                        help="export one or more manifest levels; defaults to every declared level")
    args = parser.parse_args(argv)
    try:
        projection = build_projection(args.root, args.level)
    except (OSError, TypeError, ValueError) as error:
        parser.error(str(error))
    sys.stdout.write(json.dumps(projection, ensure_ascii=False, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
