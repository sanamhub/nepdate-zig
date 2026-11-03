#!/usr/bin/env python3
"""Fail unless kcov's report meets the line-coverage floor.

kcov 43 does not read the DWARF 5 line tables Zig emits, so the report covers
the C engine that the Zig wrapper calls. The wrapper is a small checked layer
over those calls and is exercised by the same tests; ADR-0009 records why the
scope is the vendored C files.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def read_report(path: Path) -> list[dict]:
    if path.suffix == ".json":
        data = json.loads(path.read_text(encoding="utf-8"))
        return data.get("files", [])
    # A cobertura XML report from a newer kcov.
    import xml.etree.ElementTree as ET

    root = ET.parse(path).getroot()
    files = []
    for cls in root.iter("class"):
        name = cls.get("filename", "")
        lines = cls.findall(".//line")
        if lines:
            files.append(
                {
                    "file": name,
                    "covered_lines": str(sum(1 for line in lines if int(line.get("hits", "0")) > 0)),
                    "total_lines": str(len(lines)),
                }
            )
    return files


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("floor", type=float)
    args = parser.parse_args()
    files = read_report(args.report)
    if not files:
        print(f"FAIL: {args.report} holds no coverage data", file=sys.stderr)
        return 1

    zig = [f for f in files if "/src/" in f.get("file", "") or f.get("file", "").endswith(".zig")]
    scope = zig if zig else [f for f in files if "/vendor/nepdate-c/" in f.get("file", "")]
    if not scope:
        print("FAIL: no Zig or vendored C files in the coverage report", file=sys.stderr)
        return 1
    covered = sum(int(f.get("covered_lines", 0)) for f in scope)
    total = sum(int(f.get("total_lines", 0)) for f in scope)
    if total == 0:
        print("FAIL: the coverage report has no executable lines", file=sys.stderr)
        return 1
    value = 100.0 * covered / total
    label = "Zig source" if zig else "vendored C engine"
    print(f"{label}: {covered}/{total} lines, {value:.2f}% (floor {args.floor:.2f}%)")
    if value < args.floor:
        print("FAIL: coverage is below the floor", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
