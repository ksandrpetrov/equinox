#!/usr/bin/env python3
"""Compatibility wrapper for regenerating app brand assets."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "scripts/regenerate-design-assets.swift"


def main() -> int:
    return subprocess.run(
        ["/usr/bin/swift", str(GENERATOR), *sys.argv[1:]],
        cwd=ROOT,
        check=False,
    ).returncode


if __name__ == "__main__":
    raise SystemExit(main())
