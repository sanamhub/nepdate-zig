#!/usr/bin/env python3
"""Validate the release manifests, changelog and source archive.

    python tools/release_check.py --draft
    python tools/release_check.py --tag v1.0.0-rc.1 --archive

The draft form is what CI runs on every pull request: it accepts the
"Unreleased" changelog heading until the version bump pull request. A real tag
must have the heading for its own version.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION_RE = re.compile(r'\.version\s*=\s*"([^"]+)"')


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def manifest_version() -> str:
    text = (ROOT / "build.zig.zon").read_text(encoding="utf-8")
    match = VERSION_RE.search(text)
    if not match:
        fail("build.zig.zon has no .version")
    return match.group(1)


def check_changelog(version: str, draft: bool) -> None:
    text = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    headings = re.findall(r"^## \[([^\]]+)\]", text, re.MULTILINE)
    if not headings or headings[0] != "Unreleased":
        fail("CHANGELOG.md must start with the [Unreleased] section")
    if not draft and version not in headings:
        fail(f"CHANGELOG.md has no [{version}] heading")


def check_readme(version: str) -> None:
    text = (ROOT / "README.md").read_text(encoding="utf-8")
    if version not in text:
        fail(f"README.md does not name {version}")
    for section in (
        "## Install",
        "## Quick start",
        "## Dates",
        "## Conversion and serialization",
        "## Arithmetic",
        "## Formatting",
        "## Parsing",
        "## Ranges",
        "## Fiscal year",
        "## Today",
        "## Patro: tithi, holidays and events",
        "## Supported versions and platforms",
        "## Data and correctness",
        "## Documentation",
        "## Benchmarks",
        "## Contributing",
        "## Credit",
        "## License",
    ):
        if section not in text:
            fail(f"README.md is missing {section}")


def make_archive(version: str) -> Path:
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    name = f"nepdate-zig-{version}.tar.gz"
    target = dist / name
    prefix = f"nepdate-zig-{version}/"
    try:
        with target.open("wb") as handle:
            subprocess.run(
                ["git", "archive", "--format=tar.gz", f"--prefix={prefix}", "HEAD"],
                cwd=ROOT,
                check=True,
                stdout=handle,
            )
    except (OSError, subprocess.CalledProcessError) as error:
        fail(f"cannot create the source archive: {error}")
    sums = dist / "SHA256SUMS"
    sums.write_text(
        f"{hashlib.sha256(target.read_bytes()).hexdigest()}  {name}\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"archive: dist/{name} ({target.stat().st_size} bytes)")
    return target


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--draft", action="store_true")
    parser.add_argument("--tag")
    parser.add_argument("--archive", action="store_true")
    parser.add_argument("--no-archive", action="store_true")
    args = parser.parse_args()

    version = manifest_version()
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", version):
        fail(f"build.zig.zon version {version!r} is not SemVer")
    if args.tag:
        if args.tag != f"v{version}":
            fail(f"tag {args.tag} does not match build.zig.zon version {version}")
    check_changelog(version, args.draft)
    check_readme(version)
    if (ROOT / "NOTICE").is_file() and "Raju Prasai" not in (ROOT / "NOTICE").read_text(encoding="utf-8"):
        fail("NOTICE does not credit the C# original")
    if not args.no_archive:
        make_archive(version)
    print(f"release check OK: {version}{' (draft)' if args.draft else ''}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
