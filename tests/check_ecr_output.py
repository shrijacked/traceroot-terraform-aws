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


def omitted(block: str, names: list[str]) -> list[str]:
    """Services this output can leave out.

    A for over the repository map covers every service only when it has no
    filter. ``if name != "detector"`` still contains that for, and returning
    there let the omission through.
    """
    derived = re.search(
        r"for\s+\w+\s*,\s*\w+\s+in\s+aws_ecr_repository\.services\s*:(.*)",
        block,
        re.S,
    )
    if derived and re.search(r"\bif\b", derived.group(1)) is None:
        return []
    return [name for name in names if f'["{name}"]' not in block]


def _reject_a_filter() -> None:
    filtered = (
        'output "ecr_repositories" {\n'
        "  value = {\n"
        "    for name, repo in aws_ecr_repository.services :"
        ' name => repo.repository_url if name != "detector"\n'
        "  }\n"
        "}\n"
    )
    missing = omitted(filtered, ["rest", "detector"])
    if "detector" not in missing:
        sys.exit("a filtered comprehension was accepted")


def main() -> None:
    _reject_a_filter()
    missing = omitted(output_block(), services())
    if missing:
        print("ecr_repositories omits: " + ", ".join(missing), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
