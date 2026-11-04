#!/usr/bin/env python3
"""Check that every public Zig function is called from a test.

kcov cannot read the DWARF 5 line tables Zig 0.17 writes (ADR-0009), so the
line gate stays on the vendored C engine. This check is the Zig-side gate: it
lists each `pub fn` in `src/` and looks for a call in `tests/`, `examples/` or
a `test` block in `src/`. It is a name-level check, not a line count, and it
does not see calls made through a function pointer or a format specifier, so
the two exceptions below are explicit.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# Status helpers are package plumbing between the core and patro modules, not
# part of the documented API; the C declarations live in the same folder.
INTERNAL = {"checkStatus", "checkStatusRaw"}

# `Date.format` and `Range.format` are reached through `{f}`, which has no call
# syntax to find.
FORMAT_METHODS = {"format"}

PUB = re.compile(r"^\s*pub\s+(?:inline\s+)?fn\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
TEST_BLOCK = re.compile(r'test\s+"[^"]+"\s*\{(.*?)^\}', re.M | re.S)
CALL = r"\b{name}\s*\("


def source_functions() -> list[tuple[str, str]]:
    found: list[tuple[str, str]] = []
    for path in sorted(SRC.glob("*.zig")):
        if path.name in {"c.zig", "patro_c.zig"}:
            continue
        text = path.read_text(encoding="utf-8")
        for match in PUB.finditer(text):
            name = match.group(1)
            if name not in INTERNAL:
                found.append((path.name, name))
    return found


def test_corpus() -> str:
    parts: list[str] = []
    for folder in ("tests", "examples"):
        for path in sorted((ROOT / folder).rglob("*.zig")):
            parts.append(path.read_text(encoding="utf-8"))
    for path in sorted(SRC.glob("*.zig")):
        text = path.read_text(encoding="utf-8")
        parts.extend(TEST_BLOCK.findall(text))
    return "\n".join(parts)


def main() -> int:
    corpus = test_corpus()
    functions = source_functions()
    missing: list[str] = []
    for file_name, name in functions:
        if name in FORMAT_METHODS and '"{f}"' in corpus:
            continue
        if re.search(CALL.format(name=re.escape(name)), corpus):
            continue
        missing.append(f"{file_name}: {name}")

    if missing:
        print("FAIL: public functions with no test call:", file=sys.stderr)
        for item in missing:
            print(f"  {item}", file=sys.stderr)
        return 1
    print(f"public API: {len(functions)} functions, all called from a test")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
