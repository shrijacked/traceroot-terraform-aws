#!/usr/bin/env python3
"""ecr_repositories must cover every repository the module creates.

A hand-written output map drifted from local.services and dropped detector.
Pipelines that push from that output then never publish the detector image.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def services() -> list[str]:
    text = (ROOT / "ecr.tf").read_text()
    match = re.search(r"services\s*=\s*\[(.*?)\]", text, re.S)
    if match is None:
        sys.exit("ecr.tf has no local.services list")
    return re.findall(r'"([^"]+)"', match.group(1))


def output_block() -> str:
    text = (ROOT / "outputs.tf").read_text()
    match = re.search(r'output "ecr_repositories" \{.*?\n\}', text, re.S)
    if match is None:
        sys.exit('outputs.tf has no ecr_repositories output')
    return match.group(0)


def main() -> None:
    names = services()
    block = output_block()
    derived = re.search(
        r"for\s+\w+\s*,\s*\w+\s+in\s+aws_ecr_repository\.services\b",
        block,
    )
    if derived:
        return
    missing = [name for name in names if f'["{name}"]' not in block]
    if missing:
        print("ecr_repositories omits: " + ", ".join(missing), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
