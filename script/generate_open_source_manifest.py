#!/usr/bin/env python3
"""Generate deterministic, repository-derived open-source publication evidence."""

from __future__ import annotations

import argparse
from pathlib import Path

from publication_evidence import MANIFEST_PATH, build_manifest, write_json


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=MANIFEST_PATH)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    write_json(build_manifest(), arguments.output.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
