#!/usr/bin/env python3
"""Check the public documentation shape and its no-row-ID rule."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GROUPS = (
    "Dates, identity and comparison",
    "Conversion and serialization",
    "Arithmetic",
    "Formatting",
    "Parsing",
    "Ranges",
    "Fiscal year",
    "Patro",
)


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> int:
    api = (ROOT / "docs" / "API.md").read_text(encoding="utf-8")
    for group in GROUPS:
        if group not in api:
            fail(f"docs/API.md does not document the {group} group")
    if not re.search(r"^## Install", (ROOT / "README.md").read_text(encoding="utf-8"), re.MULTILINE):
        fail("README.md has no Install section")
    for path in [ROOT / "README.md", ROOT / "docs" / "API.md"]:
        text = path.read_text(encoding="utf-8")
        if re.search(r"\b(?:ND|NC|NA|NF|NP|NR|NY|NT)\d{2}\b", text):
            fail(f"{path.relative_to(ROOT)} names an API row ID; name the C# member instead")
        for link in re.findall(r"\]\(([^)]+)\)", text):
            if link.startswith(("http://", "https://", "#", "mailto:")):
                continue
            if link.startswith("<"):
                link = link[1:-1]
            target = (path.parent / link.split("#", 1)[0]).resolve()
            if not target.exists():
                fail(f"{path.relative_to(ROOT)} links to missing {link}")
    adr = ROOT / "docs" / "adr" / "README.md"
    if not adr.is_file():
        fail("docs/adr/README.md is missing")
    for number in range(1, 11):
        matches = list((ROOT / "docs" / "adr").glob(f"{number:04d}-*.md"))
        if len(matches) != 1:
            fail(f"docs/adr has {len(matches)} files numbered {number:04d}")
    print("documentation OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
