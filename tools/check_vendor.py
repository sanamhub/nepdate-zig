#!/usr/bin/env python3
"""Check the vendored C amalgamation against its pinned release tag.

    python tools/check_vendor.py
    python tools/check_vendor.py --source /path/to/nepdate-c

The first form checks the checked-in SHA256SUMS. The second also compares every
file with a checkout or extracted tarball of the tag in VENDORED_FROM.
"""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VENDOR = ROOT / "vendor" / "nepdate-c"
FILES = ("nepdate.c", "nepdate.h", "nepdate_patro.c", "nepdate_patro.h", "LICENSE")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expected_hashes() -> dict[str, str]:
    result = {}
    for line in (VENDOR / "SHA256SUMS").read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        value, name = line.split()
        result[name] = value
    return result


def metadata() -> dict[str, str]:
    result = {}
    for line in (VENDOR / "VENDORED_FROM").read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            result[key] = value
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, help="checkout or extracted archive of the pinned tag")
    args = parser.parse_args()

    wanted = expected_hashes()
    if set(wanted) != set(FILES):
        print(f"FAIL: SHA256SUMS lists {sorted(wanted)}, expected {sorted(FILES)}")
        return 1

    for name in FILES:
        actual = digest(VENDOR / name)
        if actual != wanted[name]:
            print(f"FAIL: vendor/nepdate-c/{name} has sha256 {actual}, expected {wanted[name]}")
            return 1

    info = metadata()
    for key in ("repository", "tag", "commit"):
        if not info.get(key):
            print(f"FAIL: VENDORED_FROM has no {key}")
            return 1

    header = (VENDOR / "nepdate.h").read_text(encoding="utf-8")
    if '"0.2.0-rc.1"' not in header or info["tag"] != "v0.2.0-rc.1":
        print("FAIL: the header version and the pinned tag disagree")
        return 1

    if args.source:
        source = args.source
        for name in FILES:
            candidates = [source / name, source / "dist" / name]
            path = next((candidate for candidate in candidates if candidate.is_file()), None)
            if path is None:
                print(f"FAIL: {name} is missing from the source")
                return 1
            if digest(path) != wanted[name]:
                print(f"FAIL: {path} differs from the vendored copy")
                return 1

    print(f"vendor OK: {len(FILES)} files at {info['tag']} ({info['commit'][:7]})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
