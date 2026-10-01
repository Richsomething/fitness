#!/usr/bin/env python3
"""Counts the Russian words in the app's string literals, per source file.

The text budget (docs/design/design-system.md, "Бюджет текста") needs a number to be checked against, and
this is it. It counts what could end up on a screen: Cyrillic string literals in Features/ and Domain/,
without accessibility labels, hints, values and comments. An interpolation (\\(...)) counts as one word.
It does not run the app, so it measures what is in the code, not what is visible at once.

Usage:
    python3 tools/count_text.py            # the top 15 files and the totals
    python3 tools/count_text.py --all      # every file
    python3 tools/count_text.py --over 100 # exit 1 if any file has more than 100 words, for a check before commit
"""
import argparse
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "MaestroFelix")
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*[А-Яа-яЁё](?:[^"\\]|\\.)*)"')
SKIP_LINE = re.compile(r"accessibility(Label|Hint|Value)|///|^\s*//")


def words_in(path):
    total = 0
    for line in open(path, encoding="utf8"):
        if SKIP_LINE.search(line):
            continue
        for match in LITERAL.finditer(line):
            total += len(re.sub(r"\\\([^)]*\)", "X", match.group(1)).split())
    return total


def collect(folder):
    rows = []
    for base, _, files in os.walk(os.path.join(ROOT, folder)):
        for name in files:
            if name.endswith(".swift"):
                path = os.path.join(base, name)
                rows.append((words_in(path), os.path.relpath(path, ROOT)))
    return sorted(rows, reverse=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--all", action="store_true", help="list every file")
    parser.add_argument("--over", type=int, metavar="N", help="exit 1 if a file has more than N words")
    args = parser.parse_args()

    features, domain = collect("Features"), collect("Domain")
    rows = sorted(features + domain, reverse=True)
    for words, path in rows if args.all else rows[:15]:
        print(f"{words:5d}  {path}")
    print(f"\nFeatures: {sum(w for w, _ in features)} words in {len(features)} files")
    print(f"Domain:   {sum(w for w, _ in domain)} words in {len(domain)} files")

    if args.over is not None:
        heavy = [(w, p) for w, p in rows if w > args.over]
        if heavy:
            print(f"\nOver {args.over} words: " + ", ".join(f"{p} ({w})" for w, p in heavy))
            sys.exit(1)


if __name__ == "__main__":
    main()
