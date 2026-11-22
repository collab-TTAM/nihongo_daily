#!/usr/bin/env python3
"""Choose collision-free host ports for the disposable Supabase CI stack."""
from __future__ import annotations

import re
import socket
import sys
import tomllib
from pathlib import Path
from typing import Callable

PORT_SPECS = (
    ("api", "port", "ND_LOCAL_SUPABASE_API_PORT"),
    ("db", "port", "ND_LOCAL_SUPABASE_DB_PORT"),
    ("db", "shadow_port", "ND_LOCAL_SUPABASE_SHADOW_PORT"),
)


def _free_port() -> int:
    """Ask the kernel for an available TCP port on the Docker-published host."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("0.0.0.0", 0))
        return listener.getsockname()[1]


def choose_ports(port_factory: Callable[[], int] = _free_port) -> dict[str, int]:
    """Choose three distinct unprivileged ports, retrying invalid/colliding picks."""
    chosen: dict[str, int] = {}
    used: set[int] = set()
    for _section, _key, env_name in PORT_SPECS:
        selected = None
        for _attempt in range(20):
            candidate = port_factory()
            if (
                type(candidate) is int
                and 1024 <= candidate <= 65535
                and candidate not in used
            ):
                selected = candidate
                break
        if selected is None:
            raise ValueError("Could not select three distinct local Supabase ports")
        chosen[env_name] = selected
        used.add(selected)
    return chosen


def _replace_section_port(source: str, section: str, key: str, port: int) -> str:
    if type(port) is not int or not 1024 <= port <= 65535:
        raise ValueError("Invalid local Supabase port")
    headers = list(re.finditer(rf"(?m)^\[{re.escape(section)}\][ \t]*$", source))
    if len(headers) != 1:
        raise ValueError(f"Expected exactly one [{section}] section")
    start = headers[0].end()
    next_header = re.search(r"(?m)^\[[^\]]+\][ \t]*$", source[start:])
    end = start + next_header.start() if next_header else len(source)
    block = source[start:end]
    key_pattern = re.compile(
        rf"(?m)^([ \t]*{re.escape(key)}[ \t]*=[ \t]*)\d+([ \t]*(?:#.*)?)$"
    )
    matches = list(key_pattern.finditer(block))
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one {section}.{key} entry")
    updated, count = key_pattern.subn(
        lambda match: f"{match.group(1)}{port}{match.group(2)}",
        block,
        count=1,
    )
    if count != 1:
        raise ValueError(f"Could not update {section}.{key}")
    return source[:start] + updated + source[end:]


def rewrite_config(source: str, ports: dict[str, int]) -> str:
    required = {env_name for _section, _key, env_name in PORT_SPECS}
    if set(ports) != required:
        raise ValueError("Local Supabase port selection is incomplete")
    values = [ports[env_name] for _section, _key, env_name in PORT_SPECS]
    if len(set(values)) != len(PORT_SPECS):
        raise ValueError("Local Supabase ports must be distinct")
    updated = source
    for section, key, env_name in PORT_SPECS:
        updated = _replace_section_port(updated, section, key, ports[env_name])
    parsed = tomllib.loads(updated)
    for section, key, env_name in PORT_SPECS:
        if parsed[section][key] != ports[env_name]:
            raise ValueError(f"Local Supabase config did not retain {section}.{key}")
    return updated


def prepare(
    config_path: Path,
    github_env_path: Path,
    port_factory: Callable[[], int] = _free_port,
) -> dict[str, int]:
    config_path = Path(config_path)
    github_env_path = Path(github_env_path)
    original = config_path.read_text(encoding="utf-8")
    ports = choose_ports(port_factory)
    updated = rewrite_config(original, ports)

    temporary = config_path.with_name(f".{config_path.name}.ci-tmp")
    try:
        temporary.write_text(updated, encoding="utf-8")
        temporary.replace(config_path)
    finally:
        if temporary.exists():
            temporary.unlink()

    with github_env_path.open("a", encoding="utf-8") as output:
        for _section, _key, env_name in PORT_SPECS:
            output.write(f"{env_name}={ports[env_name]}\n")
    return ports


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: prepare_local_supabase_ports.py GITHUB_ENV")
    try:
        ports = prepare(Path("supabase/config.toml"), Path(sys.argv[1]))
    except (OSError, ValueError, tomllib.TOMLDecodeError):
        raise SystemExit(
            "Local Supabase port preparation failed; no secret values were read."
        ) from None
    print(
        "Selected distinct ephemeral host ports for local Supabase "
        f"(API/DB/shadow): {ports['ND_LOCAL_SUPABASE_API_PORT']}/"
        f"{ports['ND_LOCAL_SUPABASE_DB_PORT']}/"
        f"{ports['ND_LOCAL_SUPABASE_SHADOW_PORT']}."
    )


if __name__ == "__main__":
    main()
