#!/usr/bin/env python3
"""Fail closed until every publication blocker has documented resolution."""

from __future__ import annotations

from publication_evidence import build_manifest


def main() -> int:
    blockers = build_manifest()["publication"]["blockers"]
    if blockers:
        print("Publication gates: BLOCKED")
        for blocker in blockers:
            print(f"- {blocker['code']}: {blocker['detail']}")
        return 1
    print("Publication gates: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
