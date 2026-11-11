#!/usr/bin/env python3
"""The default Helm chart must be one that sets ALB health-check paths.

Chart 1.0.0 probes GET / on rest and web. rest answers 404 and web redirects,
so every target is unhealthy and the unhealthy-host alarms stay on.
The paths arrived in chart 1.0.1.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MINIMUM = (1, 0, 1)


def version_of(text: str, label: str) -> tuple[int, int, int]:
    match = re.search(r"(\d+)\.(\d+)\.(\d+)", text)
    if match is None:
        sys.exit(f"{label} has no x.y.z chart version")
    return tuple(int(part) for part in match.groups())


def main() -> None:
    variables = (ROOT / "variables.tf").read_text()
    block = re.search(
        r'variable "traceroot_helm_chart_version".*?default\s*=\s*"([^"]+)"',
        variables,
        re.S,
    )
    if block is None:
        sys.exit("variables.tf has no traceroot_helm_chart_version default")
    default = version_of(block.group(1), "default")

    readme = (ROOT / "README.md").read_text()
    example = re.search(
        r'traceroot_helm_chart_version\s*=\s*"([^"]+)"',
        readme,
    )
    if example is None:
        sys.exit("README example does not set traceroot_helm_chart_version")
    documented = version_of(example.group(1), "README")

    if default < MINIMUM or documented < MINIMUM:
        print(
            f"chart default {default} and README {documented} are below {MINIMUM}",
            file=sys.stderr,
        )
        sys.exit(1)
    if default != documented:
        print(
            f"chart default {default} does not match the README example {documented}",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
